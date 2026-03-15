import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/stats_data.dart';

/// 任务分类饼图（环形图）
class TierPieChart extends StatelessWidget {
  final List<TierCount> tiers;

  const TierPieChart({Key? key, required this.tiers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    if (tiers.isEmpty) return const SizedBox.shrink();

    final total = tiers.fold<int>(0, (s, t) => s + t.count);
    if (total == 0) return const SizedBox.shrink();

    // 按 tier 映射颜色和中文名称
    final colorMap = {
      'Main_Quest': theme.mainQuestColor,
      'Side_Quest': theme.sideQuestColor,
      'Daily': theme.dailyQuestColor,
    };
    final nameMap = {
      'Main_Quest': '主线任务',
      'Side_Quest': '支线任务',
      'Daily': '日常任务',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '任务分类统计',
            style: AppTextStyles.heading2.copyWith(
              color: theme.primaryAccentColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              // 饼图
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    sections: tiers.map((t) {
                      final color = colorMap[t.tier] ?? AppColors.textHint;
                      final pct = (t.count / total * 100).toStringAsFixed(0);
                      return PieChartSectionData(
                        value: t.count.toDouble(),
                        color: color,
                        radius: 50,
                        title: '$pct%',
                        titleStyle: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pureWhite,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // 图例
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiers.map((t) {
                    final color = colorMap[t.tier] ?? AppColors.textHint;
                    final name = nameMap[t.tier] ?? t.tier;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$name (${t.count})',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
