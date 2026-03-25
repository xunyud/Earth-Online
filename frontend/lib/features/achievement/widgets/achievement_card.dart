import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../models/achievement.dart';

class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final Color categoryColor;

  const AchievementCard({
    Key? key,
    required this.achievement,
    required this.categoryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    final unlocked = achievement.isUnlocked;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDetailDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: unlocked ? categoryColor : Colors.transparent,
              width: 3,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: unlocked
                    ? categoryColor.withAlpha(30)
                    : AppColors.textHint.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                achievement.icon,
                style: TextStyle(
                  fontSize: 24,
                  color: unlocked ? null : AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: unlocked ? null : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: unlocked
                          ? AppColors.textSecondary
                          : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildTargetText(context),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (achievement.xpBonus > 0 || achievement.goldBonus > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      _buildRewardText(context),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFB74D),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: unlocked
                    ? categoryColor.withAlpha(18)
                    : categoryColor.withAlpha(10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _buildProgressText(context),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: unlocked ? categoryColor : AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }

  int _displayProgress() {
    final current = achievement.currentProgress;
    if (current < 0) return 0;
    return current;
  }

  String _buildProgressText(BuildContext context) {
    final current = _displayProgress();
    final target =
        achievement.conditionValue <= 0 ? 1 : achievement.conditionValue;
    switch (achievement.conditionType) {
      case 'total_completed':
        return context.tr(
          'achievement.progress.total_completed',
          params: {'current': '$current', 'target': '$target'},
        );
      case 'streak':
        return context.tr(
          'achievement.progress.streak',
          params: {'current': '$current', 'target': '$target'},
        );
      case 'total_xp':
        return context.tr(
          'achievement.progress.total_xp',
          params: {'current': '$current', 'target': '$target'},
        );
      case 'level':
        return context.tr(
          'achievement.progress.level',
          params: {'current': '$current', 'target': '$target'},
        );
      case 'board_clear':
        return context.tr(
          'achievement.progress.board_clear',
          params: {'current': '$current', 'target': '$target'},
        );
      case 'first_wechat':
        return context.tr(
          'achievement.progress.first_wechat',
          params: {'current': '$current', 'target': '$target'},
        );
      default:
        return '$current/$target';
    }
  }

  String _buildTargetText(BuildContext context) {
    final target = achievement.conditionValue;
    switch (achievement.conditionType) {
      case 'total_completed':
        return context.tr(
          'achievement.target.total_completed',
          params: {'target': '$target'},
        );
      case 'streak':
        return context.tr(
          'achievement.target.streak',
          params: {'target': '$target'},
        );
      case 'total_xp':
        return context.tr(
          'achievement.target.total_xp',
          params: {'target': '$target'},
        );
      case 'level':
        return context.tr(
          'achievement.target.level',
          params: {'target': '$target'},
        );
      case 'board_clear':
        return context.tr('achievement.target.board_clear');
      case 'first_wechat':
        return context.tr('achievement.target.first_wechat');
      default:
        return context.tr('achievement.target.default');
    }
  }

  String _buildTargetValue(BuildContext context) {
    final targetText = _buildTargetText(context);
    return targetText.replaceFirst(RegExp(r'^(目标：|Goal:\s*)'), '');
  }

  String _buildRewardText(BuildContext context) {
    final parts = <String>[
      if (achievement.xpBonus > 0) '+${achievement.xpBonus} XP',
      if (achievement.goldBonus > 0)
        '+${achievement.goldBonus} ${context.tr('home.gold_label')}',
    ];
    return parts.join(' / ');
  }

  Future<void> _showDetailDialog(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'achievement_detail',
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(96),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, _, __) {
        final eased = Curves.easeOutBack.transform(animation.value);
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Transform.scale(
                scale: 0.88 + 0.12 * eased,
                child: Opacity(
                  opacity: animation.value.clamp(0.0, 1.0),
                  child: GestureDetector(
                    onTap: () {},
                    child: _buildDetailCard(dialogContext, theme),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, QuestTheme theme) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: categoryColor.withAlpha(80), width: 2),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withAlpha(30),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(achievement.icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            context.tr('achievement.detail_title'),
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: categoryColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            style: AppTextStyles.heading2.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            context.tr('achievement.status_label'),
            achievement.isUnlocked
                ? context.tr('achievement.status_unlocked')
                : context.tr('achievement.status_locked'),
          ),
          _buildDetailRow(
            context.tr('achievement.progress_label'),
            _buildProgressText(context),
          ),
          _buildDetailRow(
            context.tr('achievement.target_label'),
            _buildTargetValue(context),
          ),
          _buildDetailRow(
            context.tr('achievement.rule_label'),
            achievement.description,
          ),
          if (achievement.unlockedAt != null)
            _buildDetailRow(
              context.tr('achievement.unlocked_at_label'),
              _formatDate(achievement.unlockedAt!),
            ),
          if (achievement.xpBonus > 0 || achievement.goldBonus > 0)
            _buildDetailRow(
              context.tr('achievement.reward_label'),
              _buildRewardText(context).replaceAll('+', ''),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: categoryColor.withAlpha(220),
                  foregroundColor: Colors.white,
                ),
                child: Text(context.tr('achievement.acknowledge')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
