import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../shared/widgets/quest_dialog_shell.dart';

/// 夜间反思对话框返回结果，携带用户选择和可选的回复文本。
class NightReflectionDialogResult {
  /// true = 加入明日任务，false = 仅记录
  final bool addTask;

  /// 用户对 follow_up_question 的回复文本（可为空）
  final String replyText;

  const NightReflectionDialogResult({
    required this.addTask,
    this.replyText = '',
  });
}

class NightReflectionDialog extends StatefulWidget {
  final String title;
  final String opening;
  final String followUpQuestion;
  final String suggestedTaskTitle;
  final int xpReward;
  final String keepOnlyLabel;
  final String addTomorrowLabel;

  const NightReflectionDialog({
    super.key,
    required this.title,
    required this.opening,
    required this.followUpQuestion,
    required this.suggestedTaskTitle,
    required this.xpReward,
    required this.keepOnlyLabel,
    required this.addTomorrowLabel,
  });

  @override
  State<NightReflectionDialog> createState() => _NightReflectionDialogState();
}

class _NightReflectionDialogState extends State<NightReflectionDialog> {
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _pop(bool addTask) {
    Navigator.of(context).pop(
      NightReflectionDialogResult(
        addTask: addTask,
        replyText: _replyController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<QuestTheme>() ?? QuestTheme.freshBreath();
    const accent = Color(0xFF7762C5);

    return QuestDialogShell(
      title: widget.title,
      subtitle: context.tr('night.dialog.subtitle'),
      maxWidth: 980,
      scrollable: true,
      accentColor: accent,
      leading: const QuestDialogBadge(
        icon: Icons.nights_stay_rounded,
        accentColor: Color(0xFF7762C5),
      ),
      onClose: () => _pop(false),
      actions: [
        QuestDialogSecondaryButton(
          label: widget.keepOnlyLabel,
          icon: Icons.bookmark_border_rounded,
          onPressed: () => _pop(false),
        ),
        QuestDialogPrimaryButton(
          label: widget.addTomorrowLabel,
          icon: Icons.arrow_forward_rounded,
          onPressed: () => _pop(true),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestDialogInfoCard(
            label: context.tr('night.dialog.review_label'),
            icon: Icons.local_fire_department_rounded,
            accentColor: accent,
            child: Text(
              widget.opening,
              style: AppTextStyles.body.copyWith(
                height: 1.65,
                color: const Color(0xFF322B45),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF8F5FF),
                  Color.lerp(theme.surfaceColor, accent, 0.08)!,
                ],
              ),
              border: Border.all(color: accent.withAlpha(36)),
            ),
            child: Text(
              widget.followUpQuestion,
              style: AppTextStyles.heading2.copyWith(
                fontSize: 22,
                height: 1.45,
                color: const Color(0xFF29203D),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 用户回复输入框：回复 follow_up_question
          TextField(
            controller: _replyController,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: context.tr('night.dialog.reply_hint'),
              hintStyle: AppTextStyles.body.copyWith(
                color: const Color(0xFF9E95B0),
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(180),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: accent.withAlpha(34)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: accent.withAlpha(34)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: accent, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          QuestDialogInfoCard(
            label: context.tr('night.dialog.tomorrow_label'),
            icon: Icons.wb_twilight_rounded,
            accentColor: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.suggestedTaskTitle,
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 20,
                    color: const Color(0xFF2E2640),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(196),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withAlpha(28)),
                  ),
                  child: Text(
                    '+${widget.xpReward} XP',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
