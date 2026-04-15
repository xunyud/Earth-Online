import 'package:flutter/material.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../models/stats_data.dart';

/// 里程碑高光区域
/// 使用 Wrap 布局展示胶囊形徽章，已达成为金色，未达成为灰色
class MilestoneHighlights extends StatelessWidget {
  final List<MilestoneData> milestones;
  final Animation<double> animation;
  final bool isCompact;

  const MilestoneHighlights({
    Key? key,
    required this.milestones,
    required this.animation,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('stats.milestones_title'),
                style: StatsTextStyles.sectionTitle,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: milestones.map(_buildBadge).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(MilestoneData m) {
    final bgColor = m.isEarned ? StatsColors.goldLight : StatsColors.gridLine;
    final fgColor =
        m.isEarned ? StatsColors.goldPrimary : StatsColors.subtitleText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m.icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            m.label,
            style: StatsTextStyles.badgeText.copyWith(color: fgColor),
          ),
        ],
      ),
    );
  }
}
