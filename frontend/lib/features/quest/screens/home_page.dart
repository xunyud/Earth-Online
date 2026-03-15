import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/evermemos_service.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../shared/widgets/celebration_overlay.dart';
import '../../../shared/widgets/quest_dialog_shell.dart';
import '../../../shared/widgets/sync_indicator.dart';
import '../../achievement/screens/achievement_page.dart';
import '../../achievement/widgets/achievement_unlock_overlay.dart';
import '../../reward/screens/inventory_page.dart';
import '../../reward/screens/reward_shop_page.dart';
import '../../stats/screens/stats_page.dart';
import '../controllers/quest_controller.dart';
import '../widgets/guide_panel_dialog.dart';
import '../widgets/quest_board.dart';
import '../widgets/quest_board_fab.dart';
import '../widgets/quick_add_bar.dart';

enum _GuideConnectionStatus {
  ready,
  authExpired,
  network,
  service,
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
  final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  int _previousUncompletedCount = -1;
  bool _isSyncingMemory = false;
  bool _isGeneratingProfile = false;
  bool _isGuideBootstrapping = false;
  bool _isGuideEventHandling = false;
  _GuideConnectionStatus _guideStatus = _GuideConnectionStatus.ready;

  final List<_GuideChatMessage> _guideMessages = <_GuideChatMessage>[];
  GuideDailyEvent? _latestDailyEvent;
  String? _guideDisplayName;
  String _guideMemoryDigest = '';
  List<String> _guideBehaviorSignals = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQuestStateChanged);
    _controller.init();
    unawaited(_loadGuideDisplayName());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runGuideBootstrapIfNeeded());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuestStateChanged);
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
    if (digest.isNotEmpty) return digest;
    return context.tr(
      'guide.memory.empty',
      params: {'name': _guideName},
    );
  }

  Future<void> _loadGuideDisplayName() async {
    final stored = await PreferencesService.guideDisplayName();
    if (!mounted) return;
    setState(() => _guideDisplayName = stored);
  }

  Map<String, dynamic> _buildGuideClientContext() {
    return <String, dynamic>{
      'guide_name': _guideName,
      'memory_digest': _guideMemoryDigest.trim(),
      'behavior_signals': _guideBehaviorSignals,
      if (_latestDailyEvent != null)
        'latest_daily_event': <String, dynamic>{
          'title': _latestDailyEvent!.title,
          'reason': _latestDailyEvent!.reason,
        },
    };
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
    await PreferencesService.setGuideDisplayName(nextName);
    if (!mounted) return;

    final normalized = nextName.trim().isEmpty ? null : nextName.trim();
    setState(() => _guideDisplayName = normalized);
    setModalState(() {});
  }

  void _appendGuideMessage(
    String role,
    String content, {
    List<String> memoryRefs = const <String>[],
  }) {
    final text = content.trim();
    if (text.isEmpty) return;
    setState(() {
      _guideMessages.add(
        _GuideChatMessage(
          role: role,
          content: text,
          memoryRefCount: memoryRefs.length,
        ),
      );
      if (_guideMessages.length > 60) {
        _guideMessages.removeRange(0, _guideMessages.length - 60);
      }
    });
  }

  Future<void> _runGuideBootstrapIfNeeded() async {
    if (_isGuideBootstrapping) return;
    final guideEnabled = await PreferencesService.guideEnabled();
    final proactiveEnabled = await PreferencesService.guideProactiveEnabled();
    if (!guideEnabled || !proactiveEnabled) return;
    final today = _localDateId();
    final lastDate = await PreferencesService.guideLastBootstrapDate();
    if (lastDate == today || !mounted) return;

    setState(() => _isGuideBootstrapping = true);
    try {
      final result = await _guideService.bootstrap(scene: 'home');
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
        title: context.tr('home.event.title'),
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
              label: context.tr('home.event.badge'),
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
                    '+${event.rewardGold} 金币',
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
                label: '记忆依据',
                icon: Icons.psychology_alt_rounded,
                accentColor: eventTheme.sideQuestColor,
                child: Text(
                  context.tr(
                    'home.event.reason',
                    params: {'reason': event.reason},
                  ),
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

  String _quickPrompt(String action) {
    if (action == context.tr('guide.quick.week')) {
      return context.tr('guide.quick.week.prompt');
    }
    if (action == context.tr('guide.quick.recovery')) {
      return context.tr('guide.quick.recovery.prompt');
    }
    return context.tr('guide.quick.today.prompt');
  }

  Future<void> _openGuidePanel() async {
    final guideFallbackReply = context.tr('guide.fallback.reply');
    final guideNetworkFallback = context.tr('guide.network_fallback');
    if (_guideMessages.isEmpty) {
      _appendGuideMessage(
        'assistant',
        context.tr(
          'guide.default_opening',
          params: {'name': _guideName},
        ),
      );
    }

    final messages = List<_GuideChatMessage>.from(_guideMessages);
    final input = TextEditingController();
    GuideSuggestedTask? suggestedTask;
    List<String> quickActions = [
      context.tr('guide.quick.today'),
      context.tr('guide.quick.week'),
      context.tr('guide.quick.recovery'),
    ];
    var sending = false;

    Future<void> send(StateSetter setModalState, String value) async {
      final text = value.trim();
      if (text.isEmpty || sending) return;
      setModalState(() {
        sending = true;
        messages.add(_GuideChatMessage(role: 'user', content: text));
      });
      _appendGuideMessage('user', text);
      input.clear();

      try {
        final result = await _guideService.chat(
          message: text,
          scene: 'home',
          clientContext: _buildGuideClientContext(),
        );
        final reply =
            result.reply.trim().isNotEmpty ? result.reply : guideFallbackReply;
        if (mounted) {
          setState(() => _guideStatus = _GuideConnectionStatus.ready);
        }
        setModalState(() {
          messages.add(
            _GuideChatMessage(
              role: 'assistant',
              content: reply,
              memoryRefCount: result.memoryRefs.length,
            ),
          );
          if (result.quickActions.isNotEmpty) {
            quickActions = result.quickActions.take(3).toList();
          }
          suggestedTask = result.suggestedTask;
          sending = false;
        });
        _appendGuideMessage(
          'assistant',
          reply,
          memoryRefs: result.memoryRefs,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _guideStatus = _statusFromError(e));
        }
        final fallback = guideNetworkFallback;
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
            quickActions: quickActions,
            suggestedTask: suggestedTask,
            inputController: input,
            inputHintText: context.tr(
              'guide.input.hint',
              params: {'name': guideName},
            ),
            sendLabel: context.tr('common.send'),
            retryLabel: context.tr('common.retry'),
            addTaskLabel: context.tr('common.add_task'),
            proposalTitle: context.tr(
              'guide.proposal.title',
              params: {'name': guideName},
            ),
            closeLabel: context.tr('common.close'),
            sending: sending,
            memoryRefsLabelBuilder: (count) => context.tr(
              'guide.memory.refs',
              params: {'count': '$count'},
            ),
            onRetry: _guideStatus == _GuideConnectionStatus.ready
                ? null
                : () => send(
                      setModalState,
                      _quickPrompt(context.tr('guide.quick.today')),
                    ),
            onSubmit: (value) => send(setModalState, value),
            onQuickActionTap: (action) =>
                send(setModalState, _quickPrompt(action)),
            onAddSuggestedTask: suggestedTask == null
                ? null
                : () async {
                    final inserted = await _controller.addGuideSuggestedTask(
                      title: suggestedTask!.title,
                      description: suggestedTask!.description,
                      xpReward: suggestedTask!.xpReward,
                      questTier: suggestedTask!.questTier,
                    );
                    if (!mounted) return;
                    if (inserted != null) {
                      showForestSnackBar(
                        context,
                        context.tr(
                          'guide.added_task',
                          params: {'name': _guideName},
                        ),
                      );
                      setModalState(() => suggestedTask = null);
                    }
                  },
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
    final addTask = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nightTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.opening),
            const SizedBox(height: 8),
            Text(result.followUpQuestion,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
                '${result.suggestedTask.title} (+${result.suggestedTask.xpReward} XP)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(nightKeepOnly),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(nightAddTomorrow),
          ),
        ],
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
        ),
      );
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
      if (result.isQueued && result.requestId != null) {
        showForestSnackBar(context, context.tr('night.upload_queued'));
        await _startMemoryStatusPolling(result.requestId!);
      } else {
        HapticFeedback.lightImpact();
        showForestSnackBar(context, context.tr('night.upload_success'));
        await _triggerNightReflection(uploadRequestId: result.requestId);
      }
    } catch (_) {
      if (mounted) showForestSnackBar(context, context.tr('night.upload_fail'));
    } finally {
      if (mounted) setState(() => _isSyncingMemory = false);
    }
  }

  Future<void> _startMemoryStatusPolling(String requestId) async {
    try {
      final result = await _evermemosService.pollMemoryStatus(
        requestId,
        maxAttempts: 10,
        interval: const Duration(seconds: 3),
      );
      if (!mounted) return;
      if (result.isSuccess) {
        showForestSnackBar(context, context.tr('night.poll_success'));
        await _triggerNightReflection(uploadRequestId: requestId);
      } else {
        showForestSnackBar(context, context.tr('night.poll_pending'));
      }
    } catch (_) {
      if (mounted) showForestSnackBar(context, context.tr('night.poll_fail'));
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
          final insight = _PortraitInsightData.fromPortrait(portrait);
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
                          context.tr('profile.title'),
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
                            Text(
                              context.tr('profile.analysis_title'),
                              style: AppTextStyles.heading2.copyWith(
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    localTheme.backgroundColor.withAlpha(170),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: localTheme.primaryAccentColor
                                      .withAlpha(52),
                                ),
                              ),
                              child: Text(
                                insight.summary,
                                style: AppTextStyles.body.copyWith(height: 1.6),
                              ),
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
                            const SizedBox(height: 16),
                            _PortraitEvaluationSection(
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
    if (ok == true) _controller.deleteAllActiveQuests();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      drawer: AppDrawer(
        questController: _controller,
        onOpenSettings: _openUnifiedSettings,
        onOpenGuide: _openGuidePanel,
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
          context.tr('app.title'),
          style:
              AppTextStyles.heading1.copyWith(color: theme.primaryAccentColor),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final statsLevel = _controller.levelProgress;
              return Padding(
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
                                'Lv.${statsLevel.level} ${statsLevel.title}',
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTopStatChip(
                          icon: Icons.auto_graph_rounded,
                          label: '${_controller.totalXp} XP',
                          color: theme.primaryAccentColor,
                        ),
                        const SizedBox(width: 8),
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
                        backgroundColor: theme.primaryAccentColor.withAlpha(36),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryAccentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          IconButton(
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RewardShopPage(questController: _controller)),
            ),
            icon: const Icon(Icons.shopping_bag_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => InventoryPage(questController: _controller)),
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
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => QuestBoard(
                entries: _controller.timelineEntries,
                quests: _controller.activeQuests,
                isAnalyzing: _controller.isAnalyzing,
                onQuestCompleted: _controller.toggleQuestCompletion,
                onQuestDeleted: _controller.deleteQuest,
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
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => QuickAddBar(
                isLoading: _controller.isAnalyzing,
                onSubmitted: _controller.simulateAIParsing,
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
              label: Text(context.tr('home.event.badge')),
            ),
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

  factory _PortraitInsightData.fromPortrait(GuidePortraitResult portrait) {
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
      summary: summary,
      memoryRefs: portrait.memoryRefs,
      energyScore: energyScore,
      rhythmScore: rhythmScore,
      resilienceScore: resilienceScore,
      awarenessScore: awarenessScore,
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
  required String summary,
  required List<String> memoryRefs,
  required int energyScore,
  required int rhythmScore,
  required int resilienceScore,
  required int awarenessScore,
}) {
  final evaluations = <String>[
    if (energyScore >= 75)
      'AI 觉得你最近是带着推进力在行动，不太像只靠情绪硬撑。'
    else if (energyScore >= 55)
      'AI 觉得你还有行动意愿，但更适合用小步推进，而不是一下把自己拉满。'
    else
      'AI 觉得你现在更需要先回收精力，温和启动会比强推自己更有效。',
    if (rhythmScore >= 72)
      '你的节奏感比较稳，说明你已经在形成“做一点也算前进”的惯性。'
    else if (rhythmScore >= 50)
      '你的节奏正在恢复中，关键不是更拼，而是把重复的小动作守住。'
    else
      '你的节奏还偏散，AI 更建议先固定一个最容易完成的起手动作。',
    if (resilienceScore >= 70)
      '遇到波动时，你有把自己拉回来的能力，这说明恢复力已经在长出来了。'
    else if (resilienceScore >= 48)
      '你有恢复的趋势，但还需要更明显的休息边界和回弹空间。'
    else
      'AI 觉得你最近容易被消耗，先保证恢复感，比继续加任务更重要。',
    if (awarenessScore >= 72)
      '你对自己状态的观察是在线的，这会让你更容易做出适合当下的选择。'
    else if (awarenessScore >= 52)
      '你已经能感知到自己的状态变化，再多一点记录会让判断更稳定。'
    else
      'AI 觉得你还在一边做一边摸索，先把感受说清楚，比追求标准答案更重要。',
  ];

  if (memoryRefs.isNotEmpty) {
    evaluations.add(
      '这次评价参考了 ${memoryRefs.length} 段近期记忆，所以更像一份阶段观察，不是一次性的情绪判断。',
    );
  }
  if (summary.length <= 40) {
    evaluations.add('目前样本还不算多，等你积累更多记录后，评价会更具体也更贴身。');
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

  const _PortraitEvaluationSection({
    required this.insight,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('profile.evaluation_title'),
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

  const _GuideChatMessage({
    required this.role,
    required this.content,
    this.memoryRefCount = 0,
  });
}
