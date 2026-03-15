import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/stats_data.dart';

/// XP 累积曲线图（30 天）
/// 附带等级门槛横虚线
class XpCurveChart extends StatelessWidget {
  final List<XpDayPoint> points;
  final int totalXpBefore; // 30 天前的累积 XP 基准值

  const XpCurveChart({
    Key? key,
    required this.points,
    this.totalXpBefore = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    if (points.isEmpty) return const SizedBox.shrink();

    // 计算 Y 轴范围
    final minXp = totalXpBefore.toDouble();
    final maxXp = points.last.cumulativeXp.toDouble() + totalXpBefore;
    final yRange = maxXp - minXp;
    final ceilY = maxXp + (yRange * 0.1).clamp(50, 500);

    // 等级门槛线（找出 Y 轴范围内的等级阈值）
    final thresholdLines = _levelThresholds(minXp, ceilY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'XP 成长曲线',
            style: AppTextStyles.heading2.copyWith(
              color: theme.primaryAccentColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: LineChart(
              LineChartData(
                minY: minXp,
                maxY: ceilY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      if (idx < 0 || idx >= points.length) {
                        return null;
                      }
                      final p = points[idx];
                      final absXp = p.cumulativeXp + totalXpBefore;
                      return LineTooltipItem(
                        '${p.date.month}/${p.date.day}\n$absXp XP',
                        AppTextStyles.caption.copyWith(
                          color: AppColors.pureWhite,
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatXp(value.toInt()),
                          style: AppTextStyles.caption.copyWith(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.textHint.withAlpha(30),
                    strokeWidth: 0.6,
                  ),
                ),
                borderData: FlBorderData(show: false),
                // 等级门槛虚线
                extraLinesData: ExtraLinesData(
                  horizontalLines: thresholdLines
                      .map((t) => HorizontalLine(
                            y: t.xp.toDouble(),
                            color: theme.sideQuestColor.withAlpha(80),
                            strokeWidth: 1,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 4, bottom: 2),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                color: theme.sideQuestColor,
                              ),
                              labelResolver: (_) => 'Lv.${t.level}',
                            ),
                          ))
                      .toList(),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      points.length,
                      (i) => FlSpot(
                        i.toDouble(),
                        points[i].cumulativeXp.toDouble() + totalXpBefore,
                      ),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.2,
                    preventCurveOverShooting: true,
                    color: const Color(0xFFFFB74D), // 温暖金色
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFFB74D).withAlpha(50),
                          const Color(0xFFFFB74D).withAlpha(5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 计算 Y 轴范围内的等级阈值
  List<_LevelThreshold> _levelThresholds(double minY, double maxY) {
    final results = <_LevelThreshold>[];
    // 遍历可能涉及的等级（最多到 100 级）
    int cumulativeXp = 0;
    for (int level = 1; level <= 100; level++) {
      final needed = (500 * _pow(1.2, level - 1)).toInt();
      cumulativeXp += needed;
      if (cumulativeXp > maxY) break;
      if (cumulativeXp >= minY && cumulativeXp <= maxY) {
        results.add(_LevelThreshold(level: level + 1, xp: cumulativeXp));
      }
    }
    // 最多显示 5 条线避免过于密集
    if (results.length > 5) {
      final step = results.length ~/ 5;
      return [for (int i = 0; i < results.length; i += step) results[i]];
    }
    return results;
  }

  double _pow(double base, int exp) {
    double r = 1;
    for (int i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }

  String _formatXp(int xp) {
    if (xp >= 10000) return '${(xp / 1000).toStringAsFixed(0)}k';
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}k';
    return '$xp';
  }
}

class _LevelThreshold {
  final int level;
  final int xp;
  const _LevelThreshold({required this.level, required this.xp});
}
