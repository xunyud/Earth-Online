import 'package:flutter/material.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../theme/stats_decorations.dart';
import '../models/stats_data.dart';

/// 任务构成 — 横向进度条展示
/// 替代原有的环形饼图，更现代、更易读
class QuestMixCard extends StatelessWidget {
  final List<TierCount> tiers;
  final Animation<double> animation;
  final bool isCompact;

  const QuestMixCard({
    Key? key,
    required this.tiers,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) return const SizedBox.shrink();

    final total = tiers.fold<int>(0, (s, t) => s + t.count);
    if (total == 0) return const SizedBox.shrink();

    final theme = Theme.of(context).extension<QuestTheme>()!;
    final padding = isCompact ? 16.0 : 20.0;

    // 颜色和名称映射
    final colorMap = {
      'Main_Quest': theme.mainQuestColor,
      'Side_Quest': theme.sideQuestColor,
      'Daily': theme.dailyQuestColor,
    };
    final nameMap = {
      'Main_Quest': context.tr('quick_add.create.tier_main'),
      'Side_Quest': context.tr('quick_add.create.tier_side'),
      'Daily': context.tr('quick_add.create.tier_daily'),
    };

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: StatsDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('stats.quest_mix_title'),
                  style: StatsTextStyles.sectionTitle,
                ),
                const SizedBox(height: 16),
                ...tiers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  final color = colorMap[t.tier] ?? StatsColors.subtitleText;
                  final name = nameMap[t.tier] ?? t.tier;
                  final pct = (t.count / total * 100).toStringAsFixed(0);

                  return Padding(
                    padding: EdgeInsets.only(bottom: i < tiers.length - 1 ? 14.0 : 0),
                    child: _QuestMixBar(
                      label: name,
                      count: t.count,
                      percentage: t.count / total,
                      percentLabel: '$pct%',
                      color: color,
                      delay: i * 0.1,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestMixBar extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final String percentLabel;
  final Color color;
  final double delay;

  const _QuestMixBar({
    required this.label,
    required this.count,
    required this.percentage,
    required this.percentLabel,
    required this.color,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: StatsTextStyles.chartLabel.copyWith(
                fontSize: 13,
                color: StatsColors.bodyText,
              ),
            ),
            const Spacer(),
            Text(
              context.tr(
                'stats.quest_mix_count',
                params: {'count': '$count', 'percent': percentLabel},
              ),
              style: StatsTextStyles.chartLabel.copyWith(
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 进度条动画
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: percentage),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // 轨道
                    Container(
                      width: double.infinity,
                      height: 8,
                      color: StatsColors.gridLine,
                    ),
                    // 填充
                    FractionallySizedBox(
                      widthFactor: value.clamp(0, 1),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
