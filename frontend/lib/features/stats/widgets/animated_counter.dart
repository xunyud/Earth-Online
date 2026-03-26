import 'package:flutter/material.dart';

/// 动画数字计数器
/// 从 0 平滑过渡到目标值，用于英雄卡的 XP 展示
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final String Function(int)? formatter;
  final Duration duration;

  const AnimatedCounter({
    Key? key,
    required this.value,
    required this.style,
    this.formatter,
    this.duration = const Duration(milliseconds: 1000),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        final display = formatter != null
            ? formatter!(val.toInt())
            : _defaultFormat(val.toInt());
        return Text(display, style: style);
      },
    );
  }

  String _defaultFormat(int v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    // 千分位逗号
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
