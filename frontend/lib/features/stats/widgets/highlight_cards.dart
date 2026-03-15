import 'package:flutter/material.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/stats_data.dart';

/// 亮点数据横向滚动卡片
class HighlightCards extends StatelessWidget {
  final HighlightData data;

  const HighlightCards({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    final cards = <_CardInfo>[
      _CardInfo(
        icon: Icons.check_circle_outline_rounded,
        label: '本周完成',
        value: '${data.weeklyCompleted}',
        color: theme.mainQuestColor,
      ),
      _CardInfo(
        icon: Icons.star_rounded,
        label: '累计 XP',
        value: _formatXp(data.totalXp),
        color: const Color(0xFFFFB74D),
      ),
      _CardInfo(
        icon: Icons.shield_rounded,
        label: 'Lv.${data.currentLevel}',
        value: data.levelTitle,
        color: theme.primaryAccentColor,
      ),
      _CardInfo(
        icon: Icons.local_fire_department_rounded,
        label: '最长连续',
        value: '${data.longestStreak}天',
        color: Colors.deepOrange,
      ),
      _CardInfo(
        icon: Icons.emoji_events_rounded,
        label: '最高效一天',
        value: data.bestDayCount > 0
            ? '${data.bestDayCount}个任务'
            : '—',
        color: theme.sideQuestColor,
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final c = cards[index];
          return _HighlightCard(
            info: c,
            surfaceColor: theme.surfaceColor,
          );
        },
      ),
    );
  }

  String _formatXp(int xp) {
    if (xp >= 10000) return '${(xp / 1000).toStringAsFixed(1)}k';
    return '$xp';
  }
}

class _CardInfo {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CardInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _HighlightCard extends StatelessWidget {
  final _CardInfo info;
  final Color surfaceColor;

  const _HighlightCard({
    required this.info,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, size: 18, color: info.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            info.value,
            style: AppTextStyles.heading2.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: info.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
