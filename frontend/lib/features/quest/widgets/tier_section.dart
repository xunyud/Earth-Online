import 'package:flutter/material.dart';
import '../models/quest_node.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class TierSection extends StatelessWidget {
  final String title;
  final String questTier;
  final Function(QuestNode quest, String newTier) onQuestDrop;

  const TierSection({
    Key? key,
    required this.title,
    required this.questTier,
    required this.onQuestDrop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    // Icon mapping
    IconData icon;
    switch (questTier) {
      case 'Main_Quest':
        icon = Icons.flag_rounded;
        break;
      case 'Side_Quest':
        icon = Icons.explore_rounded;
        break;
      case 'Daily':
        icon = Icons.calendar_today_rounded;
        break;
      default:
        icon = Icons.circle;
    }

    return DragTarget<QuestNode>(
      onWillAcceptWithDetails: (details) => details.data.questTier != questTier,
      onAcceptWithDetails: (details) => onQuestDrop(details.data, questTier),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isHovering
                ? theme.primaryAccentColor.withAlpha(20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.softBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: theme.primaryAccentColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.heading2.copyWith(
                  color: isHovering
                      ? theme.primaryAccentColor
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (isHovering)
                Text(
                  "Drop to move here",
                  style: AppTextStyles.caption
                      .copyWith(color: theme.primaryAccentColor),
                ),
            ],
          ),
        );
      },
    );
  }
}
