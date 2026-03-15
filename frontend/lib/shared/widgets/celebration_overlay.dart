import 'dart:math';
import 'package:flutter/material.dart';

/// 温暖柔和的庆祝粒子覆盖层
/// 使用 CustomPainter + AnimationController 实现轻量级粒子效果
class CelebrationOverlay extends StatefulWidget {
  /// 触发序列号，每次变化时播放一次动画
  final int triggerSeq;

  const CelebrationOverlay({super.key, required this.triggerSeq});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<_Particle> _particles = [];
  int _lastSeq = 0;

  // 温暖的配色：琥珀、蜜桃、柔金、暖粉
  static const _colors = [
    Color(0xFFFFD54F), // 柔金
    Color(0xFFFFCC80), // 蜜桃
    Color(0xFFFFAB91), // 暖珊瑚
    Color(0xFFE6B980), // 琥珀
    Color(0xFFF8BBD0), // 暖粉
    Color(0xFFB2DFDB), // 淡青（点缀）
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _lastSeq = widget.triggerSeq;
  }

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    if (widget.triggerSeq != _lastSeq && widget.triggerSeq > 0) {
      _lastSeq = widget.triggerSeq;
      _startAnimation();
    }
  }

  void _startAnimation() {
    final rng = Random();
    // 生成 30 个粒子，从屏幕中下方向上飘散
    _particles = List.generate(30, (_) {
      return _Particle(
        // 起始 x：屏幕宽度的 20%~80% 范围
        startX: 0.2 + rng.nextDouble() * 0.6,
        // 起始 y：屏幕下半部分
        startY: 0.5 + rng.nextDouble() * 0.3,
        // 水平漂移量（-0.15 ~ 0.15）
        driftX: (rng.nextDouble() - 0.5) * 0.3,
        // 上升高度（0.3 ~ 0.6）
        riseY: 0.3 + rng.nextDouble() * 0.3,
        // 粒子大小
        radius: 3.0 + rng.nextDouble() * 4.0,
        // 随机颜色
        color: _colors[rng.nextInt(_colors.length)],
        // 延迟出现（0 ~ 0.3 的动画进度）
        delay: rng.nextDouble() * 0.3,
      );
    });
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.isAnimating && _controller.value == 0) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _CelebrationPainter(
              particles: _particles,
              progress: _controller.value,
            ),
          );
        },
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
  final Color color;
  final double delay;

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

class _CelebrationPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _CelebrationPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // 粒子自身的进度（减去延迟）
      final localProgress = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      // 使用 easeOut 曲线让运动更自然
      final eased = Curves.easeOutCubic.transform(localProgress);

      final x = (p.startX + p.driftX * eased) * size.width;
      final y = (p.startY - p.riseY * eased) * size.height;

      // 透明度：先淡入再淡出
      double opacity;
      if (localProgress < 0.15) {
        opacity = localProgress / 0.15;
      } else if (localProgress > 0.6) {
        opacity = 1.0 - ((localProgress - 0.6) / 0.4);
      } else {
        opacity = 1.0;
      }
      opacity = opacity.clamp(0.0, 1.0);

      // 大小随进度略微缩小
      final currentRadius = p.radius * (1.0 - localProgress * 0.3);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x, y), currentRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.progress != progress;
}
