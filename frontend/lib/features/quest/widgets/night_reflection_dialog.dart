import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../shared/widgets/quest_dialog_shell.dart';

class NightReflectionDialog extends StatelessWidget {
  final String title;
  final String opening;
  final String followUpQuestion;
  final String suggestedTaskTitle;
  final int xpReward;
  final String keepOnlyLabel;
  final String addTomorrowLabel;
  final VoidCallback onKeepOnly;
  final VoidCallback onAddTomorrow;

  const NightReflectionDialog({
    super.key,
    required this.title,
    required this.opening,
    required this.followUpQuestion,
    required this.suggestedTaskTitle,
    required this.xpReward,
    required this.keepOnlyLabel,
    required this.addTomorrowLabel,
    required this.onKeepOnly,
    required this.onAddTomorrow,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<QuestTheme>() ?? QuestTheme.freshBreath();
    const accent = Color(0xFF7762C5);

    return QuestDialogShell(
      title: title,
      subtitle: '把今天的完成感收回来一点，再决定要不要给明天留一个起步动作。',
      maxWidth: 980,
      scrollable: true,
      accentColor: accent,
      leading: const QuestDialogBadge(
        icon: Icons.nights_stay_rounded,
        accentColor: Color(0xFF7762C5),
      ),
      onClose: onKeepOnly,
      actions: [
        QuestDialogSecondaryButton(
          label: keepOnlyLabel,
          icon: Icons.bookmark_border_rounded,
          onPressed: onKeepOnly,
        ),
        QuestDialogPrimaryButton(
          label: addTomorrowLabel,
          icon: Icons.arrow_forward_rounded,
          onPressed: onAddTomorrow,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestDialogInfoCard(
            label: '今晚复盘',
            icon: Icons.local_fire_department_rounded,
            accentColor: accent,
            child: Text(
              opening,
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
              followUpQuestion,
              style: AppTextStyles.heading2.copyWith(
                fontSize: 22,
                height: 1.45,
                color: const Color(0xFF29203D),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          QuestDialogInfoCard(
            label: '如果你想顺手留给明天',
            icon: Icons.wb_twilight_rounded,
            accentColor: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestedTaskTitle,
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
                    '+$xpReward XP',
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
