import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stats widgets use localization keys instead of hardcoded chinese labels', () async {
    final completionChart = await File(
      'lib/features/stats/widgets/completion_chart.dart',
    ).readAsString();
    final statsHeader = await File(
      'lib/features/stats/widgets/stats_header.dart',
    ).readAsString();
    final streakCalendar = await File(
      'lib/features/stats/widgets/streak_calendar.dart',
    ).readAsString();
    final tierMix = await File(
      'lib/features/stats/widgets/tier_pie_chart.dart',
    ).readAsString();
    final xpCurve = await File(
      'lib/features/stats/widgets/xp_curve_chart.dart',
    ).readAsString();

    expect(completionChart, contains("context.tr('stats.chart.completion_title')"));
    expect(completionChart, contains("context.tr('stats.metric.daily_average')"));
    expect(statsHeader, contains("context.tr('stats.dashboard_title')"));
    expect(streakCalendar, contains("context.tr('stats.checkin_calendar_title')"));
    expect(tierMix, contains("context.tr('stats.quest_mix_title')"));
    expect(xpCurve, contains("context.tr('stats.xp_curve_title')"));

    expect(completionChart, isNot(contains("Text('任务完成趋势'")));
    expect(statsHeader, isNot(contains("'成长仪表盘'")));
    expect(streakCalendar, isNot(contains("'签到日历'")));
  });

  test('stats custom text styles explicitly apply font fallback', () async {
    final heroCard = await File(
      'lib/features/stats/widgets/hero_xp_card.dart',
    ).readAsString();
    final segmentedToggle = await File(
      'lib/features/stats/widgets/segmented_toggle.dart',
    ).readAsString();
    final statsHeader = await File(
      'lib/features/stats/widgets/stats_header.dart',
    ).readAsString();
    final streakCalendar = await File(
      'lib/features/stats/widgets/streak_calendar.dart',
    ).readAsString();

    expect(heroCard, contains('AppTextStyles.withFontFallback'));
    expect(segmentedToggle, contains('AppTextStyles.withFontFallback'));
    expect(statsHeader, contains('AppTextStyles.withFontFallback'));
    expect(streakCalendar, contains('AppTextStyles.withFontFallback'));
  });
}
