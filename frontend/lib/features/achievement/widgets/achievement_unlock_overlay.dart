import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../models/achievement.dart';

class AchievementUnlockOverlay extends StatefulWidget {
  final int triggerSeq;
  final Achievement? Function() consumeNext;

  const AchievementUnlockOverlay({
    super.key,
    required this.triggerSeq,
    required this.consumeNext,
  });

  @override
  State<AchievementUnlockOverlay> createState() =>
      _AchievementUnlockOverlayState();
}

class _AchievementUnlockOverlayState extends State<AchievementUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Achievement? _current;
  int _lastSeq = 0;
  List<_Particle> _particles = [];

  static const _categoryColors = <String, Color>{
    'quest': Color(0xFF66BB6A),
    'streak': Color(0xFFFFA726),
    'xp': Color(0xFF42A5F5),
    'special': Color(0xFF2E7D32),
  };

  static const _particleColors = [
    Color(0xFFFFD54F),
    Color(0xFFFFCC80),
    Color(0xFFFFAB91),
    Color(0xFFE6B980),
    Color(0xFFF8BBD0),
    Color(0xFFB2DFDB),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _current = null);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _playNext();
        });
      }
    });
    _lastSeq = widget.triggerSeq;
  }

  @override
  void didUpdateWidget(AchievementUnlockOverlay old) {
    super.didUpdateWidget(old);
    if (widget.triggerSeq != _lastSeq) {
      _lastSeq = widget.triggerSeq;
      if (_current == null) _playNext();
    }
  }

  void _playNext() {
    final next = widget.consumeNext();
    if (next == null) return;
    _current = next;
    _generateParticles();
    _controller.forward(from: 0.0);
    if (mounted) setState(() {});
  }

  void _generateParticles() {
    final rng = Random();
    _particles = List.generate(20, (_) {
      return _Particle(
        startX: 0.3 + rng.nextDouble() * 0.4,
        startY: 0.35 + rng.nextDouble() * 0.2,
        driftX: (rng.nextDouble() - 0.5) * 0.4,
        riseY: 0.15 + rng.nextDouble() * 0.25,
        radius: 2.5 + rng.nextDouble() * 3.5,
        color: _particleColors[rng.nextInt(_particleColors.length)],
        delay: rng.nextDouble() * 0.25,
      );
    });
  }

  void _dismiss() {
    _controller.stop();
    setState(() => _current = null);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _playNext();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_current == null) return const SizedBox.shrink();

    final theme = Theme.of(context).extension<QuestTheme>()!;
    final catColor =
        _categoryColors[_current!.category] ?? theme.primaryAccentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        double overlayOpacity;
        if (t < 0.06) {
          overlayOpacity = t / 0.06;
        } else if (t > 0.80) {
          overlayOpacity = 1.0 - ((t - 0.80) / 0.20);
        } else {
          overlayOpacity = 1.0;
        }

        double cardScale;
        double cardOpacity;
        if (t < 0.06) {
          cardScale = 0.0;
          cardOpacity = 0.0;
        } else if (t < 0.22) {
          final st = (t - 0.06) / 0.16;
          cardScale = 0.5 + 0.5 * Curves.easeOutBack.transform(st);
          cardOpacity = st.clamp(0.0, 1.0);
        } else if (t > 0.80) {
          final et = (t - 0.80) / 0.20;
          cardScale = 1.0 - 0.15 * et;
          cardOpacity = 1.0 - et;
        } else {
          cardScale = 1.0;
          cardOpacity = 1.0;
        }

        return GestureDetector(
          onTap: _dismiss,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black
                      .withAlpha((overlayOpacity * 100).round().clamp(0, 255)),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: t,
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: cardOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: cardScale.clamp(0.0, 2.0),
                    child: _buildCard(context, theme, catColor),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, QuestTheme theme, Color catColor) {
    final achievement = _current!;
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: catColor.withAlpha(80), width: 2),
        boxShadow: [
          BoxShadow(
            color: catColor.withAlpha(30),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(achievement.icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            context.tr('achievement.unlocked_badge'),
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: catColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            style: AppTextStyles.heading2.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (achievement.xpBonus > 0 || achievement.goldBonus > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (achievement.xpBonus > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${achievement.xpBonus} XP',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFB74D),
                      ),
                    ),
                  ),
                if (achievement.xpBonus > 0 && achievement.goldBonus > 0)
                  const SizedBox(width: 8),
                if (achievement.goldBonus > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${achievement.goldBonus} ${context.tr('home.gold_label')}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Particle {
  final double startX;
  final double startY;
  final double driftX;
  final double riseY;
  final double radius;
  final double delay;
  final Color color;

  _Particle({
    required this.startX,
    required this.startY,
    required this.driftX,
    required this.riseY,
    required this.radius,
    required this.color,
    required this.delay,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final localProgress =
          ((progress - particle.delay) / (1.0 - particle.delay))
              .clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final eased = Curves.easeOutCubic.transform(localProgress);
      final x = (particle.startX + particle.driftX * eased) * size.width;
      final y = (particle.startY - particle.riseY * eased) * size.height;

      double opacity;
      if (localProgress < 0.15) {
        opacity = localProgress / 0.15;
      } else if (localProgress > 0.6) {
        opacity = 1.0 - ((localProgress - 0.6) / 0.4);
      } else {
        opacity = 1.0;
      }
      opacity = opacity.clamp(0.0, 1.0);

      final radius = particle.radius * (1.0 - localProgress * 0.3);
      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
