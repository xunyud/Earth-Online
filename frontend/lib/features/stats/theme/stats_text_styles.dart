import 'package:flutter/material.dart';
import 'stats_colors.dart';

/// 成长仪表盘专属字体样式
class StatsTextStyles {
  // 英雄数值（XP 总量等大数字）
  static const TextStyle heroValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: StatsColors.goldPrimary,
  );

  // 指标卡数值
  static const TextStyle metricValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: StatsColors.bodyText,
  );

  // 指标卡标签
  static const TextStyle metricLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: StatsColors.subtitleText,
  );

  // 区域标题
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: StatsColors.bodyText,
  );

  // 图表轴标签
  static const TextStyle chartLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: StatsColors.subtitleText,
  );

  // 激励文案
  static const TextStyle insightBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: StatsColors.bodyText,
  );

  // 徽章文字
  static const TextStyle badgeText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: StatsColors.goldPrimary,
  );
}
