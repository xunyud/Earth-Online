import 'dart:math' as math;

import 'package:flutter/material.dart';

class SoftAuthBackground extends StatelessWidget {
  final Color accentColor;

  const SoftAuthBackground({
    super.key,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final shortSide = math.min(width, height);

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFFFFFCF7),
                      Color(0xFFF8F3E8),
                      Color(0xFFEDE7D7),
                    ],
                    stops: [0.0, 0.58, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.76, -0.9),
                    radius: 1.04,
                    colors: [
                      const Color(0xFFFFF3CC).withValues(alpha: 0.76),
                      const Color(0xFFFFF3CC).withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.34, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.76, -0.18),
                    radius: 0.92,
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      accentColor.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: shortSide * 0.08,
                left: -shortSide * 0.1,
                child: _PaperShape(
                  width: shortSide * 0.42,
                  height: shortSide * 0.14,
                  color: const Color(0xFFF4ECD7).withValues(alpha: 0.64),
                  angle: -0.12,
                ),
              ),
              Positioned(
                top: height * 0.16,
                right: -shortSide * 0.06,
                child: _PaperShape(
                  width: shortSide * 0.3,
                  height: shortSide * 0.2,
                  color: accentColor.withValues(alpha: 0.08),
                  angle: 0.36,
                ),
              ),
              Positioned(
                bottom: -shortSide * 0.08,
                left: width * 0.08,
                child: _PaperShape(
                  width: shortSide * 0.4,
                  height: shortSide * 0.22,
                  color: const Color(0xFFF3E6C9).withValues(alpha: 0.54),
                  angle: 0.08,
                ),
              ),
              Positioned(
                bottom: -shortSide * 0.12,
                right: width * 0.04,
                child: _PaperShape(
                  width: shortSide * 0.34,
                  height: shortSide * 0.24,
                  color: accentColor.withValues(alpha: 0.06),
                  angle: -0.18,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: shortSide * 0.24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaperShape extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double angle;

  const _PaperShape({
    required this.width,
    required this.height,
    required this.color,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: color.a * 0.5),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: color.a * 0.18),
              blurRadius: 48,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
