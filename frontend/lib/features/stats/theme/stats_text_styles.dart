import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import 'stats_colors.dart';

/// 成长仪表盘专属字体样式
class StatsTextStyles {
  // 英雄数值（XP 总量等大数字）
  static TextStyle get heroValue => withFallback(
        const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: StatsColors.goldPrimary,
        ),
      );

  // 指标卡数值
  static TextStyle get metricValue => withFallback(
        const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: StatsColors.bodyText,
        ),
      );

  // 指标卡标签
  static TextStyle get metricLabel => withFallback(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: StatsColors.subtitleText,
        ),
      );

  // 区域标题
  static TextStyle get sectionTitle => withFallback(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: StatsColors.bodyText,
        ),
      );

  // 图表轴标签
  static TextStyle get chartLabel => withFallback(
        const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: StatsColors.subtitleText,
        ),
      );

  // 激励文案
  static TextStyle get insightBody => withFallback(
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: StatsColors.bodyText,
        ),
      );

  // 徽章文字
  static TextStyle get badgeText => withFallback(
        const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: StatsColors.goldPrimary,
        ),
      );

  static TextStyle withFallback(TextStyle style) {
    return AppTextStyles.withFontFallback(style);
  }
}
