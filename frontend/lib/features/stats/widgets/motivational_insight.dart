import 'package:flutter/material.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';

/// 成长感言 / 激励洞察模块
/// 根据数据自动生成一句鼓励性文案
class MotivationalInsight extends StatelessWidget {
  final String insight;
  final Animation<double> animation;
  final bool isCompact;

  const MotivationalInsight({
    Key? key,
    required this.insight,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.0 : 20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: StatsColors.sageTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: StatsColors.softSage.withAlpha(60),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: StatsColors.softSage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight,
                    style: StatsTextStyles.insightBody,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
