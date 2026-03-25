import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../quest/controllers/quest_controller.dart';
import '../controllers/stats_controller.dart';
import '../widgets/completion_chart.dart';
import '../widgets/highlight_cards.dart';
import '../widgets/tier_pie_chart.dart';
import '../widgets/xp_curve_chart.dart';

class StatsPage extends StatefulWidget {
  final QuestController questController;

  const StatsPage({Key? key, required this.questController}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final StatsController _stats;

  @override
  void initState() {
    super.initState();
    _stats = StatsController(questController: widget.questController);
    _stats.loadAll();
  }

  @override
  void dispose() {
    _stats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('stats.title'),
          style: AppTextStyles.heading1.copyWith(
            color: theme.primaryAccentColor,
          ),
        ),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: _stats,
        builder: (context, _) {
          if (_stats.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.primaryAccentColor,
                strokeWidth: 2.5,
              ),
            );
          }

          if (!_stats.hasData) {
            return _buildEmptyState(context, theme);
          }

          return _buildContent(theme);
        },
      ),
    );
  }

  Widget _buildContent(QuestTheme theme) {
    final recent30Xp =
        _stats.xpCurve.isNotEmpty ? _stats.xpCurve.last.cumulativeXp : 0;
    final xpBefore = _stats.highlights.totalXp - recent30Xp;

    return RefreshIndicator(
      color: theme.primaryAccentColor,
      onRefresh: _stats.loadAll,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 8),
          HighlightCards(data: _stats.highlights),
          const SizedBox(height: 28),
          CompletionChart(stats: _stats.dailyStats),
          const SizedBox(height: 28),
          if (_stats.xpCurve.isNotEmpty) ...[
            XpCurveChart(
              points: _stats.xpCurve,
              totalXpBefore: xpBefore.clamp(0, xpBefore),
            ),
            const SizedBox(height: 28),
          ],
          if (_stats.tierCounts.isNotEmpty)
            TierPieChart(tiers: _stats.tierCounts),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, QuestTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 64,
              color: AppColors.textHint.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('stats.empty_title'),
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('stats.empty_body'),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
