import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/level_engine.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../theme/stats_decorations.dart';
import 'animated_counter.dart';

/// 英雄 XP 卡片 — 页面的情感锚点
/// 展示累计 XP、等级进度条、环形等级进度
class HeroXpCard extends StatelessWidget {
  final int totalXp;
  final LevelProgress levelProgress;
  final Animation<double> animation;
  final bool isCompact;

  const HeroXpCard({
    Key? key,
    required this.totalXp,
    required this.levelProgress,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.0 : 20.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: StatsDecorations.heroCard(),
            child: isCompact ? _buildCompactLayout() : _buildWideLayout(),
          ),
        ),
      ),
    );
  }

  /// 横向布局（≥ 600px）
  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildTextSection()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildProgressRing()),
      ],
    );
  }

  /// 纵向布局（< 600px）
  Widget _buildCompactLayout() {
    return Column(
      children: [
        _buildTextSection(),
        const SizedBox(height: 20),
        SizedBox(height: 120, child: _buildProgressRing()),
      ],
    );
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocaleController.instance.t('stats.hero.total_xp'),
          style: StatsTextStyles.metricLabel.copyWith(
            color: StatsColors.goldDark.withAlpha(160),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedCounter(
              value: totalXp,
              style: StatsTextStyles.heroValue,
            ),
            const SizedBox(width: 4),
            Text(
              'XP',
              style: StatsTextStyles.metricLabel.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: StatsColors.goldPrimary.withAlpha(140),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 等级徽章
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: StatsColors.lavenderTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lv.${levelProgress.level}',
                style: StatsTextStyles.badgeText.copyWith(
                  color: StatsColors.dustyLavender,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                AppLocaleController.instance.t(levelProgress.title),
                style: StatsTextStyles.metricLabel.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 进度条
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: levelProgress.progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: StatsColors.dividerLine,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        StatsColors.dustyLavender,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${levelProgress.currentLevelXp} / ${levelProgress.nextLevelXp} XP',
                      style: StatsTextStyles.chartLabel,
                    ),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: StatsTextStyles.chartLabel,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressRing() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: levelProgress.progress),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            size: const Size(110, 110),
            painter: _LevelRingPainter(
              progress: value,
              level: levelProgress.level,
            ),
          );
        },
      ),
    );
  }
}

/// 等级环形进度绘制器
class _LevelRingPainter extends CustomPainter {
  final double progress;
  final int level;

  _LevelRingPainter({required this.progress, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 7.0;

    // 背景轨道
    final trackPaint = Paint()
      ..color = StatsColors.goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 进度弧
    if (progress > 0.01) {
      final progressPaint = Paint()
        ..color = StatsColors.goldPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // 渐变仅在进度足够大时使用，避免退化渐变异常
      if (progress > 0.05) {
        progressPaint.shader = SweepGradient(
          colors: const [
            StatsColors.dustyLavender,
            StatsColors.goldPrimary,
          ],
          stops: const [0.0, 1.0],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(
            Rect.fromCircle(center: center, radius: radius));
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }

    // 中心等级数字
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$level',
        style: AppTextStyles.withFontFallback(const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: StatsColors.bodyText,
        )),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 2,
      ),
    );

    // "LEVEL" 小字
    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'LEVEL',
        style: AppTextStyles.withFontFallback(const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: StatsColors.subtitleText,
        )),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + textPainter.height / 2 - 4,
      ),
    );
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) =>
      old.progress != progress || old.level != level;
}
