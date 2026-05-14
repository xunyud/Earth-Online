import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/theme/quest_theme.dart';

/// 用户画像洞察数据
class PortraitInsightData {
  final String summary;
  final List<String> evaluations;
  final int energyScore;
  final int rhythmScore;
  final int resilienceScore;
  final int awarenessScore;

  const PortraitInsightData({
    required this.summary,
    required this.evaluations,
    required this.energyScore,
    required this.rhythmScore,
    required this.resilienceScore,
    required this.awarenessScore,
  });

  factory PortraitInsightData.fromPortrait(
    GuidePortraitResult portrait,
    String guideName,
  ) {
    final summary = portrait.summary.trim().isEmpty
        ? AppLocaleController.instance.t('profile.analysis_fallback')
        : portrait.summary.trim();
    final summaryLength = summary.runes.length;
    final energyScore =
        (42 + portrait.memoryRefs.length * 9 + (summaryLength ~/ 18))
            .clamp(28, 92);
    final rhythmScore = (38 +
            portrait.memoryRefs.length * 7 +
            (portrait.traceId.isEmpty ? 4 : 16))
        .clamp(24, 90);
    final resilienceScore =
        (34 + (summaryLength ~/ 16) + (portrait.seed >= 0 ? 12 : 0))
            .clamp(20, 88);
    final awarenessScore =
        (40 + (summaryLength ~/ 14) + (portrait.memoryRefs.length * 5))
            .clamp(26, 94);
    final evaluations = buildPortraitEvaluations(
      guideName: guideName,
      summary: summary,
      memoryRefs: portrait.memoryRefs,
      energyScore: energyScore,
      rhythmScore: rhythmScore,
      resilienceScore: resilienceScore,
      awarenessScore: awarenessScore,
      isEnglish: AppLocaleController.instance.isEnglish,
    );

    return PortraitInsightData(
      summary: summary,
      evaluations: evaluations,
      energyScore: energyScore,
      rhythmScore: rhythmScore,
      resilienceScore: resilienceScore,
      awarenessScore: awarenessScore,
    );
  }
}

/// 构建用户画像评估文本
List<String> buildPortraitEvaluations({
  required String guideName,
  required String summary,
  required List<String> memoryRefs,
  required int energyScore,
  required int rhythmScore,
  required int resilienceScore,
  required int awarenessScore,
  required bool isEnglish,
}) {
  String pick(String zh, String en) => isEnglish ? en : zh;

  final evaluations = <String>[
    if (energyScore >= 75)
      pick(
        '$guideName觉得你最近是带着推进力在行动，不太像只靠情绪硬撑。',
        '$guideName feels that you have been moving with real momentum lately, not just forcing yourself through emotions.',
      )
    else if (energyScore >= 55)
      pick(
        '$guideName觉得你还有行动意愿，但更适合用小步推进，而不是一下把自己拉满。',
        '$guideName feels you still want to move, but small steps fit better than trying to push yourself to the limit.',
      )
    else
      pick(
        '$guideName觉得你现在更需要先回收精力，温和启动会比强推自己更有效。',
        '$guideName feels you need to recover your energy first. A gentle start will work better than forcing yourself.',
      ),
    if (rhythmScore >= 72)
      pick(
        '你的节奏感比较稳，说明你已经在形成"做一点也算前进"的惯性。',
        'Your rhythm looks steady, which suggests you are building the habit that even a small step still counts as progress.',
      )
    else if (rhythmScore >= 50)
      pick(
        '你的节奏正在恢复中，关键不是更拼，而是把重复的小动作守住。',
        'Your rhythm is coming back. The key is not pushing harder, but protecting the small repeatable actions.',
      )
    else
      pick(
        '你的节奏还偏散，$guideName更建议先固定一个最容易完成的起手动作。',
        'Your rhythm is still a bit scattered, so $guideName suggests locking in the easiest starter action first.',
      ),
    if (resilienceScore >= 70)
      pick(
        '遇到波动时，你有把自己拉回来的能力，这说明恢复力已经在长出来了。',
        'When things wobble, you can pull yourself back. That shows your resilience is already growing.',
      )
    else if (resilienceScore >= 48)
      pick(
        '你有恢复的趋势，但还需要更明显的休息边界和回弹空间。',
        'You are trending toward recovery, but you still need clearer rest boundaries and more space to bounce back.',
      )
    else
      pick(
        '$guideName觉得你最近容易被消耗，先保证恢复感，比继续加任务更重要。',
        '$guideName feels you have been easy to drain lately, so protecting recovery matters more than adding more tasks.',
      ),
    if (awarenessScore >= 72)
      pick(
        '你对自己状态的观察是在线的，这会让你更容易做出适合当下的选择。',
        'You are noticing your own state in real time, which makes it easier to choose what fits this moment.',
      )
    else if (awarenessScore >= 52)
      pick(
        '你已经能感知到自己的状态变化，再多一点记录会让判断更稳定。',
        'You can already feel your state shifting. A little more logging will make your judgment steadier.',
      )
    else
      pick(
        '$guideName觉得你还在一边做一边摸索，先把感受说清楚，比追求标准答案更重要。',
        '$guideName feels you are still figuring things out as you go, so naming how it feels matters more than chasing a perfect answer.',
      ),
  ];

  if (memoryRefs.isNotEmpty) {
    evaluations.add(
      pick(
        '这次$guideName参考了 ${memoryRefs.length} 段近期记忆，所以更像一份阶段观察，不是一次性的情绪判断。',
        'This time $guideName referenced ${memoryRefs.length} recent memories, so this reads more like a stage snapshot than a one-off mood judgment.',
      ),
    );
  }
  if (summary.length <= 40) {
    evaluations.add(
      pick(
        '目前样本还不算多，等你积累更多记录后，$guideName的判断会更具体也更贴身。',
        'The sample is still fairly small. Once you build up more records, $guideName can make a more specific and personal read.',
      ),
    );
  }
  return evaluations.take(4).toList();
}

/// 可读的指标等级
String readableMetricLevel(BuildContext context, int score) {
  if (score >= 78) {
    return context.tr('profile.metric.level_high');
  }
  if (score >= 56) {
    return context.tr('profile.metric.level_mid');
  }
  return context.tr('profile.metric.level_low');
}

/// 可读的指标详情
String readableMetricDetail(BuildContext context, String key, int score) {
  final level = score >= 78
      ? 'high'
      : score >= 56
          ? 'mid'
          : 'low';
  return context.tr('profile.metric.$key.$level');
}

/// 用户画像柱状图数据
class PortraitBarDatum {
  final String label;
  final int value;
  final Color color;

  const PortraitBarDatum({
    required this.label,
    required this.value,
    required this.color,
  });

  String readableLevel(BuildContext context) {
    return readableMetricLevel(context, value);
  }
}

/// 用户画像指标网格数据
class PortraitMetricDatum {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const PortraitMetricDatum({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

/// 用户画像柱状图
class PortraitInsightChart extends StatelessWidget {
  final PortraitInsightData insight;
  final QuestTheme theme;

  const PortraitInsightChart({
    super.key,
    required this.insight,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bars = <PortraitBarDatum>[
      PortraitBarDatum(
        label: context.tr('profile.metric.energy'),
        value: insight.energyScore,
        color: theme.primaryAccentColor,
      ),
      PortraitBarDatum(
        label: context.tr('profile.metric.rhythm'),
        value: insight.rhythmScore,
        color: theme.mainQuestColor,
      ),
      PortraitBarDatum(
        label: context.tr('profile.metric.resilience'),
        value: insight.resilienceScore,
        color: theme.sideQuestColor,
      ),
      PortraitBarDatum(
        label: context.tr('profile.metric.awareness'),
        value: insight.awarenessScore,
        color: const Color(0xFFFFB74D),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryAccentColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('profile.metric.title'),
            style: AppTextStyles.heading2.copyWith(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 188,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = bars[group.x.toInt()];
                      return BarTooltipItem(
                        '${item.label}\n${item.readableLevel(context)}',
                        AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.textHint.withAlpha(36),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            bars[index].label,
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(
                  bars.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: bars[index].value.toDouble(),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: bars[index].color,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 用户画像可读指标网格
class PortraitReadableMetricGrid extends StatelessWidget {
  final PortraitInsightData insight;
  final QuestTheme theme;

  const PortraitReadableMetricGrid({
    super.key,
    required this.insight,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final items = <PortraitMetricDatum>[
      PortraitMetricDatum(
        label: context.tr('profile.metric.energy'),
        value: readableMetricLevel(context, insight.energyScore),
        detail: readableMetricDetail(context, 'energy', insight.energyScore),
        icon: Icons.local_fire_department_rounded,
        color: theme.primaryAccentColor,
      ),
      PortraitMetricDatum(
        label: context.tr('profile.metric.rhythm'),
        value: readableMetricLevel(context, insight.rhythmScore),
        detail: readableMetricDetail(context, 'rhythm', insight.rhythmScore),
        icon: Icons.timeline_rounded,
        color: const Color(0xFFFFB74D),
      ),
      PortraitMetricDatum(
        label: context.tr('profile.metric.resilience'),
        value: readableMetricLevel(context, insight.resilienceScore),
        detail: readableMetricDetail(
          context,
          'resilience',
          insight.resilienceScore,
        ),
        icon: Icons.spa_rounded,
        color: theme.sideQuestColor,
      ),
      PortraitMetricDatum(
        label: context.tr('profile.metric.awareness'),
        value: readableMetricLevel(context, insight.awarenessScore),
        detail: readableMetricDetail(
          context,
          'awareness',
          insight.awarenessScore,
        ),
        icon: Icons.visibility_rounded,
        color: theme.mainQuestColor,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Container(
              width: 188,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(165),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 18, color: item.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading2.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// 用户画像评估区域
class PortraitEvaluationSection extends StatelessWidget {
  final PortraitInsightData insight;
  final QuestTheme theme;
  final String guideName;

  const PortraitEvaluationSection({
    super.key,
    required this.insight,
    required this.theme,
    required this.guideName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            'profile.evaluation_title',
            params: {'name': guideName},
          ),
          style: AppTextStyles.heading2.copyWith(
            fontSize: 17,
            color: theme.primaryAccentColor,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: insight.evaluations
              .map(
                (evaluation) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(160),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primaryAccentColor.withAlpha(38),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.psychology_alt_rounded,
                        size: 18,
                        color: theme.primaryAccentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          evaluation,
                          style: AppTextStyles.body.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
