import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../theme/stats_decorations.dart';
import '../models/stats_data.dart';
import 'segmented_toggle.dart';

/// 任务完成趋势图（卡片包裹版本）
/// 周视图 BarChart 7天 / 月视图 LineChart 30天
class CompletionChart extends StatefulWidget {
  final List<DailyStats> stats;
  final Animation<double> animation;
  final bool isCompact;

  const CompletionChart({
    Key? key,
    required this.stats,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  State<CompletionChart> createState() => _CompletionChartState();
}

class _CompletionChartState extends State<CompletionChart> {
  int _selectedIndex = 0; // 0=周, 1=月

  @override
  Widget build(BuildContext context) {
    final padding = widget.isCompact ? 16.0 : 20.0;

    // 计算微统计数据
    final recent7 = _recentDays(7);
    final avg = recent7.fold<int>(0, (s, d) => s + d.completedCount) / 7;
    final perfectCount =
        widget.stats.where((s) => s.isPerfect).length;

    return FadeTransition(
      opacity: widget.animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(widget.animation),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: StatsDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Text(
                      context.tr('stats.chart.completion_title'),
                      style: StatsTextStyles.sectionTitle,
                    ),
                    const Spacer(),
                    SegmentedToggle(
                      labels: [
                        context.tr('stats.range.7_days'),
                        context.tr('stats.range.30_days'),
                      ],
                      selectedIndex: _selectedIndex,
                      onChanged: (i) => setState(() => _selectedIndex = i),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 图表
                SizedBox(
                  height: widget.isCompact ? 180.0 : 200.0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedIndex == 0
                        ? _buildBarChart(key: const ValueKey('bar'))
                        : _buildLineChart(key: const ValueKey('line')),
                  ),
                ),
                const SizedBox(height: 14),
                // 微统计行
                Row(
                  children: [
                    _MicroStat(
                      label: context.tr('stats.metric.daily_average'),
                      value: avg.toStringAsFixed(1),
                      color: StatsColors.softSage,
                    ),
                    const SizedBox(width: 20),
                    _MicroStat(
                      label: context.tr('stats.metric.perfect_days'),
                      value: '$perfectCount',
                      color: StatsColors.goldPrimary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 获取最近 N 天数据（补齐空日期）
  List<DailyStats> _recentDays(int days) {
    final now = DateTime.now();
    final map = <String, DailyStats>{};
    for (final s in widget.stats) {
      final key = '${s.date.month}-${s.date.day}';
      map[key] = s;
    }
    final result = <DailyStats>[];
    for (int i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.month}-${d.day}';
      result.add(map[key] ??
          DailyStats(
            date: DateTime(d.year, d.month, d.day),
            completedCount: 0,
          ));
    }
    return result;
  }

  /// 周视图柱状图
  Widget _buildBarChart({Key? key}) {
    final data = _recentDays(7);
    final maxY =
        data.fold<int>(0, (m, s) => s.completedCount > m ? s.completedCount : m);
    final ceilY = (maxY < 5 ? 5 : maxY + 1).toDouble();

    return BarChart(
      key: key,
      BarChartData(
        maxY: ceilY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipColor: (_) => StatsColors.cardSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = data[group.x.toInt()];
              return BarTooltipItem(
                context.tr(
                  'stats.task_count',
                  params: {'count': '${s.completedCount}'},
                ),
                StatsTextStyles.chartLabel.copyWith(
                  color: StatsColors.bodyText,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text(
                    '${value.toInt()}',
                    style: StatsTextStyles.chartLabel,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final d = data[idx].date;
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: StatsColors.gridLine,
            strokeWidth: 0.5,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final s = data[i];
          final isPerfect = s.isPerfect;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.completedCount.toDouble(),
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isPerfect
                      ? [
                          StatsColors.goldPrimary,
                          StatsColors.goldPrimary.withAlpha(180),
                        ]
                      : [
                          StatsColors.softSage,
                          StatsColors.softSage.withAlpha(180),
                        ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// 月视图折线图
  Widget _buildLineChart({Key? key}) {
    final data = _recentDays(30);
    final maxY =
        data.fold<int>(0, (m, s) => s.completedCount > m ? s.completedCount : m);
    final ceilY = (maxY < 5 ? 5 : maxY + 1).toDouble();

    return LineChart(
      key: key,
      LineChartData(
        maxY: ceilY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipColor: (_) => StatsColors.cardSurface,
            getTooltipItems: (spots) => spots.map((s) {
              final d = data[s.x.toInt()];
              return LineTooltipItem(
                '${d.date.month}/${d.date.day}: ${d.completedCount}',
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
              reservedSize: 28,
              interval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text(
                    '${value.toInt()}',
                    style: StatsTextStyles.chartLabel,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final d = data[idx].date;
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: StatsColors.gridLine,
            strokeWidth: 0.5,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i].completedCount.toDouble()),
            ),
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: StatsColors.softSage,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  StatsColors.softSage.withAlpha(40),
                  StatsColors.softSage.withAlpha(5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 微统计指标
class _MicroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MicroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: StatsTextStyles.chartLabel,
        ),
        Text(
          value,
          style: StatsTextStyles.chartLabel.copyWith(
            fontWeight: FontWeight.w700,
            color: StatsColors.bodyText,
          ),
        ),
      ],
    );
  }
}
