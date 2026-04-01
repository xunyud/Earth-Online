import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 视差滚动背景组件（Ticker 驱动，底部对齐，分层宽度）
/// 1:1 还原 HTML 中的 parallax 逻辑
class ParallaxBackground extends StatefulWidget {
  final List<ParallaxLayer> layers;
  final bool autoScroll;

  /// 基准滚动速度（像素/秒），各层按自身 speed 系数缩放
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
  late Ticker _ticker;

  /// 每层的当前 X 偏移量
  final List<double> _offsets = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.layers.length; i++) {
      _offsets.add(0.0);
    }
    _ticker = createTicker(_onTick);
    if (widget.autoScroll) {
      _ticker.start();
    }
  }

  Duration _lastElapsed = Duration.zero;

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.5) return; // 跳过异常帧

    bool changed = false;
    for (int i = 0; i < widget.layers.length; i++) {
      final layer = widget.layers[i];
      _offsets[i] -= widget.scrollSpeed * layer.speed * dt;
      changed = true;
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        return Stack(
          children: List.generate(widget.layers.length, (i) {
            final layer = widget.layers[i];
            // 每层图片的逻辑宽度 = screenW * widthMultiplier
            final imgW = screenW * layer.widthMultiplier;
            // 归位偏移量：当滚动超过一个图片宽度时无缝重置
            double ox = _offsets[i];
            if (imgW > 0) {
              ox = ox % imgW;
              if (ox > 0) ox -= imgW; // 确保 ox <= 0
            }

            // 计算层高度
            final layerH = screenH * layer.heightFraction;

            return Positioned(
              bottom: 0, // 底部对齐
              left: 0,
              right: 0,
              height: layerH,
              child: Opacity(
                opacity: layer.opacity,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    maxWidth: double.infinity,
                    maxHeight: layerH,
                    child: Transform.translate(
                      offset: Offset(ox, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildImage(layer, imgW, layerH),
                          _buildImage(layer, imgW, layerH),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildImage(ParallaxLayer layer, double width, double height) {
    if (layer.assetPath != null) {
      return Image.asset(
        layer.assetPath!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: ColoredBox(color: layer.fallbackColor ?? Colors.transparent),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(color: layer.fallbackColor ?? Colors.grey.shade200),
    );
  }
}

/// 视差图层配置
class ParallaxLayer {
  final String? assetPath;

  /// 视差速度系数（相对于 scrollSpeed）
  final double speed;

  /// 图片宽度 = 屏幕宽度 * widthMultiplier
  /// HTML 中: sky=1.0, far=1.0, mid=1.25, near=1.5625
  final double widthMultiplier;

  /// 层高度 = 屏幕高度 * heightFraction
  /// HTML 中: sky=1.0, far=0.58, mid=0.52, near=0.50
  final double heightFraction;

  /// 图层透明度
  final double opacity;

  final Color? fallbackColor;

  const ParallaxLayer({
    this.assetPath,
    required this.speed,
    this.widthMultiplier = 1.0,
    this.heightFraction = 1.0,
    this.opacity = 1.0,
    this.fallbackColor,
  });
}
