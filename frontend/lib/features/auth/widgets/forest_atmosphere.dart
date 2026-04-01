import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 森林氛围层：太阳脉冲、神光、暖光、雾气漂移、光球、草丛、暗角
/// 1:1 还原 HTML 中除粒子外的全部视觉效果
class ForestAtmosphere extends StatefulWidget {
  const ForestAtmosphere({super.key});

  @override
  State<ForestAtmosphere> createState() => _ForestAtmosphereState();
}

class _ForestAtmosphereState extends State<ForestAtmosphere>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 8), // 4s 脉冲周期 × 2（来回）
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value; // 0→1→0 (reverse)
        return Stack(
          fit: StackFit.expand,
          children: [
            // ═══ 太阳光晕 (sun-halo) ═══
            _buildSunHalo(t),
            // ═══ 太阳核心 (sun) ═══
            _buildSunCore(t),
            // ═══ 太阳耀斑 (sun-flare) ═══
            _buildSunFlare(t),
            // ═══ 7 条神光 (god rays) ═══
            _buildGodRays(t),
            // ═══ 暖光洗 (sunwash) ═══
            _buildSunwash(),
            // ═══ 雾气层 A (底部 15%, 高30%) ═══
            const Positioned.fill(
              child: _MistLayer(
                  direction: 1, bottomFrac: 0.15, heightFrac: 0.30, opacity: 1.0),
            ),
            // ═══ 雾气层 B (底部 25%, 高20%) ═══
            const Positioned.fill(
              child: _MistLayer(
                  direction: -1, bottomFrac: 0.25, heightFrac: 0.20, opacity: 0.5),
            ),
            // ═══ 3 个光球 ═══
            _buildGlowOrbs(t),
            // ═══ 草丛 ═══
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: _GrassForeground(),
            ),
          ],
        );
      },
    );
  }

  // ── 太阳光晕（巨大模糊圆，左上偏移）──
  Widget _buildSunHalo(double t) {
    final scale = 1.0 + t * 0.1; // 1.0 → 1.1
    final opacity = 0.9 + t * 0.1; // 0.9 → 1.0
    return Positioned(
      top: -200,
      left: -60,
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: 620,
              height: 620,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFF8C8).withValues(alpha: 0.35),
                    const Color(0xFFFFEB96).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.65],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 太阳核心 ──
  Widget _buildSunCore(double t) {
    final scale = 1.0 + t * 0.1;
    final opacity = 0.9 + t * 0.1;
    return Positioned(
      top: -80,
      left: 0,
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFFCDC),
                    const Color(0xFFFFF0A0).withValues(alpha: 0.7),
                    const Color(0xFFFFDC64).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.72],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 太阳耀斑（小光斑漂移）──
  Widget _buildSunFlare(double t) {
    // flareDrift: translate(0→20, 0→10), scale(1→1.15), opacity(0.4→0.65)
    final dx = t * 20;
    final dy = t * 10;
    final scale = 1.0 + t * 0.15;
    final opacity = 0.4 + t * 0.25;
    return Positioned(
      top: 30,
      left: 80,
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFFFF0).withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 7 条神光（shimmer 效果）──
  Widget _buildGodRays(double t) {
    // HTML: 7 rays, 不同角度/宽度/偏移/透明度
    final rays = <_RayData>[
      _RayData(left: 0.06, width: 180, angle: 10, baseOp: 1.0),
      _RayData(left: 0.14, width: 130, angle: 16, baseOp: 0.7),
      _RayData(left: 0.24, width: 200, angle: 6, baseOp: 0.55),
      _RayData(left: 0.03, width: 110, angle: 22, baseOp: 0.45),
      _RayData(left: 0.34, width: 150, angle: 3, baseOp: 0.35),
      _RayData(left: 0.19, width: 90, angle: 25, baseOp: 0.30),
      _RayData(left: 0.40, width: 170, angle: -2, baseOp: 0.25),
    ];

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.45, // HTML: .rays { opacity: 0.45 }
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: rays.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  // 各光线使用不同相位的 shimmer
                  // 用 sin 模拟不同 delay 的闪烁
                  final phase = i * 0.9;
                  final shimmer = 0.3 + (math.sin(t * math.pi + phase) * 0.5 + 0.5) * 0.4;
                  return Positioned(
                    top: -h * 0.1,
                    left: w * r.left,
                    child: Transform.rotate(
                      angle: r.angle * math.pi / 180,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: (shimmer * r.baseOp).clamp(0.0, 1.0),
                        child: Container(
                          width: r.width,
                          height: h * 1.35,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFFFFFAD2).withValues(alpha: 0.6),
                                const Color(0xFFFFF5B4).withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.82],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── 暖光洗 ──
  Widget _buildSunwash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.64, -0.8),
              radius: 1.1,
              colors: [
                const Color(0xFFFFF5BE).withValues(alpha: 0.35),
                const Color(0xFFFFF0AA).withValues(alpha: 0.15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.55],
            ),
          ),
        ),
      ),
    );
  }

  // ── 3 个光球 ──
  Widget _buildGlowOrbs(double t) {
    // HTML: .glow-orb.a: top 2%, left 10%, 480x480, yellow
    //       .glow-orb.b: bottom 22%, right 8%, 350x350, green
    //       .glow-orb.c: top 45%, left 60%, 250x250, yellow
    final dx = t * 30;
    final dy = t * -20;
    final scale = 1.0 + t * 0.06;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            // Orb A
            Positioned(
              top: h * 0.02,
              left: w * 0.10,
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 480,
                      height: 480,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFF6CF).withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Orb B (delay: animation-delay -3s → 相位反转)
            Positioned(
              bottom: h * 0.22,
              right: w * 0.08,
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(-dx, -dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4EC784).withValues(alpha: 0.20),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Orb C
            Positioned(
              top: h * 0.45,
              left: w * 0.60,
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(dx * 0.5, dy * 0.7),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFFDDC).withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RayData {
  final double left; // fraction of screen width
  final double width;
  final double angle; // degrees
  final double baseOp; // base opacity multiplier

  const _RayData({
    required this.left,
    required this.width,
    required this.angle,
    required this.baseOp,
  });
}

/// 雾气漂移层（无限横移，自身处理定位）
class _MistLayer extends StatefulWidget {
  final int direction; // 1 = 正向, -1 = 反向
  final double bottomFrac; // 底部位置（占父高度比例）
  final double heightFrac; // 层高度（占父高度比例）
  final double opacity;

  const _MistLayer({
    required this.direction,
    required this.bottomFrac,
    required this.heightFrac,
    this.opacity = 1.0,
  });

  @override
  State<_MistLayer> createState() => _MistLayerState();
}

class _MistLayerState extends State<_MistLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final dur = widget.direction > 0 ? 25 : 35;
    _ctrl = AnimationController(
      duration: Duration(seconds: dur),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sw = constraints.maxWidth;
        final sh = constraints.maxHeight;
        final mistW = sw * 2;
        final mistH = sh * widget.heightFrac;
        final bottomPx = sh * widget.bottomFrac;

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final progress =
                widget.direction > 0 ? _ctrl.value : 1.0 - _ctrl.value;
            final dx = -progress * sw;

            return Stack(
              children: [
                Positioned(
                  bottom: bottomPx,
                  left: 0,
                  height: mistH,
                  width: sw,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: widget.opacity,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth: double.infinity,
                          child: Transform.translate(
                            offset: Offset(dx, 0),
                            child: SizedBox(
                              width: mistW,
                              height: mistH,
                              child: CustomPaint(
                                painter: _MistPainter(),
                                size: Size(mistW, mistH),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MistPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // HTML: 3 个 radial-gradient 叠加
    final paint = Paint();
    // ellipse at 20% 50%
    final c1 = Offset(size.width * 0.2, size.height * 0.5);
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFFDCEBD2).withValues(alpha: 0.35),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: c1, radius: size.width * 0.25));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // ellipse at 60% 40%
    final c2 = Offset(size.width * 0.6, size.height * 0.4);
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFFFFFFF5).withValues(alpha: 0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: c2, radius: size.width * 0.225));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // ellipse at 85% 60%
    final c3 = Offset(size.width * 0.85, size.height * 0.6);
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFFC8E6BE).withValues(alpha: 0.30),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: c3, radius: size.width * 0.25));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 前景草丛（120 根摇摆草叶，CustomPainter 实现）
class _GrassForeground extends StatefulWidget {
  const _GrassForeground();

  @override
  State<_GrassForeground> createState() => _GrassForegroundState();
}

class _GrassForegroundState extends State<_GrassForeground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_GrassBlade> _blades;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    final rng = math.Random(42);
    final greens = [
      const Color(0xFF3A7A2E),
      const Color(0xFF4A8F3A),
      const Color(0xFF2D6622),
      const Color(0xFF5BA34A),
      const Color(0xFF68B455),
      const Color(0xFF3D7030),
    ];
    _blades = List.generate(120, (i) {
      return _GrassBlade(
        xFraction: i / 120.0 + (rng.nextDouble() - 0.5) * 0.012,
        height: 25 + rng.nextDouble() * 50,
        width: 2 + rng.nextDouble() * 3,
        colorTop: greens[(i + 2) % greens.length],
        colorBot: greens[i % greens.length],
        swayDuration: 2.5 + rng.nextDouble() * 2.0,
        swayPhase: rng.nextDouble() * math.pi * 2,
        opacity: 0.5 + rng.nextDouble() * 0.5,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _GrassPainter(
            blades: _blades,
            time: DateTime.now().millisecondsSinceEpoch / 1000.0,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GrassBlade {
  final double xFraction;
  final double height;
  final double width;
  final Color colorTop;
  final Color colorBot;
  final double swayDuration;
  final double swayPhase;
  final double opacity;

  const _GrassBlade({
    required this.xFraction,
    required this.height,
    required this.width,
    required this.colorTop,
    required this.colorBot,
    required this.swayDuration,
    required this.swayPhase,
    required this.opacity,
  });
}

class _GrassPainter extends CustomPainter {
  final List<_GrassBlade> blades;
  final double time;

  _GrassPainter({required this.blades, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in blades) {
      // grassSway: rotate(-4deg → 4deg)
      final angle =
          math.sin(time * (math.pi * 2 / b.swayDuration) + b.swayPhase) *
              4.0 *
              math.pi /
              180.0;
      final cx = b.xFraction * size.width;
      final cy = size.height; // 底部

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      final rect = Rect.fromLTWH(-b.width / 2, -b.height, b.width, b.height);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(b.width / 2),
        topRight: Radius.circular(b.width / 2),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            b.colorTop.withValues(alpha: b.opacity),
            b.colorBot.withValues(alpha: b.opacity),
          ],
        ).createShader(rect);

      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GrassPainter old) => true;
}
