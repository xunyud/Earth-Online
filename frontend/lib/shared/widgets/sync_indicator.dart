import 'package:flutter/material.dart';

class WeChatSyncIndicator extends StatefulWidget {
  final bool isSyncing;
  const WeChatSyncIndicator({Key? key, required this.isSyncing}) : super(key: key);

  @override
  State<WeChatSyncIndicator> createState() => _WeChatSyncIndicatorState();
}

class _WeChatSyncIndicatorState extends State<WeChatSyncIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSyncing) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _controller,
      child: const Icon(Icons.sync, color: Colors.blue),
    );
  }
}
