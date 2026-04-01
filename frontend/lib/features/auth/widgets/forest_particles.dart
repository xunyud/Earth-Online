import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 森林粒子引擎（5 类粒子 1:1 还原 HTML canvas）
/// Leaf × 14, Firefly × 20, Pollen × 12, SunDust × 25, Glow × 6
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
    // ── 颜色面板（与 HTML leafPal 一致）──
    final leafFlutterColors = [
      const Color(0xFF228B22).withValues(alpha: 0.6),
      const Color(0xFF32CD32).withValues(alpha: 0.5),
      const Color(0xFFFFD700).withValues(alpha: 0.45),
      const Color(0xFF98FF98).withValues(alpha: 0.45),
      const Color(0xFF6BAA4A).withValues(alpha: 0.5),
      const Color(0xFFB47828).withValues(alpha: 0.4),
    ];

    // ── 14 片树叶（HTML: 3-8px, vy 0.08-0.26）──
    for (int i = 0; i < 14; i++) {
      _particles.add(_Particle(
        type: _PType.leaf,
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 1.3 - 0.15,
        size: 3 + _rng.nextDouble() * 5, // 3-8
        vy: 0.08 + _rng.nextDouble() * 0.18, // px/frame → 归一化
        vx: 0,
        rotation: _rng.nextDouble() * math.pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.04,
        color: leafFlutterColors[_rng.nextInt(leafFlutterColors.length)],
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0.2 + _rng.nextDouble() * 0.4,
        blinkSpeed: 0,
      ));
    }

    // ── 20 只萤火虫（HTML: 3-7px, 下半屏）──
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        type: _PType.firefly,
        x: _rng.nextDouble(),
        y: 0.35 + _rng.nextDouble() * 0.6,
        size: 3 + _rng.nextDouble() * 4,
        vx: (_rng.nextDouble() - 0.5) * 0.15,
        vy: (_rng.nextDouble() - 0.5) * 0.1,
        rotation: 0,
        rotationSpeed: 0,
        color: _rng.nextDouble() > 0.3
            ? const Color(0xFFDCFF78) // rgba(220,255,120,*)
            : const Color(0xFFFFF096), // rgba(255,240,150,*)
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 1.5 + _rng.nextDouble() * 2.5,
      ));
    }

    // ── 12 颗花粉（HTML: tiny white dots, upward）──
    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle(
        type: _PType.pollen,
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 1.5 + _rng.nextDouble() * 2,
        vx: (_rng.nextDouble() - 0.5) * 0.08,
        vy: -(0.05 + _rng.nextDouble() * 0.1), // 向上
        rotation: 0,
        rotationSpeed: 0,
        color: const Color(0xFFFFFFF5).withValues(alpha: 0.8),
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 2.0,
      ));
    }

    // ── 25 颗阳光浮尘（HTML: gold sparkles, top-left bias）──
    for (int i = 0; i < 25; i++) {
      _particles.add(_Particle(
        type: _PType.sunDust,
        x: _rng.nextDouble() * 0.55, // 偏左
        y: _rng.nextDouble() * 0.65, // 偏上
        size: 1 + _rng.nextDouble() * 2.5,
        vx: 0.02 + _rng.nextDouble() * 0.06, // 右移
        vy: 0.03 + _rng.nextDouble() * 0.08, // 下移
        rotation: 0,
        rotationSpeed: 0,
        color: const Color(0xFFFFF0AA),
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 2 + _rng.nextDouble() * 4,
      ));
    }

    // ── 6 个柔和大光斑 ──
    for (int i = 0; i < 6; i++) {
      _particles.add(_Particle(
        type: _PType.glow,
        x: _rng.nextDouble(),
        y: 0.1 + _rng.nextDouble() * 0.6,
        size: 22 + _rng.nextDouble() * 30,
        vx: 0,
        vy: 0.03 + _rng.nextDouble() * 0.04,
        rotation: 0,
        rotationSpeed: 0,
        color: const Color(0xFFFFFACD).withValues(alpha: 0.08),
        phase: _rng.nextDouble() * math.pi * 2,
        drift: 0,
        blinkSpeed: 0.8,
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
        painter: _ParticleEnginePainter(
          particles: _particles,
          time: DateTime.now().millisecondsSinceEpoch / 1000.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

enum _PType { leaf, firefly, pollen, sunDust, glow }

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

/// 完整 5 类粒子绘制引擎（1:1 还原 HTML canvas draw() 函数）
class _ParticleEnginePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  static final math.Random _rng = math.Random();

  _ParticleEnginePainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w < 1 || h < 1) return;

    for (final p in particles) {
      switch (p.type) {
        case _PType.leaf:
          _updateLeaf(p, w, h);
          _drawLeaf(canvas, p, w, h);
          break;
        case _PType.firefly:
          _updateFirefly(p, w, h);
          _drawFirefly(canvas, p, w, h);
          break;
        case _PType.pollen:
          _updatePollen(p, w, h);
          _drawPollen(canvas, p, w, h);
          break;
        case _PType.sunDust:
          _updateSunDust(p, w, h);
          _drawSunDust(canvas, p, w, h);
          break;
        case _PType.glow:
          _updateGlow(p, w, h);
          _drawGlow(canvas, p, w, h);
          break;
      }
    }
  }

  // ════════════════════════════════════════════════════
  // 树叶（HTML: bezierCurveTo 尖叶 + 中心叶脉）
  // ════════════════════════════════════════════════════
  void _updateLeaf(_Particle p, double w, double h) {
    p.y += p.vy / h;
    if (p.y > 1.15) {
      p.y = -0.1;
      p.x = _rng.nextDouble();
    }
    p.rotation += p.rotationSpeed;
    p.x += math.sin(p.y * math.pi * 3 + p.phase) * p.drift / w;
    if (p.x < -0.05) p.x = 1.05;
    if (p.x > 1.05) p.x = -0.05;
  }

  void _drawLeaf(Canvas canvas, _Particle p, double w, double h) {
    final px = p.x * w;
    final py = p.y * h;
    final len = p.size * 1.4;
    final bulge = p.size * 0.3; // 窄叶

    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(p.rotation);

    // 贝塞尔尖叶
    final path = Path()
      ..moveTo(0, -len / 2) // 尖端
      ..cubicTo(bulge, -len * 0.15, bulge, len * 0.15, 0, len / 2) // 右弧
      ..cubicTo(-bulge, len * 0.15, -bulge, -len * 0.15, 0, -len / 2); // 左弧

    canvas.drawPath(path, Paint()..color = p.color);

    // 中心叶脉
    canvas.drawLine(
      Offset(0, -len * 0.35),
      Offset(0, len * 0.35),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 0.4,
    );
    canvas.restore();
  }

  // ════════════════════════════════════════════════════
  // 萤火虫（HTML: shadowColor + shadowBlur 发光）
  // ════════════════════════════════════════════════════
  void _updateFirefly(_Particle p, double w, double h) {
    p.x += p.vx / w;
    p.y += p.vy / h;
    p.vx += (_rng.nextDouble() - 0.5) * 0.01;
    p.vy += (_rng.nextDouble() - 0.5) * 0.008;
    p.vx *= 0.99;
    p.vy *= 0.99;
    // 软边界
    if (p.x < 0.02) p.vx += 0.02;
    if (p.x > 0.98) p.vx -= 0.02;
    if (p.y < 0.3) p.vy += 0.01;
    if (p.y > 0.95) p.vy -= 0.01;
  }

  void _drawFirefly(Canvas canvas, _Particle p, double w, double h) {
    final blink =
        0.2 + (math.sin(time * p.blinkSpeed + p.phase) * 0.5 + 0.5) * 0.8;
    final px = p.x * w;
    final py = p.y * h;

    // 外发光（HTML: shadowBlur 25, alpha 0.3）
    canvas.drawCircle(
      Offset(px, py),
      p.size * 3,
      Paint()
        ..color = p.color.withValues(alpha: blink * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );
    // 核心亮点（HTML: shadowBlur 12, alpha 0.9）
    canvas.drawCircle(
      Offset(px, py),
      p.size,
      Paint()
        ..color = p.color.withValues(alpha: blink * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  // ════════════════════════════════════════════════════
  // 花粉（HTML: tiny white dots drifting upward）
  // ════════════════════════════════════════════════════
  void _updatePollen(_Particle p, double w, double h) {
    p.y += p.vy / h;
    p.x += p.vx / w + math.sin(time * 1.5 + p.phase) * 0.0003;
    if (p.y < -0.05) {
      p.y = 1.05;
      p.x = _rng.nextDouble();
    }
  }

  void _drawPollen(Canvas canvas, _Particle p, double w, double h) {
    final alpha = (0.3 + math.sin(time * 2 + p.phase) * 0.2).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(p.x * w, p.y * h),
      p.size,
      Paint()..color = const Color(0xFFFFFFF5).withValues(alpha: alpha * 0.8),
    );
  }

  // ════════════════════════════════════════════════════
  // 阳光浮尘（HTML: golden dust motes in sunbeams）
  // ════════════════════════════════════════════════════
  void _updateSunDust(_Particle p, double w, double h) {
    p.x += p.vx / w;
    p.y += p.vy / h;
    p.x += math.sin(time * 1.2 + p.phase) * 0.0002;
    p.y += math.cos(time * 0.9 + p.phase) * 0.0001;
    if (p.x > 0.7 || p.y > 0.75) {
      p.x = _rng.nextDouble() * 0.3;
      p.y = _rng.nextDouble() * 0.3;
    }
  }

  void _drawSunDust(Canvas canvas, _Particle p, double w, double h) {
    final twinkle =
        0.15 + (math.sin(time * p.blinkSpeed + p.phase) * 0.5 + 0.5) * 0.85;
    final px = p.x * w;
    final py = p.y * h;

    // 暖金色光晕（HTML: shadowBlur 10, alpha twinkle*0.25）
    canvas.drawCircle(
      Offset(px, py),
      p.size * 3,
      Paint()
        ..color = const Color(0xFFFFF0AA).withValues(alpha: twinkle * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // 明亮核心
    canvas.drawCircle(
      Offset(px, py),
      p.size,
      Paint()
        ..color = const Color(0xFFFFFCE6).withValues(alpha: twinkle * 0.95),
    );
  }

  // ════════════════════════════════════════════════════
  // 柔和大光斑
  // ════════════════════════════════════════════════════
  void _updateGlow(_Particle p, double w, double h) {
    p.y += p.vy / h;
    if (p.y > 1.1) {
      p.y = -0.05;
      p.x = _rng.nextDouble();
    }
  }

  void _drawGlow(Canvas canvas, _Particle p, double w, double h) {
    final alpha =
        (0.5 + math.sin(time * 0.8 + p.phase) * 0.4).clamp(0.05, 0.5);
    canvas.drawCircle(
      Offset(p.x * w, p.y * h),
      p.size,
      Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(covariant _ParticleEnginePainter old) => true;
}
