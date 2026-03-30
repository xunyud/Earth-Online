import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 森林粒子系统（增强版）
/// 包含纤细树叶、萤火虫、阳光浮尘和柔和光斑
class ForestParticles extends StatefulWidget {
  final bool enabled;

  const ForestParticles({super.key, this.enabled = true});

  @override
  State<ForestParticles> createState() => _ForestParticlesState();
}

class _ForestParticlesState extends State<ForestParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    _initParticles();
  }

  void _initParticles() {
    final leafColors = [
      const Color(0xFF228B22).withValues(alpha: 0.55),
      const Color(0xFF32CD32).withValues(alpha: 0.45),
      const Color(0xFFFFD700).withValues(alpha: 0.4),
      const Color(0xFF98FF98).withValues(alpha: 0.4),
      const Color(0xFF6BAA4A).withValues(alpha: 0.5),
    ];

    // 8 片纤细树叶 — 非常缓慢飘落
    for (int i = 0; i < 8; i++) {
      _particles.add(_Particle(
        type: _PType.leaf,
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 1.2 - 0.1,
        size: 3 + _rng.nextDouble() * 4,
        vy: 0.003 + _rng.nextDouble() * 0.006, // 极慢
        vx: 0,
        rotation: _rng.nextDouble() * math.pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.015, // 缓转
        color: leafColors[_rng.nextInt(leafColors.length)],
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0.1 + _rng.nextDouble() * 0.2,
        blinkSpeed: 0,
      ));
    }

    // 10 只萤火虫 — 轻柔游走，慢呼吸
    for (int i = 0; i < 10; i++) {
      _particles.add(_Particle(
        type: _PType.firefly,
        x: _rng.nextDouble(),
        y: 0.4 + _rng.nextDouble() * 0.55,
        size: 2 + _rng.nextDouble() * 2.5,
        vy: (_rng.nextDouble() - 0.5) * 0.001, // 极慢
        vx: (_rng.nextDouble() - 0.5) * 0.0015,
        rotation: 0,
        rotationSpeed: 0,
        color: _rng.nextDouble() > 0.3
            ? const Color(0xFFDCFF78).withValues(alpha: 0.7)
            : const Color(0xFFFFF096).withValues(alpha: 0.7),
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 0.5 + _rng.nextDouble() * 1.0, // 很慢的呼吸
      ));
    }

    // 12 颗阳光浮尘 — 几乎静止的金色微粒
    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle(
        type: _PType.sunDust,
        x: _rng.nextDouble() * 0.5,
        y: _rng.nextDouble() * 0.5,
        size: 1 + _rng.nextDouble() * 1.5,
        vy: 0.0008 + _rng.nextDouble() * 0.002, // 几乎不动
        vx: 0.0005 + _rng.nextDouble() * 0.0015,
        rotation: 0,
        rotationSpeed: 0,
        color: const Color(0xFFFFF8D0).withValues(alpha: 0.6),
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 0.8 + _rng.nextDouble() * 1.5, // 慢闪
      ));
    }

    // 4 个柔和大光斑 — 缓慢飘动
    for (int i = 0; i < 4; i++) {
      _particles.add(_Particle(
        type: _PType.glow,
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.7,
        size: 20 + _rng.nextDouble() * 25,
        vy: 0.001 + _rng.nextDouble() * 0.002, // 极慢
        vx: 0,
        rotation: 0,
        rotationSpeed: 0,
        color: const Color(0xFFFFFACD).withValues(alpha: 0.08),
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 0.3 + _rng.nextDouble() * 0.4,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          time: DateTime.now().millisecondsSinceEpoch / 1000.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

enum _PType { leaf, firefly, sunDust, glow }

class _Particle {
  final _PType type;
  double x, y;
  final double size;
  double vy, vx;
  double rotation;
  final double rotationSpeed;
  final Color color;
  final double phase;
  final double drift;
  final double blinkSpeed;

  _Particle({
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.vy,
    required this.vx,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.phase,
    required this.drift,
    required this.blinkSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  static final math.Random _rng = math.Random();

  _ParticlePainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      switch (p.type) {
        case _PType.leaf:
          _updateLeaf(p, size);
          _drawLeaf(canvas, p, size);
          break;
        case _PType.firefly:
          _updateFirefly(p, size);
          _drawFirefly(canvas, p, size);
          break;
        case _PType.sunDust:
          _updateSunDust(p, size);
          _drawSunDust(canvas, p, size);
          break;
        case _PType.glow:
          _updateGlow(p, size);
          _drawGlow(canvas, p, size);
          break;
      }
    }
  }

  // ── 树叶 ──
  void _updateLeaf(_Particle p, Size sz) {
    p.y += p.vy;
    if (p.y > 1.12) {
      p.y = -0.08;
      p.x = _rng.nextDouble();
    }
    p.rotation += p.rotationSpeed;
    p.x += math.sin(p.y * math.pi * 3 + p.phase) * p.drift * 0.003;
    p.x = p.x.clamp(-0.05, 1.05);
  }

  void _drawLeaf(Canvas canvas, _Particle p, Size sz) {
    final px = p.x * sz.width;
    final py = p.y * sz.height;
    final len = p.size * 1.4;
    final bulge = p.size * 0.28;

    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(p.rotation);

    final path = Path()
      ..moveTo(0, -len / 2)
      ..cubicTo(bulge, -len * 0.15, bulge, len * 0.15, 0, len / 2)
      ..cubicTo(-bulge, len * 0.15, -bulge, -len * 0.15, 0, -len / 2);

    canvas.drawPath(path, Paint()..color = p.color);

    // 叶脉
    canvas.drawLine(
      Offset(0, -len * 0.35),
      Offset(0, len * 0.35),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = 0.4,
    );
    canvas.restore();
  }

  // ── 萤火虫 ──
  void _updateFirefly(_Particle p, Size sz) {
    // 非常温柔的随机游走
    p.vx += (_rng.nextDouble() - 0.5) * 0.00008;
    p.vy += (_rng.nextDouble() - 0.5) * 0.00006;
    p.vx *= 0.998;
    p.vy *= 0.998;
    p.x += p.vx;
    p.y += p.vy;
    // 软边界
    if (p.x < 0.03) p.vx += 0.0002;
    if (p.x > 0.97) p.vx -= 0.0002;
    if (p.y < 0.35) p.vy += 0.0001;
    if (p.y > 0.93) p.vy -= 0.0001;
  }

  void _drawFirefly(Canvas canvas, _Particle p, Size sz) {
    final blink =
        0.2 + (math.sin(time * p.blinkSpeed + p.phase) * 0.5 + 0.5) * 0.8;
    final px = p.x * sz.width;
    final py = p.y * sz.height;

    // 外发光
    canvas.drawCircle(
      Offset(px, py),
      p.size * 3.5,
      Paint()
        ..color = p.color.withValues(alpha: blink * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // 核心亮点
    canvas.drawCircle(
      Offset(px, py),
      p.size,
      Paint()
        ..color = p.color.withValues(alpha: blink * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // ── 阳光浮尘 ──
  void _updateSunDust(_Particle p, Size sz) {
    p.x += p.vx;
    p.y += p.vy;
    p.x += math.sin(time * 1.2 + p.phase) * 0.0001;
    if (p.x > 0.7 || p.y > 0.7) {
      p.x = _rng.nextDouble() * 0.3;
      p.y = _rng.nextDouble() * 0.25;
    }
  }

  void _drawSunDust(Canvas canvas, _Particle p, Size sz) {
    final twinkle =
        0.15 + (math.sin(time * p.blinkSpeed + p.phase) * 0.5 + 0.5) * 0.85;
    final px = p.x * sz.width;
    final py = p.y * sz.height;

    // 暖光晕
    canvas.drawCircle(
      Offset(px, py),
      p.size * 3,
      Paint()
        ..color = const Color(0xFFFFF0AA).withValues(alpha: twinkle * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // 亮核
    canvas.drawCircle(
      Offset(px, py),
      p.size,
      Paint()..color = const Color(0xFFFFFCE6).withValues(alpha: twinkle),
    );
  }

  // ── 柔和光斑 ──
  void _updateGlow(_Particle p, Size sz) {
    p.y += p.vy;
    if (p.y > 1.1) {
      p.y = -0.05;
      p.x = _rng.nextDouble();
    }
  }

  void _drawGlow(Canvas canvas, _Particle p, Size sz) {
    final alpha =
        0.4 + math.sin(time * p.blinkSpeed + p.phase) * 0.35;
    canvas.drawCircle(
      Offset(p.x * sz.width, p.y * sz.height),
      p.size,
      Paint()
        ..color = p.color.withValues(alpha: alpha.clamp(0.05, 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
