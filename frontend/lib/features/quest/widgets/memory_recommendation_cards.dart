import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';

/// 小忆建议卡片区域
/// 在 QuickAddBar 上方展示记忆驱动的任务推荐，仅当推荐列表非空时显示
/// 点击卡片将 title 预填到任务创建流程
class MemoryRecommendationCards extends StatelessWidget {
  final List<dynamic> recommendations;
  final ValueChanged<String> onTap;

  const MemoryRecommendationCards({
    super.key,
    required this.recommendations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context).extension<QuestTheme>()!;
    return Container(
      color: theme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: theme.primaryAccentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr('home.recommendations.title'),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.primaryAccentColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final rec = recommendations[index];
                return _MemoryRecommendationChip(
                  title: rec.title,
                  reason: rec.reason,
                  accentColor: theme.primaryAccentColor,
                  onTap: () => onTap(rec.title),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张小忆建议卡片
class _MemoryRecommendationChip extends StatelessWidget {
  final String title;
  final String reason;
  final Color accentColor;
  final VoidCallback onTap;

  const _MemoryRecommendationChip({
    required this.title,
    required this.reason,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
