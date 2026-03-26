import 'package:flutter/material.dart';

import '../../quest/controllers/quest_controller.dart';
import '../controllers/stats_controller.dart';
import '../theme/stats_colors.dart';
import '../theme/stats_text_styles.dart';
import '../widgets/stats_header.dart';
import '../widgets/hero_xp_card.dart';
import '../widgets/summary_metrics_row.dart';
import '../widgets/completion_chart.dart';
import '../widgets/xp_curve_chart.dart';
import '../widgets/tier_pie_chart.dart';
import '../widgets/motivational_insight.dart';
import '../widgets/milestone_highlights.dart';
import '../widgets/streak_calendar.dart';

class StatsPage extends StatefulWidget {
  final QuestController questController;

  const StatsPage({Key? key, required this.questController}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  late final StatsController _stats;
  late final AnimationController _animCtrl;
  bool _animStarted = false;

  // 各区域的交错动画
  late final Animation<double> _headerAnim;
  late final Animation<double> _heroAnim;
  late final Animation<double> _summaryAnim;
  late final Animation<double> _calendarAnim;
  late final Animation<double> _chart1Anim;
  late final Animation<double> _chart2Anim;
  late final Animation<double> _chart3Anim;
  late final Animation<double> _insightAnim;
  late final Animation<double> _milestoneAnim;

  @override
  void initState() {
    super.initState();
    _stats = StatsController(questController: widget.questController);
    _stats.loadAll();

    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 定义交错时间间隔
    _headerAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    );
    _heroAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.05, 0.4, curve: Curves.easeOutCubic),
    );
    _summaryAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic),
    );
    _calendarAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.20, 0.55, curve: Curves.easeOutCubic),
    );
    _chart1Anim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.28, 0.63, curve: Curves.easeOutCubic),
    );
    _chart2Anim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
    );
    _chart3Anim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.40, 0.75, curve: Curves.easeOutCubic),
    );
    _insightAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.50, 0.85, curve: Curves.easeOutCubic),
    );
    _milestoneAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _stats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StatsColors.creamBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: StatsColors.subtitleText,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: _stats,
        builder: (context, _) {
          if (_stats.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: StatsColors.goldPrimary,
                strokeWidth: 2.5,
              ),
            );
          }

          if (!_stats.hasData) {
            return _buildEmptyState();
          }

          // 数据加载完成后触发入场动画（仅一次）
          if (!_animStarted) {
            _animStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _animCtrl.forward();
            });
          }

          return _buildContent();
        },
      ),
    );
  }

  Widget _buildContent() {
    final recent30Xp = _stats.recent30DaysXp;
    final xpBefore = _stats.highlights.totalXp - recent30Xp;
    final lp = widget.questController.levelProgress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final isWide = constraints.maxWidth > 900;
        final sectionSpacing = isCompact ? 20.0 : 28.0;

        Widget content = RefreshIndicator(
          color: StatsColors.goldPrimary,
          onRefresh: _stats.loadAll,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // 1. Header
              StatsHeader(
                streakDays: _stats.highlights.longestStreak,
                animation: _headerAnim,
              ),

              // 2. 英雄 XP 卡片
              HeroXpCard(
                totalXp: _stats.highlights.totalXp,
                levelProgress: lp,
                animation: _heroAnim,
                isCompact: isCompact,
              ),
              SizedBox(height: sectionSpacing),

              // 3. 三卡摘要
              SummaryMetricsRow(
                data: _stats.highlights,
                animation: _summaryAnim,
                isCompact: isCompact,
              ),
              SizedBox(height: sectionSpacing),

              // 3.5 签到日历 + 补签
              StreakCalendar(
                controller: _stats,
                animation: _calendarAnim,
                isCompact: isCompact,
              ),
              SizedBox(height: sectionSpacing),

              // 4. 任务完成趋势
              CompletionChart(
                stats: _stats.dailyStats,
                animation: _chart1Anim,
                isCompact: isCompact,
              ),
              SizedBox(height: sectionSpacing),

              // 5. XP 成长曲线
              if (_stats.xpCurve.isNotEmpty) ...[
                XpCurveChart(
                  points: _stats.xpCurve,
                  totalXpBefore: xpBefore < 0 ? 0 : xpBefore,
                  recent30DaysXp: recent30Xp,
                  animation: _chart2Anim,
                  isCompact: isCompact,
                ),
                SizedBox(height: sectionSpacing),
              ],

              // 6. 任务构成
              if (_stats.tierCounts.isNotEmpty) ...[
                QuestMixCard(
                  tiers: _stats.tierCounts,
                  animation: _chart3Anim,
                  isCompact: isCompact,
                ),
                SizedBox(height: sectionSpacing),
              ],

              // 7. 成长感言
              MotivationalInsight(
                insight: _stats.motivationalInsight,
                animation: _insightAnim,
                isCompact: isCompact,
              ),
              SizedBox(height: sectionSpacing),

              // 8. 里程碑
              MilestoneHighlights(
                milestones: _stats.milestones,
                animation: _milestoneAnim,
                isCompact: isCompact,
              ),
            ],
          ),
        );

        // 宽屏居中约束
        if (isWide) {
          content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 64,
              color: StatsColors.subtitleText.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              '还没有数据',
              style: StatsTextStyles.sectionTitle.copyWith(
                color: StatsColors.subtitleText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成一些任务后，这里会展示你的成长轨迹',
              style: StatsTextStyles.metricLabel.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
