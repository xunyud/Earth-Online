import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../shared/widgets/quest_dialog_shell.dart';
import '../models/quest_node.dart';

/// 快速创建模式
enum QuickCreateMode {
  newMainWithSides,
  attachToExistingMain,
  daily,
}

/// 快速创建对话框结果
class QuickCreateDialogResult {
  final QuickCreateMode mode;
  final String title;
  final List<String> sideTitles;
  final String? parentMainQuestId;
  final int? dailyDueMinutes;

  const QuickCreateDialogResult({
    required this.mode,
    required this.title,
    this.sideTitles = const <String>[],
    this.parentMainQuestId,
    this.dailyDueMinutes,
  });
}

/// 快速创建对话框主体
class QuickCreateDialogBody extends StatefulWidget {
  final List<QuestNode> mainQuestOptions;
  final QuestTheme theme;
  final ValueChanged<QuickCreateDialogResult> onConfirm;
  final VoidCallback onClose;

  const QuickCreateDialogBody({
    super.key,
    required this.mainQuestOptions,
    required this.theme,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  State<QuickCreateDialogBody> createState() => _QuickCreateDialogBodyState();
}

class _QuickCreateDialogBodyState extends State<QuickCreateDialogBody> {
  QuickCreateMode _selectedMode = QuickCreateMode.newMainWithSides;
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

  void _setMode(QuickCreateMode mode) {
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
      case QuickCreateMode.newMainWithSides:
        return _mainTitleController.text.trim().isNotEmpty;
      case QuickCreateMode.attachToExistingMain:
        return _attachSideTitleController.text.trim().isNotEmpty &&
            _selectedParentMainQuestId != null &&
            widget.mainQuestOptions.isNotEmpty;
      case QuickCreateMode.daily:
        return _dailyTitleController.text.trim().isNotEmpty;
    }
  }

  String get _confirmLabel {
    switch (_selectedMode) {
      case QuickCreateMode.newMainWithSides:
        return _normalizedSideTitles.isEmpty
            ? context.tr('quick_add.create.tier_main')
            : context.tr('quick_add.dialog.mode.new_main.title');
      case QuickCreateMode.attachToExistingMain:
        return context.tr('quick_add.create.tier_side');
      case QuickCreateMode.daily:
        return context.tr('quick_add.dialog.mode.daily.title');
    }
  }

  IconData get _confirmIcon {
    switch (_selectedMode) {
      case QuickCreateMode.newMainWithSides:
        return Icons.account_tree_rounded;
      case QuickCreateMode.attachToExistingMain:
        return Icons.call_split_rounded;
      case QuickCreateMode.daily:
        return Icons.schedule_rounded;
    }
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    FocusScope.of(context).unfocus();
    switch (_selectedMode) {
      case QuickCreateMode.newMainWithSides:
        widget.onConfirm(
          QuickCreateDialogResult(
            mode: QuickCreateMode.newMainWithSides,
            title: _mainTitleController.text.trim(),
            sideTitles: _normalizedSideTitles,
          ),
        );
      case QuickCreateMode.attachToExistingMain:
        widget.onConfirm(
          QuickCreateDialogResult(
            mode: QuickCreateMode.attachToExistingMain,
            title: _attachSideTitleController.text.trim(),
            parentMainQuestId: _selectedParentMainQuestId,
          ),
        );
      case QuickCreateMode.daily:
        widget.onConfirm(
          QuickCreateDialogResult(
            mode: QuickCreateMode.daily,
            title: _dailyTitleController.text.trim(),
            dailyDueMinutes: _dailyDueMinutes,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeCards = <({
      QuickCreateMode mode,
      String title,
      String description,
      IconData icon,
      Color color,
    })>[
      (
        mode: QuickCreateMode.newMainWithSides,
        title: context.tr('quick_add.dialog.mode.new_main.title'),
        description: context.tr('quick_add.dialog.mode.new_main.description'),
        icon: Icons.account_tree_rounded,
        color: widget.theme.mainQuestColor,
      ),
      (
        mode: QuickCreateMode.attachToExistingMain,
        title: context.tr('quick_add.dialog.mode.attach.title'),
        description: context.tr('quick_add.dialog.mode.attach.description'),
        icon: Icons.call_split_rounded,
        color: widget.theme.sideQuestColor,
      ),
      (
        mode: QuickCreateMode.daily,
        title: context.tr('quick_add.dialog.mode.daily.title'),
        description: context.tr('quick_add.dialog.mode.daily.description'),
        icon: Icons.wb_sunny_rounded,
        color: widget.theme.dailyQuestColor,
      ),
    ];
    final activeColor = switch (_selectedMode) {
      QuickCreateMode.newMainWithSides => widget.theme.mainQuestColor,
      QuickCreateMode.attachToExistingMain => widget.theme.sideQuestColor,
      QuickCreateMode.daily => widget.theme.dailyQuestColor,
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
              QuickCreateMode.newMainWithSides =>
                _buildNewMainWithSidesPanel(activeColor),
              QuickCreateMode.attachToExistingMain =>
                _buildAttachToExistingMainPanel(activeColor),
              QuickCreateMode.daily => _buildDailyPanel(activeColor),
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
