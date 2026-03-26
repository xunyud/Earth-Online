import 'package:flutter/material.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../theme/stats_decorations.dart';
import '../models/stats_data.dart';

/// 三卡横排指标区域
/// 本周完成(绿) / 连续天数(橙) / 最佳一天(金)
class SummaryMetricsRow extends StatelessWidget {
  final HighlightData data;
  final Animation<double> animation;
  final bool isCompact;

  const SummaryMetricsRow({
    Key? key,
    required this.data,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricInfo(
        icon: Icons.check_circle_outline_rounded,
        value: '${data.weeklyCompleted}',
        label: '本周完成',
        accent: StatsColors.softSage,
        tint: StatsColors.sageTint,
      ),
      _MetricInfo(
        icon: Icons.local_fire_department_rounded,
        value: '${data.longestStreak}天',
        label: '连续天数',
        accent: StatsColors.warmCoral,
        tint: StatsColors.coralTint,
      ),
      _MetricInfo(
        icon: Icons.emoji_events_rounded,
        value: data.bestDayCount > 0 ? '${data.bestDayCount}' : '--',
        label: '最佳一天',
        accent: StatsColors.goldPrimary,
        tint: StatsColors.goldLight,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.0 : 20.0),
      child: Row(
        children: List.generate(cards.length * 2 - 1, (i) {
          if (i.isOdd) return const SizedBox(width: 12);
          final cardIndex = i ~/ 2;
          // 交错入场动画
          final delay = cardIndex * 0.08;
          final cardAnimation = CurvedAnimation(
            parent: animation,
            curve: Interval(
              delay,
              delay + 0.5,
              curve: Curves.easeOutCubic,
            ),
          );
          return Expanded(
            child: FadeTransition(
              opacity: cardAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(cardAnimation),
                child: _MetricCard(info: cards[cardIndex]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MetricInfo {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final Color tint;

  const _MetricInfo({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.tint,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricInfo info;

  const _MetricCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: StatsDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标容器
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: info.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(info.icon, size: 20, color: info.accent),
          ),
          const SizedBox(height: 12),
          // 数值
          Text(
            info.value,
            style: StatsTextStyles.metricValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 标签
          Text(
            info.label,
            style: StatsTextStyles.metricLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
