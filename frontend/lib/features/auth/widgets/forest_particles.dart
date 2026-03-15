import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 森林粒子系统
/// 包含飘落的树叶和漂浮的光斑
class ForestParticles extends StatefulWidget {
  /// 是否启用粒子动画
  final bool enabled;

  const ForestParticles({
    super.key,
    this.enabled = true,
  });

  @override
  State<ForestParticles> createState() => _ForestParticlesState();
}

class _ForestParticlesState extends State<ForestParticles>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    // 初始化粒子
    _initParticles();
  }

  void _initParticles() {
    // 树叶粒子（10-12 个）
    for (int i = 0; i < 12; i++) {
      _particles.add(Particle(
        type: ParticleType.leaf,
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 8 + _random.nextDouble() * 8, // 8-16px
        speed: 0.02 + _random.nextDouble() * 0.03, // 0.02-0.05
        rotation: _random.nextDouble() * math.pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.1,
        color: _getLeafColor(),
        phase: _random.nextDouble() * math.pi * 2,
      ));
    }

    // 光斑粒子（5-8 个）
    for (int i = 0; i < 6; i++) {
      _particles.add(Particle(
        type: ParticleType.lightSpot,
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 20 + _random.nextDouble() * 20, // 20-40px
        speed: 0.01 + _random.nextDouble() * 0.01, // 0.01-0.02
        rotation: 0,
        rotationSpeed: 0,
        color: const Color(0xFFFFFACD).withValues(alpha: 0.3),
        phase: _random.nextDouble() * math.pi * 2,
      ));
    }
  }

  Color _getLeafColor() {
    final colors = [
      const Color(0xFF228B22), // 森林绿
      const Color(0xFF32CD32), // 亮绿
      const Color(0xFFFFD700), // 金色
      const Color(0xFF98FF98), // 淡绿
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            animationValue: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// 粒子类型
enum ParticleType {
  leaf, // 树叶
  lightSpot, // 光斑
}

/// 粒子数据
class Particle {
  final ParticleType type;
  double x; // 0.0-1.0（相对位置）
  double y; // 0.0-1.0（相对位置）
  final double size;
  final double speed;
  double rotation;
  final double rotationSpeed;
  final Color color;
  final double phase; // 正弦波相位

  Particle({
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.phase,
  });

  void update() {
    // 更新位置
    y += speed;
    if (y > 1.1) {
      y = -0.1; // 循环
    }

    // 更新旋转
    rotation += rotationSpeed;

    // 水平正弦波运动（仅树叶）
    if (type == ParticleType.leaf) {
      x += math.sin(y * math.pi * 4 + phase) * 0.001;
      x = x.clamp(0.0, 1.0);
    }
  }
}

/// 粒子绘制器
class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  _ParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.update();

      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      final dx = particle.x * size.width;
      final dy = particle.y * size.height;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(particle.rotation);

      if (particle.type == ParticleType.leaf) {
        // 绘制树叶（简单椭圆）
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 1.5,
          ),
          paint,
        );
      } else {
        // 绘制光斑（模糊圆形）
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(
          Offset.zero,
          particle.size / 2,
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return true; // 每帧重绘
  }
}
