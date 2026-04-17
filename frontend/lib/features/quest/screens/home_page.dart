import 'dart:async';
import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/app_config.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/evermemos_service.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/services/local_agent_runtime_service.dart';
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
import '../models/quest_node.dart';
import '../models/agent_run.dart';
import '../models/agent_step.dart';
import '../services/agent_run_service.dart';
import '../services/weekly_summary_job_service.dart';
import '../widgets/guide_panel_dialog.dart';
import '../widgets/night_reflection_dialog.dart';
import '../widgets/quest_board.dart';
import '../widgets/quest_board_fab.dart';
import '../widgets/quick_add_bar.dart';

enum _GuideConnectionStatus {
  ready,
  authExpired,
  network,
  service,
}

const String _localOnboardingEventId = 'local_onboarding_tutorial';

enum _GuideActionType {
  generateTask,
  modifyTask,
  weeklySummary,
  openStats,
  openShop,
  redeemReward,
}

class _GuideTurnResponse {
  final GuideChatResult result;
  final Future<void> Function()? postAction;
  final bool closeDialogBeforeAction;
  final bool appendAssistantReply;
  final GuideTaskEditDraft? pendingTaskEditDraft;
  final DateTime? pendingTaskDueDate;

  const _GuideTurnResponse({
    required this.result,
    this.postAction,
    this.closeDialogBeforeAction = false,
    this.appendAssistantReply = true,
    this.pendingTaskEditDraft,
    this.pendingTaskDueDate,
  });
}

class _GuideRewardMatch {
  final Reward? reward;
  final List<Reward> candidates;

  const _GuideRewardMatch({
    this.reward,
    this.candidates = const <Reward>[],
  });
}

class _AgentRunResult {
  final AgentRun? run;
  final List<AgentStep> steps;
  final String? latestAssistantMessage;

  const _AgentRunResult({
    required this.run,
    required this.steps,
    this.latestAssistantMessage,
  });
}

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
  final GuideService _guideService = GuideService();
  final AgentRunService _agentRunService = AgentRunService();
  late final LocalAgentRuntimeService _localAgentRuntimeService;
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
  final Set<String> _runningLocalAgentStepIds = <String>{};
  final Set<String> _finishedLocalAgentStepIds = <String>{};
  final Map<String, LocalToolResult> _localAgentStepResults =
      <String, LocalToolResult>{};
  String? _trackedAgentRunId;

  int _previousUncompletedCount = -1;
  bool _isSyncingMemory = false;
  bool _isGeneratingProfile = false;
  bool _isGuideBootstrapping = false;
  bool _isGuideEventHandling = false;
  _GuideConnectionStatus _guideStatus = _GuideConnectionStatus.ready;

  final List<_GuideChatMessage> _guideMessages = <_GuideChatMessage>[];
  GuideDailyEvent? _latestDailyEvent;
  String? _guideDisplayName;
  String? _profileDisplayName;
  String _guideMemoryDigest = '';
  List<String> _guideBehaviorSignals = const <String>[];
  GuideTaskEditDraft? _pendingGuideTaskEditDraft;
  DateTime? _pendingGuideTaskDueDate;
  final List<String> _recentlyDeletedGuideTaskTitles = <String>[];

  @override
  void initState() {
    super.initState();
    _localAgentRuntimeService = LocalAgentRuntimeService(
      questCreateHandler: _executeAgentQuestCreate,
      questUpdateHandler: _executeAgentQuestUpdate,
      questSplitHandler: _executeAgentQuestSplit,
      chatFreeformHandler: _executeAgentFreeformChat,
      weeklySummaryGenerateHandler: _executeAgentWeeklySummaryGenerate,
      rewardRedeemHandler: _executeAgentRewardRedeem,
      navigationOpenHandler: _executeAgentNavigationOpen,
    );
    _controller.addListener(_onQuestStateChanged);
    _agentRunService.addListener(_onAgentRunStateChanged);
    _initFuture = _controller.init();
    unawaited(_loadGuideDisplayName());
    unawaited(_loadProfileDisplayName());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runGuideBootstrapIfNeeded());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuestStateChanged);
    _agentRunService.removeListener(_onAgentRunStateChanged);
    _agentRunService.dispose();
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

  void _onAgentRunStateChanged() {
    final runId = _agentRunService.currentRun?.id;
    if (_trackedAgentRunId != runId) {
      _trackedAgentRunId = runId;
      _runningLocalAgentStepIds.clear();
      _finishedLocalAgentStepIds.clear();
      _localAgentStepResults.clear();
    }

    if (mounted) {
      setState(() {});
    }
    unawaited(_tryExecuteReadyAgentStep());
  }

  String _localDateId() {
    final now = DateTime.now().toLocal();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get _guideName {
    final value = _guideDisplayName?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return context.tr('guide.name.default');
  }

  String _guideMemorySummary() {
    final digest = _guideMemoryDigest.trim();
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
        await _guideService.resolveDisplayName(localFallback: stored);
    await PreferencesService.setGuideDisplayName(resolved);
    if (!mounted) return;
    setState(() => _guideDisplayName = resolved);
  }

  Future<void> _loadProfileDisplayName() async {
    final name = await PreferencesService.profileDisplayName();
    if (!mounted) return;
    setState(() => _profileDisplayName = name);
  }

  Map<String, dynamic> _buildGuideClientContext() {
    final activeTasks = _controller.activeQuests
        .where((quest) => !quest.isReward && !quest.isDeleted)
        .toList(growable: false);
    return <String, dynamic>{
      'guide_name': _guideName,
      'language_code': AppLocaleController.instance.locale.languageCode,
      'is_english': AppLocaleController.instance.isEnglish,
      'memory_digest': _guideMemoryDigest.trim(),
      'behavior_signals': _guideBehaviorSignals,
      'active_task_titles': activeTasks.map((quest) => quest.title).toList(),
      'active_task_ids': activeTasks.map((quest) => quest.id).toList(),
      'active_task_count': activeTasks.length,
      'recently_deleted_task_titles': _recentlyDeletedGuideTaskTitles,
      'task_truth_rule':
          'Only active_task_titles are current tasks. Memory is historical context only. If a memory-mentioned task is not active, ask whether to recreate it instead of treating it as existing.',
      if (_latestDailyEvent != null)
        'latest_daily_event': <String, dynamic>{
          'title': _latestDailyEvent!.title,
          'reason': _latestDailyEvent!.reason,
        },
    };
  }

  Future<bool> _shouldOfferOnboardingTutorial() async {
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
      eventId: _localOnboardingEventId,
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
    return event.eventId == _localOnboardingEventId;
  }

  bool _isOnboardingEventId(String eventId) {
    return eventId == _localOnboardingEventId;
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
      await _guideService.saveDisplayName(normalized);
    } catch (_) {
      syncFailed = true;
    }
    if (!mounted) return;

    setState(() => _guideDisplayName = normalized);
    setModalState(() {});
    if (syncFailed) {
      showForestSnackBar(context, context.tr('quest.error.save_failed'));
    }
  }

  _AgentRunResult _currentAgentRunResult() {
    String? latestAssistantMessage;
    for (final item in _visibleGuideMessages().reversed) {
      if (item.role == 'assistant' && item.content.trim().isNotEmpty) {
        latestAssistantMessage = item.content.trim();
        break;
      }
    }
    return _AgentRunResult(
      run: _agentRunService.currentRun,
      steps: List<AgentStep>.from(_agentRunService.steps),
      latestAssistantMessage: latestAssistantMessage,
    );
  }

  QuestNode? _findAgentTargetTaskByArguments(Map<String, dynamic> arguments) {
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
      return _findGuideTargetTask(sourceText);
    }
    return null;
  }

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
      return _extractGuideDueDate(sourceText);
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

  Future<LocalToolResult> _executeAgentQuestCreate(
    Map<String, dynamic> arguments,
  ) async {
    final sourceText = '${arguments['source_text'] ?? ''}'.trim();
    final explicitTitle = '${arguments['title'] ?? ''}'.trim();
    final baseText = explicitTitle.isNotEmpty ? explicitTitle : sourceText;
    final title = _normalizeGuideTaskTitle(baseText);
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
      description:
          _guideTaskDescription(sourceText.isNotEmpty ? sourceText : title),
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

  Future<LocalToolResult> _executeAgentQuestUpdate(
    Map<String, dynamic> arguments,
  ) async {
    final target = _findAgentTargetTaskByArguments(arguments);
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
            ? _extractGuideNaturalTitleFromModifyText(sourceText, target)
            : null);
    final nextDescriptionRaw =
        '${arguments['updated_description'] ?? ''}'.trim();
    final nextDescription =
        nextDescriptionRaw.isEmpty ? null : nextDescriptionRaw;
    final nextXp = (_parseAgentInt(arguments['updated_xp_reward']) ??
            (sourceText.isNotEmpty ? _extractGuideXp(sourceText) : null))
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

  Future<LocalToolResult> _executeAgentQuestSplit(
    Map<String, dynamic> arguments,
  ) async {
    final target = _findAgentTargetTaskByArguments(arguments);
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
        : _buildGuideSplitSteps(
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
      outputText: '已拆分任务：${target.title}',
      resultJson: <String, dynamic>{
        'split_task_id': target.id,
        'created_subtasks':
            inserted.map((item) => item.title).toList(growable: false),
      },
    );
  }

  Map<String, dynamic> _guideChatResultToJson(GuideChatResult result) {
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

  GuideChatResult? _extractGuideChatResultFromAgentLocalResult(
    LocalToolResult? localResult,
  ) {
    final raw = localResult?.resultJson?['guide_chat_result'];
    if (raw is Map<String, dynamic>) {
      return GuideChatResult.fromMap(raw);
    }
    if (raw is Map) {
      return GuideChatResult.fromMap(
        raw.map((key, value) => MapEntry('$key', value)),
      );
    }
    return null;
  }

  Uri _buildOpenAIChatUri() {
    final normalized = AppConfig.openaiBaseUrl.trim().replaceAll(
          RegExp(r'/+$'),
          '',
        );
    final withVersion =
        normalized.endsWith('/v1') ? normalized : '$normalized/v1';
    return Uri.parse('$withVersion/chat/completions');
  }

  String _buildDirectFreeformChatSystemPrompt() {
    final activeTasks = _controller.activeQuests
        .where((quest) => !quest.isDeleted && !quest.isReward)
        .map((quest) => quest.title.trim())
        .where((title) => title.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final memoryDigest = _guideMemoryDigest.trim().isEmpty
        ? '暂无稳定长期记忆摘要。'
        : _guideMemoryDigest.trim();
    final behaviorSignals = _guideBehaviorSignals.isEmpty
        ? '暂无明显行为信号。'
        : _guideBehaviorSignals.join('；');
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

    final apiKey = AppConfig.openaiApiKey.trim();
    if (apiKey.isEmpty) return null;

    try {
      final response = await http
          .post(
            _buildOpenAIChatUri(),
            headers: <String, String>{
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'model': AppConfig.openaiChatModel,
              'temperature': 0.4,
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'system',
                  'content': _buildDirectFreeformChatSystemPrompt(),
                },
                <String, String>{'role': 'user', 'content': sourceText},
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      final reply =
          '${decoded['choices']?[0]?['message']?['content'] ?? ''}'.trim();
      if (reply.isEmpty) {
        return null;
      }

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

  bool _shouldShowAgentStepMessage(AgentStep step) {
    final sourceTool = '${step.resultJson?['source_tool'] ?? ''}'.trim();
    return step.toolName != 'app.chat.freeform.respond' &&
        sourceTool != 'app.chat.freeform.respond';
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
          await _guideService
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
          'guide_chat_result': _guideChatResultToJson(resolvedResult),
        },
      );
    } catch (_) {
      final fallback = _buildCompanionGuideResult(sourceText);
      return LocalToolResult(
        success: true,
        outputText: fallback.reply,
        resultJson: <String, dynamic>{
          'guide_chat_result': _guideChatResultToJson(fallback),
        },
      );
    }
  }

  Future<LocalToolResult> _executeAgentWeeklySummaryGenerate(
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

  Future<LocalToolResult> _executeAgentNavigationOpen(
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

  Future<LocalToolResult?> _startAgentRunFromGuideInput(String text) async {
    _runningLocalAgentStepIds.clear();
    _finishedLocalAgentStepIds.clear();
    _localAgentStepResults.clear();
    final snapshot = await _agentRunService.startRun(
      goal: text,
      clientContext: _buildGuideClientContext(),
    );
    _trackedAgentRunId = snapshot.run.id;
    _appendAgentMessagesFromSteps(snapshot.steps);
    final immediateResult = await _tryExecuteReadyAgentStep();
    if (immediateResult != null) return immediateResult;
    final pendingStepId = _agentRunService.latestStep?.id;
    if (pendingStepId == null || pendingStepId.isEmpty) return null;
    return _waitForLocalAgentStepResult(pendingStepId);
  }

  Future<LocalToolResult?> _waitForLocalAgentStepResult(
    String stepId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = _localAgentStepResults[stepId];
      if (result != null) return result;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return _localAgentStepResults[stepId];
  }

  void _appendAgentMessagesFromSteps(List<AgentStep> steps) {
    final existingKeys = _guideMessages
        .where((message) => message.agentStepId != null)
        .map((message) => '${message.role}:${message.agentStepId}')
        .toSet();

    for (final step in steps) {
      if ((step.outputText ?? '').trim().isEmpty) continue;
      if (!_shouldShowAgentStepMessage(step)) continue;
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
    final run = _agentRunService.currentRun;
    final step = _agentRunService.latestStep;
    if (run == null || step == null) return null;
    final cachedResult = _localAgentStepResults[step.id];
    if (cachedResult != null) {
      return cachedResult;
    }
    if (!step.isToolCall || !step.isReady || step.needsConfirmation) {
      return null;
    }
    if (_runningLocalAgentStepIds.contains(step.id) ||
        _finishedLocalAgentStepIds.contains(step.id)) {
      return null;
    }

    _runningLocalAgentStepIds.add(step.id);
    try {
      late final LocalToolResult result;
      try {
        result = await _localAgentRuntimeService.execute(
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
      _localAgentStepResults[step.id] = result;
      final snapshot = await _agentRunService.reportLatestLocalResult(
        success: result.success,
        outputText: result.outputText,
        errorText: result.errorText,
        resultJson: result.resultJson,
      );
      _finishedLocalAgentStepIds.add(step.id);
      if (snapshot != null) {
        _appendAgentMessagesFromSteps(snapshot.steps);
      }
      return result;
    } finally {
      _runningLocalAgentStepIds.remove(step.id);
    }
  }

  Future<void> _approveLatestAgentStep() async {
    final snapshot = await _agentRunService.approveLatestStep();
    if (snapshot != null) {
      _appendAgentMessagesFromSteps(snapshot.steps);
      await _tryExecuteReadyAgentStep();
    }
  }

  Future<void> _rejectLatestAgentStep() async {
    final snapshot = await _agentRunService.rejectLatestStep();
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
      _guideMessages.add(
        _GuideChatMessage(
          role: role,
          content: text,
          memoryRefCount: memoryRefs.length,
          agentStepId: agentStepId,
        ),
      );
      if (_guideMessages.length > 60) {
        _guideMessages.removeRange(0, _guideMessages.length - 60);
      }
    });
  }

  List<_GuideChatMessage> _visibleGuideMessages() {
    return _guideMessages
        .where((message) => message.agentStepId == null)
        .toList(growable: false);
  }

  bool _shouldRouteToAgent(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return true;
  }

  Future<void> _runGuideBootstrapIfNeeded() async {
    if (_isGuideBootstrapping) return;
    // 等待数据加载完成，确保 quests/xp/gold 等状态已就绪
    await _initFuture;
    if (!mounted) return;
    final guideEnabled = await PreferencesService.guideEnabled();
    final proactiveEnabled = await PreferencesService.guideProactiveEnabled();
    if (!guideEnabled || !proactiveEnabled) return;
    final today = _localDateId();
    final lastDate = await PreferencesService.guideLastBootstrapDate();
    if (lastDate == today || !mounted) return;

    if (await _shouldOfferOnboardingTutorial()) {
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
      setState(() => _latestDailyEvent = event);
      await _showDailyEventDialog(event);
      return;
    }

    setState(() => _isGuideBootstrapping = true);
    try {
      final result = await _guideService.bootstrap(
          scene: 'home', clientContext: _buildGuideClientContext());
      if (!mounted) return;
      setState(() {
        _guideStatus = _GuideConnectionStatus.ready;
        _guideMemoryDigest = result.memoryDigest.trim();
        _guideBehaviorSignals = result.behaviorSignals.take(3).toList();
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
        setState(() => _latestDailyEvent = result.dailyEvent);
        await _showDailyEventDialog(result.dailyEvent!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guideStatus = _statusFromError(e));
      showForestSnackBar(context, context.tr('home.bootstrap.offline'));
    } finally {
      if (mounted) {
        setState(() => _isGuideBootstrapping = false);
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
    if (_isGuideEventHandling || !mounted) return;
    setState(() => _isGuideEventHandling = true);
    try {
      final result =
          await _guideService.acceptEvent(eventId: eventId, accept: accept);
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
      if (mounted) setState(() => _latestDailyEvent = null);
    } catch (_) {
      if (!mounted) return;
      showForestSnackBar(context, context.tr('home.event.failed'));
    } finally {
      if (mounted) setState(() => _isGuideEventHandling = false);
    }
  }

  Future<void> _handleOnboardingTutorialDecision(bool accept) async {
    if (_isGuideEventHandling || !mounted) return;
    if (!accept) {
      setState(() => _latestDailyEvent = null);
      showForestSnackBar(context, context.tr('guide.onboarding.dismissed'));
      return;
    }

    setState(() => _isGuideEventHandling = true);
    try {
      final inserted =
          await _controller.addOnboardingTutorialBundle(guideName: _guideName);
      if (!mounted) return;
      if (inserted.isEmpty) {
        showForestSnackBar(context, context.tr('guide.onboarding.failed'));
        return;
      }
      setState(() => _latestDailyEvent = null);
      showForestSnackBar(context, context.tr('guide.onboarding.accepted'));
    } finally {
      if (mounted) setState(() => _isGuideEventHandling = false);
    }
  }

  GuideChatIntent _classifyGuideIntent(String text) {
    if (_matchGuideAction(text) != null) {
      return GuideChatIntent.action;
    }

    final normalized = text.trim().toLowerCase();
    const adviceKeywords = <String>[
      '建议',
      '判断',
      '帮我理',
      '怎么选',
      '怎么办',
      '更适合',
      'advice',
      'suggest',
      'should i',
    ];
    if (adviceKeywords.any((keyword) => normalized.contains(keyword))) {
      return GuideChatIntent.advice;
    }

    return GuideChatIntent.companion;
  }

  String _guideText(String zh, String en) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode.toLowerCase().startsWith('en')) {
      return en;
    }
    return zh;
  }

  bool _containsGuideCjk(String text) {
    return RegExp(r'[\u3400-\u9FFF]').hasMatch(text);
  }

  GuideChatResult _guideResultForCurrentLocale(GuideChatResult result) {
    if (!context.isEnglish || !_containsGuideCjk(result.reply)) {
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

  String _normalizeGuideLookup(String text) {
    return text.trim().toLowerCase();
  }

  String? _extractQuotedGuidePhrase(String text) {
    final match = RegExp("[“\"'‘](.+?)[”\"'’]").firstMatch(text);
    final value = match?.group(1)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  _GuideRewardMatch _findGuideRewardMatch(String text, List<Reward> rewards) {
    final availableRewards = rewards
        .where((reward) => reward.title.trim().isNotEmpty)
        .toList(growable: false);
    if (availableRewards.isEmpty) {
      return const _GuideRewardMatch();
    }

    final query =
        _normalizeGuideLookup(_extractQuotedGuidePhrase(text) ?? text);
    if (query.isEmpty) {
      return const _GuideRewardMatch();
    }

    final exactMatches = availableRewards
        .where(
          (reward) => reward
              .localizedLookupTitles(context.isEnglish)
              .map(_normalizeGuideLookup)
              .contains(query),
        )
        .toList(growable: false);
    if (exactMatches.length == 1) {
      return _GuideRewardMatch(
        reward: exactMatches.first,
        candidates: exactMatches,
      );
    }
    if (exactMatches.length > 1) {
      return _GuideRewardMatch(candidates: exactMatches);
    }

    final partialMatches = availableRewards.where((reward) {
      for (final candidate in reward.localizedLookupTitles(context.isEnglish)) {
        final title = _normalizeGuideLookup(candidate);
        if (title.isNotEmpty &&
            (query.contains(title) || title.contains(query))) {
          return true;
        }
      }
      return false;
    }).toList(growable: false);
    if (partialMatches.length == 1) {
      return _GuideRewardMatch(
        reward: partialMatches.first,
        candidates: partialMatches,
      );
    }
    return _GuideRewardMatch(candidates: partialMatches);
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

  _GuideActionType? _matchGuideAction(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('兑换') ||
        normalized.contains('换奖励') ||
        normalized.contains('买奖励') ||
        normalized.contains('redeem')) {
      return _GuideActionType.redeemReward;
    }
    if (normalized.contains('商店') ||
        normalized.contains('商城') ||
        normalized.contains('shop')) {
      return _GuideActionType.openShop;
    }
    if (normalized.contains('统计') || normalized.contains('stats')) {
      return _GuideActionType.openStats;
    }
    if (normalized.contains('周报') ||
        normalized.contains('周总结') ||
        normalized.contains('weekly')) {
      return _GuideActionType.weeklySummary;
    }
    if (normalized.contains('修改任务') ||
        normalized.contains('改任务') ||
        normalized.contains('改轻') ||
        normalized.contains('标题改成') ||
        normalized.contains('描述改成') ||
        normalized.contains('xp改') ||
        normalized.contains('经验改') ||
        (normalized.contains('拆成') && normalized.contains('任务'))) {
      return _GuideActionType.modifyTask;
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
    if (_findGuideTargetTask(text) != null &&
        (hasSplitIntent ||
            hasDueDateIntent ||
            normalized.contains('修改') ||
            normalized.contains('调整'))) {
      return _GuideActionType.modifyTask;
    }
    if (hasSplitIntent && _findGuideTargetTask(text) != null) {
      return _GuideActionType.modifyTask;
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
      return _GuideActionType.generateTask;
    }
    return null;
  }

  Future<_GuideTurnResponse> _handleGuideRedeemReward(String text) async {
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
        return _GuideTurnResponse(
          result: _buildGuideRedeemRewardNeedConfirmation(
            text,
            candidates: match.candidates,
          ),
        );
      }

      if (_controller.currentGold < reward.cost) {
        return _GuideTurnResponse(
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
        return _GuideTurnResponse(
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

      return _GuideTurnResponse(
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

  String _extractQuotedText(String text) {
    final quoted = RegExp(r'[“"](.*?)[”"]').firstMatch(text);
    if (quoted == null) return '';
    return quoted.group(1)?.trim() ?? '';
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

  String _guessGuideTaskTitleFromModifyText(String text) {
    final explicit = _extractQuotedText(text);
    if (explicit.isNotEmpty) return explicit;

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

  QuestNode? _findGuideTargetTask(String text) {
    final explicit = _extractQuotedText(text);
    if (explicit.isNotEmpty) {
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

  int? _extractGuideXp(String text) {
    final match = RegExp(r'(?:xp|经验|奖励)\D{0,3}(\d{1,3})', caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  int? _parseGuideDigitText(String raw, {bool allowSequence = false}) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final direct = int.tryParse(normalized);
    if (direct != null) return direct;
    const digits = <String, int>{
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    if (allowSequence &&
        normalized.split('').every((char) => digits.containsKey(char))) {
      final mapped = normalized.split('').map((char) => digits[char]).join();
      return int.tryParse(mapped);
    }
    if (!normalized.contains('十')) {
      return digits[normalized];
    }
    final parts = normalized.split('十');
    final tensRaw = parts.first.trim();
    final onesRaw = parts.length > 1 ? parts.last.trim() : '';
    final tens = tensRaw.isEmpty ? 1 : digits[tensRaw];
    final ones = onesRaw.isEmpty ? 0 : digits[onesRaw];
    if (tens == null || ones == null) return null;
    return tens * 10 + ones;
  }

  String? _extractGuideNaturalTitleFromModifyText(
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

    cleaned =
        cleaned.replaceFirst(RegExp(r'^(?:改成|改为|改到|调整为|设为|为)'), '').trim();

    final dueKeyword = RegExp(r'(?:截止时间?|到期时间?|截止|到期)').firstMatch(cleaned);
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

    if (cleaned.isEmpty || cleaned == target.title.trim()) {
      return null;
    }
    return cleaned;
  }

  DateTime? _extractGuideDueDate(String text) {
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

  bool _shouldGuideGenerateSubtasks(String text) {
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

  bool _isGuideConfirmationText(String text) {
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

  bool _isGuideCancellationText(String text) {
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

  List<String> _extractGuideStepTitles(String text) {
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
      if (pieces.length >= 2) {
        return pieces;
      }
    }
    return const <String>[];
  }

  List<String> _buildGuideSplitSteps(QuestNode quest, String text) {
    final explicitSteps = _extractGuideStepTitles(text);
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
    final explicitSteps = _extractGuideStepTitles(text);
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

  QuestNode? _findGuideTaskById(String taskId) {
    for (final quest in _controller.activeQuests) {
      if (quest.id == taskId) {
        return quest;
      }
    }
    return null;
  }

  void _rememberRecentlyDeletedGuideTasks(List<String> titles) {
    for (final raw in titles) {
      final title = raw.trim();
      if (title.isEmpty) continue;
      _recentlyDeletedGuideTaskTitles.remove(title);
      _recentlyDeletedGuideTaskTitles.insert(0, title);
    }
    if (_recentlyDeletedGuideTaskTitles.length > 8) {
      _recentlyDeletedGuideTaskTitles.removeRange(
        8,
        _recentlyDeletedGuideTaskTitles.length,
      );
    }
  }

  void _deleteQuestWithGuideMemory(String questId) {
    final deletingTitles = _controller.quests
        .where((quest) => quest.id == questId || quest.parentId == questId)
        .map((quest) => quest.title)
        .toList(growable: false);
    _rememberRecentlyDeletedGuideTasks(deletingTitles);
    _controller.deleteQuest(questId);
  }

  void _deleteAllQuestsWithGuideMemory() {
    final deletingTitles = _controller.activeQuests
        .where((quest) => !quest.isReward && !quest.isDeleted)
        .map((quest) => quest.title)
        .toList(growable: false);
    _rememberRecentlyDeletedGuideTasks(deletingTitles);
    _controller.deleteAllActiveQuests();
  }

  bool _shouldKeepPendingGuideTaskEditDraft(GuideTaskEditDraft? draft) {
    if (draft == null) return false;
    if (draft.action == 'confirm') return true;
    if (draft.action == 'sync_due_date') return true;
    return draft.action == 'split' && draft.subtasks.isNotEmpty;
  }

  Future<_GuideTurnResponse> _handlePendingGuideTaskEdit(String text) async {
    final draft = _pendingGuideTaskEditDraft;
    if (draft == null) {
      return _GuideTurnResponse(result: _buildAdviceGuideResult(text));
    }
    if (_isGuideCancellationText(text)) {
      _pendingGuideTaskEditDraft = null;
      _pendingGuideTaskDueDate = null;
      return _GuideTurnResponse(
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
    if (!_isGuideConfirmationText(text)) {
      return _GuideTurnResponse(result: _buildAdviceGuideResult(text));
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
        return _GuideTurnResponse(
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
          pendingTaskDueDate: _pendingGuideTaskDueDate,
        );
      }
      if (_pendingGuideTaskDueDate != null) {
        await _controller.updateQuestDetails(
          inserted.id,
          dueDate: _pendingGuideTaskDueDate,
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
      final dueDate = _pendingGuideTaskDueDate;
      _pendingGuideTaskEditDraft = null;
      _pendingGuideTaskDueDate = null;
      return _GuideTurnResponse(
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

    final target = _findGuideTaskById(draft.taskId) ??
        _findGuideTargetTask(draft.taskTitle);
    if (target == null) {
      _pendingGuideTaskEditDraft = null;
      _pendingGuideTaskDueDate = null;
      return _GuideTurnResponse(
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

    if (draft.action == 'sync_due_date' && _pendingGuideTaskDueDate != null) {
      final dueDate = _pendingGuideTaskDueDate!;
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
      _pendingGuideTaskEditDraft = null;
      _pendingGuideTaskDueDate = null;
      return _GuideTurnResponse(
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
        return _GuideTurnResponse(
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
      _pendingGuideTaskEditDraft = null;
      _pendingGuideTaskDueDate = null;
      return _GuideTurnResponse(
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

    _pendingGuideTaskEditDraft = null;
    _pendingGuideTaskDueDate = null;
    return _GuideTurnResponse(result: _buildAdviceGuideResult(text));
  }

  Future<_GuideTurnResponse> _handleGuideGenerateTask(String text) async {
    final quoted = _extractQuotedText(text);
    final source = quoted.isNotEmpty ? quoted : text;
    final title = _normalizeGuideTaskTitle(source);
    if (title.isEmpty) {
      return _GuideTurnResponse(
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
      return _GuideTurnResponse(
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
    if (_shouldGuideGenerateSubtasks(text)) {
      insertedChildren = await _controller.addGuideChildTasks(
        parent: inserted,
        stepTitles: _buildGuideGeneratedSubtasks(inserted.title, text),
        xpReward: (inserted.xpReward / 2).round(),
      );
    }

    return _GuideTurnResponse(
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

  Future<_GuideTurnResponse> _handleGuideModifyTask(String text) async {
    final target = _findGuideTargetTask(text);
    if (target == null) {
      final suggestedTitle = _guessGuideTaskTitleFromModifyText(text);
      if (suggestedTitle.isNotEmpty) {
        final dueDate = _extractGuideDueDate(text.trim());
        final shouldGenerateSubtasks = _shouldGuideGenerateSubtasks(text);
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
        return _GuideTurnResponse(
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
      return _GuideTurnResponse(
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
    final xp = _extractGuideXp(normalized);
    final dueDate = _extractGuideDueDate(normalized);
    final renameMatch = RegExp(r'(?:标题改成|改成)(.+)$').firstMatch(normalized);
    final descriptionMatch =
        RegExp(r'(?:描述改成|说明改成)(.+)$').firstMatch(normalized);
    final naturalTitle = renameMatch == null && descriptionMatch == null
        ? _extractGuideNaturalTitleFromModifyText(normalized, target)
        : null;

    if (normalized.contains('拆') || normalized.contains('拆成')) {
      final steps = _buildGuideSplitSteps(target, normalized);
      final inserted = await _controller.addGuideChildTasks(
        parent: target,
        stepTitles: steps,
        xpReward: (target.xpReward / 2).round(),
      );
      if (inserted.isEmpty) {
        return _GuideTurnResponse(
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
      return _GuideTurnResponse(
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
      return _GuideTurnResponse(
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
        return _GuideTurnResponse(
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

    return _GuideTurnResponse(
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

  Future<_GuideTurnResponse> _handleGuideAction(String text) async {
    final action = _matchGuideAction(text);
    switch (action) {
      case _GuideActionType.generateTask:
        return _handleGuideGenerateTask(text);
      case _GuideActionType.modifyTask:
        return _handleGuideModifyTask(text);
      case _GuideActionType.openShop:
        return _GuideTurnResponse(
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
      case _GuideActionType.redeemReward:
        return _handleGuideRedeemReward(text);
      case _GuideActionType.weeklySummary:
        return _GuideTurnResponse(
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
      case _GuideActionType.openStats:
        return _GuideTurnResponse(
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
        return _GuideTurnResponse(
          result: _buildAdviceGuideResult(text),
        );
    }
  }

  Future<_GuideTurnResponse> _handleGuideTurn(String text) async {
    if (_pendingGuideTaskEditDraft != null &&
        (_isGuideConfirmationText(text) || _isGuideCancellationText(text))) {
      return _handlePendingGuideTaskEdit(text);
    }

    if (_shouldRouteToAgent(text)) {
      final fallbackReply = context.tr('guide.fallback.reply');
      try {
        final localResult = await _startAgentRunFromGuideInput(text);
        final guideChatResult = _extractGuideChatResultFromAgentLocalResult(
          localResult,
        );
        final latest = _currentAgentRunResult().latestAssistantMessage;
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
        return _GuideTurnResponse(
          result: result,
          pendingTaskEditDraft: result.taskEditDraft,
          closeDialogBeforeAction: navigationTarget.isNotEmpty,
          appendAssistantReply: guideChatResult != null,
          postAction: navigationTarget.isEmpty
              ? null
              : () => _performAgentNavigation(navigationTarget),
        );
      } catch (_) {
        final action = _matchGuideAction(text);
        if (action != null) {
          return _handleGuideAction(text);
        }
        final localResult = await _executeAgentFreeformChat(
          <String, dynamic>{'source_text': text},
        );
        final result =
            _extractGuideChatResultFromAgentLocalResult(localResult) ??
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
        return _GuideTurnResponse(
          result: result,
          pendingTaskEditDraft: result.taskEditDraft,
        );
      }
    }

    final intent = _classifyGuideIntent(text);
    if (intent == GuideChatIntent.action) {
      _pendingGuideTaskEditDraft = null;
      _pendingGuideTaskDueDate = null;
      return _handleGuideAction(text);
    }

    final result = await _guideService.chat(
      message: text,
      scene: 'home',
      clientContext: _buildGuideClientContext(),
    );

    if (result.reply.trim().isNotEmpty ||
        result.messageCard != null ||
        result.resultCard != null ||
        result.quickActions.isNotEmpty) {
      return _GuideTurnResponse(
        result: result,
        pendingTaskEditDraft:
            _shouldKeepPendingGuideTaskEditDraft(result.taskEditDraft)
                ? result.taskEditDraft
                : null,
        pendingTaskDueDate: null,
      );
    }

    return _GuideTurnResponse(
      result: intent == GuideChatIntent.advice
          ? _buildAdviceGuideResult(text)
          : _buildCompanionGuideResult(text),
    );
  }

  Future<void> _openGuidePanel() async {
    if (_guideMessages.isEmpty) {
      _appendGuideMessage(
        'assistant',
        context.tr(
          'guide.default_opening',
          params: {'name': _guideName},
        ),
      );
    }

    final messages = List<_GuideChatMessage>.from(_visibleGuideMessages());
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
        messages.add(_GuideChatMessage(role: 'user', content: shownText));
      });
      latestUserText = shownText;
      _appendGuideMessage('user', shownText);
      input.clear();

      try {
        final turn = await _handleGuideTurn(text);
        if (!mounted || !dialogContext.mounted) return;
        final result = _guideResultForCurrentLocale(turn.result);
        _pendingGuideTaskEditDraft = turn.pendingTaskEditDraft;
        _pendingGuideTaskDueDate = turn.pendingTaskDueDate;
        final reply = result.reply.trim().isNotEmpty
            ? result.reply
            : context.tr('guide.fallback.reply');
        setState(() => _guideStatus = _GuideConnectionStatus.ready);
        if (turn.appendAssistantReply) {
          setModalState(() {
            messages.add(
              _GuideChatMessage(
                role: 'assistant',
                content: reply,
                memoryRefCount: result.memoryRefs.length,
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
              ..addAll(_visibleGuideMessages());
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
        setState(() => _guideStatus = _statusFromError(e));
        final fallback = context.tr('guide.network_fallback');
        setModalState(() {
          messages.add(_GuideChatMessage(role: 'assistant', content: fallback));
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
            guideMemorySignals: _guideBehaviorSignals,
            statusText: _guideStatus == _GuideConnectionStatus.ready
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
            statusReady: _guideStatus == _GuideConnectionStatus.ready,
            messages: messages
                .map(
                  (item) => GuideDialogMessage(
                    role: item.role == 'user'
                        ? GuideDialogRole.user
                        : GuideDialogRole.assistant,
                    content: item.content,
                    memoryRefCount: item.memoryRefCount,
                  ),
                )
                .toList(),
            quickActions: entryActions,
            examplePrompts: currentExamplePrompts,
            inputController: input,
            inputHintText: currentInputHint,
            sendLabel: context.tr('common.send'),
            retryLabel: context.tr('common.retry'),
            closeLabel: context.tr('common.close'),
            sending: sending,
            memoryRefsLabelBuilder: (count) => context.tr(
              'guide.memory.refs',
              params: {'count': '$count'},
            ),
            onRetry: _guideStatus == _GuideConnectionStatus.ready
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
      result = await _guideService.nightReflection(
        dayId: _localDateId(),
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
    final addTask = await showQuestDialog<bool>(
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
        onKeepOnly: () => Navigator.of(dialogContext).pop(false),
        onAddTomorrow: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    if (addTask == true) {
      final inserted = await _controller.addGuideSuggestedTask(
        title: result.suggestedTask.title,
        description: result.suggestedTask.description,
        xpReward: result.suggestedTask.xpReward,
        questTier: result.suggestedTask.questTier,
      );
      if (inserted != null && mounted) {
        showForestSnackBar(context, nightAddTomorrow);
      }
    } else if (addTask == false) {
      unawaited(
        _guideService.chat(
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
                _PlusMenuItem(
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
                _PlusMenuItem(
                  icon: Icons.image_rounded,
                  color: const Color(0xFFFFB74D),
                  title: context.tr('quick_add.menu.image'),
                  subtitle: context.tr('quick_add.menu.image_desc'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr('quick_add.menu.coming_soon'),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showForestSnackBar(
                      context,
                      context.tr('quick_add.menu.coming_soon'),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final result = await showQuestDialog<_QuickCreateDialogResult>(
      context: context,
      barrierLabel: 'quick_create_dialog',
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext).extension<QuestTheme>()!;
        return _QuickCreateDialogBody(
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
      case _QuickCreateMode.newMainWithSides:
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
      case _QuickCreateMode.attachToExistingMain:
        final insertedSide = await _controller.createManualQuest(
          title: result.title,
          description: '',
          xpReward: 30,
          questTier: 'Side_Quest',
          parentMainQuestId: result.parentMainQuestId,
        );
        createdAny = insertedSide != null;
      case _QuickCreateMode.daily:
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

  Future<void> _generateUserProfile() async {
    if (_isGeneratingProfile || !mounted) return;
    setState(() => _isGeneratingProfile = true);
    try {
      final portrait = await _guideService.generatePortrait(
        scene: 'profile',
        style: 'pencil_sketch',
        forceRefresh: true,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withAlpha(120),
        builder: (dialogContext) {
          final localTheme = Theme.of(dialogContext).extension<QuestTheme>()!;
          final dialogSize = MediaQuery.of(dialogContext).size;
          final dialogWidth = (dialogSize.width - 48).clamp(320.0, 620.0);
          final dialogHeight = (dialogSize.height - 48).clamp(480.0, 760.0);
          final insight = _PortraitInsightData.fromPortrait(
            portrait,
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
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PortraitEvaluationSection(
                              insight: insight,
                              theme: localTheme,
                              guideName: _guideName,
                            ),
                            const SizedBox(height: 16),
                            _PortraitInsightChart(
                              insight: insight,
                              theme: localTheme,
                            ),
                            const SizedBox(height: 16),
                            _PortraitReadableMetricGrid(
                              insight: insight,
                              theme: localTheme,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(context.tr('common.close')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                            _SettingsSectionCard(
                              icon: Icons.smart_toy_rounded,
                              accentColor: localTheme.primaryAccentColor,
                              title: context.tr('settings.section.guide'),
                              description:
                                  context.tr('settings.section.guide_desc'),
                              child: Column(
                                children: [
                                  _SettingsToggleTile(
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
                                  _SettingsToggleTile(
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
                            _SettingsSectionCard(
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
                                    child: _SettingsChoicePill(
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
                            _SettingsSectionCard(
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
                                    child: _SettingsChoicePill(
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

  _GuideConnectionStatus _statusFromError(Object error) {
    if (error is GuideServiceException) {
      return switch (error.type) {
        GuideErrorType.authExpired => _GuideConnectionStatus.authExpired,
        GuideErrorType.network => _GuideConnectionStatus.network,
        GuideErrorType.service ||
        GuideErrorType.unknown =>
          _GuideConnectionStatus.service,
      };
    }
    return _GuideConnectionStatus.service;
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
    if (ok == true) _deleteAllQuestsWithGuideMemory();
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
              (_profileDisplayName?.trim().isNotEmpty == true)
                  ? context.tr('app.title',
                      params: {'name': _profileDisplayName!.trim()})
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
                      onQuestDeleted: _deleteQuestWithGuideMemory,
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
                child: KeyedSubtree(
                  key: _coachKeyQuickAdd,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => QuickAddBar(
                      isLoading: _controller.isAnalyzing,
                      onSubmitted: _controller.simulateAIParsing,
                      onPlusTap: _showPlusMenu,
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _latestDailyEvent == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showDailyEventDialog(_latestDailyEvent!),
                  icon: _isGuideEventHandling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flash_on_rounded),
                  label: Text(_eventBadgeLabel(_latestDailyEvent!)),
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

class _PortraitInsightData {
  final String summary;
  final List<String> evaluations;
  final int energyScore;
  final int rhythmScore;
  final int resilienceScore;
  final int awarenessScore;

  const _PortraitInsightData({
    required this.summary,
    required this.evaluations,
    required this.energyScore,
    required this.rhythmScore,
    required this.resilienceScore,
    required this.awarenessScore,
  });

  factory _PortraitInsightData.fromPortrait(
    GuidePortraitResult portrait,
    String guideName,
  ) {
    final summary = portrait.summary.trim().isEmpty
        ? AppLocaleController.instance.t('profile.analysis_fallback')
        : portrait.summary.trim();
    final summaryLength = summary.runes.length;
    final energyScore =
        (42 + portrait.memoryRefs.length * 9 + (summaryLength ~/ 18))
            .clamp(28, 92);
    final rhythmScore = (38 +
            portrait.memoryRefs.length * 7 +
            (portrait.traceId.isEmpty ? 4 : 16))
        .clamp(24, 90);
    final resilienceScore =
        (34 + (summaryLength ~/ 16) + (portrait.seed >= 0 ? 12 : 0))
            .clamp(20, 88);
    final awarenessScore =
        (40 + (summaryLength ~/ 14) + (portrait.memoryRefs.length * 5))
            .clamp(26, 94);
    final evaluations = _buildPortraitEvaluations(
      guideName: guideName,
      summary: summary,
      memoryRefs: portrait.memoryRefs,
      energyScore: energyScore,
      rhythmScore: rhythmScore,
      resilienceScore: resilienceScore,
      awarenessScore: awarenessScore,
      isEnglish: AppLocaleController.instance.isEnglish,
    );

    return _PortraitInsightData(
      summary: summary,
      evaluations: evaluations,
      energyScore: energyScore,
      rhythmScore: rhythmScore,
      resilienceScore: resilienceScore,
      awarenessScore: awarenessScore,
    );
  }
}

List<String> _buildPortraitEvaluations({
  required String guideName,
  required String summary,
  required List<String> memoryRefs,
  required int energyScore,
  required int rhythmScore,
  required int resilienceScore,
  required int awarenessScore,
  required bool isEnglish,
}) {
  String pick(String zh, String en) => isEnglish ? en : zh;

  final evaluations = <String>[
    if (energyScore >= 75)
      pick(
        '$guideName觉得你最近是带着推进力在行动，不太像只靠情绪硬撑。',
        '$guideName feels that you have been moving with real momentum lately, not just forcing yourself through emotions.',
      )
    else if (energyScore >= 55)
      pick(
        '$guideName觉得你还有行动意愿，但更适合用小步推进，而不是一下把自己拉满。',
        '$guideName feels you still want to move, but small steps fit better than trying to push yourself to the limit.',
      )
    else
      pick(
        '$guideName觉得你现在更需要先回收精力，温和启动会比强推自己更有效。',
        '$guideName feels you need to recover your energy first. A gentle start will work better than forcing yourself.',
      ),
    if (rhythmScore >= 72)
      pick(
        '你的节奏感比较稳，说明你已经在形成“做一点也算前进”的惯性。',
        'Your rhythm looks steady, which suggests you are building the habit that even a small step still counts as progress.',
      )
    else if (rhythmScore >= 50)
      pick(
        '你的节奏正在恢复中，关键不是更拼，而是把重复的小动作守住。',
        'Your rhythm is coming back. The key is not pushing harder, but protecting the small repeatable actions.',
      )
    else
      pick(
        '你的节奏还偏散，$guideName更建议先固定一个最容易完成的起手动作。',
        'Your rhythm is still a bit scattered, so $guideName suggests locking in the easiest starter action first.',
      ),
    if (resilienceScore >= 70)
      pick(
        '遇到波动时，你有把自己拉回来的能力，这说明恢复力已经在长出来了。',
        'When things wobble, you can pull yourself back. That shows your resilience is already growing.',
      )
    else if (resilienceScore >= 48)
      pick(
        '你有恢复的趋势，但还需要更明显的休息边界和回弹空间。',
        'You are trending toward recovery, but you still need clearer rest boundaries and more space to bounce back.',
      )
    else
      pick(
        '$guideName觉得你最近容易被消耗，先保证恢复感，比继续加任务更重要。',
        '$guideName feels you have been easy to drain lately, so protecting recovery matters more than adding more tasks.',
      ),
    if (awarenessScore >= 72)
      pick(
        '你对自己状态的观察是在线的，这会让你更容易做出适合当下的选择。',
        'You are noticing your own state in real time, which makes it easier to choose what fits this moment.',
      )
    else if (awarenessScore >= 52)
      pick(
        '你已经能感知到自己的状态变化，再多一点记录会让判断更稳定。',
        'You can already feel your state shifting. A little more logging will make your judgment steadier.',
      )
    else
      pick(
        '$guideName觉得你还在一边做一边摸索，先把感受说清楚，比追求标准答案更重要。',
        '$guideName feels you are still figuring things out as you go, so naming how it feels matters more than chasing a perfect answer.',
      ),
  ];

  if (memoryRefs.isNotEmpty) {
    evaluations.add(
      pick(
        '这次$guideName参考了 ${memoryRefs.length} 段近期记忆，所以更像一份阶段观察，不是一次性的情绪判断。',
        'This time $guideName referenced ${memoryRefs.length} recent memories, so this reads more like a stage snapshot than a one-off mood judgment.',
      ),
    );
  }
  if (summary.length <= 40) {
    evaluations.add(
      pick(
        '目前样本还不算多，等你积累更多记录后，$guideName的判断会更具体也更贴身。',
        'The sample is still fairly small. Once you build up more records, $guideName can make a more specific and personal read.',
      ),
    );
  }
  return evaluations.take(4).toList();
}

class _PortraitInsightChart extends StatelessWidget {
  final _PortraitInsightData insight;
  final QuestTheme theme;

  const _PortraitInsightChart({
    required this.insight,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bars = <_PortraitBarDatum>[
      _PortraitBarDatum(
        label: context.tr('profile.metric.energy'),
        value: insight.energyScore,
        color: theme.primaryAccentColor,
      ),
      _PortraitBarDatum(
        label: context.tr('profile.metric.rhythm'),
        value: insight.rhythmScore,
        color: theme.mainQuestColor,
      ),
      _PortraitBarDatum(
        label: context.tr('profile.metric.resilience'),
        value: insight.resilienceScore,
        color: theme.sideQuestColor,
      ),
      _PortraitBarDatum(
        label: context.tr('profile.metric.awareness'),
        value: insight.awarenessScore,
        color: const Color(0xFFFFB74D),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('profile.metric.title'),
            style: AppTextStyles.heading2.copyWith(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 188,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = bars[group.x.toInt()];
                      return BarTooltipItem(
                        '${item.label}\n${item.readableLevel(context)}',
                        AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.textHint.withAlpha(36),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            bars[index].label,
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(
                  bars.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: bars[index].value.toDouble(),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: bars[index].color,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitReadableMetricGrid extends StatelessWidget {
  final _PortraitInsightData insight;
  final QuestTheme theme;

  const _PortraitReadableMetricGrid({
    required this.insight,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_PortraitMetricDatum>[
      _PortraitMetricDatum(
        label: context.tr('profile.metric.energy'),
        value: _readableMetricLevel(context, insight.energyScore),
        detail: _readableMetricDetail(context, 'energy', insight.energyScore),
        icon: Icons.local_fire_department_rounded,
        color: theme.primaryAccentColor,
      ),
      _PortraitMetricDatum(
        label: context.tr('profile.metric.rhythm'),
        value: _readableMetricLevel(context, insight.rhythmScore),
        detail: _readableMetricDetail(context, 'rhythm', insight.rhythmScore),
        icon: Icons.timeline_rounded,
        color: const Color(0xFFFFB74D),
      ),
      _PortraitMetricDatum(
        label: context.tr('profile.metric.resilience'),
        value: _readableMetricLevel(context, insight.resilienceScore),
        detail: _readableMetricDetail(
          context,
          'resilience',
          insight.resilienceScore,
        ),
        icon: Icons.spa_rounded,
        color: theme.sideQuestColor,
      ),
      _PortraitMetricDatum(
        label: context.tr('profile.metric.awareness'),
        value: _readableMetricLevel(context, insight.awarenessScore),
        detail: _readableMetricDetail(
          context,
          'awareness',
          insight.awarenessScore,
        ),
        icon: Icons.visibility_rounded,
        color: theme.mainQuestColor,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Container(
              width: 188,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(165),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 18, color: item.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PortraitEvaluationSection extends StatelessWidget {
  final _PortraitInsightData insight;
  final QuestTheme theme;
  final String guideName;

  const _PortraitEvaluationSection({
    required this.insight,
    required this.theme,
    required this.guideName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            'profile.evaluation_title',
            params: {'name': guideName},
          ),
          style: AppTextStyles.heading2.copyWith(
            fontSize: 17,
            color: theme.primaryAccentColor,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: insight.evaluations
              .map(
                (evaluation) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(160),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primaryAccentColor.withAlpha(38),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.psychology_alt_rounded,
                        size: 18,
                        color: theme.primaryAccentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          evaluation,
                          style: AppTextStyles.body.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

String _readableMetricLevel(BuildContext context, int score) {
  if (score >= 78) {
    return context.tr('profile.metric.level_high');
  }
  if (score >= 56) {
    return context.tr('profile.metric.level_mid');
  }
  return context.tr('profile.metric.level_low');
}

String _readableMetricDetail(BuildContext context, String key, int score) {
  final level = score >= 78
      ? 'high'
      : score >= 56
          ? 'mid'
          : 'low';
  return context.tr('profile.metric.$key.$level');
}

class _PortraitBarDatum {
  final String label;
  final int value;
  final Color color;

  const _PortraitBarDatum({
    required this.label,
    required this.value,
    required this.color,
  });

  String readableLevel(BuildContext context) {
    return _readableMetricLevel(context, value);
  }
}

class _PortraitMetricDatum {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _PortraitMetricDatum({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _PlusMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _PlusMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final Widget child;

  const _SettingsSectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(158),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withAlpha(42)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.heading2.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.caption.copyWith(
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

enum _QuickCreateMode {
  newMainWithSides,
  attachToExistingMain,
  daily,
}

class _QuickCreateDialogResult {
  final _QuickCreateMode mode;
  final String title;
  final List<String> sideTitles;
  final String? parentMainQuestId;
  final int? dailyDueMinutes;

  const _QuickCreateDialogResult({
    required this.mode,
    required this.title,
    this.sideTitles = const <String>[],
    this.parentMainQuestId,
    this.dailyDueMinutes,
  });
}

class _QuickCreateDialogBody extends StatefulWidget {
  final List<QuestNode> mainQuestOptions;
  final QuestTheme theme;
  final ValueChanged<_QuickCreateDialogResult> onConfirm;
  final VoidCallback onClose;

  const _QuickCreateDialogBody({
    required this.mainQuestOptions,
    required this.theme,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  State<_QuickCreateDialogBody> createState() => _QuickCreateDialogBodyState();
}

class _QuickCreateDialogBodyState extends State<_QuickCreateDialogBody> {
  _QuickCreateMode _selectedMode = _QuickCreateMode.newMainWithSides;
  final TextEditingController _mainTitleController = TextEditingController();
  final TextEditingController _attachSideTitleController =
      TextEditingController();
  final TextEditingController _dailyTitleController = TextEditingController();
  final List<TextEditingController> _sideDraftControllers =
      <TextEditingController>[];
  String? _selectedParentMainQuestId;
  int? _dailyDueMinutes;

  @override
  void initState() {
    super.initState();
    _mainTitleController.addListener(_onFormChanged);
    _attachSideTitleController.addListener(_onFormChanged);
    _dailyTitleController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _mainTitleController
      ..removeListener(_onFormChanged)
      ..dispose();
    _attachSideTitleController
      ..removeListener(_onFormChanged)
      ..dispose();
    _dailyTitleController
      ..removeListener(_onFormChanged)
      ..dispose();
    for (final controller in _sideDraftControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setMode(_QuickCreateMode mode) {
    if (_selectedMode == mode) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _selectedMode = mode);
  }

  void _addSideDraft([String initialValue = '']) {
    final controller = TextEditingController(text: initialValue)
      ..addListener(_onFormChanged);
    setState(() => _sideDraftControllers.add(controller));
  }

  void _removeSideDraft(int index) {
    final controller = _sideDraftControllers.removeAt(index);
    controller
      ..removeListener(_onFormChanged)
      ..dispose();
    setState(() {});
  }

  String _formatDailyDueMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final safeMinutes = minutes.clamp(0, 1439);
    return TimeOfDay(hour: safeMinutes ~/ 60, minute: safeMinutes % 60);
  }

  Future<void> _pickDailyDueTime() async {
    final initialTime = _dailyDueMinutes == null
        ? const TimeOfDay(hour: 21, minute: 0)
        : _timeOfDayFromMinutes(_dailyDueMinutes!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              dialHandColor: widget.theme.primaryAccentColor,
              hourMinuteTextColor: widget.theme.primaryAccentColor,
              dayPeriodTextColor: widget.theme.primaryAccentColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _dailyDueMinutes = picked.hour * 60 + picked.minute);
  }

  List<String> get _normalizedSideTitles => _sideDraftControllers
      .map((controller) => controller.text.trim())
      .where((title) => title.isNotEmpty)
      .toList(growable: false);

  bool get _canSubmit {
    switch (_selectedMode) {
      case _QuickCreateMode.newMainWithSides:
        return _mainTitleController.text.trim().isNotEmpty;
      case _QuickCreateMode.attachToExistingMain:
        return _attachSideTitleController.text.trim().isNotEmpty &&
            _selectedParentMainQuestId != null &&
            widget.mainQuestOptions.isNotEmpty;
      case _QuickCreateMode.daily:
        return _dailyTitleController.text.trim().isNotEmpty;
    }
  }

  String get _confirmLabel {
    switch (_selectedMode) {
      case _QuickCreateMode.newMainWithSides:
        return _normalizedSideTitles.isEmpty
            ? context.tr('quick_add.create.tier_main')
            : context.tr('quick_add.dialog.mode.new_main.title');
      case _QuickCreateMode.attachToExistingMain:
        return context.tr('quick_add.create.tier_side');
      case _QuickCreateMode.daily:
        return context.tr('quick_add.dialog.mode.daily.title');
    }
  }

  IconData get _confirmIcon {
    switch (_selectedMode) {
      case _QuickCreateMode.newMainWithSides:
        return Icons.account_tree_rounded;
      case _QuickCreateMode.attachToExistingMain:
        return Icons.call_split_rounded;
      case _QuickCreateMode.daily:
        return Icons.schedule_rounded;
    }
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    FocusScope.of(context).unfocus();
    switch (_selectedMode) {
      case _QuickCreateMode.newMainWithSides:
        widget.onConfirm(
          _QuickCreateDialogResult(
            mode: _QuickCreateMode.newMainWithSides,
            title: _mainTitleController.text.trim(),
            sideTitles: _normalizedSideTitles,
          ),
        );
      case _QuickCreateMode.attachToExistingMain:
        widget.onConfirm(
          _QuickCreateDialogResult(
            mode: _QuickCreateMode.attachToExistingMain,
            title: _attachSideTitleController.text.trim(),
            parentMainQuestId: _selectedParentMainQuestId,
          ),
        );
      case _QuickCreateMode.daily:
        widget.onConfirm(
          _QuickCreateDialogResult(
            mode: _QuickCreateMode.daily,
            title: _dailyTitleController.text.trim(),
            dailyDueMinutes: _dailyDueMinutes,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeCards = <({
      _QuickCreateMode mode,
      String title,
      String description,
      IconData icon,
      Color color,
    })>[
      (
        mode: _QuickCreateMode.newMainWithSides,
        title: context.tr('quick_add.dialog.mode.new_main.title'),
        description: context.tr('quick_add.dialog.mode.new_main.description'),
        icon: Icons.account_tree_rounded,
        color: widget.theme.mainQuestColor,
      ),
      (
        mode: _QuickCreateMode.attachToExistingMain,
        title: context.tr('quick_add.dialog.mode.attach.title'),
        description: context.tr('quick_add.dialog.mode.attach.description'),
        icon: Icons.call_split_rounded,
        color: widget.theme.sideQuestColor,
      ),
      (
        mode: _QuickCreateMode.daily,
        title: context.tr('quick_add.dialog.mode.daily.title'),
        description: context.tr('quick_add.dialog.mode.daily.description'),
        icon: Icons.wb_sunny_rounded,
        color: widget.theme.dailyQuestColor,
      ),
    ];
    final activeColor = switch (_selectedMode) {
      _QuickCreateMode.newMainWithSides => widget.theme.mainQuestColor,
      _QuickCreateMode.attachToExistingMain => widget.theme.sideQuestColor,
      _QuickCreateMode.daily => widget.theme.dailyQuestColor,
    };

    return QuestDialogShell(
      title: context.tr('quick_add.create.title'),
      subtitle: context.tr('quick_add.dialog.subtitle'),
      maxWidth: 680,
      maxHeight: 760,
      scrollable: true,
      accentColor: widget.theme.primaryAccentColor,
      leading: QuestDialogBadge(
        icon: Icons.edit_note_rounded,
        accentColor: widget.theme.primaryAccentColor,
        size: 56,
      ),
      onClose: widget.onClose,
      actions: [
        QuestDialogSecondaryButton(
          label: context.tr('common.cancel'),
          icon: Icons.close_rounded,
          onPressed: widget.onClose,
        ),
        QuestDialogPrimaryButton(
          label: _confirmLabel,
          icon: _confirmIcon,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final cardWidth =
                  wide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: modeCards.map((config) {
                  final selected = _selectedMode == config.mode;
                  final foreground =
                      selected ? Colors.white : const Color(0xFF243427);
                  final background = selected
                      ? Color.lerp(config.color, Colors.black, 0.08)!
                      : Color.lerp(
                          widget.theme.surfaceColor,
                          config.color,
                          0.12,
                        )!;
                  return SizedBox(
                    width: cardWidth,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _setMode(config.mode),
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                background,
                                selected
                                    ? Color.lerp(
                                        config.color, Colors.white, 0.18)!
                                    : Color.lerp(
                                        widget.theme.backgroundColor,
                                        config.color,
                                        0.08,
                                      )!,
                              ],
                            ),
                            border: Border.all(
                              color: selected
                                  ? config.color.withAlpha(210)
                                  : config.color.withAlpha(58),
                              width: selected ? 1.4 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: config.color.withAlpha(42),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ]
                                : const <BoxShadow>[],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withAlpha(36)
                                      : config.color.withAlpha(24),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  config.icon,
                                  color: selected ? Colors.white : config.color,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                config.title,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                config.description,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: selected
                                      ? Colors.white.withAlpha(230)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_selectedMode) {
              _QuickCreateMode.newMainWithSides =>
                _buildNewMainWithSidesPanel(activeColor),
              _QuickCreateMode.attachToExistingMain =>
                _buildAttachToExistingMainPanel(activeColor),
              _QuickCreateMode.daily => _buildDailyPanel(activeColor),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewMainWithSidesPanel(Color accentColor) {
    return QuestDialogInfoCard(
      key: const ValueKey<String>('quick_create_new_main_panel'),
      accentColor: accentColor,
      label: context.tr('quick_add.dialog.current_task'),
      icon: Icons.account_tree_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            title: context.tr('quick_add.dialog.main_title'),
            description: context.tr('quick_add.dialog.main_description'),
          ),
          const SizedBox(height: 10),
          _buildTitleField(
            controller: _mainTitleController,
            hint: context.tr('quick_add.dialog.main_hint'),
            icon: Icons.flag_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSectionTitle(
                  title: context.tr('quick_add.dialog.side_drafts_title'),
                  description:
                      context.tr('quick_add.dialog.side_drafts_description'),
                ),
              ),
              TextButton.icon(
                onPressed: _addSideDraft,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('quick_add.dialog.add_side')),
                style: TextButton.styleFrom(
                  foregroundColor: widget.theme.sideQuestColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_sideDraftControllers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: widget.theme.sideQuestColor.withAlpha(12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.theme.sideQuestColor.withAlpha(32),
                ),
              ),
              child: Text(
                context.tr('quick_add.dialog.no_side_drafts'),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            )
          else
            Column(
              children: List.generate(_sideDraftControllers.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _sideDraftControllers.length - 1 ? 0 : 10,
                  ),
                  child: _buildSideDraftCard(index),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachToExistingMainPanel(Color accentColor) {
    return QuestDialogInfoCard(
      key: const ValueKey<String>('quick_create_attach_existing_panel'),
      accentColor: accentColor,
      label: context.tr('quick_add.dialog.attach_label'),
      icon: Icons.call_split_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            title: context.tr('quick_add.dialog.side_title'),
            description: context.tr('quick_add.dialog.side_description'),
          ),
          const SizedBox(height: 10),
          _buildTitleField(
            controller: _attachSideTitleController,
            hint: context.tr('quick_add.dialog.side_hint'),
            icon: Icons.explore_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 18),
          _buildSectionTitle(
            title: context.tr('quick_add.dialog.select_main_title'),
            description: widget.mainQuestOptions.isEmpty
                ? context.tr('quick_add.dialog.select_main_empty')
                : context.tr('quick_add.dialog.select_main_description'),
          ),
          const SizedBox(height: 12),
          if (widget.mainQuestOptions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: widget.theme.sideQuestColor.withAlpha(10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.theme.sideQuestColor.withAlpha(28),
                ),
              ),
              child: Text(
                context.tr('quick_add.dialog.select_main_empty'),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: widget.mainQuestOptions.map((quest) {
                    final selected = quest.id == _selectedParentMainQuestId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(
                            () => _selectedParentMainQuestId = quest.id,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? widget.theme.sideQuestColor.withAlpha(26)
                                  : Colors.white.withAlpha(148),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? widget.theme.sideQuestColor
                                    : widget.theme.sideQuestColor.withAlpha(28),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        widget.theme.mainQuestColor.withAlpha(
                                      selected ? 52 : 24,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    Icons.flag_rounded,
                                    color: widget.theme.mainQuestColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quest.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF203322),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selected
                                            ? context.tr(
                                                'quick_add.dialog.attach_selected',
                                              )
                                            : context.tr(
                                                'quick_add.dialog.attach_unselected',
                                              ),
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: selected
                                      ? widget.theme.sideQuestColor
                                      : widget.theme.sideQuestColor.withAlpha(
                                          120,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyPanel(Color accentColor) {
    return QuestDialogInfoCard(
      key: const ValueKey<String>('quick_create_daily_panel'),
      accentColor: accentColor,
      label: context.tr('quick_add.dialog.daily_label'),
      icon: Icons.wb_sunny_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            title: context.tr('quick_add.dialog.daily_title'),
            description: context.tr('quick_add.dialog.daily_description'),
          ),
          const SizedBox(height: 10),
          _buildTitleField(
            controller: _dailyTitleController,
            hint: context.tr('quick_add.dialog.daily_hint'),
            icon: Icons.wb_sunny_rounded,
            autofocus: true,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.theme.dailyQuestColor.withAlpha(18),
                  widget.theme.surfaceColor,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.theme.dailyQuestColor.withAlpha(34),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.theme.dailyQuestColor.withAlpha(24),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: widget.theme.dailyQuestColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('quick_add.dialog.daily_due_title'),
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF203322),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dailyDueMinutes == null
                                ? context.tr('quick_add.dialog.daily_due_empty')
                                : context.tr(
                                    'quick_add.dialog.daily_due_value',
                                    params: {
                                      'time': _formatDailyDueMinutes(
                                        _dailyDueMinutes!,
                                      ),
                                    },
                                  ),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDailyDueTime,
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(
                        _dailyDueMinutes == null
                            ? context.tr('quick_add.dialog.daily_due_set')
                            : context.tr(
                                'quick_add.dialog.daily_due_reselect',
                              ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.theme.dailyQuestColor,
                        side: BorderSide(
                          color: widget.theme.dailyQuestColor.withAlpha(54),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    if (_dailyDueMinutes != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _dailyDueMinutes = null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text(
                          context.tr('quick_add.dialog.daily_due_clear'),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideDraftCard(int index) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: widget.theme.sideQuestColor.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.theme.sideQuestColor.withAlpha(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr(
                  'quick_add.dialog.side_index',
                  params: {'index': '${index + 1}'},
                ),
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: widget.theme.sideQuestColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeSideDraft(index),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: context.tr('quick_add.dialog.delete_side'),
                splashRadius: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          _buildTitleField(
            controller: _sideDraftControllers[index],
            hint: context.tr('quick_add.dialog.side_draft_hint'),
            icon: Icons.alt_route_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: const Color(0xFF203322),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: AppTextStyles.body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF203322),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(
          color: AppColors.textHint,
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, color: widget.theme.primaryAccentColor),
        filled: true,
        fillColor: Colors.white.withAlpha(188),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: widget.theme.primaryAccentColor.withAlpha(32),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: widget.theme.primaryAccentColor.withAlpha(32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: widget.theme.primaryAccentColor.withAlpha(180),
            width: 1.4,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final Color activeColor;
  final ValueChanged<bool>? onChanged;

  const _SettingsToggleTile({
    required this.title,
    required this.description,
    required this.value,
    required this.activeColor,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(168),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: activeColor.withAlpha(30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              activeThumbColor: activeColor,
              activeTrackColor: activeColor.withAlpha(108),
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsChoicePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  const _SettingsChoicePill({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withAlpha(24)
                : Colors.white.withAlpha(150),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accentColor.withAlpha(118)
                  : AppColors.textHint.withAlpha(44),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(selected ? 24 : 14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.caption.copyWith(
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? accentColor : AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideChatMessage {
  final String role;
  final String content;
  final int memoryRefCount;
  final String? agentStepId;

  const _GuideChatMessage({
    required this.role,
    required this.content,
    this.memoryRefCount = 0,
    this.agentStepId,
  });
}
