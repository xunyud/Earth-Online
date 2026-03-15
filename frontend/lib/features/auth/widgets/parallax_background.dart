import 'package:flutter/material.dart';

/// 视差滚动背景组件
/// 支持多层图片以不同速度滚动，营造深度感
class ParallaxBackground extends StatefulWidget {
  /// 背景图层配置（从远到近）
  final List<ParallaxLayer> layers;

  /// 是否启用自动滚动
  final bool autoScroll;

  /// 滚动速度（像素/秒）
  final double scrollSpeed;

  const ParallaxBackground({
    super.key,
    required this.layers,
    this.autoScroll = true,
    this.scrollSpeed = 20.0,
  });

  @override
  State<ParallaxBackground> createState() => _ParallaxBackgroundState();
}

class _ParallaxBackgroundState extends State<ParallaxBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    if (widget.autoScroll) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: widget.layers.map((layer) {
            return _buildLayer(layer, _animation.value);
          }).toList(),
        );
      },
    );
  }

  Widget _buildLayer(ParallaxLayer layer, double progress) {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = -progress * screenWidth * layer.speed;

    return Positioned.fill(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: double.infinity,
        child: Transform.translate(
          offset: Offset(offset, 0),
          child: Row(
            children: [
              _buildLayerImage(layer, screenWidth),
              _buildLayerImage(layer, screenWidth), // 无缝循环
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerImage(ParallaxLayer layer, double screenWidth) {
    if (layer.assetPath != null) {
      return Image.asset(
        layer.assetPath!,
        width: screenWidth,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 图片加载失败时显示占位色
          return Container(
            width: screenWidth,
            color: layer.fallbackColor ?? Colors.transparent,
          );
        },
      );
    } else {
      // 纯色占位
      return Container(
        width: screenWidth,
        color: layer.fallbackColor ?? Colors.grey.shade200,
      );
    }
  }
}

/// 视差图层配置
class ParallaxLayer {
  /// 图片资源路径（可选）
  final String? assetPath;

  /// 视差速度（0.0 = 静止，1.0 = 全速）
  final double speed;

  /// 备用颜色（图片加载失败或未提供时使用）
  final Color? fallbackColor;

  const ParallaxLayer({
    this.assetPath,
    required this.speed,
    this.fallbackColor,
  });
}
