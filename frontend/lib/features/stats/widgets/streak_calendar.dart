import 'package:flutter/material.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../theme/stats_decorations.dart';
import '../controllers/stats_controller.dart';

/// 签到日历 — 展示最近 30 天签到状态 + 补签交互
class StreakCalendar extends StatelessWidget {
  final StatsController controller;
  final Animation<double> animation;
  final bool isCompact;

  const StreakCalendar({
    Key? key,
    required this.controller,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padding = isCompact ? 16.0 : 20.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 生成最近 30 天的日期列表（从 29 天前到今天）
    final days = List.generate(30, (i) {
      return today.subtract(Duration(days: 29 - i));
    });

    final checkedIn = controller.checkedInDates;
    final currentGold = controller.questController.currentGold;

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
                // 标题行
                Row(
                  children: [
                    Text('签到日历', style: StatsTextStyles.sectionTitle),
                    const Spacer(),
                    // 补签价格提示
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: StatsColors.goldLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on_rounded,
                              size: 13, color: StatsColors.goldPrimary),
                          const SizedBox(width: 3),
                          Text(
                            '补签 50/天',
                            style: StatsTextStyles.badgeText.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 月份标签
                Text(
                  '${days.first.month}月${days.first.day}日 - ${days.last.month}月${days.last.day}日',
                  style: StatsTextStyles.chartLabel,
                ),
                const SizedBox(height: 14),
                // 星期表头
                _buildWeekdayHeader(),
                const SizedBox(height: 6),
                // 日期网格
                _buildCalendarGrid(context, days, today, checkedIn, currentGold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: weekdays.map((d) {
        return Expanded(
          child: Center(
            child: Text(
              d,
              style: StatsTextStyles.chartLabel.copyWith(fontSize: 11),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    List<DateTime> days,
    DateTime today,
    Set<DateTime> checkedIn,
    int currentGold,
  ) {
    // 计算第一天是周几（1=周一, 7=周日）
    final firstWeekday = days.first.weekday;
    // 前面补空白
    final leadingBlanks = firstWeekday - 1;
    final totalCells = leadingBlanks + days.length;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row < rows - 1 ? 4.0 : 0),
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col - leadingBlanks;
              if (cellIndex < 0 || cellIndex >= days.length) {
                return const Expanded(child: SizedBox(height: 36));
              }
              final date = days[cellIndex];
              final isToday = date == today;
              final isChecked = checkedIn.contains(date);
              final canMakeup = !isToday && !isChecked;

              return Expanded(
                child: GestureDetector(
                  onTap: canMakeup
                      ? () => _showMakeupDialog(context, date, currentGold)
                      : null,
                  child: _CalendarCell(
                    day: date.day,
                    isToday: isToday,
                    isChecked: isChecked,
                    canMakeup: canMakeup,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  void _showMakeupDialog(BuildContext ctx, DateTime date, int gold) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        backgroundColor: StatsColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('补签确认', style: StatsTextStyles.sectionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '补签 ${date.month}月${date.day}日',
              style: StatsTextStyles.insightBody,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.monetization_on_rounded,
                    size: 16, color: StatsColors.goldPrimary),
                const SizedBox(width: 4),
                Text(
                  '花费 50 金币',
                  style: StatsTextStyles.insightBody.copyWith(
                    color: StatsColors.goldPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '余额 $gold',
                  style: StatsTextStyles.chartLabel,
                ),
              ],
            ),
            if (gold < 50) ...[
              const SizedBox(height: 8),
              Text(
                '金币不足',
                style: StatsTextStyles.chartLabel.copyWith(
                  color: Colors.redAccent,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: StatsColors.subtitleText),
            ),
          ),
          TextButton(
            onPressed: gold >= 50
                ? () {
                    Navigator.pop(context);
                    _doMakeup(ctx, date);
                  }
                : null,
            child: Text(
              '确认补签',
              style: TextStyle(
                color: gold >= 50
                    ? StatsColors.goldPrimary
                    : StatsColors.subtitleText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _doMakeup(BuildContext ctx, DateTime date) async {
    final result = await controller.makeupCheckin(date);
    if (!ctx.mounted) return;

    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? StatsColors.softSage : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 日历单元格
class _CalendarCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isChecked;
  final bool canMakeup;

  const _CalendarCell({
    required this.day,
    required this.isToday,
    required this.isChecked,
    required this.canMakeup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isChecked
            ? StatsColors.sageTint
            : canMakeup
                ? StatsColors.gridLine.withAlpha(80)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: StatsColors.goldPrimary, width: 1.5)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 日期数字
          Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isChecked
                  ? StatsColors.softSage
                  : isToday
                      ? StatsColors.goldPrimary
                      : StatsColors.bodyText,
            ),
          ),
          // 已签到指示点
          if (isChecked)
            Positioned(
              bottom: 3,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: StatsColors.softSage,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          // 可补签金币小图标
          if (canMakeup)
            Positioned(
              top: 2,
              right: 2,
              child: Icon(
                Icons.add_circle_outline_rounded,
                size: 10,
                color: StatsColors.subtitleText.withAlpha(120),
              ),
            ),
        ],
      ),
    );
  }
}
