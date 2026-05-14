import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../achievement/screens/achievement_page.dart';
import '../../../core/config/app_config.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/models/local_tool_call.dart';
import '../../../core/models/local_tool_result.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/services/local_agent_runtime_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../reward/controllers/reward_controller.dart';
import '../../reward/models/reward.dart';
import '../../stats/screens/stats_page.dart';
import '../../reward/screens/reward_shop_page.dart';
import '../models/agent_run.dart';
import '../models/agent_step.dart';
import '../models/guide_chat_message.dart';
import '../models/quest_node.dart';
import '../services/agent_run_service.dart';
import '../services/weekly_summary_job_service.dart';
import 'quest_controller.dart';

// ---------------------------------------------------------------------------
// 公开类型
// ---------------------------------------------------------------------------

enum GuideConnectionStatus {
  ready,
  authExpired,
  network,
  service,
}

enum GuideActionType {
  generateTask,
  modifyTask,
  weeklySummary,
  openStats,
  openShop,
  redeemReward,
}

class GuideTurnResponse {
  final GuideChatResult result;
  final Future<void> Function()? postAction;
  final bool closeDialogBeforeAction;
  final bool appendAssistantReply;
  final GuideTaskEditDraft? pendingTaskEditDraft;
  final DateTime? pendingTaskDueDate;

  const GuideTurnResponse({
    required this.result,
    this.postAction,
    this.closeDialogBeforeAction = false,
    this.appendAssistantReply = true,
    this.pendingTaskEditDraft,
    this.pendingTaskDueDate,
  });
}

class GuideRewardMatch {
  final Reward? reward;
  final List<Reward> candidates;

  const GuideRewardMatch({
    this.reward,
    this.candidates = const <Reward>[],
  });
}

class AgentRunResult {
  final AgentRun? run;
  final List<AgentStep> steps;
  final String? latestAssistantMessage;

  const AgentRunResult({
    required this.run,
    required this.steps,
    this.latestAssistantMessage,
  });
}

const String localOnboardingEventId = 'local_onboarding_tutorial';

// ---------------------------------------------------------------------------
// GuideController
// ---------------------------------------------------------------------------

class GuideController extends ChangeNotifier {
  final QuestController _controller;
  final GuideService guideService = GuideService();
  final AgentRunService agentRunService = AgentRunService();
  late final LocalAgentRuntimeService localAgentRuntimeService;

  GuideController({required QuestController questController})
      : _controller = questController {
    localAgentRuntimeService = LocalAgentRuntimeService(
      questCreateHandler: executeAgentQuestCreate,
      questUpdateHandler: executeAgentQuestUpdate,
      questSplitHandler: executeAgentQuestSplit,
      chatFreeformHandler: executeAgentFreeformChat,
      weeklySummaryGenerateHandler: executeAgentWeeklySummaryGenerate,
      rewardRedeemHandler: executeAgentRewardRedeem,
      navigationOpenHandler: executeAgentNavigationOpen,
    );
    agentRunService.addListener(_onAgentRunStateChanged);
  }

  // ---- Guide 状态 ----

  GuideConnectionStatus guideStatus = GuideConnectionStatus.ready;
  bool isGuideBootstrapping = false;
  bool isGuideEventHandling = false;
  final List<GuideChatMessage> guideMessages = <GuideChatMessage>[];
  GuideDailyEvent? latestDailyEvent;
  List<MemoryRecommendation> recommendations = const <MemoryRecommendation>[];
  String? guideDisplayName;
  String? profileDisplayName;
  String guideMemoryDigest = '';
  List<String> guideBehaviorSignals = const <String>[];
  GuideTaskEditDraft? pendingGuideTaskEditDraft;
  DateTime? pendingGuideTaskDueDate;
  final List<String> recentlyDeletedGuideTaskTitles = <String>[];

  // ---- Agent 状态 ----

  final Set<String> runningLocalAgentStepIds = <String>{};
  final Set<String> finishedLocalAgentStepIds = <String>{};
  final Map<String, LocalToolResult> localAgentStepResults =
      <String, LocalToolResult>{};
  String? trackedAgentRunId;

  // ---- 生命周期 ----

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// 由页面 initState 调用
  Future<void> init(Future<void> initFuture) async {
    await loadGuideDisplayName();
    await loadProfileDisplayName();
  }

  @override
  void dispose() {
    _disposed = true;
    agentRunService.removeListener(_onAgentRunStateChanged);
    agentRunService.dispose();
    super.dispose();
  }

  // =========================================================================
  // 名称与上下文
  // =========================================================================

  String getGuideName(BuildContext context) {
    final value = guideDisplayName?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return context.tr('guide.name.default');
  }

  String guideMemorySummary(BuildContext context) {
    final digest = guideMemoryDigest.trim();
    if (digest.isEmpty) {
      return context.tr(
        'guide.memory.empty',
        params: {'name': getGuideName(context)},
      );
    }
    return digest.split('\n').first.trim();
  }

  Future<void> loadGuideDisplayName() async {
    final stored = await PreferencesService.guideDisplayName();
    final resolved =
        await guideService.resolveDisplayName(localFallback: stored);
    await PreferencesService.setGuideDisplayName(resolved);
    guideDisplayName = resolved;
    notifyListeners();
  }

  String guideText(String zh, String en) {
    return AppLocaleController.instance.isEnglish ? en : zh;
  }

  Future<void> saveDisplayName(String? name) async {
    await guideService.saveDisplayName(name);
  }

  Future<GuideNightReflectionResult> nightReflection({
    required String dayId,
    String? uploadRequestId,
    required Map<String, dynamic> clientContext,
  }) {
    return guideService.nightReflection(
      dayId: dayId,
      uploadRequestId: uploadRequestId,
      clientContext: clientContext,
    );
  }

  Future<dynamic> generatePortrait({
    required String scene,
    required String style,
    bool forceRefresh = false,
  }) {
    return guideService.generatePortrait(
      scene: scene,
      style: style,
      forceRefresh: forceRefresh,
    );
  }

  Future<dynamic> acceptEvent({
    required String eventId,
    required bool accept,
  }) {
    return guideService.acceptEvent(eventId: eventId, accept: accept);
  }

  Future<void> loadProfileDisplayName() async {
    final name = await PreferencesService.profileDisplayName();
    profileDisplayName = name;
    notifyListeners();
  }

  Map<String, dynamic> buildGuideClientContext() {
    final activeTasks = _controller.activeQuests
        .where((quest) => !quest.isReward && !quest.isDeleted)
        .toList(growable: false);
    return <String, dynamic>{
      'guide_name': guideDisplayName?.trim().isNotEmpty == true
          ? guideDisplayName!.trim()
          : '小忆',
      'language_code': AppLocaleController.instance.locale.languageCode,
      'is_english': AppLocaleController.instance.isEnglish,
      'memory_digest': guideMemoryDigest.trim(),
      'behavior_signals': guideBehaviorSignals,
      'active_task_titles': activeTasks.map((quest) => quest.title).toList(),
      'active_task_ids': activeTasks.map((quest) => quest.id).toList(),
      'active_task_count': activeTasks.length,
      'recently_deleted_task_titles': recentlyDeletedGuideTaskTitles,
      'task_truth_rule':
          'Only active_task_titles are current tasks. Memory is historical context only. If a memory-mentioned task is not active, ask whether to recreate it instead of treating it as existing.',
      if (latestDailyEvent != null)
        'latest_daily_event': <String, dynamic>{
          'title': latestDailyEvent!.title,
          'reason': latestDailyEvent!.reason,
        },
    };
  }

  // =========================================================================
  // Bootstrap
  // =========================================================================

  Future<void> runBootstrapIfNeeded(Future<void> initFuture) async {
    if (isGuideBootstrapping) return;
    await initFuture;
    final guideEnabled = await PreferencesService.guideEnabled();
    final proactiveEnabled = await PreferencesService.guideProactiveEnabled();
    if (!guideEnabled || !proactiveEnabled) return;
    final today = localDateId();
    final lastDate = await PreferencesService.guideLastBootstrapDate();
    if (lastDate == today) return;

    isGuideBootstrapping = true;
    notifyListeners();
    try {
      final result = await guideService.bootstrap(
          scene: 'home', clientContext: buildGuideClientContext());
      guideStatus = GuideConnectionStatus.ready;
      guideMemoryDigest = result.memoryDigest.trim();
      guideBehaviorSignals = result.behaviorSignals.take(3).toList();
      recommendations = result.recommendations;
      notifyListeners();
      await PreferencesService.setGuideLastBootstrapDate(today);

      if (result.proactiveMessage.trim().isNotEmpty) {
        appendGuideMessage(
          'assistant',
          result.proactiveMessage,
          memoryRefs: result.memoryRefs,
        );
      }

      if (result.dailyEvent != null && result.dailyEvent!.isPending) {
        latestDailyEvent = result.dailyEvent;
        notifyListeners();
      }
    } catch (e) {
      guideStatus = statusFromError(e);
      notifyListeners();
    } finally {
      isGuideBootstrapping = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // 每日事件 / Onboarding
  // =========================================================================

  Future<void> handleDailyEventDecision(String eventId, bool accept) async {
    if (eventId == localOnboardingEventId) {
      return handleOnboardingTutorialDecision(accept);
    }
    if (isGuideEventHandling) return;
    isGuideEventHandling = true;
    notifyListeners();
    try {
      final result =
          await guideService.acceptEvent(eventId: eventId, accept: accept);
      if (accept && result.accepted) {
        await _controller.refreshQuests();
      }
      latestDailyEvent = null;
      notifyListeners();
    } catch (_) {
      // silent
    } finally {
      isGuideEventHandling = false;
      notifyListeners();
    }
  }

  Future<void> handleOnboardingTutorialDecision(bool accept) async {
    if (isGuideEventHandling) return;
    if (!accept) {
      latestDailyEvent = null;
      notifyListeners();
      return;
    }
    isGuideEventHandling = true;
    notifyListeners();
    try {
      final guideName = guideDisplayName?.trim().isNotEmpty == true
          ? guideDisplayName!.trim()
          : '小忆';
      await _controller.addOnboardingTutorialBundle(guideName: guideName);
      latestDailyEvent = null;
      notifyListeners();
    } finally {
      isGuideEventHandling = false;
      notifyListeners();
    }
  }

  bool isOnboardingEvent(GuideDailyEvent event) {
    return event.eventId == localOnboardingEventId;
  }

  bool isOnboardingEventId(String eventId) {
    return eventId == localOnboardingEventId;
  }

  // =========================================================================
  // Guide 对话处理
  // =========================================================================

  Future<GuideTurnResponse> handleGuideTurn(String text) async {
    if (pendingGuideTaskEditDraft != null &&
        (isGuideConfirmationText(text) || isGuideCancellationText(text))) {
      return _handlePendingGuideTaskEdit(text);
    }

    if (shouldRouteToAgent(text)) {
      const fallbackReply = 'Let me think about that...';
      try {
        final localResult = await startAgentRunFromGuideInput(text);
        final guideChatResult =
            extractGuideChatResultFromAgentLocalResult(localResult);
        final latest = currentAgentRunLatestMessage();
        final localOutput = localResult?.outputText.trim() ?? '';
        final navigationTarget =
            '${localResult?.resultJson?['navigation_target'] ?? ''}'.trim();
        final result = guideChatResult ??
            GuideChatResult(
              reply: localOutput.isNotEmpty
                  ? localOutput
                  : (latest ?? fallbackReply),
              intent: GuideChatIntent.action,
              quickActions: const <String>[],
              messageCard: null,
              resultCard: null,
              suggestedTask: null,
              taskEditDraft: null,
              memoryRefs: const <String>[],
            );
        return GuideTurnResponse(
          result: result,
          pendingTaskEditDraft: result.taskEditDraft,
          closeDialogBeforeAction: navigationTarget.isNotEmpty,
          appendAssistantReply: guideChatResult != null,
        );
      } catch (_) {
        final action = matchGuideAction(text);
        if (action != null) {
          return handleGuideAction(text);
        }
        final localResult = await executeAgentFreeformChat(
          <String, dynamic>{'source_text': text},
        );
        final result =
            extractGuideChatResultFromAgentLocalResult(localResult) ??
                GuideChatResult(
                  reply: localResult.outputText.trim().isEmpty
                      ? fallbackReply
                      : localResult.outputText.trim(),
                  intent: GuideChatIntent.companion,
                  quickActions:
                      buildGuideQuickActions(GuideChatIntent.companion),
                  messageCard: null,
                  resultCard: null,
                  suggestedTask: null,
                  taskEditDraft: null,
                  memoryRefs: const <String>[],
                );
        return GuideTurnResponse(
          result: result,
          pendingTaskEditDraft: result.taskEditDraft,
        );
      }
    }

    final intent = classifyGuideIntent(text);
    if (intent == GuideChatIntent.action) {
      pendingGuideTaskEditDraft = null;
      pendingGuideTaskDueDate = null;
      return handleGuideAction(text);
    }

    final result = await guideService.chat(
      message: text,
      scene: 'home',
      clientContext: buildGuideClientContext(),
    );

    if (result.reply.trim().isNotEmpty ||
        result.messageCard != null ||
        result.resultCard != null ||
        result.quickActions.isNotEmpty) {
      return GuideTurnResponse(
        result: result,
        pendingTaskEditDraft:
            shouldKeepPendingGuideTaskEditDraft(result.taskEditDraft)
                ? result.taskEditDraft
                : null,
        pendingTaskDueDate: null,
      );
    }

    return GuideTurnResponse(
      result: intent == GuideChatIntent.advice
          ? buildAdviceGuideResult(text)
          : buildCompanionGuideResult(text),
    );
  }

  Future<GuideTurnResponse> handleGuideAction(String text) async {
    final action = matchGuideAction(text);
    if (action == null) {
      return GuideTurnResponse(result: buildCompanionGuideResult(text));
    }
    switch (action) {
      case GuideActionType.generateTask:
        return _handleGuideGenerateTask(text);
      case GuideActionType.modifyTask:
        return _handleGuideModifyTask(text);
      case GuideActionType.weeklySummary:
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: '正在为你生成周报…',
            intent: GuideChatIntent.action,
            quickActions: buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: null,
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      case GuideActionType.openStats:
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: '已打开统计页。',
            intent: GuideChatIntent.action,
            quickActions: buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: null,
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      case GuideActionType.openShop:
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: '已打开商店。',
            intent: GuideChatIntent.action,
            quickActions: buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: null,
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      case GuideActionType.redeemReward:
        return _handleGuideRedeemReward(text);
    }
  }

  // =========================================================================
  // 消息管理
  // =========================================================================

  void appendGuideMessage(
    String role,
    String content, {
    List<String> memoryRefs = const <String>[],
    String? agentStepId,
  }) {
    final text = content.trim();
    if (text.isEmpty) return;
    guideMessages.add(
      GuideChatMessage(
        role: role,
        content: text,
        memoryRefCount: memoryRefs.length,
        memoryRefs: memoryRefs,
        agentStepId: agentStepId,
      ),
    );
    if (guideMessages.length > 60) {
      guideMessages.removeRange(0, guideMessages.length - 60);
    }
    notifyListeners();
  }

  List<GuideChatMessage> visibleGuideMessages() {
    return guideMessages
        .where((message) => message.agentStepId == null)
        .toList(growable: false);
  }

  // =========================================================================
  // Agent 运行时
  // =========================================================================

  void _onAgentRunStateChanged() {
    final runId = agentRunService.currentRun?.id;
    if (trackedAgentRunId != runId) {
      trackedAgentRunId = runId;
      runningLocalAgentStepIds.clear();
      finishedLocalAgentStepIds.clear();
      localAgentStepResults.clear();
    }
    notifyListeners();
    unawaited(tryExecuteReadyAgentStep());
  }

  Future<LocalToolResult?> startAgentRunFromGuideInput(String text) async {
    runningLocalAgentStepIds.clear();
    finishedLocalAgentStepIds.clear();
    localAgentStepResults.clear();
    final snapshot = await agentRunService.startRun(
      goal: text,
      clientContext: buildGuideClientContext(),
    );
    trackedAgentRunId = snapshot.run.id;
    appendAgentMessagesFromSteps(snapshot.steps);
    final immediateResult = await tryExecuteReadyAgentStep();
    if (immediateResult != null) return immediateResult;
    final pendingStepId = agentRunService.latestStep?.id;
    if (pendingStepId == null || pendingStepId.isEmpty) return null;
    return waitForLocalAgentStepResult(pendingStepId);
  }

  Future<LocalToolResult?> waitForLocalAgentStepResult(
    String stepId, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = localAgentStepResults[stepId];
      if (result != null) return result;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    final result = localAgentStepResults[stepId];
    if (result != null) return result;
    return const LocalToolResult(
      success: false,
      outputText: '',
      errorText: '_agentTimeout',
    );
  }

  void appendAgentMessagesFromSteps(List<AgentStep> steps) {
    final existingKeys = guideMessages
        .where((message) => message.agentStepId != null)
        .map((message) => '${message.role}:${message.agentStepId}')
        .toSet();

    for (final step in steps) {
      if ((step.outputText ?? '').trim().isEmpty) continue;
      if (!shouldShowAgentStepMessage(step)) continue;
      final role = step.kind == 'error' ? 'assistant' : 'assistant';
      final key = '$role:${step.id}';
      if (existingKeys.contains(key)) continue;
      appendGuideMessage(
        role,
        step.outputText!.trim(),
        agentStepId: step.id,
      );
      existingKeys.add(key);
    }
  }

  Future<LocalToolResult?> tryExecuteReadyAgentStep() async {
    final run = agentRunService.currentRun;
    final step = agentRunService.latestStep;
    if (run == null || step == null) return null;
    final cachedResult = localAgentStepResults[step.id];
    if (cachedResult != null) return cachedResult;
    if (!step.isToolCall || !step.isReady || step.needsConfirmation) {
      return null;
    }
    if (runningLocalAgentStepIds.contains(step.id) ||
        finishedLocalAgentStepIds.contains(step.id)) {
      return null;
    }

    runningLocalAgentStepIds.add(step.id);
    try {
      late final LocalToolResult result;
      try {
        result = await localAgentRuntimeService.execute(
          LocalToolCall(
            stepId: step.id,
            toolName: step.toolName ?? '',
            arguments: step.argumentsJson,
          ),
        );
      } catch (error) {
        result = LocalToolResult(
          success: false,
          outputText: '本地步骤执行失败：$error',
          errorText: 'local_agent_execution_exception',
          resultJson: <String, dynamic>{
            'step_id': step.id,
            'tool_name': step.toolName,
            'error': '$error',
          },
        );
      }
      localAgentStepResults[step.id] = result;
      final snapshot = await agentRunService.reportLatestLocalResult(
        success: result.success,
        outputText: result.outputText,
        errorText: result.errorText,
        resultJson: result.resultJson,
      );
      finishedLocalAgentStepIds.add(step.id);
      if (snapshot != null) {
        appendAgentMessagesFromSteps(snapshot.steps);
      }
      return result;
    } finally {
      runningLocalAgentStepIds.remove(step.id);
    }
  }

  Future<void> approveLatestAgentStep() async {
    final snapshot = await agentRunService.approveLatestStep();
    if (snapshot != null) {
      appendAgentMessagesFromSteps(snapshot.steps);
      await tryExecuteReadyAgentStep();
    }
  }

  Future<void> rejectLatestAgentStep() async {
    final snapshot = await agentRunService.rejectLatestStep();
    if (snapshot != null) {
      appendAgentMessagesFromSteps(snapshot.steps);
    }
  }

  String? currentAgentRunLatestMessage() {
    for (final msg in visibleGuideMessages().reversed) {
      if (msg.role == 'assistant' && msg.content.trim().isNotEmpty) {
        return msg.content.trim();
      }
    }
    return null;
  }

  // =========================================================================
  // Agent 执行器
  // =========================================================================

  Future<LocalToolResult> executeAgentQuestCreate(
    Map<String, dynamic> arguments,
  ) async {
    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    final explicitTitle = '${arguments['title'] ?? ''}'.trim();
    final baseText = explicitTitle.isNotEmpty ? explicitTitle : sourceText;
    final title = normalizeGuideTaskTitle(baseText);
    if (title.isEmpty) {
      return const LocalToolResult(
        success: false,
        outputText: '还没有识别到要创建的任务标题。',
        errorText: 'missing_task_title',
      );
    }

    final questTierRaw = '${arguments['quest_tier'] ?? ''}'.trim();
    final questTier = switch (questTierRaw) {
      'Main_Quest' => 'Main_Quest',
      'Side_Quest' => 'Side_Quest',
      _ => 'Daily',
    };
    final xpReward =
        (_parseAgentInt(arguments['xp_reward']) ?? 20).clamp(5, 200);
    final dailyDueMinutes = _parseAgentInt(arguments['daily_due_minutes']);
    final parentMainQuestId =
        '${arguments['parent_main_quest_id'] ?? ''}'.trim().isEmpty
            ? null
            : '${arguments['parent_main_quest_id'] ?? ''}'.trim();

    final inserted = await _controller.createManualQuest(
      title: title,
      description: guideTaskDescription(sourceText.isNotEmpty ? sourceText : title),
      questTier: questTier,
      parentMainQuestId: parentMainQuestId,
      dailyDueMinutes: dailyDueMinutes,
      xpReward: xpReward,
    );
    if (inserted == null) {
      return const LocalToolResult(
        success: false,
        outputText: '任务创建失败，请稍后再试。',
        errorText: 'quest_create_failed',
      );
    }

    final subtasks = _parseAgentSubtasks(arguments);
    final createdChildren = subtasks.isEmpty
        ? const <QuestNode>[]
        : await _controller.addGuideChildTasks(
            parent: inserted,
            stepTitles: subtasks,
            xpReward: (inserted.xpReward / 2).round(),
          );

    return LocalToolResult(
      success: true,
      outputText: createdChildren.isEmpty
          ? '已创建任务：${inserted.title}'
          : '已创建任务：${inserted.title}，并补充 ${createdChildren.length} 个子任务',
      resultJson: <String, dynamic>{
        'created_task_id': inserted.id,
        'created_task_title': inserted.title,
        if (createdChildren.isNotEmpty)
          'created_subtasks':
              createdChildren.map((item) => item.title).toList(growable: false),
      },
    );
  }

  Future<LocalToolResult> executeAgentQuestUpdate(
    Map<String, dynamic> arguments,
  ) async {
    final target = findAgentTargetTaskByArguments(arguments);
    if (target == null) {
      return const LocalToolResult(
        success: false,
        outputText: '没有找到要更新的任务。',
        errorText: 'quest_not_found',
      );
    }

    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    final nextTitleRaw = '${arguments['updated_title'] ?? ''}'.trim();
    final nextTitle = nextTitleRaw.isNotEmpty
        ? nextTitleRaw
        : (sourceText.isNotEmpty
            ? extractGuideNaturalTitleFromModifyText(sourceText, target)
            : null);
    final nextDescriptionRaw =
        '${arguments['updated_description'] ?? ''}'.trim();
    final nextDescription =
        nextDescriptionRaw.isEmpty ? null : nextDescriptionRaw;
    final nextXp = (_parseAgentInt(arguments['updated_xp_reward']) ??
            (sourceText.isNotEmpty ? extractGuideXp(sourceText) : null))
        ?.clamp(5, 200);
    final dueDate = _parseAgentDueDate(arguments);
    final dailyDueMinutes = _parseAgentInt(arguments['daily_due_minutes']);

    if (nextTitle == null &&
        nextDescription == null &&
        nextXp == null &&
        dueDate == null &&
        dailyDueMinutes == null) {
      return const LocalToolResult(
        success: false,
        outputText: '没有识别到可更新的任务字段。',
        errorText: 'quest_update_empty',
      );
    }

    await _controller.updateQuestDetails(
      target.id,
      title: nextTitle,
      description: nextDescription,
      dueDate: dueDate,
      dailyDueMinutes: dailyDueMinutes,
      xpReward: nextXp,
    );

    return LocalToolResult(
      success: true,
      outputText: '已更新任务：${nextTitle ?? target.title}',
      resultJson: <String, dynamic>{
        'updated_task_id': target.id,
        'updated_task_title': nextTitle ?? target.title,
        if (dueDate != null) 'due_at': dueDate.toIso8601String(),
      },
    );
  }

  Future<LocalToolResult> executeAgentQuestSplit(
    Map<String, dynamic> arguments,
  ) async {
    final target = findAgentTargetTaskByArguments(arguments);
    if (target == null) {
      return const LocalToolResult(
        success: false,
        outputText: '没有找到要拆分的任务。',
        errorText: 'quest_not_found',
      );
    }

    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    final subtasks = _parseAgentSubtasks(arguments);
    final stepTitles = subtasks.isNotEmpty
        ? subtasks
        : buildGuideSplitSteps(
            target, sourceText.isNotEmpty ? sourceText : target.title);

    if (stepTitles.isEmpty) {
      return const LocalToolResult(
        success: false,
        outputText: '还没有识别到可拆分的子任务。',
        errorText: 'missing_subtasks',
      );
    }

    final inserted = await _controller.addGuideChildTasks(
      parent: target,
      stepTitles: stepTitles,
      xpReward: (target.xpReward / 2).round(),
    );
    if (inserted.isEmpty) {
      return const LocalToolResult(
        success: false,
        outputText: '任务拆分失败，请稍后再试。',
        errorText: 'quest_split_failed',
      );
    }

    return LocalToolResult(
      success: true,
      outputText: '已拆分任务：${target.title}，新增 ${inserted.length} 个子任务',
      resultJson: <String, dynamic>{
        'parent_task_id': target.id,
        'parent_task_title': target.title,
        'created_subtasks':
            inserted.map((item) => item.title).toList(growable: false),
      },
    );
  }

  Future<LocalToolResult> executeAgentFreeformChat(
    Map<String, dynamic> arguments,
  ) async {
    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    if (sourceText.isEmpty) {
      return const LocalToolResult(
        success: false,
        outputText: '还没有收到要继续聊天的内容。',
        errorText: 'missing_chat_message',
      );
    }

    try {
      final result = await requestDirectFreeformChat(sourceText) ??
          await guideService
              .chat(
                message: sourceText,
                scene: 'home',
                clientContext: buildGuideClientContext(),
              )
              .timeout(const Duration(seconds: 8));
      final resolvedResult = result.reply.trim().isEmpty
          ? buildCompanionGuideResult(sourceText)
          : result;
      return LocalToolResult(
        success: true,
        outputText: resolvedResult.reply,
        resultJson: <String, dynamic>{
          'guide_chat_result': guideChatResultToJson(resolvedResult),
        },
      );
    } catch (_) {
      final fallback = buildCompanionGuideResult(sourceText);
      return LocalToolResult(
        success: true,
        outputText: fallback.reply,
        resultJson: <String, dynamic>{
          'guide_chat_result': guideChatResultToJson(fallback),
        },
      );
    }
  }

  Future<LocalToolResult> executeAgentWeeklySummaryGenerate(
    Map<String, dynamic> arguments,
  ) async {
    final job = await WeeklySummaryJobService.instance.enqueue();
    if (job == null) {
      return const LocalToolResult(
        success: false,
        outputText: '当前未登录，无法生成周报。',
        errorText: 'missing_user_session',
      );
    }
    return LocalToolResult(
      success: true,
      outputText: job.isActive ? '已开始生成本周周报' : '本周周报已可查看',
      resultJson: <String, dynamic>{
        'weekly_summary_job_id': job.id,
        'navigation_target': 'weekly_summary',
        'source_text': '${arguments['source_text'] ?? ''}',
      },
    );
  }

  Future<LocalToolResult> executeAgentRewardRedeem(
    Map<String, dynamic> arguments,
  ) async {
    final rewardController = RewardController(quest: _controller);
    try {
      await rewardController.loadRewards();
      await rewardController.loadInventory();
      final rewards = <Reward>[
        ...rewardController.systemRewards,
        ...rewardController.customRewards,
      ];
      final rewardTitle = '${arguments['reward_title'] ?? ''}'.trim();
      final sourceText = rewardTitle.isNotEmpty
          ? rewardTitle
          : '${arguments['source_text'] ?? ''}'.trim();
      final match = findGuideRewardMatch(sourceText, rewards);
      final reward = match.reward;
      if (reward == null) {
        return const LocalToolResult(
          success: false,
          outputText: '没有找到可兑换的奖励。',
          errorText: 'reward_not_found',
        );
      }
      if (_controller.currentGold < reward.cost) {
        return LocalToolResult(
          success: false,
          outputText: '金币不足，无法兑换 ${reward.localizedTitle(false)}',
          errorText: 'insufficient_gold',
        );
      }
      final redeemed = await rewardController.buyReward(reward);
      if (!redeemed) {
        return LocalToolResult(
          success: false,
          outputText: '奖励兑换失败：${reward.localizedTitle(false)}',
          errorText: 'reward_redeem_failed',
        );
      }
      return LocalToolResult(
        success: true,
        outputText: '已兑换奖励：${reward.localizedTitle(false)}',
        resultJson: <String, dynamic>{
          'reward_id': reward.id,
          'reward_title': reward.localizedTitle(false),
        },
      );
    } finally {
      rewardController.dispose();
    }
  }

  Future<LocalToolResult> executeAgentNavigationOpen(
    Map<String, dynamic> arguments,
  ) async {
    final target = '${arguments['target'] ?? ''}'.trim();
    if (target.isEmpty) {
      return const LocalToolResult(
        success: false,
        outputText: '没有指定要打开的页面。',
        errorText: 'missing_navigation_target',
      );
    }
    return LocalToolResult(
      success: true,
      outputText: switch (target) {
        'stats' => '已打开统计页',
        'shop' => '已打开商店',
        'weekly_summary' => '已打开周报页',
        _ => '已打开目标页面',
      },
      resultJson: <String, dynamic>{
        'navigation_target': target,
      },
    );
  }

  QuestNode? findAgentTargetTaskByArguments(Map<String, dynamic> arguments) {
    final taskId = '${arguments['task_id'] ?? ''}'.trim();
    if (taskId.isNotEmpty) {
      final byId =
          _controller.activeQuests.where((quest) => quest.id == taskId);
      if (byId.isNotEmpty) return byId.first;
    }
    final taskTitle = '${arguments['task_title'] ?? ''}'.trim();
    if (taskTitle.isNotEmpty) {
      final byTitle = _controller.activeQuests.where(
        (quest) =>
            !quest.isDeleted &&
            !quest.isReward &&
            quest.title.trim().toLowerCase() == taskTitle.toLowerCase(),
      );
      if (byTitle.isNotEmpty) return byTitle.first;
    }
    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    if (sourceText.isNotEmpty) {
      return findGuideTargetTask(sourceText);
    }
    return null;
  }

  // =========================================================================
  // 纯工具方法
  // =========================================================================

  int? _parseAgentInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  DateTime? _parseAgentDueDate(Map<String, dynamic> arguments) {
    final dueAt = '${arguments['due_at'] ?? ''}'.trim();
    if (dueAt.isNotEmpty) {
      final parsed = DateTime.tryParse(dueAt);
      if (parsed != null) return parsed.toLocal();
    }
    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    if (sourceText.isNotEmpty) {
      return extractGuideDueDate(sourceText);
    }
    return null;
  }

  List<String> _parseAgentSubtasks(Map<String, dynamic> arguments) {
    final raw = arguments['subtasks'];
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool shouldShowAgentStepMessage(AgentStep step) {
    final sourceTool = '${step.resultJson?['source_tool'] ?? ''}'.trim();
    return step.toolName != 'app.chat.freeform.respond' &&
        sourceTool != 'app.chat.freeform.respond';
  }

  GuideConnectionStatus statusFromError(Object error) {
    if (error is GuideServiceException) {
      return switch (error.type) {
        GuideErrorType.authExpired => GuideConnectionStatus.authExpired,
        GuideErrorType.network => GuideConnectionStatus.network,
        GuideErrorType.service ||
        GuideErrorType.unknown =>
          GuideConnectionStatus.service,
      };
    }
    return GuideConnectionStatus.service;
  }

  String localDateId() {
    final now = DateTime.now().toLocal();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // =========================================================================
  // Guide 文本处理
  // =========================================================================

  String normalizeGuideTaskTitle(String raw) {
    final lowerRaw = raw.toLowerCase();
    if (raw.contains('恢复任务') || lowerRaw.contains('recovery task')) {
      return _randomGuideRecoveryTask();
    }
    var cleaned = raw
        .replaceAll('把这句变成任务', '')
        .replaceAll('变成任务', '')
        .replaceAll('生成任务', '')
        .replaceAll('帮我生成', '')
        .replaceAll('帮我创建', '')
        .replaceAll('帮我做成', '')
        .replaceAll('给我一个', '')
        .replaceAll('给我个', '')
        .replaceAll('给我来个', '')
        .replaceAll('创建任务', '')
        .replaceAll('创建', '')
        .replaceAll('做成任务', '')
        .replaceAll('帮我安排', '')
        .replaceAll('安排一下', '')
        .replaceAll('安排一个', '')
        .replaceAll('安排个', '')
        .replaceAll('帮我', '')
        .replaceAll('生成', '')
        .replaceAll('详细一点', '')
        .replaceAll('具体一点', '')
        .replaceAll('详细些', '')
        .replaceAll('更详细一点', '')
        .replaceAll('带子项', '')
        .replaceAll('带上子项', '')
        .replaceAll('加上子项', '')
        .replaceAll('Turn this into a quest', '')
        .replaceAll('turn this into a quest', '')
        .replaceAll('turn this into a task', '')
        .replaceAll('make this a task', '')
        .replaceAll('create a task', '')
        .replaceAll('generate a task', '')
        .replaceAll('help me create', '')
        .replaceAll('help me make', '')
        .replaceAll('help me generate', '')
        .replaceAll('give me a', '')
        .replaceAll('give me an', '')
        .replaceAll('more detailed', '')
        .replaceAll('more specific', '')
        .replaceAll('with subtasks', '')
        .replaceAll('with steps', '')
        .replaceAll('。', '')
        .replaceAll('.', '')
        .trim();
    if (cleaned.endsWith('任务')) {
      cleaned = cleaned.substring(0, cleaned.length - 2).trim();
    }
    if (cleaned.toLowerCase().endsWith(' task')) {
      cleaned = cleaned.substring(0, cleaned.length - 5).trim();
    }
    if (cleaned.endsWith('的')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    final lowerCleaned = cleaned.toLowerCase();
    if (cleaned == '恢复' ||
        cleaned == '恢复一下' ||
        lowerCleaned == 'recovery' ||
        lowerCleaned == 'recovery task') {
      return _randomGuideRecoveryTask();
    }
    if (cleaned.isEmpty) return '';
    final segments = cleaned.split(RegExp(r'[，,；;：:。.!?]'));
    return segments.first.trim();
  }

  String guideTaskDescription(String raw) {
    final cleaned = raw.replaceAll('。', '').trim();
    if (cleaned.isEmpty) {
      final name = guideDisplayName?.trim().isNotEmpty == true
          ? guideDisplayName!.trim()
          : '小忆';
      final isEnglish = AppLocaleController.instance.isEnglish;
      return isEnglish
          ? 'A new task $name organized from this conversation.'
          : '$name根据这次对话整理出的新任务。';
    }
    return cleaned;
  }

  QuestNode? findGuideTargetTask(String text) {
    final explicit = extractQuotedText(text);
    if (explicit != null && explicit.isNotEmpty) {
      for (final quest in _controller.activeQuests) {
        if (!quest.isCompleted &&
            !quest.isReward &&
            quest.title.trim() == explicit) {
          return quest;
        }
      }
    }
    for (final quest in _controller.activeQuests) {
      if (quest.isCompleted || quest.isReward) continue;
      if (text.contains(quest.title)) {
        return quest;
      }
    }
    return null;
  }

  int? extractGuideXp(String text) {
    final match = RegExp(r'(?:xp|经验|奖励)\D{0,3}(\d{1,3})', caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String? extractGuideNaturalTitleFromModifyText(
    String text,
    QuestNode target,
  ) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) return null;
    final escapedTitle = RegExp.escape(target.title.trim());
    final prefixes = <RegExp>[
      RegExp('^(?:修改|调整|改)\\s*$escapedTitle\\s*(?:的)?任务?'),
      RegExp('^把\\s*$escapedTitle\\s*(?:的)?任务?'),
      RegExp('^(?:修改|调整|改)\\s*(?:任务)?\\s*$escapedTitle'),
    ];
    for (final pattern in prefixes) {
      cleaned = cleaned.replaceFirst(pattern, '').trim();
    }
    cleaned = cleaned
        .replaceFirst(RegExp(r'^(?:改成|改为|改到|调整为|设为|为)'), '')
        .trim();
    final dueKeyword =
        RegExp(r'(?:截止时间?|到期时间?|截止|到期)').firstMatch(cleaned);
    if (dueKeyword != null) {
      cleaned = cleaned.substring(dueKeyword.end).trim();
    }
    cleaned = cleaned
        .replaceFirst(RegExp(r'^(?:今天|明天|后天)\s*'), '')
        .replaceFirst(
          RegExp(r'^(?:(?:\d{4}[/-])?\d{1,2}[/-]\d{1,2})\s*'),
          '',
        )
        .replaceFirst(
          RegExp(
            r'^(?:\d{1,2}\s*月\s*\d{1,2}\s*[日号]?|[零〇一二两三四五六七八九十]{1,4}\s*月\s*[零〇一二两三四五六七八九十]{1,3}\s*[日号]?)\s*',
          ),
          '',
        )
        .replaceFirst(RegExp(r'^[，,。:：\s]+'), '')
        .replaceAll(RegExp(r'[。]+$'), '')
        .trim();
    if (cleaned.isEmpty || cleaned == target.title.trim()) return null;
    return cleaned;
  }

  DateTime? extractGuideDueDate(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    final now = DateTime.now().toLocal();
    if (normalized.contains('今天')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (normalized.contains('明天')) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (normalized.contains('后天')) {
      return DateTime(now.year, now.month, now.day + 2);
    }
    final chineseMatch = RegExp(
      r'(?:(\d{4}|[零〇一二两三四五六七八九]{4})\s*年)?\s*([0-9零〇一二两三四五六七八九十]{1,3})\s*月\s*([0-9零〇一二两三四五六七八九十]{1,3})\s*[日号]?',
    ).firstMatch(normalized);
    if (chineseMatch != null) {
      final year = _parseGuideDigitText(
            chineseMatch.group(1) ?? '',
            allowSequence: true,
          ) ??
          now.year;
      final month = _parseGuideDigitText(chineseMatch.group(2) ?? '');
      final day = _parseGuideDigitText(chineseMatch.group(3) ?? '');
      if (month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    final slashMatch = RegExp(r'(?:(\d{4})[/-])?(\d{1,2})[/-](\d{1,2})')
        .firstMatch(normalized);
    if (slashMatch != null) {
      final year = int.tryParse(slashMatch.group(1) ?? '') ?? now.year;
      final month = int.tryParse(slashMatch.group(2) ?? '');
      final day = int.tryParse(slashMatch.group(3) ?? '');
      if (month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  int? _parseGuideDigitText(String raw, {bool allowSequence = false}) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final direct = int.tryParse(normalized);
    if (direct != null) return direct;
    const digits = <String, int>{
      '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2,
      '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
    };
    if (allowSequence &&
        normalized.split('').every((char) => digits.containsKey(char))) {
      final mapped = normalized.split('').map((char) => digits[char]).join();
      return int.tryParse(mapped);
    }
    if (!normalized.contains('十')) return digits[normalized];
    final parts = normalized.split('十');
    final tensRaw = parts.first.trim();
    final onesRaw = parts.length > 1 ? parts.last.trim() : '';
    final tens = tensRaw.isEmpty ? 1 : digits[tensRaw];
    final ones = onesRaw.isEmpty ? 0 : digits[onesRaw];
    if (tens == null || ones == null) return null;
    return tens * 10 + ones;
  }

  List<String> buildGuideSplitSteps(QuestNode quest, String text) {
    final explicitSteps = extractGuideStepTitles(text);
    if (explicitSteps.length >= 2) {
      return explicitSteps.take(3).toList();
    }
    final isEnglish = AppLocaleController.instance.isEnglish;
    if (isEnglish) {
      return <String>[
        'Clarify the goal of ${quest.title}',
        'Finish the first small step of ${quest.title}',
        'Review it and patch one detail',
      ];
    }
    return <String>[
      '确认${quest.title}的目标',
      '完成${quest.title}的第一小步',
      '回看并补一处细节',
    ];
  }

  bool shouldRouteToAgent(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return true;
  }

  bool isGuideConfirmationText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == '需要' ||
        normalized == '要' ||
        normalized == '要的' ||
        normalized == '好的' ||
        normalized == '好' ||
        normalized == '确认' ||
        normalized == '可以' ||
        normalized == '行' ||
        normalized == '继续' ||
        normalized == '是的' ||
        normalized == '嗯' ||
        normalized == 'yes' ||
        normalized == 'yep' ||
        normalized == 'sure' ||
        normalized == 'ok' ||
        normalized == 'okay' ||
        normalized == 'do it' ||
        normalized == 'continue';
  }

  bool isGuideCancellationText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == '不用' ||
        normalized == '先不用' ||
        normalized == '不用了' ||
        normalized == '不要' ||
        normalized == '先别' ||
        normalized == '算了' ||
        normalized == '取消' ||
        normalized == 'no' ||
        normalized == 'not now' ||
        normalized == 'skip' ||
        normalized == 'cancel';
  }

  GuideActionType? matchGuideAction(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('兑换') ||
        normalized.contains('换奖励') ||
        normalized.contains('买奖励') ||
        normalized.contains('redeem')) {
      return GuideActionType.redeemReward;
    }
    if (normalized.contains('商店') ||
        normalized.contains('商城') ||
        normalized.contains('shop')) {
      return GuideActionType.openShop;
    }
    if (normalized.contains('统计') || normalized.contains('stats')) {
      return GuideActionType.openStats;
    }
    if (normalized.contains('周报') ||
        normalized.contains('周总结') ||
        normalized.contains('weekly')) {
      return GuideActionType.weeklySummary;
    }
    if (normalized.contains('修改任务') ||
        normalized.contains('改任务') ||
        normalized.contains('改轻') ||
        normalized.contains('标题改成') ||
        normalized.contains('描述改成') ||
        normalized.contains('xp改') ||
        normalized.contains('经验改') ||
        (normalized.contains('拆成') && normalized.contains('任务'))) {
      return GuideActionType.modifyTask;
    }
    final hasSplitIntent = normalized.contains('拆成') ||
        normalized.contains('拆解') ||
        normalized.contains('拆开') ||
        normalized.contains('分成') ||
        normalized.contains('分解') ||
        normalized.contains('分步骤') ||
        normalized.contains('子项') ||
        normalized.contains('子任务');
    final hasDueDateIntent = normalized.contains('截止') ||
        normalized.contains('截止时间') ||
        normalized.contains('到期') ||
        normalized.contains('due');
    if (findGuideTargetTask(text) != null &&
        (hasSplitIntent ||
            hasDueDateIntent ||
            normalized.contains('修改') ||
            normalized.contains('调整'))) {
      return GuideActionType.modifyTask;
    }
    if (hasSplitIntent && findGuideTargetTask(text) != null) {
      return GuideActionType.modifyTask;
    }
    final mentionsTask = normalized.contains('任务');
    if (normalized.contains('恢复任务') ||
        normalized.contains('变成任务') ||
        normalized.contains('生成任务') ||
        normalized.contains('安排一下') ||
        normalized.contains('记成任务') ||
        (normalized.contains('生成') && normalized.contains('任务')) ||
        (normalized.contains('创建') && normalized.contains('任务')) ||
        (normalized.contains('安排') && normalized.contains('任务')) ||
        (normalized.contains('做成') && normalized.contains('任务')) ||
        (normalized.contains('帮我') && mentionsTask) ||
        (normalized.contains('给我一个') && mentionsTask) ||
        (normalized.contains('给我个') && mentionsTask)) {
      return GuideActionType.generateTask;
    }
    return null;
  }

  GuideChatIntent classifyGuideIntent(String text) {
    if (matchGuideAction(text) != null) return GuideChatIntent.action;
    final normalized = text.trim().toLowerCase();
    const adviceKeywords = <String>[
      '建议', '判断', '帮我理', '怎么选', '怎么办', '更适合',
      'advice', 'suggest', 'should i',
    ];
    if (adviceKeywords.any((keyword) => normalized.contains(keyword))) {
      return GuideChatIntent.advice;
    }
    return GuideChatIntent.companion;
  }

  GuideRewardMatch findGuideRewardMatch(String text, List<Reward> rewards) {
    final availableRewards = rewards
        .where((reward) => reward.title.trim().isNotEmpty)
        .toList(growable: false);
    if (availableRewards.isEmpty) return const GuideRewardMatch();
    final query = normalizeGuideLookup(extractQuotedGuidePhrase(text) ?? text);
    if (query.isEmpty) return const GuideRewardMatch();

    final isEnglish = AppLocaleController.instance.isEnglish;
    final exactMatches = availableRewards
        .where(
          (reward) => reward
              .localizedLookupTitles(isEnglish)
              .map(normalizeGuideLookup)
              .contains(query),
        )
        .toList(growable: false);
    if (exactMatches.length == 1) {
      return GuideRewardMatch(
        reward: exactMatches.first,
        candidates: exactMatches,
      );
    }
    if (exactMatches.length > 1) {
      return GuideRewardMatch(candidates: exactMatches);
    }
    final partialMatches = availableRewards.where((reward) {
      for (final candidate in reward.localizedLookupTitles(isEnglish)) {
        final title = normalizeGuideLookup(candidate);
        if (title.isNotEmpty &&
            (query.contains(title) || title.contains(query))) {
          return true;
        }
      }
      return false;
    }).toList(growable: false);
    if (partialMatches.length == 1) {
      return GuideRewardMatch(
        reward: partialMatches.first,
        candidates: partialMatches,
      );
    }
    return GuideRewardMatch(candidates: partialMatches);
  }

  GuideChatResult buildGuideRedeemRewardNeedConfirmation(
    String text, {
    List<Reward> candidates = const <Reward>[],
  }) {
    final rewardTitlesZh = candidates
        .map((reward) => reward.localizedTitle(false).trim())
        .where((title) => title.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final rewardTitlesEn = candidates
        .map((reward) => reward.localizedTitle(true).trim())
        .where((title) => title.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final hasCandidates =
        rewardTitlesZh.isNotEmpty && rewardTitlesEn.isNotEmpty;
    final zhCandidateList = rewardTitlesZh.join('、');
    final enCandidateList = rewardTitlesEn.join(', ');
    final firstZh = hasCandidates ? rewardTitlesZh.first : '';
    final firstEn = hasCandidates ? rewardTitlesEn.first : '';
    final isEnglish = AppLocaleController.instance.isEnglish;

    return GuideChatResult(
      reply: isEnglish
          ? 'I am not sure which reward you want to redeem yet. Tell me the reward name directly and I can keep going.'
          : '我还没确定你想兑换哪一个奖励。你可以直接说奖励名，我就能继续帮你处理。',
      intent: GuideChatIntent.advice,
      quickActions: buildGuideQuickActions(GuideChatIntent.advice),
      messageCard: GuideMessageCard(
        label: isEnglish ? 'Need your confirmation' : '还需要你确认',
        content: hasCandidates
            ? (isEnglish
                ? 'Possible matches so far: $enCandidateList. You can say "Redeem $firstEn".'
                : '我现在想到的候选有：$zhCandidateList。你可以直接说"兑换$firstZh"。')
            : (isEnglish
                ? 'I could not extract a reward name from "$text" yet. A clearer request like "Redeem Forest Theme" would help.'
                : '我还没从"$text"里抓到具体奖励名。你可以直接说"兑换森林主题"这种更明确的话。'),
      ),
      resultCard: null,
      suggestedTask: null,
      taskEditDraft: null,
      memoryRefs: const <String>[],
    );
  }

  GuideChatResult buildCompanionGuideResult(String text) {
    final isEnglish = AppLocaleController.instance.isEnglish;
    return GuideChatResult(
      reply: isEnglish
          ? 'I am here with you. Take your time.'
          : '我在，你说，我听着。',
      intent: GuideChatIntent.companion,
      quickActions: buildGuideQuickActions(GuideChatIntent.companion),
      messageCard: null,
      resultCard: null,
      suggestedTask: null,
      taskEditDraft: null,
      memoryRefs: const <String>[],
    );
  }

  GuideChatResult buildAdviceGuideResult(String text) {
    final isEnglish = AppLocaleController.instance.isEnglish;
    return GuideChatResult(
      reply: isEnglish
          ? 'Let us sort the situation first.'
          : '我们先把情况理一理。',
      intent: GuideChatIntent.advice,
      quickActions: buildGuideQuickActions(GuideChatIntent.advice),
      messageCard: null,
      resultCard: null,
      suggestedTask: null,
      taskEditDraft: null,
      memoryRefs: const <String>[],
    );
  }

  List<String> buildGuideQuickActions(GuideChatIntent intent) {
    final isEnglish = AppLocaleController.instance.isEnglish;
    return switch (intent) {
      GuideChatIntent.action => isEnglish
          ? ['Create a task', 'Open stats', 'Weekly summary']
          : ['生成任务', '打开统计', '周报'],
      GuideChatIntent.advice => isEnglish
          ? ['Give me advice', 'What should I do', 'Help me decide']
          : ['给我建议', '怎么选', '帮我判断'],
      GuideChatIntent.companion => isEnglish
          ? ['I want to chat', 'Give me a task', 'How are you']
          : ['我想聊聊', '给我一个任务', '你好吗'],
    };
  }

  Map<String, dynamic> guideChatResultToJson(GuideChatResult result) {
    return <String, dynamic>{
      'reply': result.reply,
      'intent': switch (result.intent) {
        GuideChatIntent.action => 'action',
        GuideChatIntent.advice => 'advice',
        GuideChatIntent.companion => 'companion',
      },
      'quick_actions': result.quickActions,
      if (result.messageCard != null)
        'message_card': <String, dynamic>{
          'label': result.messageCard!.label,
          'content': result.messageCard!.content,
        },
      if (result.resultCard != null)
        'result_card': <String, dynamic>{
          'label': result.resultCard!.label,
          'title': result.resultCard!.title,
          'description': result.resultCard!.description,
        },
      if (result.suggestedTask != null)
        'suggested_task': <String, dynamic>{
          'title': result.suggestedTask!.title,
          'description': result.suggestedTask!.description,
          'xp_reward': result.suggestedTask!.xpReward,
          'quest_tier': result.suggestedTask!.questTier,
        },
      if (result.taskEditDraft != null)
        'task_edit_draft': <String, dynamic>{
          'task_id': result.taskEditDraft!.taskId,
          'task_title': result.taskEditDraft!.taskTitle,
          'action': result.taskEditDraft!.action,
          'updated_title': result.taskEditDraft!.updatedTitle,
          'updated_description': result.taskEditDraft!.updatedDescription,
          'updated_xp_reward': result.taskEditDraft!.updatedXpReward,
          'subtasks': result.taskEditDraft!.subtasks,
        },
      'memory_refs': result.memoryRefs,
    };
  }

  GuideChatResult? extractGuideChatResultFromAgentLocalResult(
    LocalToolResult? localResult,
  ) {
    final raw = localResult?.resultJson?['guide_chat_result'];
    if (raw is Map<String, dynamic>) return GuideChatResult.fromMap(raw);
    if (raw is Map) {
      return GuideChatResult.fromMap(
        raw.map((key, value) => MapEntry('$key', value)),
      );
    }
    return null;
  }

  // =========================================================================
  // Direct freeform chat (OpenAI)
  // =========================================================================

  String _buildDirectFreeformChatSystemPrompt() {
    final activeTasks = _controller.activeQuests
        .where((quest) => !quest.isDeleted && !quest.isReward)
        .map((quest) => quest.title.trim())
        .where((title) => title.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final memoryDigest = guideMemoryDigest.trim().isEmpty
        ? '暂无稳定长期记忆摘要。'
        : guideMemoryDigest.trim();
    final behaviorSignals = guideBehaviorSignals.isEmpty
        ? '暂无明显行为信号。'
        : guideBehaviorSignals.join('；');
    final activeTaskText =
        activeTasks.isEmpty ? '当前任务板为空。' : activeTasks.join('；');
    final name = guideDisplayName?.trim().isNotEmpty == true
        ? guideDisplayName!.trim()
        : '小忆';
    return '''
你是 Earth Online 里的"小忆"，是一个温和、具体、会继续聊下去的陪伴型效率助手。
请直接回答用户，不要复述"我已复盘你最近几条记忆"这类模板句。
除非用户明确要求，不要把回答强行转成任务。
回答要求：
1. 用中文回答。
2. 1 到 3 句，先直接回应用户当前问题。
3. 如果合适，可以补一句很短的追问或陪伴式延续。
4. 不要输出 JSON，不要输出 Markdown 代码块。

当前上下文：
- 你的名字：$name
- 记忆摘要：$memoryDigest
- 行为信号：$behaviorSignals
- 当前任务：$activeTaskText
''';
  }

  Future<GuideChatResult?> requestDirectFreeformChat(String sourceText) async {
    final proxyUrl = AppConfig.agentChatProxyUrl.trim();
    if (proxyUrl.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse(proxyUrl),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'message': sourceText,
                'model': AppConfig.openaiChatModel,
                'systemPrompt': _buildDirectFreeformChatSystemPrompt(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          final reply = '${decoded['reply'] ?? ''}'.trim();
          if (reply.isNotEmpty) {
            return GuideChatResult(
              reply: reply,
              intent: GuideChatIntent.companion,
              quickActions: buildGuideQuickActions(GuideChatIntent.companion),
              messageCard: null,
              resultCard: null,
              suggestedTask: null,
              taskEditDraft: null,
              memoryRefs: const <String>[],
            );
          }
        }
      } catch (_) {}
    }

    try {
      final response = await Supabase
          .instance.client.functions
          .invoke(
            'guide-freeform-chat',
            body: <String, dynamic>{
              'message': sourceText,
              'system_prompt': _buildDirectFreeformChatSystemPrompt(),
              'model': AppConfig.openaiChatModel,
              'temperature': 0.4,
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = response.data;
      if (data is! Map) return null;
      final reply = '${data['reply'] ?? ''}'.trim();
      if (reply.isEmpty) return null;

      return GuideChatResult(
        reply: reply,
        intent: GuideChatIntent.companion,
        quickActions: buildGuideQuickActions(GuideChatIntent.companion),
        messageCard: null,
        resultCard: null,
        suggestedTask: null,
        taskEditDraft: null,
        memoryRefs: const <String>[],
      );
    } catch (_) {
      return null;
    }
  }

  // =========================================================================
  // 私有辅助
  // =========================================================================

  String _randomGuideRecoveryTask() {
    final isEnglish = AppLocaleController.instance.isEnglish;
    final tasks = isEnglish
        ? <String>[
            'Take a 10-minute walk',
            'Drink a glass of water',
            'Stretch for 5 minutes',
            'Write down one thing you did today',
          ]
        : <String>[
            '出门走 10 分钟',
            '喝一杯水',
            '做 5 分钟拉伸',
            '写下今天做的一件事',
          ];
    final index = DateTime.now().millisecondsSinceEpoch % tasks.length;
    return tasks[index];
  }

  String normalizeGuideLookup(String text) {
    return text.trim().toLowerCase();
  }

  String? extractQuotedGuidePhrase(String text) {
    final match = RegExp("[\"\"''](.+?)[\"\"'']").firstMatch(text);
    final value = match?.group(1)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? extractQuotedText(String text) {
    final match = RegExp(r'[""「『](.+?)[""」』]').firstMatch(text);
    final value = match?.group(1)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  List<String> extractGuideStepTitles(String text) {
    final patterns = <RegExp>[
      RegExp(r'(?:拆成|拆解成|拆解为|分成|分解成|分步骤)[:：]?\s*(.*)$'),
      RegExp(r'(?:子项是|子任务是|包括|例如|比如)[:：]?\s*(.*)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final raw = match.group(1)?.trim() ?? '';
      if (raw.isEmpty) continue;
      final pieces = raw
          .split(RegExp(r'[，,、；;]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(5)
          .toList();
      if (pieces.length >= 2) return pieces;
    }
    return const <String>[];
  }

  bool shouldKeepPendingGuideTaskEditDraft(GuideTaskEditDraft? draft) {
    if (draft == null) return false;
    return draft.action == 'split' ||
        draft.updatedTitle.trim().isNotEmpty ||
        draft.updatedDescription.trim().isNotEmpty;
  }

  // =========================================================================
  // Guide 内部处理方法
  // =========================================================================

  Future<GuideTurnResponse> _handleGuideGenerateTask(String text) async {
    final normalized = text.trim();
    final title = normalizeGuideTaskTitle(normalized);
    if (title.isEmpty) {
      return GuideTurnResponse(result: buildCompanionGuideResult(text));
    }
    final shouldSubtask = shouldGuideGenerateSubtasks(normalized);
    final dueDate = extractGuideDueDate(normalized);
    final xp = extractGuideXp(normalized);
    final result = await guideService.chat(
      message: normalized,
      scene: 'home',
      clientContext: buildGuideClientContext(),
    );
    return GuideTurnResponse(
      result: result,
      pendingTaskEditDraft: GuideTaskEditDraft(
        taskId: '',
        taskTitle: title,
        action: shouldSubtask ? 'split' : 'create',
        updatedTitle: title,
        updatedDescription: '',
        updatedXpReward: xp,
        subtasks: shouldSubtask ? buildGuideSplitSteps(QuestNode(id: '', userId: '', title: title, questTier: 'Daily', isCompleted: false, isDeleted: false, isExpanded: false, xpReward: 20, sortOrder: 0, createdAt: DateTime.now()), normalized) : const <String>[],
      ),
      pendingTaskDueDate: dueDate,
    );
  }

  Future<GuideTurnResponse> _handleGuideModifyTask(String text) async {
    final target = findGuideTargetTask(text);
    if (target == null) {
      return GuideTurnResponse(result: buildCompanionGuideResult(text));
    }
    final normalized = text.trim();
    final dueDate = extractGuideDueDate(normalized);
    final xp = extractGuideXp(normalized);
    final updatedTitle =
        extractGuideNaturalTitleFromModifyText(normalized, target);
    final result = await guideService.chat(
      message: normalized,
      scene: 'home',
      clientContext: buildGuideClientContext(),
    );
    return GuideTurnResponse(
      result: result,
      pendingTaskEditDraft: GuideTaskEditDraft(
        taskId: target.id,
        taskTitle: target.title,
        action: 'update',
        updatedTitle: updatedTitle ?? target.title,
        updatedDescription: '',
        updatedXpReward: xp,
        subtasks: const <String>[],
      ),
      pendingTaskDueDate: dueDate,
    );
  }

  Future<GuideTurnResponse> _handleGuideRedeemReward(String text) async {
    final rewardController = RewardController(quest: _controller);
    try {
      await rewardController.loadRewards();
      await rewardController.loadInventory();
      final rewards = <Reward>[
        ...rewardController.systemRewards,
        ...rewardController.customRewards,
      ];
      final match = findGuideRewardMatch(text, rewards);
      final reward = match.reward;
      if (reward == null) {
        return GuideTurnResponse(
          result: buildGuideRedeemRewardNeedConfirmation(
            text,
            candidates: match.candidates,
          ),
        );
      }
      if (_controller.currentGold < reward.cost) {
        final isEnglish = AppLocaleController.instance.isEnglish;
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: isEnglish
                ? 'Not just yet. You are a little short on gold for this one.'
                : '这次先换不了，我看到你的金币还差一点。',
            intent: GuideChatIntent.action,
            quickActions: buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: isEnglish ? 'Almost there' : '这次还差一点',
              title: isEnglish
                  ? 'Not enough gold for ${reward.localizedTitle(true)}'
                  : '金币还不够兑换 ${reward.localizedTitle(false)}',
              description: isEnglish
                  ? 'It needs ${reward.cost} gold, and you currently have ${_controller.currentGold}.'
                  : '它需要 ${reward.cost} 金币，你现在有 ${_controller.currentGold} 金币。',
            ),
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      }
      final redeemed = await rewardController.buyReward(reward);
      if (!redeemed) {
        final isEnglish = AppLocaleController.instance.isEnglish;
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: isEnglish
                ? 'I tried to redeem this reward for you, but it did not go through this time.'
                : '我试着帮你兑换这个奖励，但这次没有成功。',
            intent: GuideChatIntent.action,
            quickActions: buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: null,
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      }
      final isEnglish = AppLocaleController.instance.isEnglish;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: isEnglish
              ? 'Done! You redeemed ${reward.localizedTitle(true)}.'
              : '已兑换：${reward.localizedTitle(false)}',
          intent: GuideChatIntent.action,
          quickActions: buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: isEnglish ? 'Redeemed' : '兑换成功',
            title: reward.localizedTitle(isEnglish),
            description: isEnglish
                ? 'Spent ${reward.cost} gold. Enjoy!'
                : '花费 ${reward.cost} 金币。',
          ),
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    } finally {
      rewardController.dispose();
    }
  }

  Future<GuideTurnResponse> _handlePendingGuideTaskEdit(String text) async {
    final draft = pendingGuideTaskEditDraft;
    if (draft == null) {
      return GuideTurnResponse(result: buildCompanionGuideResult(text));
    }
    if (isGuideCancellationText(text)) {
      pendingGuideTaskEditDraft = null;
      pendingGuideTaskDueDate = null;
      final isEnglish = AppLocaleController.instance.isEnglish;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: isEnglish ? 'OK, cancelled.' : '好的，取消了。',
          intent: GuideChatIntent.companion,
          quickActions: buildGuideQuickActions(GuideChatIntent.companion),
          messageCard: null,
          resultCard: null,
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }
    // Confirm path: create/update the task
    if (draft.action == 'create' || draft.action == 'split') {
      final title = draft.updatedTitle.trim().isNotEmpty
          ? draft.updatedTitle.trim()
          : draft.taskTitle.trim();
      final inserted = await _controller.createManualQuest(
        title: title,
        description: guideTaskDescription(title),
        questTier: 'Daily',
        xpReward: draft.updatedXpReward ?? 20,
      );
      if (inserted != null && draft.subtasks.isNotEmpty) {
        await _controller.addGuideChildTasks(
          parent: inserted,
          stepTitles: draft.subtasks,
          xpReward: (inserted.xpReward / 2).round(),
        );
      }
      pendingGuideTaskEditDraft = null;
      pendingGuideTaskDueDate = null;
      final isEnglish = AppLocaleController.instance.isEnglish;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: isEnglish
              ? 'Created task: $title'
              : '已创建任务：$title',
          intent: GuideChatIntent.action,
          quickActions: buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: null,
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }
    if (draft.action == 'update' && draft.taskId.isNotEmpty) {
      await _controller.updateQuestDetails(
        draft.taskId,
        title: draft.updatedTitle,
        description: draft.updatedDescription,
        xpReward: draft.updatedXpReward,
        dueDate: pendingGuideTaskDueDate,
      );
      pendingGuideTaskEditDraft = null;
      pendingGuideTaskDueDate = null;
      final isEnglish = AppLocaleController.instance.isEnglish;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: isEnglish
              ? 'Updated task: ${draft.taskTitle}'
              : '已更新任务：${draft.taskTitle}',
          intent: GuideChatIntent.action,
          quickActions: buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: null,
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }
    pendingGuideTaskEditDraft = null;
    pendingGuideTaskDueDate = null;
    return GuideTurnResponse(result: buildCompanionGuideResult(text));
  }

  bool shouldGuideGenerateSubtasks(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('详细一点') ||
        normalized.contains('具体一点') ||
        normalized.contains('详细些') ||
        normalized.contains('更详细一点') ||
        normalized.contains('拆开') ||
        normalized.contains('拆解') ||
        normalized.contains('分步骤') ||
        normalized.contains('子项') ||
        normalized.contains('子任务') ||
        normalized.contains('more detailed') ||
        normalized.contains('more specific') ||
        normalized.contains('break it down') ||
        normalized.contains('split') ||
        normalized.contains('steps') ||
        normalized.contains('subtask');
  }

  // =========================================================================
  // 从 home_page.dart 迁移的公开方法
  // =========================================================================

  /// 判断是否应该展示新手引导教程
  Future<bool> shouldOfferOnboardingTutorial() async {
    final userId =
        SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? '';
    if (userId.isEmpty) return false;
    final seenUserId =
        await PreferencesService.guideOnboardingSeenUserId() ?? '';
    if (seenUserId == userId) return false;
    if (_controller.quests.isNotEmpty) return false;
    if (_controller.totalXp > 0 ||
        _controller.currentGold > 0 ||
        _controller.longestStreak > 0) {
      return false;
    }
    return true;
  }

  /// 检测文本中是否包含 CJK 字符
  bool containsGuideCjk(String text) {
    return RegExp(r'[㐀-鿿]').hasMatch(text);
  }

  /// 在活跃任务中按 id 查找任务
  QuestNode? findGuideTaskById(String id) {
    for (final quest in _controller.activeQuests) {
      if (quest.id == id) {
        return quest;
      }
    }
    return null;
  }

  /// 从修改类文本中猜测目标任务标题
  String guessGuideTaskTitleFromModifyText(String text) {
    final explicit = extractQuotedText(text);
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final patterns = <RegExp>[
      RegExp(r'(?:修改|调整|改)\s*(.+?)(?:的)?任务'),
      RegExp(r'把\s*(.+?)\s*(?:改成|改为|拆成|拆解|调整)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = match?.group(1)?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    var cleaned = text
        .replaceAll('修改', '')
        .replaceAll('调整', '')
        .replaceAll('改', '')
        .replaceAll('任务', '')
        .replaceAll(RegExp(r'截止时间.*$'), '')
        .replaceAll(RegExp(r'到期.*$'), '')
        .replaceAll(RegExp(r'xp.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'经验.*$'), '')
        .replaceAll(RegExp(r'奖励.*$'), '')
        .trim();
    final segments = cleaned.split(RegExp(r'[，,；;。]'));
    return segments.first.trim();
  }

  /// 获取当前 Agent 运行结果快照
  AgentRunResult currentAgentRunResult() {
    String? latestAssistantMessage;
    for (final item in visibleGuideMessages().reversed) {
      if (item.role == 'assistant' && item.content.trim().isNotEmpty) {
        latestAssistantMessage = item.content.trim();
        break;
      }
    }
    return AgentRunResult(
      run: agentRunService.currentRun,
      steps: List<AgentStep>.from(agentRunService.steps),
      latestAssistantMessage: latestAssistantMessage,
    );
  }

  /// 删除单个任务并记录到最近删除列表
  void deleteQuestWithGuideMemory(String questId) {
    final deletingTitles = _controller.quests
        .where((quest) => quest.id == questId || quest.parentId == questId)
        .map((quest) => quest.title)
        .toList(growable: false);
    _rememberRecentlyDeletedGuideTasks(deletingTitles);
    _controller.deleteQuest(questId);
  }

  /// 删除所有活跃任务并记录到最近删除列表
  void deleteAllQuestsWithGuideMemory() {
    final deletingTitles = _controller.activeQuests
        .where((quest) => !quest.isReward && !quest.isDeleted)
        .map((quest) => quest.title)
        .toList(growable: false);
    _rememberRecentlyDeletedGuideTasks(deletingTitles);
    _controller.deleteAllActiveQuests();
  }

  /// 记录最近删除的任务标题（供记忆上下文使用）
  void _rememberRecentlyDeletedGuideTasks(List<String> titles) {
    for (final raw in titles) {
      final title = raw.trim();
      if (title.isEmpty) continue;
      recentlyDeletedGuideTaskTitles.remove(title);
      recentlyDeletedGuideTaskTitles.insert(0, title);
    }
    if (recentlyDeletedGuideTaskTitles.length > 8) {
      recentlyDeletedGuideTaskTitles.removeRange(
        8,
        recentlyDeletedGuideTaskTitles.length,
      );
    }
  }
}
