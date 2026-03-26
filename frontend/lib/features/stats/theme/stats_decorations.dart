import 'package:flutter/material.dart';
import 'stats_colors.dart';

/// 成长仪表盘可复用装饰预设
class StatsDecorations {
  /// 标准卡片装饰
  static BoxDecoration card({Color? color}) => BoxDecoration(
        color: color ?? StatsColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
      );

  /// 英雄卡片装饰（金色渐变）
  static BoxDecoration heroCard() => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StatsColors.goldLight,
            StatsColors.cardSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
      );

  /// 图表容器装饰
  static BoxDecoration chartContainer() => BoxDecoration(
        color: StatsColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: StatsColors.dividerLine,
          width: 1,
        ),
      );
}
