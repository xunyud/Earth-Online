import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../theme/stats_decorations.dart';
import '../models/stats_data.dart';

/// XP 成长曲线图（卡片包裹版本）
/// 附带等级门槛横虚线和终点脉冲高亮
class XpCurveChart extends StatelessWidget {
  final List<XpDayPoint> points;
  final int totalXpBefore;
  final int recent30DaysXp;
  final Animation<double> animation;
  final bool isCompact;

  const XpCurveChart({
    Key? key,
    required this.points,
    this.totalXpBefore = 0,
    this.recent30DaysXp = 0,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final padding = isCompact ? 16.0 : 20.0;

    // 计算 Y 轴范围（防止 minY == maxY 导致 fl_chart 除零）
    final minXp = totalXpBefore.toDouble();
    final rawMaxXp = points.last.cumulativeXp.toDouble() + totalXpBefore;
    final maxXp = rawMaxXp <= minXp ? minXp + 100 : rawMaxXp;
    final yRange = maxXp - minXp;
    final ceilY = maxXp + (yRange * 0.1).clamp(50, 500);
    final thresholdLines = _levelThresholds(minXp, ceilY);

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
                // 标题行 + XP 徽章
                Row(
                  children: [
                    Text(
                      context.tr('stats.xp_curve_title'),
                      style: StatsTextStyles.sectionTitle,
                    ),
                    const Spacer(),
                    if (recent30DaysXp > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: StatsColors.goldLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+$recent30DaysXp XP',
                          style: StatsTextStyles.badgeText.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: isCompact ? 200.0 : 220.0,
                  child: LineChart(
                    LineChartData(
                      minY: minXp,
                      maxY: ceilY,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          getTooltipColor: (_) => StatsColors.cardSurface,
                          getTooltipItems: (spots) => spots.map((s) {
                            final idx = s.x.toInt();
                            if (idx < 0 || idx >= points.length) return null;
                            final p = points[idx];
                            final absXp = p.cumulativeXp + totalXpBefore;
                            return LineTooltipItem(
                              '${p.date.month}/${p.date.day}\n$absXp XP',
                              StatsTextStyles.chartLabel.copyWith(
                                color: StatsColors.bodyText,
                                fontWeight: FontWeight.w600,
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
                                style: StatsTextStyles.chartLabel,
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
                                  style: StatsTextStyles.chartLabel,
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
                          color: StatsColors.gridLine.withAlpha(120),
                          strokeWidth: 0.5,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      // 等级门槛虚线
                      extraLinesData: ExtraLinesData(
                        horizontalLines: thresholdLines
                            .map((t) => HorizontalLine(
                                  y: t.xp.toDouble(),
                                  color:
                                      StatsColors.dustyLavender.withAlpha(80),
                                  strokeWidth: 1,
                                  dashArray: [6, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(
                                        right: 4, bottom: 2),
                                    style: StatsTextStyles.chartLabel.copyWith(
                                      fontSize: 9,
                                      color: StatsColors.dustyLavender,
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
                              points[i].cumulativeXp.toDouble() +
                                  totalXpBefore,
                            ),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.2,
                          preventCurveOverShooting: true,
                          color: StatsColors.goldPrimary,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) {
                              // 只在最后一个点显示高亮圆点
                              return spot.x ==
                                  barData.spots.last.x;
                            },
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 5,
                                color: StatsColors.goldPrimary,
                                strokeWidth: 3,
                                strokeColor: StatsColors.goldLight,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                StatsColors.goldPrimary.withAlpha(35),
                                StatsColors.goldPrimary.withAlpha(3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 计算 Y 轴范围内的等级阈值
  List<_LevelThreshold> _levelThresholds(double minY, double maxY) {
    final results = <_LevelThreshold>[];
    int cumulativeXp = 0;
    for (int level = 1; level <= 100; level++) {
      final needed = (500 * _pow(1.2, level - 1)).toInt();
      cumulativeXp += needed;
      if (cumulativeXp > maxY) break;
      if (cumulativeXp >= minY && cumulativeXp <= maxY) {
        results.add(_LevelThreshold(level: level + 1, xp: cumulativeXp));
      }
    }
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
