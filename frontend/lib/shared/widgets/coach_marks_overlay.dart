import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_locale_controller.dart';

/// Coach Marks 单步数据
class CoachMarkStep {
  final GlobalKey targetKey;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final EdgeInsets highlightPadding;
  final double highlightBorderRadius;

  const CoachMarkStep({
    required this.targetKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    this.highlightPadding = const EdgeInsets.all(8),
    this.highlightBorderRadius = 16,
  });
}

/// 全屏 Coach Marks 遮罩引导
class CoachMarksOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const CoachMarksOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<CoachMarksOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;

  late AnimationController _highlightAnim;
  late AnimationController _bubbleAnim;

  Rect _fromRect = Rect.zero;
  Rect _toRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _highlightAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bubbleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToStep(0, animate: false);
    });
  }

  @override
  void dispose() {
    _highlightAnim.dispose();
    _bubbleAnim.dispose();
    super.dispose();
  }

  /// 获取目标 Widget 在屏幕上的位置
  Rect? _getTargetRect(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= widget.steps.length) return null;
    final step = widget.steps[stepIndex];
    final renderObj = step.targetKey.currentContext?.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return null;

    final topLeft = renderObj.localToGlobal(Offset.zero);
    final size = renderObj.size;
    final rect = topLeft & size;

    // 应用 padding 扩展/收缩
    return Rect.fromLTRB(
      rect.left - step.highlightPadding.left,
      rect.top - step.highlightPadding.top,
      rect.right + step.highlightPadding.right,
      rect.bottom + step.highlightPadding.bottom,
    );
  }

  void _goToStep(int index, {bool animate = true}) {
    // 目标找不到时向后查找下一个可用步骤，全部找不到则退出引导
    int resolvedIndex = index;
    Rect? targetRect;
    while (resolvedIndex < widget.steps.length) {
      targetRect = _getTargetRect(resolvedIndex);
      if (targetRect != null) break;
      resolvedIndex++;
    }
    if (targetRect == null) {
      widget.onComplete();
      return;
    }

    setState(() {
      _currentStep = resolvedIndex;
      _fromRect = _currentInterpolatedRect;
      _toRect = targetRect!;
    });

    if (animate) {
      _highlightAnim.forward(from: 0);
      _bubbleAnim.forward(from: 0);
    } else {
      _fromRect = targetRect;
      _highlightAnim.value = 1.0;
      _bubbleAnim.forward(from: 0);
    }
  }

  Rect get _currentInterpolatedRect {
    final t = Curves.easeInOut.transform(_highlightAnim.value);
    return Rect.lerp(_fromRect, _toRect, t) ?? _toRect;
  }

  void _nextStep() {
    if (_currentStep >= widget.steps.length - 1) {
      widget.onComplete();
    } else {
      _goToStep(_currentStep + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final total = widget.steps.length;
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == total - 1;

    return AnimatedBuilder(
      animation: Listenable.merge([_highlightAnim, _bubbleAnim]),
      builder: (context, _) {
        // 限制高亮区域不超出屏幕
        final raw = _currentInterpolatedRect;
        final highlightRect = Rect.fromLTRB(
          raw.left.clamp(0, screenSize.width),
          raw.top.clamp(0, screenSize.height),
          raw.right.clamp(0, screenSize.width),
          raw.bottom.clamp(0, screenSize.height),
        );

        // 气泡位置：目标在上半屏 -> 气泡放下方，反之放上方
        final targetCenter = highlightRect.center.dy;
        final showBubbleBelow = targetCenter < screenSize.height * 0.5;

        final double? bubbleTop;
        final double? bubbleBottom;
        if (showBubbleBelow) {
          // 气泡在高亮下方，但不能超出屏幕
          bubbleTop = highlightRect.bottom.clamp(0, screenSize.height * 0.6) + 16;
          bubbleBottom = null;
        } else {
          // 气泡在高亮上方
          final gap = screenSize.height - highlightRect.top.clamp(0, screenSize.height);
          bubbleBottom = (gap + 16).clamp(16, screenSize.height * 0.6);
          bubbleTop = null;
        }

        final bubbleProgress = Curves.easeOutCubic.transform(
          _bubbleAnim.value,
        );
        final bubbleOffset = (1 - bubbleProgress) * 16;

        return Stack(
          children: [
            // 遮罩 + 挖洞（高亮区域内点击可穿透到底层 widget）
            _HighlightPassthrough(
              highlightRect: highlightRect,
              child: CustomPaint(
                size: screenSize,
                painter: _CoachMarksPainter(
                  highlightRect: highlightRect,
                  borderRadius: step.highlightBorderRadius,
                ),
              ),
            ),

            // 说明气泡
            Positioned(
              left: 20,
              right: 20,
              top: bubbleTop,
              bottom: bubbleBottom,
              child: Opacity(
                opacity: bubbleProgress,
                child: Transform.translate(
                  offset: Offset(0, showBubbleBelow ? bubbleOffset : -bubbleOffset),
                  child: _buildBubble(context, step, isLast, total),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBubble(
    BuildContext context,
    CoachMarkStep step,
    bool isLast,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤标签 + 图标
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.mintGreenDark,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr('coach.step_label', params: {
                    'current': '${_currentStep + 1}',
                    'total': '$total',
                  }),
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(step.icon, size: 22, color: AppColors.mintGreenDark),
            ],
          ),
          const SizedBox(height: 14),

          // 标题
          Text(
            context.tr(step.titleKey),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF203222),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),

          // 描述
          Text(
            context.tr(step.descriptionKey),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),

          // 进度指示器
          Row(
            children: List.generate(total, (i) {
              final isActive = i == _currentStep;
              final isDone = i < _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.mintGreenDark.withValues(alpha: 0.5)
                      : isActive
                          ? AppColors.mintGreenDark
                          : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // 按钮行
          Row(
            children: [
              // 跳过按钮
              OutlinedButton(
                onPressed: widget.onSkip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  side: const BorderSide(color: AppColors.textHint),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.tr('coach.skip'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              // 下一步 / 完成按钮
              FilledButton(
                onPressed: _nextStep,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mintGreenDark,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.mintGreenDark.withValues(alpha: 0.4),
                ),
                child: Text(
                  isLast
                      ? context.tr('coach.finish')
                      : context.tr('coach.next'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pureWhite,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 遮罩画笔：全屏半透明 + 挖洞高亮
class _CoachMarksPainter extends CustomPainter {
  final Rect highlightRect;
  final double borderRadius;

  _CoachMarksPainter({
    required this.highlightRect,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0x8C000000);

    // saveLayer 后用 BlendMode.clear 挖洞
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final clearPaint = Paint()..blendMode = ui.BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(
      highlightRect,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(rrect, clearPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoachMarksPainter old) =>
      old.highlightRect != highlightRect || old.borderRadius != borderRadius;
}

/// 高亮区域内点击穿透、遮罩区域吸收点击
class _HighlightPassthrough extends SingleChildRenderObjectWidget {
  final Rect highlightRect;

  const _HighlightPassthrough({
    required this.highlightRect,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHighlightPassthrough(highlightRect);

  @override
  void updateRenderObject(
      BuildContext context, _RenderHighlightPassthrough renderObject) {
    renderObject.highlightRect = highlightRect;
  }
}

class _RenderHighlightPassthrough extends RenderProxyBox {
  Rect highlightRect;

  _RenderHighlightPassthrough(this.highlightRect);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 高亮区域内的点击穿透到底层 widget
    if (highlightRect.contains(position)) return false;
    // 遮罩暗区吸收点击
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
