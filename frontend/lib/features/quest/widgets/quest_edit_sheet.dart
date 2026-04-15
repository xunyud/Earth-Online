import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../controllers/quest_controller.dart';
import '../models/quest_node.dart';

class QuestEditSheet extends StatefulWidget {
  final QuestNode quest;
  final QuestDetailsUpdater onUpdateDetails;

  const QuestEditSheet({
    super.key,
    required this.quest,
    required this.onUpdateDetails,
  });

  @override
  State<QuestEditSheet> createState() => _QuestEditSheetState();
}

class _QuestEditSheetState extends State<QuestEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  DateTime? _dueDate;
  int? _dailyDueMinutes;
  double _xp = 5;
  bool _saving = false;

  bool get _isDailyQuest => widget.quest.questTier == 'Daily';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quest.title);
    _descriptionController =
        TextEditingController(text: widget.quest.description ?? '');
    _dueDate = widget.quest.dueDate?.toLocal();
    _dailyDueMinutes = widget.quest.dailyDueMinutes;
    final initialXp = widget.quest.xpReward.clamp(5, 100);
    _xp = initialXp.toDouble();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDueDate = _dueDate;
    final safeInitialDate =
        (currentDueDate != null && currentDueDate.isBefore(today))
            ? today
            : (currentDueDate ?? today);
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: today,
      lastDate: DateTime(2100),
      builder: (context, child) {
        final theme = Theme.of(context).extension<QuestTheme>()!;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: theme.primaryAccentColor,
                  surface: theme.surfaceColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _dueDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickDailyDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyDueMinutes == null
          ? const TimeOfDay(hour: 21, minute: 0)
          : _timeOfDayFromMinutes(_dailyDueMinutes!),
    );
    if (!mounted || picked == null) return;
    setState(() {
      // Daily uses daily_due_minutes instead of due_date.
      _dailyDueMinutes = picked.hour * 60 + picked.minute;
      _dueDate = null;
    });
  }

  Future<void> _save() async {
    if (widget.quest.isCompleted || widget.quest.isReward) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.tr('quest.error.quest_locked')),
        ),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final String? finalDescription = desc.isEmpty ? null : desc;
    final xp = _xp.round();
    try {
      await widget.onUpdateDetails(
        widget.quest.id,
        title: title.isEmpty ? widget.quest.title : title,
        description: finalDescription,
        dueDate: _isDailyQuest ? null : _dueDate?.toUtc(),
        dailyDueMinutes: _isDailyQuest ? _dailyDueMinutes : null,
        xpReward: xp,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final locked = widget.quest.isCompleted || widget.quest.isReward;
    final lockedMsg = widget.quest.isReward
        ? context.tr('quest.edit.locked_reward')
        : context.tr('quest.edit.locked_completed');

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withAlpha(80),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (locked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.shadowColor),
                    ),
                    child: Text(
                      lockedMsg,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  enabled: !locked && !_saving,
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryAccentColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: context.tr('quest.edit.title_hint'),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.shadowColor),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !locked && !_saving,
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: context.tr('quest.edit.description_hint'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_isDailyQuest)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              locked || _saving ? null : _pickDailyDueTime,
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(
                            _dailyDueMinutes == null
                                ? context.tr('quest.edit.daily_due_set')
                                : context.tr(
                                    'quest.edit.daily_due_value',
                                    params: {
                                      'time':
                                          _formatDailyDueMinutes(_dailyDueMinutes!)
                                    },
                                  ),
                            style: AppTextStyles.body.copyWith(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryAccentColor,
                            side:
                                const BorderSide(color: AppColors.shadowColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (_dailyDueMinutes != null) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: locked || _saving
                              ? null
                              : () => setState(() => _dailyDueMinutes = null),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textSecondary,
                          tooltip: context.tr('quest.edit.clear_daily_due'),
                        ),
                      ],
                    ],
                  ),
                if (!_isDailyQuest)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: locked || _saving
                              ? null
                              : (_isDailyQuest
                                  ? _pickDailyDueTime
                                  : _pickDueDate),
                          icon: Icon(
                            _isDailyQuest
                                ? Icons.schedule_rounded
                                : Icons.calendar_today_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _dueDate == null
                                ? context.tr('quest.edit.due_set')
                                : _formatDate(_dueDate!),
                            style: AppTextStyles.body.copyWith(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryAccentColor,
                            side:
                                const BorderSide(color: AppColors.shadowColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (_dueDate != null) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: locked || _saving
                              ? null
                              : () => setState(() => _dueDate = null),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textSecondary,
                          tooltip: context.tr('quest.edit.clear_date'),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.shadowColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('quest.edit.xp_reward'),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.primaryAccentColor.withAlpha(22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_xp.round()} XP',
                              style: AppTextStyles.caption.copyWith(
                                color: theme.primaryAccentColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.primaryAccentColor,
                          thumbColor: theme.primaryAccentColor,
                          overlayColor: theme.primaryAccentColor.withAlpha(24),
                          inactiveTrackColor: AppColors.textHint.withAlpha(50),
                        ),
                        child: Slider(
                          value: _xp,
                          min: 5,
                          max: 100,
                          divisions: 19,
                          onChanged: locked || _saving
                              ? null
                              : (v) => setState(() => _xp = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                locked
                    ? OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryAccentColor,
                          side: const BorderSide(color: AppColors.shadowColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.tr('quest.edit.close'),
                          style: AppTextStyles.button,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryAccentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                context.tr('quest.edit.save'),
                                style: AppTextStyles.button,
                              ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
