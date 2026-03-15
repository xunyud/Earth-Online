import 'package:flutter/material.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
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
                      color:
                          unlocked ? AppColors.textSecondary : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildTargetText(),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (achievement.xpBonus > 0 || achievement.goldBonus > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      _buildRewardText(),
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
                _buildProgressText(),
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

  String _buildProgressText() {
    final current = _displayProgress();
    final target = achievement.conditionValue <= 0 ? 1 : achievement.conditionValue;
    switch (achievement.conditionType) {
      case 'total_completed':
        return '$current/$target 任务';
      case 'streak':
        return '$current/$target 天';
      case 'total_xp':
        return '$current/$target XP';
      case 'level':
        return '$current/$target 级';
      case 'board_clear':
        return '$current/$target 次';
      case 'first_wechat':
        return '$current/$target 次';
      default:
        return '$current/$target';
    }
  }

  String _buildTargetText() {
    final target = achievement.conditionValue;
    switch (achievement.conditionType) {
      case 'total_completed':
        return '目标：累计完成 $target 个任务';
      case 'streak':
        return '目标：连续签到 $target 天';
      case 'total_xp':
        return '目标：累计获得 $target XP';
      case 'level':
        return '目标：达到 $target 级';
      case 'board_clear':
        return '目标：首次清空任务面板';
      case 'first_wechat':
        return '目标：首次通过微信创建任务';
      default:
        return '目标：达到条件';
    }
  }

  String _buildRewardText() {
    final parts = <String>[
      if (achievement.xpBonus > 0) '+${achievement.xpBonus} XP',
      if (achievement.goldBonus > 0) '+${achievement.goldBonus} 金币',
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
            '成就详情',
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
          _buildDetailRow('状态', achievement.isUnlocked ? '已解锁' : '未解锁'),
          _buildDetailRow('当前进度', _buildProgressText()),
          _buildDetailRow('目标', _buildTargetText().replaceFirst('目标：', '')),
          _buildDetailRow('规则说明', achievement.description),
          if (achievement.unlockedAt != null)
            _buildDetailRow('解锁时间', _formatDate(achievement.unlockedAt!)),
          if (achievement.xpBonus > 0 || achievement.goldBonus > 0)
            _buildDetailRow('解锁奖励', _buildRewardText().replaceAll('+', '')),
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
                child: const Text('我知道了'),
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
              '$label：',
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
