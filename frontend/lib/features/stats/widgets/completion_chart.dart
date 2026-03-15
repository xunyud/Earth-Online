import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/stats_data.dart';

/// 任务完成趋势图
/// 周视图（BarChart 7 天） / 月视图（LineChart 30 天），可切换
class CompletionChart extends StatefulWidget {
  final List<DailyStats> stats;

  const CompletionChart({Key? key, required this.stats}) : super(key: key);

  @override
  State<CompletionChart> createState() => _CompletionChartState();
}

class _CompletionChartState extends State<CompletionChart> {
  bool _isWeekView = true; // true=周视图, false=月视图

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题 + 切换按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '任务完成趋势',
                style: AppTextStyles.heading2.copyWith(
                  color: theme.primaryAccentColor,
                ),
              ),
              const Spacer(),
              _ToggleChip(
                label: '周',
                isSelected: _isWeekView,
                color: theme.primaryAccentColor,
                onTap: () => setState(() => _isWeekView = true),
              ),
              const SizedBox(width: 6),
              _ToggleChip(
                label: '月',
                isSelected: !_isWeekView,
                color: theme.primaryAccentColor,
                onTap: () => setState(() => _isWeekView = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 图表
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: _isWeekView
                ? _buildBarChart(theme)
                : _buildLineChart(theme),
          ),
        ),
      ],
    );
  }

  /// 获取最近 N 天的数据（补齐空日期）
  List<DailyStats> _recentDays(int days) {
    final now = DateTime.now();
    final result = <DailyStats>[];
    final map = <String, DailyStats>{};
    for (final s in widget.stats) {
      final key = '${s.date.month}-${s.date.day}';
      map[key] = s;
    }
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

  /// 周视图柱状图（7 天）
  Widget _buildBarChart(QuestTheme theme) {
    final data = _recentDays(7);
    final maxY = data.fold<int>(0, (m, s) => s.completedCount > m ? s.completedCount : m);
    final ceilY = (maxY < 5 ? 5 : maxY + 1).toDouble();

    return BarChart(
      BarChartData(
        maxY: ceilY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = data[group.x.toInt()];
              return BarTooltipItem(
                '${s.completedCount}',
                AppTextStyles.caption.copyWith(
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.w700,
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
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
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
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                final d = data[idx].date;
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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.textHint.withAlpha(40),
            strokeWidth: 0.8,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final s = data[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.completedCount.toDouble(),
                width: 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                color: s.isPerfect
                    ? const Color(0xFFFFD54F) // 完美日用金色
                    : theme.primaryAccentColor.withAlpha(200),
              ),
            ],
            // 完美日在柱子上方显示星标
            showingTooltipIndicators: s.isPerfect ? [0] : [],
          );
        }),
      ),
    );
  }

  /// 月视图折线图（30 天）
  Widget _buildLineChart(QuestTheme theme) {
    final data = _recentDays(30);
    final maxY = data.fold<int>(0, (m, s) => s.completedCount > m ? s.completedCount : m);
    final ceilY = (maxY < 5 ? 5 : maxY + 1).toDouble();

    return LineChart(
      LineChartData(
        maxY: ceilY,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final d = data[s.x.toInt()];
              return LineTooltipItem(
                '${d.date.month}/${d.date.day}: ${d.completedCount}',
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
              reservedSize: 28,
              interval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text(
                    '${value.toInt()}',
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
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
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                final d = data[idx].date;
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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceilY > 10 ? (ceilY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.textHint.withAlpha(40),
            strokeWidth: 0.8,
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
            color: theme.primaryAccentColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.primaryAccentColor.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }
}

/// 切换小标签
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.textHint.withAlpha(80),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
