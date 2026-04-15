import 'package:flutter/material.dart';
import '../controllers/quest_controller.dart';
import '../../../core/theme/quest_theme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
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
          context.tr('recycle.title'),
          style: AppTextStyles.heading1.copyWith(
            color: theme.primaryAccentColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('recycle.restore_all.tooltip'),
            icon: const Icon(Icons.restore_page_rounded),
            color: AppColors.textSecondary,
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: context.tr('recycle.restore_all.title'),
                message: context.tr('recycle.restore_all.message'),
                confirmText: context.tr('recycle.restore_all.confirm'),
              );
              if (ok) {
                controller.restoreAllQuests();
              }
            },
          ),
          IconButton(
            tooltip: context.tr('recycle.empty_bin.tooltip'),
            icon: const Icon(Icons.delete_forever_rounded),
            color: Colors.redAccent,
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: context.tr('recycle.empty_bin.title'),
                message: context.tr('recycle.empty_bin.message'),
                confirmText: context.tr('recycle.empty_bin.confirm'),
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
                context.tr('recycle.empty'),
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
                        tooltip: context.tr('recycle.restore.tooltip'),
                        icon: const Icon(Icons.restore_rounded),
                        color: AppColors.textSecondary,
                        onPressed: () => controller.restoreQuest(q.id),
                      ),
                      IconButton(
                        tooltip: context.tr('recycle.delete.tooltip'),
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
