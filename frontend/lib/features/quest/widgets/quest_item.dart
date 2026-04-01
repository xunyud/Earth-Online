import 'package:flutter/material.dart';
import '../models/quest_node.dart';
import '../controllers/quest_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/snackbar_utils.dart';
import 'quest_edit_sheet.dart';

class QuestItem extends StatefulWidget {
  final QuestNode quest;
  final List<QuestNode> quests;
  final ValueChanged<QuestNode> onCompleted;
  final QuestDetailsUpdater onUpdateDetails;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleExpanded;
  final Widget? dragHandle;

  const QuestItem({
    Key? key,
    required this.quest,
    required this.quests,
    required this.onCompleted,
    required this.onUpdateDetails,
    this.onDelete,
    this.onToggleExpanded,
    this.dragHandle,
  }) : super(key: key);

  @override
  State<QuestItem> createState() => _QuestItemState();
}

class _QuestItemState extends State<QuestItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false; // For hover effect

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _handleCompletion(bool? value) async {
    // If value is true (checking), play animation then callback
    // If value is false (unchecking), just callback (or play reverse if desired)
    if (value == true) {
      await _controller.forward();
      await _controller.reverse();
    }
    // We trigger the callback regardless of true/false to toggle state
    widget.onCompleted(widget.quest);
  }

  String _formatShortDate(DateTime date) {
    final local = date.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  String _formatDailyDueMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _openEditSheet() async {
    if (widget.quest.isReward) {
      showForestSnackBar(context, '🎁 这是一个奖励任务，尽情享受吧，不可编辑。');
      return;
    }
    if (widget.quest.isCompleted) {
      showForestSnackBar(context, '已完成的任务无法修改，请先撤销完成状态。');
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return QuestEditSheet(
          quest: widget.quest,
          onUpdateDetails: widget.onUpdateDetails,
        );
      },
    );
  }

  Color _tierBorderColor(QuestTheme theme) {
    switch (widget.quest.questTier) {
      case 'Main_Quest':
        return theme.mainQuestColor;
      case 'Side_Quest':
        return theme.sideQuestColor;
      default:
        return theme.dailyQuestColor;
    }
  }

  Color _tierGlowColor() {
    switch (widget.quest.questTier) {
      case 'Main_Quest':
        return AppColors.mainQuestGlow;
      case 'Side_Quest':
        return AppColors.sideQuestGlow;
      default:
        return AppColors.dailyQuestGlow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    final hasChildren = widget.quests.any((q) => q.parentId == widget.quest.id);

    final tierBorderColor = _tierBorderColor(theme);
    final tierGlowColor = _tierGlowColor();
    final activeColor = tierBorderColor;

    final trailingWidgets = <Widget>[];
    if (widget.onToggleExpanded != null && hasChildren) {
      trailingWidgets.add(
        IconButton(
          icon: Icon(
            widget.quest.isExpanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            color: AppColors.textSecondary,
          ),
          onPressed: widget.onToggleExpanded,
        ),
      );
    }
    if (widget.onDelete != null) {
      trailingWidgets.add(
        IconButton(
          onPressed: widget.onDelete,
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.errorRed,
        ),
      );
    }
    if (widget.dragHandle != null) {
      trailingWidgets.add(widget.dragHandle!);
    }

    Widget cardContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Opacity(
        // Visual State: Dim if completed
        opacity: widget.quest.isCompleted ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0,
            _isHovering && !widget.quest.isCompleted ? -4 : 0,
            0,
          ),
          margin: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 0), // Removed horizontal margin handled by board
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: _isHovering && !widget.quest.isCompleted ? 18 : 8,
                offset: _isHovering && !widget.quest.isCompleted
                    ? const Offset(0, 8)
                    : const Offset(0, 2),
              ),
              BoxShadow(
                color: tierGlowColor.withValues(
                  alpha: widget.quest.isCompleted
                      ? 0.08
                      : (_isHovering ? 0.22 : 0.14),
                ),
                blurRadius: _isHovering ? 14 : 9,
                spreadRadius: _isHovering ? 1 : 0,
              ),
            ],
            border: Border.all(
              color: widget.quest.isCompleted
                  ? tierBorderColor.withValues(alpha: 0.45)
                  : tierBorderColor.withValues(
                      alpha: _isHovering ? 0.95 : 0.8,
                    ),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _handleCompletion(!widget.quest.isCompleted),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.quest.isCompleted
                            ? activeColor
                            : Colors.transparent,
                        border: Border.all(
                          color: widget.quest.isCompleted
                              ? activeColor
                              : AppColors.textHint,
                          width: 2,
                        ),
                      ),
                      child: widget.quest.isCompleted
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _openEditSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.quest.title,
                            style: theme.questTitleStyle.copyWith(
                              decoration: widget.quest.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textHint,
                              color: widget.quest.isCompleted
                                  ? AppColors.textHint
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final descriptionPreview =
                                  (widget.quest.description ?? '').trim();
                              final hasDescription =
                                  descriptionPreview.isNotEmpty;

                              final now = DateTime.now();
                              final today =
                                  DateTime(now.year, now.month, now.day);
                              final currentMinutes = now.hour * 60 + now.minute;
                              // Daily displays daily_due_minutes instead of due_date.
                              final dailyDueMinutes =
                                  widget.quest.questTier == 'Daily'
                                      ? widget.quest.dailyDueMinutes
                                      : null;

                              final dueLocal = widget.quest.dueDate?.toLocal();
                              final dueDay = dueLocal == null
                                  ? null
                                  : DateTime(
                                      dueLocal.year,
                                      dueLocal.month,
                                      dueLocal.day,
                                    );

                              final isOverdueOrToday = dueDay == null
                                  ? false
                                  : !dueDay.isAfter(today);
                              final isDailyDuePassed = dailyDueMinutes == null
                                  ? false
                                  : currentMinutes >= dailyDueMinutes;

                              final dueColor = widget.quest.isCompleted
                                  ? AppColors.textHint
                                  : ((dailyDueMinutes != null
                                          ? isDailyDuePassed
                                          : isOverdueOrToday)
                                      ? AppColors.errorRed
                                      : AppColors.textHint);

                              final metaStyle = AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              );

                              final notePreview = descriptionPreview.length <=
                                      18
                                  ? descriptionPreview
                                  : '${descriptionPreview.substring(0, 18)}…';

                              return Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.quest.xpReward} XP',
                                        style: metaStyle,
                                      ),
                                    ],
                                  ),
                                  if (dailyDueMinutes != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 14,
                                          color: dueColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDailyDueMinutes(
                                              dailyDueMinutes),
                                          style: metaStyle.copyWith(
                                              color: dueColor),
                                        ),
                                      ],
                                    ),
                                  if (dailyDueMinutes == null && dueDay != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: dueColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatShortDate(dueDay),
                                          style: metaStyle.copyWith(
                                              color: dueColor),
                                        ),
                                      ],
                                    ),
                                  if (hasDescription)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 180,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.subject_rounded,
                                            size: 14,
                                            color: AppColors.textHint,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              notePreview,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: metaStyle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (trailingWidgets.isNotEmpty)
                  Row(
                      mainAxisSize: MainAxisSize.min,
                      children: trailingWidgets),
              ],
            ),
          ),
        ),
      ),
    );

    return cardContent;
  }
}
