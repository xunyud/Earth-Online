import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/quest_theme.dart';

/// 任务看板浮动按钮 — 玻璃鹅卵石设计
/// 多层叠加营造真实玻璃质感：外阴影 → 模糊层 → 着色层 → 高光层 → 内发光边缘
class QuestBoardFab extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const QuestBoardFab({
    super.key,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<QuestBoardFab> createState() => _QuestBoardFabState();
}

class _QuestBoardFabState extends State<QuestBoardFab>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();

    // 旋转动画（展开/折叠）
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    if (widget.isExpanded) {
      _rotationController.value = 1.0;
    }

    // 按压动画（缩放 + 阴影收缩）
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(QuestBoardFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      widget.isExpanded
          ? _rotationController.forward()
          : _rotationController.reverse();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressController.forward();
  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onToggle();
  }

  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final questTheme = Theme.of(context).extension<QuestTheme>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = questTheme.surfaceColor;

    // 玻璃着色 — 取 surface 颜色微混，让按钮融入背景
    final glassTint = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : surface.withValues(alpha: 0.55);

    const double size = 46;
    const double radius = 15;

    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          final scale = _scaleAnimation.value;
          final elev = _elevationAnimation.value;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                // 外层阴影 — 双层营造柔和扩散
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10 * elev),
                    blurRadius: 12 * elev,
                    spreadRadius: 1,
                    offset: Offset(0, 4 * elev),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06 * elev),
                    blurRadius: 4 * elev,
                    offset: Offset(0, 2 * elev),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: GestureDetector(
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: _onTapCancel,
                    behavior: HitTestBehavior.opaque,
                    child: CustomPaint(
                      painter: _GlassFabPainter(
                        glassTint: glassTint,
                        isDark: isDark,
                      ),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Center(
                          child: RotationTransition(
                            turns: _rotationAnimation,
                            child: Icon(
                              widget.isExpanded
                                  ? Icons.unfold_less_rounded
                                  : Icons.unfold_more_rounded,
                              color: Colors.black.withValues(alpha: 0.72),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 自定义画笔 — 在单个 Canvas 上叠加多层玻璃效果
class _GlassFabPainter extends CustomPainter {
  final Color glassTint;
  final bool isDark;

  _GlassFabPainter({required this.glassTint, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(15));

    // ① 玻璃底色 — 半透明着色层
    canvas.drawRRect(
      rrect,
      Paint()..color = glassTint,
    );

    // ② 顶部高光 — 模拟天光照射在玻璃上半部分
    final highlightRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.52);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      highlightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.12 : 0.45),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(highlightRect),
    );
    canvas.restore();

    // ③ 内发光边缘 — 1px 亮边模拟光线折射
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.28 : 0.65),
            Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
          ],
        ).createShader(rect),
    );

    // ④ 外轮廓 — 极细边线增加形体感
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = (isDark ? Colors.white : Colors.black)
            .withValues(alpha: isDark ? 0.10 : 0.06),
    );
  }

  @override
  bool shouldRepaint(_GlassFabPainter oldDelegate) =>
      glassTint != oldDelegate.glassTint || isDark != oldDelegate.isDark;
}
