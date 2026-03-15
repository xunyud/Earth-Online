import 'package:flutter/material.dart';
import '../controllers/quest_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class RecycleBinPage extends StatelessWidget {
  final QuestController controller;

  const RecycleBinPage({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>()!;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          '回收站',
          style: AppTextStyles.heading1.copyWith(
            color: theme.primaryAccentColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '恢复全部',
            icon: const Icon(Icons.restore_page_rounded),
            color: AppColors.textSecondary,
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: '恢复全部',
                message: '将把回收站内的所有任务恢复到主界面。是否继续？',
                confirmText: '确认恢复',
              );
              if (ok) {
                controller.restoreAllQuests();
              }
            },
          ),
          IconButton(
            tooltip: '清空回收站',
            icon: const Icon(Icons.delete_forever_rounded),
            color: Colors.redAccent,
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: '清空回收站',
                message: '回收站内的任务将被永久删除，无法找回。是否继续？',
                confirmText: '确认清空',
                danger: true,
              );
              if (ok) {
                controller.emptyRecycleBin();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final items = controller.trashedQuests;
          if (items.isEmpty) {
            return Center(
              child: Text(
                '回收站为空',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final q = items[index];
              return Container(
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(q.title, style: theme.questTitleStyle),
                  subtitle: Text(
                    q.questTier,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '恢复',
                        icon: const Icon(Icons.restore_rounded),
                        color: AppColors.textSecondary,
                        onPressed: () => controller.restoreQuest(q.id),
                      ),
                      IconButton(
                        tooltip: '彻底删除',
                        icon: const Icon(Icons.delete_forever_rounded),
                        color: Colors.redAccent,
                        onPressed: () => controller.permanentlyDeleteQuest(q.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
