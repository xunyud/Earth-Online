import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/app_config.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/evermemos_service.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/services/preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/models/local_tool_call.dart';
import '../../../core/models/local_tool_result.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../shared/widgets/celebration_overlay.dart';
import '../../../shared/widgets/coach_marks_overlay.dart';
import '../../../shared/widgets/quest_dialog_shell.dart';
import '../../../shared/widgets/sync_indicator.dart';
import '../../achievement/screens/achievement_page.dart';
import '../../achievement/widgets/achievement_unlock_overlay.dart';
import '../../reward/controllers/reward_controller.dart';
import '../../reward/models/reward.dart';
import '../../reward/screens/inventory_page.dart';
import '../../reward/screens/reward_shop_page.dart';
import '../../stats/screens/stats_page.dart';
import 'life_diary_page.dart';
import '../controllers/quest_controller.dart';
import '../controllers/guide_controller.dart';
import '../models/guide_chat_message.dart';
import '../widgets/quick_create_dialog_content.dart';
import '../widgets/portrait_insight_chart.dart';
import '../widgets/home_settings_widgets.dart';
import '../widgets/memory_recommendation_cards.dart';
import '../models/quest_node.dart';
import '../models/agent_run.dart';
import '../models/agent_step.dart';
import '../widgets/guide_panel_dialog.dart';
import '../widgets/night_reflection_dialog.dart';
import '../widgets/quest_board.dart';
import '../widgets/quest_board_fab.dart';
import '../widgets/quick_add_bar.dart';

const String localOnboardingEventId = 'local_onboarding_tutorial';

class HomePage extends StatefulWidget {
  final String currentThemeId;
  final ValueChanged<String>? onThemeChange;

  const HomePage({
    super.key,
    this.currentThemeId = 'forest_adventure',
    this.onThemeChange,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final QuestController _controller = QuestController();
  final EvermemosService _evermemosService = EvermemosService();
  final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  // Coach Marks GlobalKeys
  final GlobalKey _coachKeyQuickAdd = GlobalKey(debugLabel: 'coach_quick_add');
  final GlobalKey _coachKeyQuestBoard =
      GlobalKey(debugLabel: 'coach_quest_board');
  final GlobalKey _coachKeyLevelBar = GlobalKey(debugLabel: 'coach_level_bar');
  final GlobalKey _coachKeyGuideBtn = GlobalKey(debugLabel: 'coach_guide_btn');
  final GlobalKey _coachKeyShopBtn = GlobalKey(debugLabel: 'coach_shop_btn');
  bool _showCoachMarks = false;
  late final Future<void> _initFuture;
  late final GuideController _guideController;

  int _previousUncompletedCount = -1;
  bool _isSyncingMemory = false;
  bool _isGeneratingProfile = false;

  @override
  void initState() {
    super.initState();
    _guideController = GuideController(questController: _controller);
    _controller.addListener(_onQuestStateChanged);
    _guideController.addListener(_onGuideStateChanged);
    _initFuture = _controller.init();
    unawaited(_guideController.init(_initFuture));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_guideController.runBootstrapIfNeeded(_initFuture));
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuestStateChanged);
    _guideController.removeListener(_onGuideStateChanged);
    _guideController.dispose();
    _evermemosService.dispose();
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onQuestStateChanged() {
    final active = _controller.activeQuests;
    final uncompleted = active.where((q) => !q.isCompleted).length;
    if (_previousUncompletedCount == -1) {
      _previousUncompletedCount = uncompleted;
      return;
    }
    if (_previousUncompletedCount > 0 &&
        uncompleted == 0 &&
        active.isNotEmpty) {
      _confetti.play();
      showForestSnackBar(context, context.tr('home.all_done'));
    }
    _previousUncompletedCount = uncompleted;
  }

  void _onGuideStateChanged() {
    if (mounted) setState(() {});
  }

  String get _guideName {
    final value = _guideController.guideDisplayName?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return context.tr('guide.name.default');
  }

  String _guideMemorySummary() {
    final digest = _guideController.guideMemoryDigest.trim();
    if (digest.isEmpty) {
      return context.tr(
        'guide.memory.empty',
        params: {'name': _guideName},
      );
    }
    // 只取第一行的自然语言摘要，隐藏原始统计数据
    final firstLine = digest.split('\n').first.trim();
    return firstLine;
  }

  Future<void> _loadGuideDisplayName() async {
    final stored = await PreferencesService.guideDisplayName();
    final resolved =
        await _guideController.guideService.resolveDisplayName(localFallback: stored);
    await PreferencesService.setGuideDisplayName(resolved);
    if (!mounted) return;
    setState(() => _guideController.guideDisplayName = resolved);
  }

  Future<void> _loadProfileDisplayName() async {
    final name = await PreferencesService.profileDisplayName();
    if (!mounted) return;
    setState(() => _guideController.profileDisplayName = name);
  }

  Map<String, dynamic> _buildGuideClientContext() {
    final activeTasks = _controller.activeQuests
        .where((quest) => !quest.isReward && !quest.isDeleted)
        .toList(growable: false);
    return <String, dynamic>{
      'guide_name': _guideName,
      'language_code': AppLocaleController.instance.locale.languageCode,
      'is_english': AppLocaleController.instance.isEnglish,
      'memory_digest': _guideController.guideMemoryDigest.trim(),
      'behavior_signals': _guideController.guideBehaviorSignals,
      'active_task_titles': activeTasks.map((quest) => quest.title).toList(),
      'active_task_ids': activeTasks.map((quest) => quest.id).toList(),
      'active_task_count': activeTasks.length,
      'recently_deleted_task_titles': _guideController.recentlyDeletedGuideTaskTitles,
      'task_truth_rule':
          'Only active_task_titles are current tasks. Memory is historical context only. If a memory-mentioned task is not active, ask whether to recreate it instead of treating it as existing.',
      if (_guideController.latestDailyEvent != null)
        'latest_daily_event': <String, dynamic>{
          'title': _guideController.latestDailyEvent!.title,
          'reason': _guideController.latestDailyEvent!.reason,
        },
    };
  }


  Future<void> _onCoachMarksComplete() async {
    final userId = SupabaseAuthService.instance.getCurrentUserId();
    final alreadySeen =
        (await PreferencesService.coachMarksSeenUserId()) == userId;
    await PreferencesService.setCoachMarksSeenUserId(userId);
    await PreferencesService.setGuideOnboardingSeenUserId(userId);
    if (!mounted) return;
    setState(() => _showCoachMarks = false);
    // 首次引导时插入教程任务，重播时不重复插入
    if (!alreadySeen) {
      final inserted =
          await _controller.addOnboardingTutorialBundle(guideName: _guideName);
      if (mounted && inserted.isNotEmpty) {
        showForestSnackBar(context, context.tr('guide.onboarding.accepted'));
      }
    }
  }

  Future<void> _onCoachMarksSkip() async {
    final userId = SupabaseAuthService.instance.getCurrentUserId();
    final alreadySeen =
        (await PreferencesService.coachMarksSeenUserId()) == userId;
    await PreferencesService.setCoachMarksSeenUserId(userId);
    await PreferencesService.setGuideOnboardingSeenUserId(userId);
    if (!mounted) return;
    setState(() => _showCoachMarks = false);
    // 首次引导时插入教程任务，重播时不重复插入
    if (!alreadySeen) {
      await _controller.addOnboardingTutorialBundle(guideName: _guideName);
    }
  }

  void _replayCoachMarks() {
    if (_showCoachMarks) return;
    setState(() => _showCoachMarks = true);
  }

  GuideDailyEvent _buildOnboardingDailyEvent() {
    return GuideDailyEvent(
      eventId: localOnboardingEventId,
      title: context.tr('guide.onboarding.event.title'),
      description: context.tr('guide.onboarding.event.description'),
      rewardXp: 120,
      rewardGold: 120,
      status: 'generated',
      reason: context.tr('guide.onboarding.event.reason'),
      memoryRefs: const <String>[],
    );
  }

  bool _isOnboardingEvent(GuideDailyEvent event) {
    return event.eventId == localOnboardingEventId;
  }

  bool _isOnboardingEventId(String eventId) {
    return eventId == localOnboardingEventId;
  }

  String _eventDialogTitle(GuideDailyEvent event) {
    if (_isOnboardingEvent(event)) {
      return context.tr('guide.onboarding.dialog_title');
    }
    return context.tr('home.event.title');
  }

  String _eventBadgeLabel(GuideDailyEvent event) {
    if (_isOnboardingEvent(event)) {
      return context.tr('guide.onboarding.badge');
    }
    return context.tr('home.event.badge');
  }

  String _eventReasonBadge(GuideDailyEvent event) {
    if (_isOnboardingEvent(event)) {
      return context.tr('guide.onboarding.reason_badge');
    }
    return context.tr('home.event.reason_badge');
  }

  Future<void> _editGuideName(StateSetter setModalState) async {
    final controller = TextEditingController(text: _guideName);
    final dialogTitle = context.tr(
      'guide.name.dialog_title',
      params: {'name': _guideName},
    );
    final dialogHint = context.tr('guide.name.dialog_hint');
    final actionLabel = context.tr('guide.name.dialog_action');
    final nextName = await showQuestDialog<String>(
      context: context,
      barrierLabel: 'guide_name_dialog',
      builder: (dialogContext) => QuestDialogShell(
        title: dialogTitle,
        subtitle: dialogHint,
        maxWidth: 540,
        leading: QuestDialogBadge(label: _guideName.characters.first),
        onClose: () => Navigator.of(dialogContext).pop(),
        actions: [
          QuestDialogSecondaryButton(
            label: context.tr('common.cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          QuestDialogPrimaryButton(
            label: actionLabel,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ],
        child: QuestDialogInfoCard(
          label: context.tr('guide.name.edit'),
          icon: Icons.edit_rounded,
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: dialogHint,
              filled: true,
              fillColor: Colors.white.withAlpha(170),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(dialogContext)
                      .extension<QuestTheme>()!
                      .primaryAccentColor
                      .withAlpha(34),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(dialogContext)
                      .extension<QuestTheme>()!
                      .primaryAccentColor
                      .withAlpha(34),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(dialogContext)
                      .extension<QuestTheme>()!
                      .primaryAccentColor,
                  width: 1.6,
                ),
              ),
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
        ),
      ),
    );
    controller.dispose();

    if (nextName == null) return;
    final normalized = nextName.trim().isEmpty ? null : nextName.trim();
    await PreferencesService.setGuideDisplayName(normalized);
    var syncFailed = false;
    try {
      await _guideController.saveDisplayName(normalized);
    } catch (_) {
      syncFailed = true;
    }
    if (!mounted) return;

    setState(() => _guideController.guideDisplayName = normalized);
    setModalState(() {});
    if (syncFailed) {
      showForestSnackBar(context, context.tr('quest.error.save_failed'));
    }
  }


  Future<void> _performAgentNavigation(String target) async {
    if (!mounted) return;
    switch (target) {
      case 'stats':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatsPage(questController: _controller),
          ),
        );
        return;
      case 'shop':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RewardShopPage(questController: _controller),
          ),
        );
        return;
      case 'weekly_summary':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LifeDiaryPage()),
        );
        return;
    }
  }


  String _buildDirectFreeformChatSystemPrompt() {
    final activeTasks = _controller.activeQuests
        .where((quest) => !quest.isDeleted && !quest.isReward)
        .map((quest) => quest.title.trim())
        .where((title) => title.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final memoryDigest = _guideController.guideMemoryDigest.trim().isEmpty
        ? '暂无稳定长期记忆摘要。'
        : _guideController.guideMemoryDigest.trim();
    final behaviorSignals = _guideController.guideBehaviorSignals.isEmpty
        ? '暂无明显行为信号。'
        : _guideController.guideBehaviorSignals.join('；');
    final activeTaskText =
        activeTasks.isEmpty ? '当前任务板为空。' : activeTasks.join('；');
    return '''
你是 Earth Online 里的“小忆”，是一个温和、具体、会继续聊下去的陪伴型效率助手。
请直接回答用户，不要复述“我已复盘你最近几条记忆”这类模板句。
除非用户明确要求，不要把回答强行转成任务。
回答要求：
1. 用中文回答。
2. 1 到 3 句，先直接回应用户当前问题。
3. 如果合适，可以补一句很短的追问或陪伴式延续。
4. 不要输出 JSON，不要输出 Markdown 代码块。

当前上下文：
- 你的名字：$_guideName
- 记忆摘要：$memoryDigest
- 行为信号：$behaviorSignals
- 当前任务：$activeTaskText
''';
  }

  Future<GuideChatResult?> _requestDirectFreeformChat(String sourceText) async {
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
              quickActions: _buildGuideQuickActions(GuideChatIntent.companion),
              messageCard: null,
              resultCard: null,
              suggestedTask: null,
              taskEditDraft: null,
              memoryRefs: const <String>[],
            );
          }
        }
      } catch (_) {
        // 本地代理不可用时继续回退到后续链路，避免整次对话直接失败。
      }
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
        quickActions: _buildGuideQuickActions(GuideChatIntent.companion),
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


  Future<LocalToolResult> _executeAgentFreeformChat(
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
      final result = await _requestDirectFreeformChat(sourceText) ??
          await _guideController.guideService
              .chat(
                message: sourceText,
                scene: 'home',
                clientContext: _buildGuideClientContext(),
              )
              .timeout(const Duration(seconds: 8));
      final resolvedResult = result.reply.trim().isEmpty
          ? _buildCompanionGuideResult(sourceText)
          : result;
      return LocalToolResult(
        success: true,
        outputText: resolvedResult.reply,
        resultJson: <String, dynamic>{
          'guide_chat_result': _guideController.guideChatResultToJson(resolvedResult),
        },
      );
    } catch (_) {
      final fallback = _buildCompanionGuideResult(sourceText);
      return LocalToolResult(
        success: true,
        outputText: fallback.reply,
        resultJson: <String, dynamic>{
          'guide_chat_result': _guideController.guideChatResultToJson(fallback),
        },
      );
    }
  }


  Future<LocalToolResult> _executeAgentRewardRedeem(
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
      final match = _findGuideRewardMatch(sourceText, rewards);
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


  Future<LocalToolResult?> _startAgentRunFromGuideInput(String text) async {
    _guideController.runningLocalAgentStepIds.clear();
    _guideController.finishedLocalAgentStepIds.clear();
    _guideController.localAgentStepResults.clear();
    final snapshot = await _guideController.agentRunService.startRun(
      goal: text,
      clientContext: _buildGuideClientContext(),
    );
    _guideController.trackedAgentRunId = snapshot.run.id;
    _appendAgentMessagesFromSteps(snapshot.steps);
    final immediateResult = await _tryExecuteReadyAgentStep();
    if (immediateResult != null) return immediateResult;
    final pendingStepId = _guideController.agentRunService.latestStep?.id;
    if (pendingStepId == null || pendingStepId.isEmpty) return null;
    return _guideController.waitForLocalAgentStepResult(pendingStepId);
  }


  void _appendAgentMessagesFromSteps(List<AgentStep> steps) {
    final existingKeys = _guideController.guideMessages
        .where((message) => message.agentStepId != null)
        .map((message) => '${message.role}:${message.agentStepId}')
        .toSet();

    for (final step in steps) {
      if ((step.outputText ?? '').trim().isEmpty) continue;
      if (!_guideController.shouldShowAgentStepMessage(step)) continue;
      final role = step.kind == 'error' ? 'assistant' : 'assistant';
      final key = '$role:${step.id}';
      if (existingKeys.contains(key)) continue;
      _appendGuideMessage(
        role,
        step.outputText!.trim(),
        agentStepId: step.id,
      );
      existingKeys.add(key);
    }
  }

  Future<LocalToolResult?> _tryExecuteReadyAgentStep() async {
    final run = _guideController.agentRunService.currentRun;
    final step = _guideController.agentRunService.latestStep;
    if (run == null || step == null) return null;
    final cachedResult = _guideController.localAgentStepResults[step.id];
    if (cachedResult != null) {
      return cachedResult;
    }
    if (!step.isToolCall || !step.isReady || step.needsConfirmation) {
      return null;
    }
    if (_guideController.runningLocalAgentStepIds.contains(step.id) ||
        _guideController.finishedLocalAgentStepIds.contains(step.id)) {
      return null;
    }

    _guideController.runningLocalAgentStepIds.add(step.id);
    try {
      late final LocalToolResult result;
      try {
        result = await _guideController.localAgentRuntimeService.execute(
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
      _guideController.localAgentStepResults[step.id] = result;
      final snapshot = await _guideController.agentRunService.reportLatestLocalResult(
        success: result.success,
        outputText: result.outputText,
        errorText: result.errorText,
        resultJson: result.resultJson,
      );
      _guideController.finishedLocalAgentStepIds.add(step.id);
      if (snapshot != null) {
        _appendAgentMessagesFromSteps(snapshot.steps);
      }
      return result;
    } finally {
      _guideController.runningLocalAgentStepIds.remove(step.id);
    }
  }

  Future<void> _approveLatestAgentStep() async {
    final snapshot = await _guideController.agentRunService.approveLatestStep();
    if (snapshot != null) {
      _appendAgentMessagesFromSteps(snapshot.steps);
      await _tryExecuteReadyAgentStep();
    }
  }

  Future<void> _rejectLatestAgentStep() async {
    final snapshot = await _guideController.agentRunService.rejectLatestStep();
    if (snapshot != null) {
      _appendAgentMessagesFromSteps(snapshot.steps);
    }
  }

  void _appendGuideMessage(
    String role,
    String content, {
    List<String> memoryRefs = const <String>[],
    String? agentStepId,
  }) {
    final text = content.trim();
    if (text.isEmpty) return;
    setState(() {
      _guideController.guideMessages.add(
        GuideChatMessage(
          role: role,
          content: text,
          memoryRefCount: memoryRefs.length,
          memoryRefs: memoryRefs,
          agentStepId: agentStepId,
        ),
      );
      if (_guideController.guideMessages.length > 60) {
        _guideController.guideMessages.removeRange(0, _guideController.guideMessages.length - 60);
      }
    });
  }

  Future<void> _copyGuideMessage(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showForestSnackBar(context, context.tr('guide.message.copied'));
  }


  Future<void> _runGuideBootstrapIfNeeded() async {
    if (_guideController.isGuideBootstrapping) return;
    // 等待数据加载完成，确保 quests/xp/gold 等状态已就绪
    await _initFuture;
    if (!mounted) return;
    final guideEnabled = await PreferencesService.guideEnabled();
    final proactiveEnabled = await PreferencesService.guideProactiveEnabled();
    if (!guideEnabled || !proactiveEnabled) return;
    final today = _guideController.localDateId();
    final lastDate = await PreferencesService.guideLastBootstrapDate();
    if (lastDate == today || !mounted) return;

    if (await _guideController.shouldOfferOnboardingTutorial()) {
      final userId = SupabaseAuthService.instance.getCurrentUserId() ?? '';
      final coachSeen = await PreferencesService.coachMarksSeenUserId();
      if (coachSeen != userId && userId.isNotEmpty) {
        // 新用户：显示 Coach Marks 高亮引导
        if (!mounted) return;
        setState(() => _showCoachMarks = true);
        return;
      }
      // 已看过 Coach Marks 但仍符合 onboarding 条件时走原有对话框路径
      await PreferencesService.setGuideOnboardingSeenUserId(userId);
      if (!mounted) return;
      final event = _buildOnboardingDailyEvent();
      setState(() => _guideController.latestDailyEvent = event);
      await _showDailyEventDialog(event);
      return;
    }

    setState(() => _guideController.isGuideBootstrapping = true);
    try {
      final result = await _guideController.guideService.bootstrap(
          scene: 'home', clientContext: _buildGuideClientContext());
      if (!mounted) return;
      setState(() {
        _guideController.guideStatus = GuideConnectionStatus.ready;
        _guideController.guideMemoryDigest = result.memoryDigest.trim();
        _guideController.guideBehaviorSignals = result.behaviorSignals.take(3).toList();
        // 每次 bootstrap 刷新时更新推荐内容，不缓存过期推荐
        _guideController.recommendations = result.recommendations;
      });
      await PreferencesService.setGuideLastBootstrapDate(today);
      if (!mounted) return;

      if (result.proactiveMessage.trim().isNotEmpty) {
        _appendGuideMessage(
          'assistant',
          result.proactiveMessage,
          memoryRefs: result.memoryRefs,
        );
        await showQuestDialog<void>(
          context: context,
          barrierLabel: 'guide_daily_open_dialog',
          builder: (dialogContext) => QuestDialogShell(
            title: context.tr(
              'guide.daily_open.title',
              params: {'name': _guideName},
            ),
            subtitle: context.tr(
              'guide.hero.subtitle',
              params: {'name': _guideName},
            ),
            maxWidth: 980,
            leading: QuestDialogBadge(
              label: _guideName.characters.first,
              size: 78,
            ),
            onClose: () => Navigator.of(dialogContext).pop(),
            actions: [
              QuestDialogSecondaryButton(
                label: context.tr('guide.cta.later'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              QuestDialogPrimaryButton(
                label: context.tr('guide.cta.continue'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _openGuidePanel();
                },
              ),
            ],
            child: QuestDialogInfoCard(
              label: context.tr(
                'guide.memory.title',
                params: {'name': _guideName},
              ),
              icon: Icons.auto_awesome_rounded,
              child: Text(
                result.proactiveMessage,
                style: AppTextStyles.body.copyWith(
                  fontSize: 17,
                  height: 1.7,
                  color: const Color(0xFF344336),
                ),
              ),
            ),
          ),
        );
      }

      if (result.dailyEvent != null && result.dailyEvent!.isPending) {
        setState(() => _guideController.latestDailyEvent = result.dailyEvent);
        await _showDailyEventDialog(result.dailyEvent!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guideController.guideStatus = _guideController.statusFromError(e));
      showForestSnackBar(context, context.tr('home.bootstrap.offline'));
    } finally {
      if (mounted) {
        setState(() => _guideController.isGuideBootstrapping = false);
      }
    }
  }

  Future<void> _showDailyEventDialog(GuideDailyEvent event) async {
    final eventTheme = Theme.of(context).extension<QuestTheme>()!;
    final decision = await showQuestDialog<bool>(
      context: context,
      barrierLabel: 'guide_daily_event_dialog',
      builder: (dialogContext) => QuestDialogShell(
        title: _eventDialogTitle(event),
        maxWidth: 1040,
        scrollable: true,
        accentColor: eventTheme.mainQuestColor,
        leading: QuestDialogBadge(
          icon: Icons.bolt_rounded,
          accentColor: eventTheme.mainQuestColor,
          size: 78,
        ),
        onClose: () => Navigator.of(dialogContext).pop(),
        actions: [
          QuestDialogSecondaryButton(
            label: context.tr('common.skip_today'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          QuestDialogPrimaryButton(
            label: context.tr('common.accept_task'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuestDialogInfoCard(
              label: _eventBadgeLabel(event),
              icon: Icons.explore_rounded,
              accentColor: eventTheme.mainQuestColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF203222),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.description,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 17,
                      height: 1.65,
                      color: const Color(0xFF344336),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: eventTheme.primaryAccentColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: eventTheme.primaryAccentColor.withAlpha(30),
                    ),
                  ),
                  child: Text(
                    '+${event.rewardXp} XP',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: eventTheme.primaryAccentColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9C5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: eventTheme.mainQuestColor.withAlpha(34),
                    ),
                  ),
                  child: Text(
                    _guideText(
                      '+${event.rewardGold} 金币',
                      '+${event.rewardGold} gold',
                    ),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8B5B00),
                    ),
                  ),
                ),
              ],
            ),
            if (event.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              QuestDialogInfoCard(
                label: _eventReasonBadge(event),
                icon: Icons.psychology_alt_rounded,
                accentColor: eventTheme.sideQuestColor,
                child: Text(
                  event.reason,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (decision == null) return;
    await _handleDailyEventDecision(event.eventId, decision);
  }

  Future<void> _handleDailyEventDecision(String eventId, bool accept) async {
    if (_isOnboardingEventId(eventId)) {
      await _handleOnboardingTutorialDecision(accept);
      return;
    }
    if (_guideController.isGuideEventHandling || !mounted) return;
    setState(() => _guideController.isGuideEventHandling = true);
    try {
      final result =
          await _guideController.acceptEvent(eventId: eventId, accept: accept);
      if (!mounted) return;
      if (accept && result.accepted) {
        showForestSnackBar(
          context,
          context.tr(
            'home.event.accepted',
            params: {
              'xp': '${result.rewardXp}',
              'gold': '${result.rewardGold}',
            },
          ),
        );
        await _controller.refreshQuests();
      } else if (!accept) {
        showForestSnackBar(context, context.tr('home.event.dismissed'));
      }
      if (mounted) setState(() => _guideController.latestDailyEvent = null);
    } catch (_) {
      if (!mounted) return;
      showForestSnackBar(context, context.tr('home.event.failed'));
    } finally {
      if (mounted) setState(() => _guideController.isGuideEventHandling = false);
    }
  }

  Future<void> _handleOnboardingTutorialDecision(bool accept) async {
    if (_guideController.isGuideEventHandling || !mounted) return;
    if (!accept) {
      setState(() => _guideController.latestDailyEvent = null);
      showForestSnackBar(context, context.tr('guide.onboarding.dismissed'));
      return;
    }

    setState(() => _guideController.isGuideEventHandling = true);
    try {
      final inserted =
          await _controller.addOnboardingTutorialBundle(guideName: _guideName);
      if (!mounted) return;
      if (inserted.isEmpty) {
        showForestSnackBar(context, context.tr('guide.onboarding.failed'));
        return;
      }
      setState(() => _guideController.latestDailyEvent = null);
      showForestSnackBar(context, context.tr('guide.onboarding.accepted'));
    } finally {
      if (mounted) setState(() => _guideController.isGuideEventHandling = false);
    }
  }


  String _guideText(String zh, String en) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode.toLowerCase().startsWith('en')) {
      return en;
    }
    return zh;
  }


  GuideChatResult _guideResultForCurrentLocale(GuideChatResult result) {
    if (!context.isEnglish || !_guideController.containsGuideCjk(result.reply)) {
      return result;
    }

    final fallbackReply = result.resultCard?.title.trim().isNotEmpty == true
        ? result.resultCard!.title.trim()
        : result.resultCard?.description.trim().isNotEmpty == true
            ? result.resultCard!.description.trim()
            : result.messageCard?.content.trim().isNotEmpty == true
                ? result.messageCard!.content.trim()
                : switch (result.intent) {
                    GuideChatIntent.action => 'Done. I updated it for you.',
                    GuideChatIntent.advice =>
                      'Let us sort the situation first.',
                    GuideChatIntent.companion => 'I am here with you.',
                  };

    return GuideChatResult(
      reply: fallbackReply,
      intent: result.intent,
      quickActions: result.quickActions,
      messageCard: result.messageCard,
      resultCard: result.resultCard,
      suggestedTask: result.suggestedTask,
      taskEditDraft: result.taskEditDraft,
      memoryRefs: result.memoryRefs,
    );
  }


  GuideRewardMatch _findGuideRewardMatch(String text, List<Reward> rewards) {
    final availableRewards = rewards
        .where((reward) => reward.title.trim().isNotEmpty)
        .toList(growable: false);
    if (availableRewards.isEmpty) {
      return const GuideRewardMatch();
    }

    final query =
        _guideController.normalizeGuideLookup(_guideController.extractQuotedGuidePhrase(text) ?? text);
    if (query.isEmpty) {
      return const GuideRewardMatch();
    }

    final exactMatches = availableRewards
        .where(
          (reward) => reward
              .localizedLookupTitles(context.isEnglish)
              .map(_guideController.normalizeGuideLookup)
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
      for (final candidate in reward.localizedLookupTitles(context.isEnglish)) {
        final title = _guideController.normalizeGuideLookup(candidate);
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

  GuideChatResult _buildGuideRedeemRewardNeedConfirmation(
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

    return GuideChatResult(
      reply: _guideText(
        '我还没确定你想兑换哪一个奖励。你可以直接说奖励名，我就能继续帮你处理。',
        'I am not sure which reward you want to redeem yet. Tell me the reward name directly and I can keep going.',
      ),
      intent: GuideChatIntent.advice,
      quickActions: _buildGuideQuickActions(GuideChatIntent.advice),
      messageCard: GuideMessageCard(
        label: _guideText('还需要你确认', 'Need your confirmation'),
        content: hasCandidates
            ? _guideText(
                '我现在想到的候选有：$zhCandidateList。你可以直接说“兑换$firstZh”。',
                'Possible matches so far: $enCandidateList. You can say "Redeem $firstEn".',
              )
            : _guideText(
                '我还没从“$text”里抓到具体奖励名。你可以直接说“兑换森林主题”这种更明确的话。',
                'I could not extract a reward name from "$text" yet. A clearer request like "Redeem Forest Theme" would help.',
              ),
      ),
      resultCard: null,
      suggestedTask: null,
      taskEditDraft: null,
      memoryRefs: const <String>[],
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
      final match = _findGuideRewardMatch(text, rewards);
      final reward = match.reward;
      if (reward == null) {
        return GuideTurnResponse(
          result: _buildGuideRedeemRewardNeedConfirmation(
            text,
            candidates: match.candidates,
          ),
        );
      }

      if (_controller.currentGold < reward.cost) {
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '这次先换不了，我看到你的金币还差一点。',
              'Not just yet. You are a little short on gold for this one.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('这次还差一点', 'Almost there'),
              title: _guideText(
                '金币还不够兑换 ${reward.localizedTitle(false)}',
                'Not enough gold for ${reward.localizedTitle(true)}',
              ),
              description: _guideText(
                '它需要 ${reward.cost} 金币，你现在有 ${_controller.currentGold} 金币。',
                'It needs ${reward.cost} gold, and you currently have ${_controller.currentGold}.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      }

      final redeemed = await rewardController.buyReward(reward);
      if (!redeemed) {
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '我试着帮你兑换这个奖励，但这次没有成功。',
              'I tried to redeem this reward for you, but it did not go through this time.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('这次没接稳', 'This did not stick'),
              title: _guideText(
                '未能兑换 ${reward.localizedTitle(false)}',
                'Could not redeem ${reward.localizedTitle(true)}',
              ),
              description: _guideText(
                '你可以稍后再试一次，或者先打开商店看看当前可兑换的奖励。',
                'You can try again shortly, or open the shop to review what is currently redeemable.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
        );
      }

      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '好，我已经帮你把这个奖励兑好了。',
            'Done. I have redeemed that reward for you.',
          ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('已为你兑换', 'Redeemed for you'),
            title: _guideText(
              '已兑换 ${reward.localizedTitle(false)}',
              'Redeemed ${reward.localizedTitle(true)}',
            ),
            description: _guideText(
              '这次一共花了 ${reward.cost} 金币，奖励已经放进你的背包或立即生效。',
              'This spent ${reward.cost} gold, and the reward is now in your inventory or already active.',
            ),
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

  List<String> _buildGuideQuickActions(GuideChatIntent intent) {
    switch (intent) {
      case GuideChatIntent.advice:
        return [
          context.tr('guide.quick.help_sort'),
          context.tr('guide.quick.ask_advice'),
          context.tr('guide.quick.push_or_rest'),
        ];
      case GuideChatIntent.action:
        return [
          context.tr('guide.quick.generate_task'),
          context.tr('guide.quick.open_stats'),
          context.tr('guide.quick.view_weekly'),
        ];
      case GuideChatIntent.companion:
        return [
          context.tr('guide.quick.listen_more'),
          context.tr('guide.quick.stay_with_me'),
          context.tr('guide.quick.hardest_part'),
        ];
    }
  }

  String _buildGuideQuickActionAnalysis(
    String action,
    String latestUserText,
  ) {
    final source = latestUserText.trim();
    if (action == context.tr('guide.quick.listen_more')) {
      return source.isEmpty
          ? _guideText('我想继续说说。', 'I want to keep talking.')
          : _guideText('$source 我想继续说说。', '$source I want to keep talking.');
    }
    if (action == context.tr('guide.quick.stay_with_me')) {
      return source.isEmpty
          ? _guideText('我想让你陪我聊聊。', 'I want you to keep me company.')
          : _guideText('$source 我现在更想让你陪我聊聊。',
              '$source I now want you to be here with me.');
    }
    if (action == context.tr('guide.quick.hardest_part')) {
      return source.isEmpty
          ? _guideText('现在最难的是哪一块？', 'What feels hardest right now?')
          : _guideText(
              '$source 现在最难的是哪一块？', '$source What feels hardest right now?');
    }
    if (action == context.tr('guide.quick.help_sort')) {
      return source.isEmpty
          ? _guideText('帮我理一下。', 'Help me sort this out.')
          : _guideText('$source 帮我理一下。', '$source Help me sort this out.');
    }
    if (action == context.tr('guide.quick.ask_advice')) {
      return source.isEmpty
          ? _guideText('给我一个建议。', 'Give me a suggestion.')
          : _guideText('$source 给我一个建议。', '$source Give me a suggestion.');
    }
    if (action == context.tr('guide.quick.push_or_rest')) {
      return source.isEmpty
          ? _guideText('现在更适合推进还是休息？', 'Should I push forward or rest now?')
          : _guideText(
              '$source 现在更适合推进还是休息？',
              '$source Should I push forward or rest now?',
            );
    }
    if (action == context.tr('guide.quick.generate_task')) {
      return source.isEmpty
          ? _guideText('把这句变成任务。', 'Turn this into a quest.')
          : _guideText('把“$source”变成任务。', 'Turn "$source" into a quest.');
    }
    if (action == context.tr('guide.quick.view_weekly')) {
      return _guideText('看看这周怎么样。', 'See how this week went.');
    }
    if (action == context.tr('guide.quick.open_stats')) {
      return _guideText('打开统计。', 'Open the stats.');
    }
    return action;
  }

  String _guideCompanionReply(String text) {
    final normalized = text.trim();
    if (normalized.contains('不开心') || normalized.contains('难过')) {
      return _guideText(
        '我听到了。你现在更需要先被接住，而不是立刻把自己整理好。我们先把让你不舒服的那一块放到台面上，我陪你慢慢说。',
        'I hear you. You need to be held first, not forced to tidy up. Let us lay out the uncomfortable part while I stay with you.',
      );
    }
    if (normalized.contains('乱')) {
      return _guideText(
        '$_guideName在。你现在不像完全停住，更像是事情一下子都挤过来了。先别急着安排任务，我们先把乱的地方说清楚。',
        '$_guideName is here. It feels less like being stuck and more like everything coming at once. Let us name the mess before planning anything.',
      );
    }
    if (normalized.contains('累') ||
        normalized.contains('不想动') ||
        normalized.contains('撑')) {
      return _guideText(
        '听起来你更需要被接住，而不是被催。我们先不急着推进，我先陪你把状态放平一点。',
        'It sounds like you need to be held, not pushed. Let us pause progress while I help you settle first.',
      );
    }
    return _guideText(
      '我在听。你不用现在就把事情说得很完整，我们先把最想说的那一块放到台面上。',
      'I am listening. You do not need to explain everything right now; let us start with the part you most want to say.',
    );
  }

  List<String> _buildGuideEntryQuickActions() {
    return [
      context.tr('guide.mode.generate_task'),
      context.tr('guide.mode.modify_task'),
      context.tr('guide.mode.companion'),
    ];
  }

  List<String> _buildGuideModeExamples(String action) {
    if (action == context.tr('guide.mode.generate_task')) {
      return [
        _guideText(
          '把“准备周会开场白”变成任务',
          'Turn "Prepare the meeting opening" into a task',
        ),
        _guideText(
          '帮我生成开会任务',
          'Help me generate a meeting task',
        ),
        _guideText(
          '给我一个恢复任务',
          'Give me a recovery task',
        ),
      ];
    }
    if (action == context.tr('guide.mode.modify_task')) {
      return [
        _guideText(
          '修改任务“开会”，截止时间是 3 月 20 日',
          'Edit the "Meeting" task to be due on March 20',
        ),
        _guideText(
          '把“开会”标题改成“准备周会”',
          'Change the title "Meeting" to "Prepare the meeting"',
        ),
        _guideText(
          '把“开会”拆成：确认时间、整理材料、写开场',
          'Split "Meeting" into: confirm the time, organize materials, write the opener',
        ),
      ];
    }
    return [
      _guideText('我现在有点乱', 'I am feeling scattered right now'),
      _guideText('陪我聊聊开会前的压力', 'Talk with me about the pre-meeting pressure'),
      _guideText('最难的是开场那一块', 'The hardest part is the opening'),
    ];
  }

  String _buildGuideInputHint(String guideName, {String? action}) {
    if (action == context.tr('guide.mode.generate_task')) {
      return context.tr('guide.input.generate_hint');
    }
    if (action == context.tr('guide.mode.modify_task')) {
      return context.tr('guide.input.modify_hint');
    }
    if (action == context.tr('guide.mode.companion')) {
      return context.tr('guide.input.companion_hint');
    }
    return context.tr(
      'guide.input.hint',
      params: {'name': guideName},
    );
  }

  String _guideCompanionCardContent(String text) {
    final normalized = text.trim();
    final lower = normalized.toLowerCase();
    final memory = _guideMemorySummary().trim();
    if (normalized.contains('不开心') ||
        normalized.contains('难过') ||
        lower.contains('sad') ||
        lower.contains('upset')) {
      if (memory.isNotEmpty) {
        return _guideText(
          '$_guideName记得：$memory。你现在可以先不用急着解决问题，我们先把这份难过说清楚。',
          '$_guideName remembers: $memory. You do not need to solve it yet. Let us name what feels heavy first.',
        );
      }
      return _guideText(
        '$_guideName会先陪你把这份难过放下来，再一起看接下来最需要被照顾的是哪一块。',
        '$_guideName will stay with you first, then help you see what needs care most right now.',
      );
    }
    if (normalized.contains('乱') ||
        lower.contains('scattered') ||
        lower.contains('overwhelmed')) {
      return _guideText(
        '$_guideName会先陪你把眼前最乱的那一块摊开，不急着立刻下结论。',
        '$_guideName will help you unpack the messiest part first, without rushing to a conclusion.',
      );
    }
    if (normalized.contains('累') ||
        normalized.contains('不想动') ||
        normalized.contains('拖') ||
        lower.contains('tired') ||
        lower.contains('burned out') ||
        lower.contains('stuck')) {
      return _guideText(
        '$_guideName会先帮你把节奏放慢一点，再决定现在是休息、梳理还是只说一会儿。',
        '$_guideName will slow the pace down first, then decide whether you need rest, structure, or just a little company.',
      );
    }
    if (memory.isNotEmpty) {
      return _guideText(
        '$_guideName记得：$memory',
        '$_guideName remembers: $memory',
      );
    }
    return _guideText(
      '$_guideName会先陪你把现在的状态说清楚，再决定要不要动手。',
      '$_guideName will help you describe where you are first, then decide whether to take action.',
    );
  }

  GuideChatResult _buildCompanionGuideResult(String text) {
    return GuideChatResult(
      reply: _guideCompanionReply(text),
      intent: GuideChatIntent.companion,
      quickActions: _buildGuideQuickActions(GuideChatIntent.companion),
      messageCard: GuideMessageCard(
        label: _guideText('我听到了', 'I hear you'),
        content: _guideCompanionCardContent(text),
      ),
      resultCard: null,
      suggestedTask: null,
      taskEditDraft: null,
      memoryRefs: const <String>[],
    );
  }

  GuideChatResult _buildAdviceGuideResult(String text) {
    final normalized = text.trim();
    final lower = normalized.toLowerCase();
    var reply = _guideText(
      '我会先帮你判断，不急着把话直接变成任务。',
      'I will help you judge the situation first, instead of turning it into a task too quickly.',
    );
    var cardContent = _guideText(
      '先分轻重，再决定推进还是恢复，会比硬撑更稳。',
      'Sort what is heavy first, then choose between progress and recovery. That is steadier than forcing it.',
    );
    if (normalized.contains('休息') ||
        normalized.contains('推进') ||
        lower.contains('rest') ||
        lower.contains('push')) {
      reply = _guideText(
        '如果你还能推进一点点，我建议保留一个最小动作；如果已经发涩，就先给自己留恢复边界。',
        'If you can still move a little, keep one tiny action. If you already feel stuck, protect a recovery boundary first.',
      );
      cardContent = _guideText(
        '现在更像是“保留一点推进，同时别把自己压扁”，适合轻推进。',
        'This looks more like keeping a little momentum without crushing yourself.',
      );
    } else if (normalized.contains('不知道') ||
        lower.contains('not sure') ||
        lower.contains('what should i do first')) {
      reply = _guideText(
        '不知道先做什么的时候，通常不是懒，而是缺一个足够小的起点。',
        'When you do not know where to start, the problem is usually not laziness. It is the lack of a small enough starting point.',
      );
      cardContent = _guideText(
        '先找一件 5 到 10 分钟能开始的事，会比追求完整计划更有效。',
        'Pick one thing you can start within 5 to 10 minutes. That is usually more useful than waiting for a perfect plan.',
      );
    }

    return GuideChatResult(
      reply: reply,
      intent: GuideChatIntent.advice,
      quickActions: _buildGuideQuickActions(GuideChatIntent.advice),
      messageCard: GuideMessageCard(
        label: _guideText('我的判断', 'My take'),
        content: cardContent,
      ),
      resultCard: null,
      suggestedTask: null,
      taskEditDraft: null,
      memoryRefs: const <String>[],
    );
  }


  List<String> _guideRecoveryTasks() {
    if (context.isEnglish) {
      return const <String>[
        'Stand up and stretch for 5 minutes',
        'Drink a warm glass of water',
        'Take a 10-minute walk outside',
        'Close your eyes and breathe for 3 minutes',
        'Wash your face and loosen your shoulders',
        'Play one song you love and unwind',
        'Tidy up your desk for a moment',
        'Make yourself a cup of tea',
      ];
    }
    return const <String>[
      '站起来拉伸 5 分钟',
      '喝一杯温水',
      '出门散步 10 分钟',
      '闭眼深呼吸 3 分钟',
      '洗把脸，活动一下肩颈',
      '听一首喜欢的歌放松一下',
      '整理一下桌面',
      '给自己泡一杯茶',
    ];
  }

  String _randomGuideRecoveryTask() {
    final tasks = _guideRecoveryTasks().toList()..shuffle();
    return tasks.first;
  }

  String _normalizeGuideTaskTitle(String raw) {
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

  String _guideTaskDescription(String raw) {
    final cleaned = raw.replaceAll('。', '').trim();
    if (cleaned.isEmpty) {
      return _guideText(
        '$_guideName根据这次对话整理出的新任务。',
        'A new task $_guideName organized from this conversation.',
      );
    }
    return cleaned;
  }


  String _formatGuideDueDate(DateTime date) {
    final local = date.toLocal();
    if (context.isEnglish) {
      const months = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[local.month - 1]} ${local.day}';
    }
    return '${local.month}月${local.day}日';
  }


  List<String> _buildGuideSplitSteps(QuestNode quest, String text) {
    final explicitSteps = _guideController.extractGuideStepTitles(text);
    if (explicitSteps.length >= 2) {
      return explicitSteps.take(3).toList();
    }
    if (context.isEnglish) {
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

  List<String> _buildGuideGeneratedSubtasks(String title, String text) {
    final explicitSteps = _guideController.extractGuideStepTitles(text);
    if (explicitSteps.length >= 2) {
      return explicitSteps.take(3).toList();
    }
    final lowerTitle = title.toLowerCase();
    if (title.contains('开会') ||
        title.contains('会议') ||
        lowerTitle.contains('meeting')) {
      return context.isEnglish
          ? const <String>[
              'Confirm the time',
              'Organize the materials',
              'Write the opener',
            ]
          : const <String>['确认时间', '整理材料', '写开场'];
    }
    if (title.contains('打扫') ||
        title.contains('卫生') ||
        lowerTitle.contains('clean')) {
      return context.isEnglish
          ? const <String>[
              'Clear the desk clutter',
              'Wipe the surfaces',
              'Sweep and mop the floor',
            ]
          : const <String>['清桌面杂物', '擦拭台面灰尘', '扫地拖地'];
    }
    if (context.isEnglish) {
      return <String>[
        'Clarify the scope of $title',
        'Finish the first step of $title',
        'Wrap up and review $title',
      ];
    }
    return <String>[
      '确认$title的范围',
      '先完成$title的第一步',
      '收尾并检查$title',
    ];
  }


  Future<GuideTurnResponse> _handlePendingGuideTaskEdit(String text) async {
    final draft = _guideController.pendingGuideTaskEditDraft;
    if (draft == null) {
      return GuideTurnResponse(result: _buildAdviceGuideResult(text));
    }
    if (_guideController.isGuideCancellationText(text)) {
      _guideController.pendingGuideTaskEditDraft = null;
      _guideController.pendingGuideTaskDueDate = null;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '好，那我先不继续这轮任务修改。你想继续时，直接告诉我要改哪条任务就行。',
            'Okay. I will pause this task edit for now. When you want to continue, just tell me which task to change.',
          ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('已为你保留', 'Kept as is'),
            title: _guideText('这次先不改任务板', 'No task-board change this time'),
            description: _guideText(
              '原任务会保持不变，等你准备好再继续拆。',
              'The original task stays untouched until you want to split it again.',
            ),
          ),
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }
    if (!_guideController.isGuideConfirmationText(text)) {
      return GuideTurnResponse(result: _buildAdviceGuideResult(text));
    }

    if (draft.action == 'generate_missing') {
      final inserted = await _controller.addGuideSuggestedTask(
        title: draft.taskTitle,
        description: draft.updatedDescription.trim().isEmpty
            ? _guideTaskDescription('')
            : draft.updatedDescription,
        xpReward: draft.updatedXpReward ?? 20,
        questTier: 'Daily',
      );
      if (inserted == null) {
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '我刚才试着按你的条件补一条新任务，但这次没有成功。你可以再说一次，我继续帮你生成。',
              'I tried to add a new task that matches your request, but it did not go through this time. Tell me again and I will keep helping.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('这次没接住', 'This did not stick'),
              title: _guideText('新任务还没加进去', 'The new task was not added'),
              description: _guideText(
                '草稿我还记着，你继续确认时我会再试一次。',
                'I still remember the draft and can try again when you confirm.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: draft,
            memoryRefs: const <String>[],
          ),
          pendingTaskEditDraft: draft,
          pendingTaskDueDate: _guideController.pendingGuideTaskDueDate,
        );
      }
      if (_guideController.pendingGuideTaskDueDate != null) {
        await _controller.updateQuestDetails(
          inserted.id,
          dueDate: _guideController.pendingGuideTaskDueDate,
        );
      }
      List<QuestNode> insertedChildren = const <QuestNode>[];
      if (draft.subtasks.isNotEmpty) {
        insertedChildren = await _controller.addGuideChildTasks(
          parent: inserted,
          stepTitles: draft.subtasks,
          xpReward: ((draft.updatedXpReward ?? inserted.xpReward) / 2).round(),
        );
      }
      final dueDate = _guideController.pendingGuideTaskDueDate;
      _guideController.pendingGuideTaskEditDraft = null;
      _guideController.pendingGuideTaskDueDate = null;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: insertedChildren.isEmpty
              ? _guideText(
                  '好，我已经按这轮条件补了一条“${inserted.title}”任务。',
                  'Done. I added a new task called "${inserted.title}" for you.',
                )
              : _guideText(
                  '好，我已经按这轮条件补了一条“${inserted.title}”任务，也顺手拆成了子项。',
                  'Done. I added a new task called "${inserted.title}" and also split it into subtasks.',
                ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('已为你生成', 'Created for you'),
            title: _guideText(
                '已加入任务：${inserted.title}', 'Task added: ${inserted.title}'),
            description: _guideText(
              dueDate == null
                  ? (insertedChildren.isEmpty
                      ? '这条任务已经放进任务板，可以直接开始。'
                      : '这条任务已经放进任务板，并补上了 ${insertedChildren.length} 个子项。')
                  : (insertedChildren.isEmpty
                      ? '这条任务已经放进任务板，截止时间设为${_formatGuideDueDate(dueDate)}。'
                      : '这条任务已经放进任务板，截止时间设为${_formatGuideDueDate(dueDate)}，并补上了 ${insertedChildren.length} 个子项。'),
              dueDate == null
                  ? (insertedChildren.isEmpty
                      ? 'The task is on your board and ready to start.'
                      : 'The task is on your board with ${insertedChildren.length} subtasks ready to go.')
                  : (insertedChildren.isEmpty
                      ? 'The task is on your board with a due date of ${_formatGuideDueDate(dueDate)}.'
                      : 'The task is on your board with a due date of ${_formatGuideDueDate(dueDate)} and ${insertedChildren.length} subtasks.'),
            ),
          ),
          suggestedTask: null,
          taskEditDraft: insertedChildren.isEmpty
              ? null
              : GuideTaskEditDraft(
                  taskId: inserted.id,
                  taskTitle: inserted.title,
                  action: 'split',
                  updatedTitle: '',
                  updatedDescription: '',
                  updatedXpReward: null,
                  subtasks: insertedChildren.map((item) => item.title).toList(),
                ),
          memoryRefs: const <String>[],
        ),
      );
    }

    final target = _guideController.findGuideTaskById(draft.taskId) ??
        _guideController.findGuideTargetTask(draft.taskTitle);
    if (target == null) {
      _guideController.pendingGuideTaskEditDraft = null;
      _guideController.pendingGuideTaskDueDate = null;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '我没在任务板里找到刚才那条任务，可能已经被删掉或改名了。你把任务名再告诉我一次，我马上继续。',
            'I could not find that task on your board just now. It may have been deleted or renamed. Tell me the task name again and I will continue.',
          ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('需要重新确认', 'Need to re-confirm'),
            title: _guideText('找不到原任务', 'Task not found'),
            description: _guideText(
              '重新说一次任务名，我就能继续把子项落进任务板。',
              'Tell me the task name again and I can keep applying the subtasks.',
            ),
          ),
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }

    if (draft.action == 'sync_due_date' && _guideController.pendingGuideTaskDueDate != null) {
      final dueDate = _guideController.pendingGuideTaskDueDate!;
      final children = _controller.activeQuests
          .where(
            (quest) =>
                quest.parentId == target.id &&
                !quest.isReward &&
                !quest.isDeleted,
          )
          .toList(growable: false);
      for (final child in children) {
        await _controller.updateQuestDetails(child.id, dueDate: dueDate);
      }
      _guideController.pendingGuideTaskEditDraft = null;
      _guideController.pendingGuideTaskDueDate = null;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: children.isEmpty
              ? _guideText(
                  '好，不过这条任务下面目前没有子任务，所以我先只保留主任务的截止时间。',
                  'Okay. There are no subtasks under this task right now, so I only kept the parent due date.',
                )
              : _guideText(
                  '好，我已经把拆解后的子任务截止时间也一起同步到${_formatGuideDueDate(dueDate)}了。',
                  'Okay. I also synced the subtasks to ${_formatGuideDueDate(dueDate)}.',
                ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('已为你同步', 'Synced for you'),
            title: _guideText(
              children.isEmpty ? '当前没有可同步的子任务' : '已同步子任务截止时间',
              children.isEmpty
                  ? 'No subtasks to sync right now'
                  : 'Subtask due date synced',
            ),
            description: _guideText(
              children.isEmpty
                  ? '主任务截止时间仍然保留为${_formatGuideDueDate(dueDate)}。'
                  : '这次共同步了 ${children.length} 项，主任务和子任务现在都对齐到${_formatGuideDueDate(dueDate)}。',
              children.isEmpty
                  ? 'The parent task still keeps ${_formatGuideDueDate(dueDate)} as its due date.'
                  : 'Synced ${children.length} subtasks so everything now lines up to ${_formatGuideDueDate(dueDate)}.',
            ),
          ),
          suggestedTask: null,
          taskEditDraft: GuideTaskEditDraft(
            taskId: target.id,
            taskTitle: target.title,
            action: 'sync_due_date',
            updatedTitle: '',
            updatedDescription: '',
            updatedXpReward: null,
            subtasks: children.map((item) => item.title).toList(),
          ),
          memoryRefs: const <String>[],
        ),
      );
    }

    if (draft.action == 'split' && draft.subtasks.isNotEmpty) {
      final inserted = await _controller.addGuideChildTasks(
        parent: target,
        stepTitles: draft.subtasks,
        xpReward: (target.xpReward / 2).round(),
      );
      if (inserted.isEmpty) {
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '我刚才试着把这些子项放进任务板，但这次没有成功。你可以再说一次，我继续帮你落板。',
              'I tried to place these subtasks on your board, but it did not work this time. Tell me again and I will keep helping.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('这次没接住', 'This did not stick'),
              title: _guideText('子任务还没加进去', 'Subtasks were not added'),
              description: _guideText(
                '原任务还在，等你继续确认时我会再试一次。',
                'The parent task is still there, and I can try adding the subtasks again.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: draft,
            memoryRefs: const <String>[],
          ),
          pendingTaskEditDraft: draft,
        );
      }
      _guideController.pendingGuideTaskEditDraft = null;
      _guideController.pendingGuideTaskDueDate = null;
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '好，我已经把这几项放进任务板，作为“${target.title}”的子任务了。',
            'Done. I added these items as subtasks under "${target.title}".',
          ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('已为你拆好', 'Split for you'),
            title: _guideText(
                '已补上子任务：${target.title}', 'Subtasks added: ${target.title}'),
            description: _guideText(
              '这次共加了 ${inserted.length} 项，你可以直接从第一项开始。',
              'Added ${inserted.length} subtasks so you can start with the first one now.',
            ),
          ),
          suggestedTask: null,
          taskEditDraft: GuideTaskEditDraft(
            taskId: target.id,
            taskTitle: target.title,
            action: 'split',
            updatedTitle: '',
            updatedDescription: '',
            updatedXpReward: null,
            subtasks: inserted.map((item) => item.title).toList(),
          ),
          memoryRefs: const <String>[],
        ),
      );
    }

    _guideController.pendingGuideTaskEditDraft = null;
    _guideController.pendingGuideTaskDueDate = null;
    return GuideTurnResponse(result: _buildAdviceGuideResult(text));
  }

  Future<GuideTurnResponse> _handleGuideGenerateTask(String text) async {
    final quoted = _guideController.extractQuotedText(text);
    final source = (quoted != null && quoted.isNotEmpty) ? quoted : text;
    final title = _normalizeGuideTaskTitle(source);
    if (title.isEmpty) {
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '我还没抓到要生成的事情。你可以直接说一句具体要做的事，比如“整理会议材料”。',
            'I still have not caught the thing you want to create. Tell me one concrete thing to do, like "Organize the meeting materials".',
          ),
          intent: GuideChatIntent.advice,
          quickActions: _buildGuideQuickActions(GuideChatIntent.advice),
          messageCard: GuideMessageCard(
            label: _guideText('还需要你确认', 'Need your confirmation'),
            content: _guideText(
              '告诉我一句更具体的事，我就能帮你直接生成任务。',
              'Give me one clearer sentence and I can turn it into a task.',
            ),
          ),
          resultCard: null,
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }

    final inserted = await _controller.addGuideSuggestedTask(
      title: title,
      description: _guideTaskDescription(source),
      xpReward: 20,
      questTier: 'Daily',
    );
    if (inserted == null) {
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '我刚刚试着帮你生成任务，但这次没有成功。你可以换个更明确的说法，我再试一次。',
            'I just tried to create the task for you, but it did not work this time. Try a clearer request and I will try again.',
          ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('这次没接稳', 'This did not stick'),
            title: _guideText('这次没有执行成功', 'Could not finish it'),
            description: _guideText(
              '你可以换个更明确的说法，我会继续帮你。',
              'Try a more specific request and I will keep helping.',
            ),
          ),
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }

    List<QuestNode> insertedChildren = const <QuestNode>[];
    if (_guideController.shouldGuideGenerateSubtasks(text)) {
      insertedChildren = await _controller.addGuideChildTasks(
        parent: inserted,
        stepTitles: _buildGuideGeneratedSubtasks(inserted.title, text),
        xpReward: (inserted.xpReward / 2).round(),
      );
    }

    return GuideTurnResponse(
      result: GuideChatResult(
        reply: insertedChildren.isEmpty
            ? _guideText(
                '好，我已经把这句话整理成任务，放到任务板里了。',
                'Done. I turned that sentence into a task and placed it on your board.',
              )
            : _guideText(
                '好，我已经把这句话整理成任务，也顺手帮你拆成可以直接开做的子项了。',
                'Done. I turned that sentence into a task and also split it into subtasks you can start right away.',
              ),
        intent: GuideChatIntent.action,
        quickActions: _buildGuideQuickActions(GuideChatIntent.action),
        messageCard: null,
        resultCard: GuideResultCard(
          label: _guideText('已为你生成', 'Created for you'),
          title: _guideText(
            '已加入任务：${inserted.title}',
            'Task added: ${inserted.title}',
          ),
          description: _guideText(
            insertedChildren.isEmpty
                ? '这条任务已经放进任务板，可以直接开始。'
                : '这条任务已经放进任务板，并补上了 ${insertedChildren.length} 个子项。',
            insertedChildren.isEmpty
                ? 'The task is on your board and ready to start.'
                : 'The task is on your board with ${insertedChildren.length} subtasks ready to go.',
          ),
        ),
        suggestedTask: null,
        taskEditDraft: insertedChildren.isEmpty
            ? null
            : GuideTaskEditDraft(
                taskId: inserted.id,
                taskTitle: inserted.title,
                action: 'split',
                updatedTitle: '',
                updatedDescription: '',
                updatedXpReward: null,
                subtasks: insertedChildren.map((item) => item.title).toList(),
              ),
        memoryRefs: const <String>[],
      ),
    );
  }

  Future<GuideTurnResponse> _handleGuideModifyTask(String text) async {
    final target = _guideController.findGuideTargetTask(text);
    if (target == null) {
      final suggestedTitle = _guideController.guessGuideTaskTitleFromModifyText(text);
      if (suggestedTitle.isNotEmpty) {
        final dueDate = _guideController.extractGuideDueDate(text.trim());
        final shouldGenerateSubtasks = _guideController.shouldGuideGenerateSubtasks(text);
        final draft = GuideTaskEditDraft(
          taskId: '',
          taskTitle: suggestedTitle,
          action: 'generate_missing',
          updatedTitle: '',
          updatedDescription: _guideTaskDescription(text),
          updatedXpReward: 20,
          subtasks: shouldGenerateSubtasks
              ? _buildGuideGeneratedSubtasks(suggestedTitle, text)
              : const <String>[],
        );
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: dueDate == null
                ? _guideText(
                    '我现在没在任务板里找到“$suggestedTitle”。要不要我直接按你的条件生成一个新任务？',
                    'I cannot find "$suggestedTitle" on your board right now. Do you want me to create a new task that matches your request?',
                  )
                : _guideText(
                    '我现在没在任务板里找到“$suggestedTitle”。要不要我直接生成一个新任务，并把截止时间设为${_formatGuideDueDate(dueDate)}？',
                    'I cannot find "$suggestedTitle" on your board right now. Do you want me to create a new task with a due date of ${_formatGuideDueDate(dueDate)}?',
                  ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: GuideMessageCard(
              label: _guideText('还需要你确认', 'Need your confirmation'),
              content: _guideText(
                dueDate == null
                    ? '你回复“需要”或“可以”，我就直接补一条符合条件的新任务。'
                    : '你回复“需要”或“可以”，我就直接补一条符合条件的新任务，并带上这个截止时间。',
                dueDate == null
                    ? 'Reply "Yes" and I will create a matching task directly.'
                    : 'Reply "Yes" and I will create a matching task with that due date.',
              ),
            ),
            resultCard: GuideResultCard(
              label: _guideText('当前没找到原任务', 'No matching task found'),
              title: _guideText(
                '可以直接生成：$suggestedTitle',
                'Can generate directly: $suggestedTitle',
              ),
              description: _guideText(
                dueDate == null
                    ? '这次会按你刚才的条件补一个新任务到任务板。'
                    : '这次会按你刚才的条件补一个新任务到任务板，并把截止时间设为${_formatGuideDueDate(dueDate)}。',
                dueDate == null
                    ? 'This will add a new matching task to your board.'
                    : 'This will add a new matching task to your board with a due date of ${_formatGuideDueDate(dueDate)}.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: draft,
            memoryRefs: const <String>[],
          ),
          pendingTaskEditDraft: draft,
          pendingTaskDueDate: dueDate,
        );
      }
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '我还没确定你想改哪一条任务。你可以直接说任务名，比如“把‘准备周会’改轻一点”。',
            'I am not sure which task you want to change yet. You can say the task name directly, like "Lighten up Prepare the weekly meeting".',
          ),
          intent: GuideChatIntent.advice,
          quickActions: _buildGuideQuickActions(GuideChatIntent.advice),
          messageCard: GuideMessageCard(
            label: _guideText('还需要你确认', 'Need your confirmation'),
            content: _guideText(
              '告诉我具体任务名，我就能继续帮你改。',
              'Tell me the task name and I can keep editing it.',
            ),
          ),
          resultCard: null,
          suggestedTask: null,
          taskEditDraft: null,
          memoryRefs: const <String>[],
        ),
      );
    }

    final normalized = text.trim();
    final xp = _guideController.extractGuideXp(normalized);
    final dueDate = _guideController.extractGuideDueDate(normalized);
    final renameMatch = RegExp(r'(?:标题改成|改成)(.+)$').firstMatch(normalized);
    final descriptionMatch =
        RegExp(r'(?:描述改成|说明改成)(.+)$').firstMatch(normalized);
    final naturalTitle = renameMatch == null && descriptionMatch == null
        ? _guideController.extractGuideNaturalTitleFromModifyText(normalized, target)
        : null;

    if (normalized.contains('拆') || normalized.contains('拆成')) {
      final steps = _buildGuideSplitSteps(target, normalized);
      final inserted = await _controller.addGuideChildTasks(
        parent: target,
        stepTitles: steps,
        xpReward: (target.xpReward / 2).round(),
      );
      if (inserted.isEmpty) {
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '我试着帮你拆小这条任务，但这次没有成功。',
              'I tried to break this task into smaller steps, but it did not work this time.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('这次没接稳', 'This did not stick'),
              title: _guideText('这次没有执行成功', 'Could not finish it'),
              description: _guideText(
                '你可以换个更明确的说法，我会继续帮你。',
                'Try a more specific request and I will keep helping.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: GuideTaskEditDraft(
              taskId: target.id,
              taskTitle: target.title,
              action: 'split',
              updatedTitle: '',
              updatedDescription: '',
              updatedXpReward: null,
              subtasks: steps,
            ),
            memoryRefs: const <String>[],
          ),
        );
      }
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '好，我已经把“${target.title}”拆成更容易开始的几步了。',
            'Done. I split "${target.title}" into a few easier starting steps.',
          ),
          intent: GuideChatIntent.action,
          quickActions: _buildGuideQuickActions(GuideChatIntent.action),
          messageCard: null,
          resultCard: GuideResultCard(
            label: _guideText('已为你拆小', 'Split for you'),
            title: _guideText(
              '已拆分任务：${target.title}',
              'Split task: ${target.title}',
            ),
            description: _guideText(
              '已经补上 ${inserted.length} 个更容易开始的子步骤。',
              'Added ${inserted.length} smaller starting steps.',
            ),
          ),
          suggestedTask: null,
          taskEditDraft: GuideTaskEditDraft(
            taskId: target.id,
            taskTitle: target.title,
            action: 'split',
            updatedTitle: '',
            updatedDescription: '',
            updatedXpReward: null,
            subtasks: inserted.map((item) => item.title).toList(),
          ),
          memoryRefs: const <String>[],
        ),
      );
    }

    String? nextTitle;
    String? nextDescription;
    var hasDescriptionUpdate = false;
    int? nextXp;
    String resultDescription = _guideText(
      '任务内容已经按你的意思改好了。',
      'The task has been updated the way you asked.',
    );

    if (renameMatch != null) {
      nextTitle = renameMatch.group(1)?.trim();
    }
    if (naturalTitle != null) {
      nextTitle = naturalTitle;
    }
    if (descriptionMatch != null) {
      nextDescription = descriptionMatch.group(1)?.trim() ?? '';
      hasDescriptionUpdate = true;
    }
    if (xp != null) {
      nextXp = xp.clamp(5, 200);
      resultDescription = _guideText(
        '这条任务的 XP 已调整为 $nextXp。',
        'XP has been adjusted to $nextXp.',
      );
    }
    if (normalized.contains('改轻') || normalized.contains('轻一点')) {
      nextXp = (target.xpReward - 10).clamp(5, 200);
      resultDescription = _guideText(
        '这条任务的 XP 已调整为 $nextXp。',
        'XP has been adjusted to $nextXp.',
      );
    }

    final resultDescriptionZh = <String>[];
    final resultDescriptionEn = <String>[];
    if (nextTitle != null) {
      resultDescriptionZh.add('标题已改成$nextTitle');
      resultDescriptionEn.add('Title updated to $nextTitle');
    }
    if (hasDescriptionUpdate) {
      resultDescriptionZh.add('描述已更新');
      resultDescriptionEn.add('Description updated');
    }
    if (nextXp != null) {
      resultDescriptionZh.add('XP 已调整为 $nextXp');
      resultDescriptionEn.add('XP adjusted to $nextXp');
    }
    if (dueDate != null) {
      resultDescriptionZh.add('截止时间设为${_formatGuideDueDate(dueDate)}');
      resultDescriptionEn
          .add('Due date set to ${_formatGuideDueDate(dueDate)}');
    }
    if (resultDescriptionZh.isNotEmpty) {
      resultDescription = _guideText(
        '${resultDescriptionZh.join('，')}。',
        '${resultDescriptionEn.join(', ')}.',
      );
    }

    if (nextTitle == null &&
        !hasDescriptionUpdate &&
        nextXp == null &&
        dueDate == null) {
      return GuideTurnResponse(
        result: GuideChatResult(
          reply: _guideText(
            '我找到这条任务了。你可以继续告诉我，是想改标题、改描述、调 XP，还是把它拆小一点。',
            'I found the task. You can now tell me whether to change the title, update the description, adjust the XP, or break it into smaller steps.',
          ),
          intent: GuideChatIntent.advice,
          quickActions: _buildGuideQuickActions(GuideChatIntent.advice),
          messageCard: GuideMessageCard(
            label: _guideText('还需要你确认', 'Need your confirmation'),
            content: _guideText(
              '你现在想调整的是“${target.title}”。',
              'You are adjusting "${target.title}".',
            ),
          ),
          resultCard: null,
          suggestedTask: null,
          taskEditDraft: GuideTaskEditDraft(
            taskId: target.id,
            taskTitle: target.title,
            action: 'confirm',
            updatedTitle: '',
            updatedDescription: '',
            updatedXpReward: null,
            subtasks: const <String>[],
          ),
          memoryRefs: const <String>[],
        ),
      );
    }

    if (hasDescriptionUpdate && dueDate != null) {
      await _controller.updateQuestDetails(
        target.id,
        title: nextTitle,
        description: nextDescription,
        dueDate: dueDate,
        xpReward: nextXp,
      );
    } else if (hasDescriptionUpdate) {
      await _controller.updateQuestDetails(
        target.id,
        title: nextTitle,
        description: nextDescription,
        xpReward: nextXp,
      );
    } else if (dueDate != null) {
      await _controller.updateQuestDetails(
        target.id,
        title: nextTitle,
        dueDate: dueDate,
        xpReward: nextXp,
      );
    } else {
      await _controller.updateQuestDetails(
        target.id,
        title: nextTitle,
        xpReward: nextXp,
      );
    }

    if (dueDate != null) {
      final childTasks = _controller.activeQuests
          .where(
            (quest) =>
                quest.parentId == target.id &&
                !quest.isReward &&
                !quest.isDeleted,
          )
          .toList(growable: false);
      if (childTasks.isNotEmpty) {
        final draft = GuideTaskEditDraft(
          taskId: target.id,
          taskTitle: nextTitle ?? target.title,
          action: 'sync_due_date',
          updatedTitle: nextTitle ?? '',
          updatedDescription:
              hasDescriptionUpdate ? (nextDescription ?? '') : '',
          updatedXpReward: nextXp,
          subtasks: childTasks.map((item) => item.title).toList(),
        );
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '已修改${nextTitle ?? target.title}任务，截止时间设为${_formatGuideDueDate(dueDate)}。需要我把拆解后的子任务也同步更新截止时间吗？',
              'The task "${nextTitle ?? target.title}" now has a due date of ${_formatGuideDueDate(dueDate)}. Do you want me to sync that date to its subtasks too?',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: GuideMessageCard(
              label: _guideText('还需要你确认', 'Need your confirmation'),
              content: _guideText(
                '这条任务下面还有 ${childTasks.length} 个子任务。你回复“可以”或“需要”，我就一起同步。',
                'This task still has ${childTasks.length} subtasks. Reply "Yes" and I will sync them too.',
              ),
            ),
            resultCard: GuideResultCard(
              label: _guideText('已为你调整', 'Updated for you'),
              title: _guideText(
                '已修改任务：${nextTitle ?? target.title}',
                'Task updated: ${nextTitle ?? target.title}',
              ),
              description: resultDescription,
            ),
            suggestedTask: null,
            taskEditDraft: draft,
            memoryRefs: const <String>[],
          ),
          pendingTaskEditDraft: draft,
          pendingTaskDueDate: dueDate,
        );
      }
    }

    return GuideTurnResponse(
      result: GuideChatResult(
        reply: _guideText(
          '好，我已经帮你把“${nextTitle ?? target.title}”改好了。',
          'Done. I updated "${nextTitle ?? target.title}" for you.',
        ),
        intent: GuideChatIntent.action,
        quickActions: _buildGuideQuickActions(GuideChatIntent.action),
        messageCard: null,
        resultCard: GuideResultCard(
          label: _guideText('已为你调整', 'Updated for you'),
          title: _guideText(
            '已修改任务：${nextTitle ?? target.title}',
            'Task updated: ${nextTitle ?? target.title}',
          ),
          description: resultDescription,
        ),
        suggestedTask: null,
        taskEditDraft: GuideTaskEditDraft(
          taskId: target.id,
          taskTitle: target.title,
          action: 'update',
          updatedTitle: nextTitle ?? '',
          updatedDescription:
              hasDescriptionUpdate ? (nextDescription ?? '') : '',
          updatedXpReward: nextXp,
          subtasks: const <String>[],
        ),
        memoryRefs: const <String>[],
      ),
    );
  }

  Future<GuideTurnResponse> _handleGuideAction(String text) async {
    final action = _guideController.matchGuideAction(text);
    switch (action) {
      case GuideActionType.generateTask:
        return _handleGuideGenerateTask(text);
      case GuideActionType.modifyTask:
        return _handleGuideModifyTask(text);
      case GuideActionType.openShop:
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '好，我先帮你把奖励商店打开。',
              'Okay, I will open the reward shop for you first.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('已为你打开', 'Opened for you'),
              title: _guideText('已打开奖励商店', 'Reward shop opened'),
              description: _guideText(
                '你可以继续看看现在能兑换什么，或者直接让我帮你兑换具体奖励。',
                'You can browse what is redeemable now, or tell me which reward to redeem next.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
          closeDialogBeforeAction: true,
          postAction: () async {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RewardShopPage(questController: _controller),
              ),
            );
          },
        );
      case GuideActionType.redeemReward:
        return _handleGuideRedeemReward(text);
      case GuideActionType.weeklySummary:
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '好，我带你去看看这周的记录和总结。',
              'Okay. I will take you to this week’s records and summary.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('已为你打开', 'Opened for you'),
              title: _guideText('已打开本周周报', 'Weekly report opened'),
              description: _guideText(
                '我带你去看这周的记录和总结。',
                'Opening this week’s records and summary now.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
          closeDialogBeforeAction: true,
          postAction: () async {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LifeDiaryPage()),
            );
          },
        );
      case GuideActionType.openStats:
        return GuideTurnResponse(
          result: GuideChatResult(
            reply: _guideText(
              '好，我先帮你把统计打开。',
              'Okay. I will open the stats view for you first.',
            ),
            intent: GuideChatIntent.action,
            quickActions: _buildGuideQuickActions(GuideChatIntent.action),
            messageCard: null,
            resultCard: GuideResultCard(
              label: _guideText('已为你打开', 'Opened for you'),
              title: _guideText('已打开统计面板', 'Stats opened'),
              description: _guideText(
                '最近的完成趋势和累计数据已经展开。',
                'Recent completion trends and totals are now visible.',
              ),
            ),
            suggestedTask: null,
            taskEditDraft: null,
            memoryRefs: const <String>[],
          ),
          closeDialogBeforeAction: true,
          postAction: () async {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StatsPage(questController: _controller),
              ),
            );
          },
        );
      case null:
        return GuideTurnResponse(
          result: _buildAdviceGuideResult(text),
        );
    }
  }

  Future<GuideTurnResponse> _handleGuideTurn(String text) async {
    if (_guideController.pendingGuideTaskEditDraft != null &&
        (_guideController.isGuideConfirmationText(text) || _guideController.isGuideCancellationText(text))) {
      return _handlePendingGuideTaskEdit(text);
    }

    if (_guideController.shouldRouteToAgent(text)) {
      final fallbackReply = context.tr('guide.fallback.reply');
      try {
        final localResult = await _startAgentRunFromGuideInput(text);
        // 超时标记：_waitForLocalAgentStepResult 超时时返回 errorText == '_agentTimeout'
        if (localResult?.errorText == '_agentTimeout' && mounted) {
          showForestSnackBar(context, context.tr('agent.timeout'));
        }
        final guideChatResult = _guideController.extractGuideChatResultFromAgentLocalResult(
          localResult,
        );
        final latest = _guideController.currentAgentRunResult().latestAssistantMessage;
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
          postAction: navigationTarget.isEmpty
              ? null
              : () => _performAgentNavigation(navigationTarget),
        );
      } catch (_) {
        final action = _guideController.matchGuideAction(text);
        if (action != null) {
          return _handleGuideAction(text);
        }
        final localResult = await _executeAgentFreeformChat(
          <String, dynamic>{'source_text': text},
        );
        final result =
            _guideController.extractGuideChatResultFromAgentLocalResult(localResult) ??
                GuideChatResult(
                  reply: localResult.outputText.trim().isEmpty
                      ? fallbackReply
                      : localResult.outputText.trim(),
                  intent: GuideChatIntent.companion,
                  quickActions:
                      _buildGuideQuickActions(GuideChatIntent.companion),
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

    final intent = _guideController.classifyGuideIntent(text);
    if (intent == GuideChatIntent.action) {
      _guideController.pendingGuideTaskEditDraft = null;
      _guideController.pendingGuideTaskDueDate = null;
      return _handleGuideAction(text);
    }

    final result = await _guideController.guideService.chat(
      message: text,
      scene: 'home',
      clientContext: _buildGuideClientContext(),
    );

    if (result.reply.trim().isNotEmpty ||
        result.messageCard != null ||
        result.resultCard != null ||
        result.quickActions.isNotEmpty) {
      return GuideTurnResponse(
        result: result,
        pendingTaskEditDraft:
            _guideController.shouldKeepPendingGuideTaskEditDraft(result.taskEditDraft)
                ? result.taskEditDraft
                : null,
        pendingTaskDueDate: null,
      );
    }

    return GuideTurnResponse(
      result: intent == GuideChatIntent.advice
          ? _buildAdviceGuideResult(text)
          : _buildCompanionGuideResult(text),
    );
  }

  Future<void> _openGuidePanel() async {
    if (_guideController.guideMessages.isEmpty) {
      _appendGuideMessage(
        'assistant',
        context.tr(
          'guide.default_opening',
          params: {'name': _guideName},
        ),
      );
    }

    final messages = List<GuideChatMessage>.from(_guideController.visibleGuideMessages());
    final input = TextEditingController();
    final entryActions = _buildGuideEntryQuickActions();
    List<String> currentExamplePrompts = const <String>[];
    var currentInputHint = _buildGuideInputHint(_guideName);
    var latestUserText = '';
    for (final item in messages.reversed) {
      if (item.role == 'user' && item.content.trim().isNotEmpty) {
        latestUserText = item.content.trim();
        break;
      }
    }
    var sending = false;

    Future<void> send(
      BuildContext dialogContext,
      StateSetter setModalState,
      String displayText, {
      String? analysisText,
    }) async {
      final shownText = displayText.trim();
      final text = (analysisText ?? displayText).trim();
      if (shownText.isEmpty || text.isEmpty || sending) return;
      setModalState(() {
        sending = true;
        messages.add(GuideChatMessage(role: 'user', content: shownText));
      });
      latestUserText = shownText;
      _appendGuideMessage('user', shownText);
      input.clear();

      try {
        final turn = await _handleGuideTurn(text);
        if (!mounted || !dialogContext.mounted) return;
        final result = _guideResultForCurrentLocale(turn.result);
        _guideController.pendingGuideTaskEditDraft = turn.pendingTaskEditDraft;
        _guideController.pendingGuideTaskDueDate = turn.pendingTaskDueDate;
        final reply = result.reply.trim().isNotEmpty
            ? result.reply
            : context.tr('guide.fallback.reply');
        setState(() => _guideController.guideStatus = GuideConnectionStatus.ready);
        if (turn.appendAssistantReply) {
          setModalState(() {
            messages.add(
              GuideChatMessage(
                role: 'assistant',
                content: reply,
                memoryRefCount: result.memoryRefs.length,
                memoryRefs: result.memoryRefs,
              ),
            );
            currentExamplePrompts = result.quickActions.isNotEmpty
                ? result.quickActions.take(3).toList()
                : _buildGuideQuickActions(result.intent);
            sending = false;
          });
          _appendGuideMessage(
            'assistant',
            reply,
            memoryRefs: result.memoryRefs,
          );
        } else {
          setModalState(() {
            messages
              ..clear()
              ..addAll(_guideController.visibleGuideMessages());
            currentExamplePrompts = result.quickActions.isNotEmpty
                ? result.quickActions.take(3).toList()
                : _buildGuideQuickActions(result.intent);
            sending = false;
          });
        }
        if (turn.closeDialogBeforeAction) {
          if (!dialogContext.mounted) return;
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          if (turn.postAction != null) {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            await turn.postAction!.call();
          }
        }
      } catch (e) {
        if (!mounted || !dialogContext.mounted) return;
        setState(() => _guideController.guideStatus = _guideController.statusFromError(e));
        final fallback = context.tr('guide.network_fallback');
        setModalState(() {
          messages.add(GuideChatMessage(role: 'assistant', content: fallback));
          sending = false;
        });
        _appendGuideMessage('assistant', fallback);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final guideName = _guideName;

          return GuidePanelDialog(
            title: guideName,
            guideName: guideName,
            subtitle: context.tr(
              'guide.hero.subtitle',
              params: {'name': guideName},
            ),
            guideMemoryTitle: context.tr(
              'guide.memory.title',
              params: {'name': guideName},
            ),
            guideMemorySummary: _guideMemorySummary(),
            guideMemorySignals: _guideController.guideBehaviorSignals,
            statusText: _guideController.guideStatus == GuideConnectionStatus.ready
                ? context.tr(
                    'guide.status.ready',
                    params: {'name': guideName},
                  )
                : context.tr(
                    'guide.status.retry',
                    params: {'name': guideName},
                  ),
            editNameLabel: context.tr('guide.name.edit'),
            closeTooltip: context.tr('common.close'),
            statusReady: _guideController.guideStatus == GuideConnectionStatus.ready,
            messages: messages
                .map(
                  (item) => GuideDialogMessage(
                    role: item.role == 'user'
                        ? GuideDialogRole.user
                        : GuideDialogRole.assistant,
                    content: item.content,
                    memoryRefCount: item.memoryRefCount,
                    memoryRefs: item.memoryRefs,
                  ),
                )
                .toList(),
            copyMessageTooltip: context.tr('common.copy'),
            quickActions: entryActions,
            examplePrompts: currentExamplePrompts,
            inputController: input,
            messageHistory: messages
                .where((item) => item.role == 'user')
                .map((item) => item.content)
                .toList(growable: false),
            inputHintText: currentInputHint,
            sendLabel: context.tr('common.send'),
            retryLabel: context.tr('common.retry'),
            closeLabel: context.tr('common.close'),
            sending: sending,
            memoryRefsLabelBuilder: (count) => context.tr(
              'guide.memory.refs',
              params: {'count': '$count'},
            ),
            onRetry: _guideController.guideStatus == GuideConnectionStatus.ready
                ? null
                : () => send(
                      dialogContext,
                      setModalState,
                      context.tr('guide.quick.listen_more'),
                      analysisText: latestUserText.isEmpty
                          ? _guideText(
                              '我想继续说说。',
                              'I want to keep talking.',
                            )
                          : _guideText(
                              '$latestUserText 我想继续说说。',
                              '$latestUserText I want to keep talking.',
                            ),
                    ),
            onCopyMessage: (value) => unawaited(_copyGuideMessage(value)),
            onSubmit: (value) => send(dialogContext, setModalState, value),
            onQuickActionTap: (action) {
              setModalState(() {
                currentExamplePrompts = _buildGuideModeExamples(action);
                currentInputHint = _buildGuideInputHint(
                  guideName,
                  action: action,
                );
              });
            },
            onExamplePromptTap: (prompt) => send(
              dialogContext,
              setModalState,
              prompt,
              analysisText:
                  _buildGuideQuickActionAnalysis(prompt, latestUserText),
            ),
            onEditGuideName: () => _editGuideName(setModalState),
            onClose: () => Navigator.of(dialogContext).pop(),
          );
        },
      ),
    );
    input.dispose();
  }

  Future<void> _triggerNightReflection({String? uploadRequestId}) async {
    final nightFallbackOpening = context.tr('night.fallback.opening');
    final nightFallbackQuestion = context.tr('night.fallback.question');
    final nightFallbackTaskTitle = context.tr('night.fallback.task_title');
    final nightFallbackTaskDesc = context.tr('night.fallback.task_desc');
    final nightTitle = context.tr('night.title');
    final nightKeepOnly = context.tr('night.keep_only');
    final nightAddTomorrow = context.tr('night.add_tomorrow');
    final nightRecordOnlyMessage = context.tr('night.record_only_message');
    GuideNightReflectionResult result;
    try {
      result = await _guideController.nightReflection(
        dayId: _guideController.localDateId(),
        uploadRequestId: uploadRequestId,
        clientContext: _buildGuideClientContext(),
      );
    } catch (_) {
      result = const GuideNightReflectionResult(
        opening: '',
        followUpQuestion: '',
        suggestedTask: GuideSuggestedTask(
          title: '',
          description: '',
          xpReward: 20,
          questTier: 'Daily',
        ),
        memoryRefs: <String>[],
      );
      result = GuideNightReflectionResult(
        opening: nightFallbackOpening,
        followUpQuestion: nightFallbackQuestion,
        suggestedTask: GuideSuggestedTask(
          title: nightFallbackTaskTitle,
          description: nightFallbackTaskDesc,
          xpReward: result.suggestedTask.xpReward,
          questTier: result.suggestedTask.questTier,
        ),
        memoryRefs: result.memoryRefs,
      );
    }

    _appendGuideMessage(
        'assistant', '${result.opening}\n${result.followUpQuestion}');
    if (!mounted) return;
    final dialogResult = await showQuestDialog<NightReflectionDialogResult>(
      context: context,
      barrierLabel: 'night_reflection_dialog',
      builder: (dialogContext) => NightReflectionDialog(
        title: nightTitle,
        opening: result.opening,
        followUpQuestion: result.followUpQuestion,
        suggestedTaskTitle: result.suggestedTask.title,
        xpReward: result.suggestedTask.xpReward,
        keepOnlyLabel: nightKeepOnly,
        addTomorrowLabel: nightAddTomorrow,
      ),
    );

    // 用户回复 follow_up_question 后，将回复写入 EverMemOS（静默失败）
    final replyText = dialogResult?.replyText ?? '';
    if (replyText.isNotEmpty) {
      final dayId = _guideController.localDateId();
      _controller.syncMemory(
        eventType: 'night_reflection_reply',
        content: replyText,
        memoryKind: 'dialog_event',
        summary: '$dayId 夜间反思回复',
        sender: 'user-manual',
      );
    }

    if (dialogResult?.addTask == true) {
      final inserted = await _controller.addGuideSuggestedTask(
        title: result.suggestedTask.title,
        description: result.suggestedTask.description,
        xpReward: result.suggestedTask.xpReward,
        questTier: result.suggestedTask.questTier,
      );
      if (inserted != null && mounted) {
        showForestSnackBar(context, nightAddTomorrow);
      }
    } else if (dialogResult?.addTask == false) {
      unawaited(
        _guideController.guideService.chat(
          message: nightRecordOnlyMessage,
          scene: 'night_reflection',
          clientContext: _buildGuideClientContext(),
        ),
      );
    }
  }

  // ignore: unused_element
  void _showPlusMenu() {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                PlusMenuItem(
                  icon: Icons.edit_note_rounded,
                  color: theme.primaryAccentColor,
                  title: context.tr('quick_add.menu.create'),
                  subtitle: context.tr('quick_add.menu.create_desc'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showQuickCreateDialog();
                  },
                ),
                const SizedBox(height: 8),
                PlusMenuItem(
                  icon: Icons.image_rounded,
                  color: const Color(0xFFFFB74D),
                  title: context.tr('quick_add.menu.image'),
                  subtitle: context.tr('quick_add.menu.image_desc'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleImageRecognition();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 处理图片识别流程
  ///
  /// 从 plus 菜单触发：选择图片 → 上传 → 识别 → 预填任务标题
  /// 识别失败时显示错误提示，允许用户手动输入
  Future<void> _handleImageRecognition() async {
    // 1. 选择图片
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    final imageFile = File(filePath);
    if (!imageFile.existsSync()) return;

    // 显示识别中提示
    if (mounted) {
      showForestSnackBar(
        context,
        context.tr('memory.image.recognizing'),
      );
    }

    try {
      final service = MemoryService();
      final recognition = await service.recognizeImage(imageFile);

      if (!mounted) return;

      if (recognition == null) {
        showForestSnackBar(
          context,
          context.tr('memory.image.recognize_failed'),
        );
        return;
      }

      // 含任务标题时预填到任务创建流程（复用 simulateAIParsing）
      if (recognition.suggestedTaskTitle.isNotEmpty) {
        _controller.simulateAIParsing(recognition.suggestedTaskTitle);
      }
    } catch (_) {
      if (mounted) {
        showForestSnackBar(
          context,
          context.tr('memory.image.recognize_failed'),
        );
      }
    }
  }

  Future<void> _showQuickCreateDialog() async {
    final mainQuestOptions = _controller.activeQuests
        .where(
          (quest) =>
              quest.questTier == 'Main_Quest' &&
              quest.parentId == null &&
              !quest.isDeleted &&
              !quest.isReward,
        )
        .toList(growable: false);
    final result = await showQuestDialog<QuickCreateDialogResult>(
      context: context,
      barrierLabel: 'quick_create_dialog',
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext).extension<QuestTheme>()!;
        return QuickCreateDialogBody(
          mainQuestOptions: mainQuestOptions,
          theme: theme,
          onConfirm: (result) => Navigator.of(dialogContext).pop(result),
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    var createdAny = false;
    switch (result.mode) {
      case QuickCreateMode.newMainWithSides:
        final mainQuest = await _controller.createManualQuest(
          title: result.title,
          description: '',
          xpReward: 50,
          questTier: 'Main_Quest',
        );
        if (mainQuest == null) {
          break;
        }
        createdAny = true;
        for (final sideTitle in result.sideTitles) {
          final insertedSide = await _controller.createManualQuest(
            title: sideTitle,
            description: '',
            xpReward: 30,
            questTier: 'Side_Quest',
            parentMainQuestId: mainQuest.id,
          );
          createdAny = createdAny || insertedSide != null;
        }
      case QuickCreateMode.attachToExistingMain:
        final insertedSide = await _controller.createManualQuest(
          title: result.title,
          description: '',
          xpReward: 30,
          questTier: 'Side_Quest',
          parentMainQuestId: result.parentMainQuestId,
        );
        createdAny = insertedSide != null;
      case QuickCreateMode.daily:
        final insertedDaily = await _controller.createManualQuest(
          title: result.title,
          description: '',
          xpReward: 20,
          questTier: 'Daily',
          dailyDueMinutes: result.dailyDueMinutes,
        );
        createdAny = insertedDaily != null;
    }

    if (createdAny && mounted) {
      HapticFeedback.lightImpact();
      showForestSnackBar(context, context.tr('quick_add.create.success'));
    }
  }

  Future<void> _syncTodayMemories() async {
    if (_isSyncingMemory || !mounted) return;
    setState(() => _isSyncingMemory = true);
    showForestSnackBar(context, context.tr('night.uploading'));
    try {
      final result = await _evermemosService
          .syncTodayCompletedQuests(_controller.activeQuests);
      if (!mounted) return;

      // ???????????????????
      HapticFeedback.lightImpact();
      if (mounted) setState(() => _isSyncingMemory = false);

      if (result.isQueued && result.requestId != null) {
        showForestSnackBar(context, context.tr('night.upload_queued'));
        // ?????????????????????????
        unawaited(_startMemoryStatusPolling(result.requestId!));
        await _triggerNightReflection(uploadRequestId: result.requestId);
      } else {
        showForestSnackBar(context, context.tr('night.upload_success'));
        await _triggerNightReflection(uploadRequestId: result.requestId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingMemory = false);
        showForestSnackBar(
          context,
          e is EvermemosSyncException
              ? e.message
              : context.tr('night.upload_fail'),
        );
      }
    }
  }

  Future<void> _startMemoryStatusPolling(String requestId) async {
    try {
      final result = await _evermemosService.pollMemoryStatus(
        requestId,
        maxAttempts: 5,
        interval: const Duration(seconds: 2),
      );
      if (!mounted) return;
      if (result.isSuccess) {
        showForestSnackBar(context, context.tr('night.poll_success'));
      } else {
        showForestSnackBar(context, context.tr('night.poll_pending'));
      }
    } catch (_) {
      // 轮询失败不影响用户体验，静默处理
      debugPrint('?? ??????????????');
    }
  }

  Future<void> _generateUserProfile({bool forceRefresh = false}) async {
    if (_isGeneratingProfile || !mounted) return;
    setState(() => _isGeneratingProfile = true);
    try {
      final portrait = await _guideController.generatePortrait(
        scene: 'profile',
        style: 'pencil_sketch',
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      // 用可变变量在对话框内部追踪状态
      var currentPortrait = portrait;
      var isRegenerating = false;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withAlpha(120),
        builder: (dialogContext) {
          final localTheme = Theme.of(dialogContext).extension<QuestTheme>()!;
          final dialogSize = MediaQuery.of(dialogContext).size;
          final dialogWidth = (dialogSize.width - 48).clamp(320.0, 620.0);
          final dialogHeight = (dialogSize.height - 48).clamp(480.0, 760.0);
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final insight = PortraitInsightData.fromPortrait(
                currentPortrait,
                _guideName,
              );
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SizedBox(
                  width: dialogWidth.toDouble(),
                  height: dialogHeight.toDouble(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                    decoration: BoxDecoration(
                      color: localTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(35),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.tr(
                                'profile.title',
                                params: {'name': _guideName},
                              ),
                              style: AppTextStyles.heading2.copyWith(
                                color: localTheme.primaryAccentColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: isRegenerating
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text(
                                        context.tr('profile.loading'),
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.softBlue.withAlpha(105),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr('profile.source_label'),
                                              style: AppTextStyles.caption.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (currentPortrait.imageUrl.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: dialogHeight * 0.45,
                                                  ),
                                                  child: Image.network(
                                                    currentPortrait.imageUrl,
                                                    width: double.infinity,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => Text(
                                                      context.tr('profile.analysis_notice'),
                                                      style: AppTextStyles.caption.copyWith(
                                                        color: AppColors.textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ] else
                                              Text(
                                                context.tr('profile.analysis_notice'),
                                                style: AppTextStyles.caption.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      PortraitEvaluationSection(
                                        insight: insight,
                                        theme: localTheme,
                                        guideName: _guideName,
                                      ),
                                      const SizedBox(height: 16),
                                      PortraitInsightChart(
                                        insight: insight,
                                        theme: localTheme,
                                      ),
                                      const SizedBox(height: 16),
                                      PortraitReadableMetricGrid(
                                        insight: insight,
                                        theme: localTheme,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 重新生成按钮：在对话框内部原地刷新
                            TextButton.icon(
                              onPressed: isRegenerating
                                  ? null
                                  : () async {
                                      setDialogState(() => isRegenerating = true);
                                      try {
                                        final newPortrait = await _guideController.generatePortrait(
                                          scene: 'profile',
                                          style: 'pencil_sketch',
                                          forceRefresh: true,
                                        );
                                        setDialogState(() {
                                          currentPortrait = newPortrait;
                                          isRegenerating = false;
                                        });
                                      } catch (_) {
                                        setDialogState(() => isRegenerating = false);
                                      }
                                    },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(context.tr('profile.regenerate')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: Text(context.tr('common.close')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (_) {
      if (mounted) {
        showForestSnackBar(context, context.tr('profile.generate_fail'));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingProfile = false);
    }
  }

  Future<void> _openUnifiedSettings() async {
    var guideEnabled = await PreferencesService.guideEnabled();
    var proactiveEnabled = await PreferencesService.guideProactiveEnabled();
    var selectedTheme = widget.currentThemeId;
    var languageCode = AppLocaleController.instance.locale.languageCode;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(72),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final localTheme = Theme.of(dialogContext).extension<QuestTheme>()!;
          final viewport = MediaQuery.sizeOf(dialogContext);
          final dialogWidth = (viewport.width - 40).clamp(320.0, 560.0);
          final dialogHeight = (viewport.height - 40).clamp(420.0, 760.0);
          const themeOptions = <String>['forest_adventure', 'default'];

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth.toDouble(),
                maxHeight: dialogHeight.toDouble(),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: localTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(22),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            localTheme.primaryAccentColor.withAlpha(28),
                            const Color(0xFFF6F1DC),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(176),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: localTheme.primaryAccentColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('settings.title'),
                                  style: AppTextStyles.heading1.copyWith(
                                    fontSize: 28,
                                    color: localTheme.primaryAccentColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context.tr('settings.subtitle'),
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SettingsSectionCard(
                              icon: Icons.smart_toy_rounded,
                              accentColor: localTheme.primaryAccentColor,
                              title: context.tr('settings.section.guide'),
                              description:
                                  context.tr('settings.section.guide_desc'),
                              child: Column(
                                children: [
                                  SettingsToggleRow(
                                    title: context.tr('settings.guide_enabled'),
                                    description: context.tr(
                                      'settings.guide_enabled_desc',
                                    ),
                                    value: guideEnabled,
                                    activeColor: localTheme.primaryAccentColor,
                                    onChanged: (value) async {
                                      guideEnabled = value;
                                      await PreferencesService.setGuideEnabled(
                                        value,
                                      );
                                      if (!guideEnabled) {
                                        proactiveEnabled = false;
                                        await PreferencesService
                                            .setGuideProactiveEnabled(false);
                                      }
                                      if (mounted) {
                                        showForestSnackBar(
                                          context,
                                          context.tr('settings.saved'),
                                        );
                                      }
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SettingsToggleRow(
                                    title: context.tr(
                                      'settings.proactive_enabled',
                                    ),
                                    description: context.tr(
                                      'settings.proactive_enabled_desc',
                                    ),
                                    value: proactiveEnabled,
                                    enabled: guideEnabled,
                                    activeColor: const Color(0xFFFFB74D),
                                    onChanged: guideEnabled
                                        ? (value) async {
                                            proactiveEnabled = value;
                                            await PreferencesService
                                                .setGuideProactiveEnabled(
                                              value,
                                            );
                                            if (mounted) {
                                              showForestSnackBar(
                                                context,
                                                context.tr('settings.saved'),
                                              );
                                            }
                                            setModalState(() {});
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(155),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: localTheme.primaryAccentColor
                                            .withAlpha(36),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                          color: localTheme.primaryAccentColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            context.tr('settings.memory_mode'),
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              height: 1.4,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SettingsSectionCard(
                              icon: Icons.palette_rounded,
                              accentColor: const Color(0xFFFFB74D),
                              title: context.tr('settings.section.appearance'),
                              description: context.tr(
                                'settings.section.appearance_desc',
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: themeOptions.map((themeId) {
                                  final labelKey = themeId == 'forest_adventure'
                                      ? 'settings.theme.forest'
                                      : 'settings.theme.default';
                                  final descKey = themeId == 'forest_adventure'
                                      ? 'settings.theme.forest_desc'
                                      : 'settings.theme.default_desc';
                                  final icon = themeId == 'forest_adventure'
                                      ? Icons.park_rounded
                                      : Icons.air_rounded;
                                  final accent = themeId == 'forest_adventure'
                                      ? localTheme.primaryAccentColor
                                      : const Color(0xFF5DADE2);
                                  return SizedBox(
                                    width: 220,
                                    child: SettingsChoicePill(
                                      icon: icon,
                                      label: context.tr(labelKey),
                                      description: context.tr(descKey),
                                      accentColor: accent,
                                      selected: selectedTheme == themeId,
                                      onTap: selectedTheme == themeId
                                          ? null
                                          : () async {
                                              selectedTheme = themeId;
                                              widget.onThemeChange?.call(
                                                themeId,
                                              );
                                              setModalState(() {});
                                            },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SettingsSectionCard(
                              icon: Icons.translate_rounded,
                              accentColor: const Color(0xFF5DADE2),
                              title: context.tr('settings.section.language'),
                              description: context.tr(
                                'settings.section.language_desc',
                              ),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <MapEntry<String, String>>[
                                  const MapEntry('zh', 'settings.lang.zh'),
                                  const MapEntry('en', 'settings.lang.en'),
                                ].map((entry) {
                                  return SizedBox(
                                    width: 220,
                                    child: SettingsChoicePill(
                                      icon: entry.key == 'zh'
                                          ? Icons.chat_bubble_rounded
                                          : Icons.public_rounded,
                                      label: context.tr(entry.value),
                                      description: entry.key == 'zh'
                                          ? context.tr(
                                              'settings.lang.zh_desc',
                                            )
                                          : context.tr(
                                              'settings.lang.en_desc',
                                            ),
                                      accentColor: const Color(0xFF5DADE2),
                                      selected: languageCode == entry.key,
                                      onTap: languageCode == entry.key
                                          ? null
                                          : () async {
                                              languageCode = entry.key;
                                              await AppLocaleController.instance
                                                  .setLanguageCode(entry.key);
                                              if (mounted) {
                                                showForestSnackBar(
                                                  context,
                                                  context.tr('settings.saved'),
                                                );
                                              }
                                              setModalState(() {});
                                            },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('settings.footer_note'),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: FilledButton.styleFrom(
                              foregroundColor: localTheme.primaryAccentColor,
                              backgroundColor:
                                  localTheme.primaryAccentColor.withAlpha(18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                            child: Text(context.tr('common.close')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(72)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('home.delete_all.title')),
        content: Text(context.tr('home.delete_all.message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('home.delete_all.confirm')),
          ),
        ],
      ),
    );
    if (ok == true) _guideController.deleteAllQuestsWithGuideMemory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.backgroundColor,
          onDrawerChanged: (isOpened) {
            if (!isOpened) _loadProfileDisplayName();
          },
          drawer: AppDrawer(
            questController: _controller,
            onOpenSettings: _openUnifiedSettings,
            onOpenGuide: _openGuidePanel,
            onOpenTutorial: _replayCoachMarks,
          ),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: false,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                color: AppColors.textSecondary,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Text(
              (_guideController.profileDisplayName?.trim().isNotEmpty == true)
                  ? context.tr('app.title',
                      params: {'name': _guideController.profileDisplayName!.trim()})
                  : context.tr('app.title.default'),
              style: AppTextStyles.heading1
                  .copyWith(color: theme.primaryAccentColor),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final statsLevel = _controller.levelProgress;
                  return GestureDetector(
                    key: _coachKeyLevelBar,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatsPage(questController: _controller),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${context.tr('home.level_label')} ${statsLevel.level}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Lv.${statsLevel.level} ${context.tr(statsLevel.title)}',
                                      style: AppTextStyles.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_controller.longestStreak > 0) ...[
                                _buildTopStatChip(
                                  icon: Icons.local_fire_department_rounded,
                                  label: _guideText(
                                    '${_controller.longestStreak}天',
                                    '${_controller.longestStreak} days',
                                  ),
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 6),
                              ],
                              _buildTopStatChip(
                                icon: Icons.auto_graph_rounded,
                                label: '${_controller.totalXp} XP',
                                color: theme.primaryAccentColor,
                              ),
                              const SizedBox(width: 6),
                              _buildTopStatChip(
                                icon: Icons.monetization_on_rounded,
                                label: '${_controller.currentGold}',
                                color: Colors.amber.shade800,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: statsLevel.progress,
                              minHeight: 6,
                              backgroundColor:
                                  theme.primaryAccentColor.withAlpha(36),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.primaryAccentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              IconButton(
                key: _coachKeyGuideBtn,
                onPressed: _openGuidePanel,
                icon: const Icon(Icons.smart_toy_rounded),
                tooltip: context.tr('home.guide.tooltip'),
              ),
              IconButton(
                onPressed: _isGeneratingProfile ? null : _generateUserProfile,
                icon: _isGeneratingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                tooltip: context.tr('home.profile.tooltip'),
              ),
              IconButton(
                onPressed: _isSyncingMemory ? null : _syncTodayMemories,
                icon: _isSyncingMemory
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                tooltip: context.tr('home.sync.tooltip'),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StatsPage(questController: _controller)),
                ),
                icon: const Icon(Icons.bar_chart_rounded),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AchievementPage(
                      achievementController: _controller.achievementController,
                    ),
                  ),
                ),
                icon: const Icon(Icons.emoji_events_rounded),
              ),
              IconButton(
                key: _coachKeyShopBtn,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          RewardShopPage(questController: _controller)),
                ),
                icon: const Icon(Icons.shopping_bag_rounded),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          InventoryPage(questController: _controller)),
                ),
                icon: const Icon(Icons.backpack_rounded),
              ),
              IconButton(
                onPressed: _confirmDeleteAll,
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: AppColors.errorRed),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    WeChatSyncIndicator(isSyncing: _controller.isAnalyzing),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 22,
                  emissionFrequency: 0.02,
                  gravity: 0.12,
                  shouldLoop: false,
                ),
              ),
              Positioned.fill(
                child: KeyedSubtree(
                  key: _coachKeyQuestBoard,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => QuestBoard(
                      entries: _controller.timelineEntries,
                      quests: _controller.activeQuests,
                      isAnalyzing: _controller.isAnalyzing,
                      guideName: _guideName,
                      onQuestCompleted: _controller.toggleQuestCompletion,
                      onQuestDeleted: _guideController.deleteQuestWithGuideMemory,
                      onQuestToggleExpanded: _controller.toggleQuestExpanded,
                      onQuestMove: (questId, dropIndex, targetDepth) =>
                          _controller.moveQuestByDrop(
                        questId: questId,
                        dropIndex: dropIndex,
                        targetDepth: targetDepth,
                      ),
                      onQuestUpdateDetails: _controller.updateQuestDetails,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      CelebrationOverlay(triggerSeq: _controller.confettiSeq),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller.achievementController,
                  builder: (context, _) => AchievementUnlockOverlay(
                    triggerSeq: _controller.achievementController.unlockSeq,
                    consumeNext:
                        _controller.achievementController.consumeNextUnlock,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final shouldExpand =
                      _controller.activeQuests.any((q) => !q.isExpanded);
                  return QuestBoardFab(
                    isExpanded: !shouldExpand,
                    onToggle: _controller.toggleExpandAll,
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 小忆建议卡片区域：仅当推荐列表非空时显示
                    if (_guideController.recommendations.isNotEmpty)
                      MemoryRecommendationCards(
                        recommendations: _guideController.recommendations,
                        onTap: (title) =>
                            _controller.simulateAIParsing(title),
                      ),
                    KeyedSubtree(
                      key: _coachKeyQuickAdd,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => QuickAddBar(
                          isLoading: _controller.isAnalyzing,
                          onSubmitted: _controller.simulateAIParsing,
                          onPlusTap: _showPlusMenu,
                          onImageTaskRecognized: (title) {
                            _controller.simulateAIParsing(title);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _guideController.latestDailyEvent == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showDailyEventDialog(_guideController.latestDailyEvent!),
                  icon: _guideController.isGuideEventHandling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flash_on_rounded),
                  label: Text(_eventBadgeLabel(_guideController.latestDailyEvent!)),
                ),
        ),
        // Coach Marks 新手引导遮罩（全屏覆盖，包括 AppBar）
        if (_showCoachMarks)
          CoachMarksOverlay(
            steps: [
              CoachMarkStep(
                targetKey: _coachKeyQuickAdd,
                titleKey: 'coach.step1.title',
                descriptionKey: 'coach.step1.description',
                icon: Icons.edit_note_rounded,
              ),
              CoachMarkStep(
                targetKey: _coachKeyQuestBoard,
                titleKey: 'coach.step2.title',
                descriptionKey: 'coach.step2.description',
                icon: Icons.task_alt_rounded,
                highlightPadding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              ),
              CoachMarkStep(
                targetKey: _coachKeyLevelBar,
                titleKey: 'coach.step3.title',
                descriptionKey: 'coach.step3.description',
                icon: Icons.local_fire_department_rounded,
              ),
              CoachMarkStep(
                targetKey: _coachKeyGuideBtn,
                titleKey: 'coach.step4.title',
                descriptionKey: 'coach.step4.description',
                icon: Icons.smart_toy_rounded,
              ),
              CoachMarkStep(
                targetKey: _coachKeyShopBtn,
                titleKey: 'coach.step5.title',
                descriptionKey: 'coach.step5.description',
                icon: Icons.shopping_bag_rounded,
              ),
            ],
            onComplete: _onCoachMarksComplete,
            onSkip: _onCoachMarksSkip,
          ),
      ],
    );
  }
}

