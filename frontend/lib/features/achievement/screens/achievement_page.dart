import 'package:flutter/material.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../controllers/achievement_controller.dart';
import '../widgets/achievement_card.dart';

/// 成就列表页面
/// 按分类展示所有成就，已解锁的排在前面
class AchievementPage extends StatefulWidget {
  final AchievementController achievementController;

  const AchievementPage({
    Key? key,
    required this.achievementController,
  }) : super(key: key);

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.achievementController.loadAll();
    });
  }

  // 分类元数据：(显示名, 图标, 颜色)
  static const _categoryMeta = <String, (String, IconData, Color)>{
    'quest': ('任务成就', Icons.assignment_rounded, Color(0xFF66BB6A)),
    'streak': ('签到成就', Icons.local_fire_department_rounded, Color(0xFFFFA726)),
    'xp': ('经验成就', Icons.trending_up_rounded, Color(0xFF42A5F5)),
    'special': ('特殊成就', Icons.stars_rounded, Color(0xFF2E7D32)),
  };

  static const _categoryOrder = ['quest', 'streak', 'xp', 'special'];

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
          '成就殿堂',
          style: AppTextStyles.heading1.copyWith(
            color: theme.primaryAccentColor,
          ),
        ),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: widget.achievementController,
        builder: (context, _) {
          final ctrl = widget.achievementController;

          if (ctrl.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.primaryAccentColor,
                strokeWidth: 2.5,
              ),
            );
          }

          if (ctrl.achievements.isEmpty) {
            return _buildEmptyState(theme);
          }

          return _buildContent(ctrl, theme);
        },
      ),
    );
  }

  Widget _buildContent(AchievementController ctrl, QuestTheme theme) {
    // 统计解锁数
    final total = ctrl.achievements.length;
    final unlocked = ctrl.achievements.where((a) => a.isUnlocked).length;

    final sections = <Widget>[
      // 顶部进度概览
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Text(
              '已解锁 $unlocked / $total',
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: total > 0 ? unlocked / total : 0,
                  backgroundColor: AppColors.textHint.withAlpha(40),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.primaryAccentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    // 按分类渲染
    for (final cat in _categoryOrder) {
      final meta = _categoryMeta[cat];
      if (meta == null) continue;
      final items = ctrl.achievementsByCategory(cat);
      if (items.isEmpty) continue;

      // 已解锁的排在前面
      items.sort((a, b) {
        if (a.isUnlocked && !b.isUnlocked) return -1;
        if (!a.isUnlocked && b.isUnlocked) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });

      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(meta.$2, size: 18, color: meta.$3),
              const SizedBox(width: 6),
              Text(
                meta.$1,
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: meta.$3,
                ),
              ),
            ],
          ),
        ),
      );

      for (final a in items) {
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AchievementCard(
              achievement: a,
              categoryColor: meta.$3,
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: sections,
    );
  }

  Widget _buildEmptyState(QuestTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 64,
              color: AppColors.textHint.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              '成就系统加载中',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成任务和签到来解锁成就徽章',
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
