import 'package:flutter/material.dart';

/// 任务看板浮动按钮
/// 用于展开/折叠所有任务
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
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5, // 180度旋转（0.5 * 2π）
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // 根据初始状态设置动画
    if (widget.isExpanded) {
      _rotationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(QuestBoardFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(24),
        color: theme.primaryColor.withValues(alpha: 0.9),
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: RotationTransition(
              turns: _rotationAnimation,
              child: Icon(
                widget.isExpanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
