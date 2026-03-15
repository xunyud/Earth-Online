import 'package:flutter/material.dart';

import '../../core/constants/app_text_styles.dart';
import '../../core/theme/quest_theme.dart';
import 'quest_dialog_shell.dart';

class ConfirmDialogResult {
  final bool confirmed;
  final bool dontAskAgain;

  const ConfirmDialogResult({
    required this.confirmed,
    required this.dontAskAgain,
  });
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确认',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final result = await showQuestDialog<bool>(
    context: context,
    barrierLabel: 'confirm_dialog',
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext).extension<QuestTheme>()!;
      final accentColor =
          danger ? const Color(0xFFF45D57) : theme.primaryAccentColor;
      return QuestDialogShell(
        title: title,
        leading: QuestDialogBadge(
          icon: danger ? Icons.logout_rounded : Icons.task_alt_rounded,
          accentColor: accentColor,
        ),
        accentColor: accentColor,
        maxWidth: 520,
        onClose: () => Navigator.pop(dialogContext, false),
        actions: [
          QuestDialogSecondaryButton(
            label: cancelText,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          QuestDialogPrimaryButton(
            label: confirmText,
            danger: danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
        child: QuestDialogInfoCard(
          accentColor: accentColor,
          icon:
              danger ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
          child: Text(
            message,
            style: AppTextStyles.body.copyWith(
              color: const Color(0xFF39463B),
              height: 1.55,
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

Future<ConfirmDialogResult> showConfirmWithDontAskDialog(
  BuildContext context, {
  required String title,
  required String message,
  String dontAskLabel = '下次不再提醒',
}) async {
  var dontAskAgain = false;

  final res = await showQuestDialog<bool>(
    context: context,
    barrierLabel: 'confirm_dont_ask',
    builder: (dialogContext) => StatefulBuilder(
      builder: (statefulContext, setState) {
        final theme = Theme.of(dialogContext).extension<QuestTheme>()!;
        return QuestDialogShell(
          title: title,
          leading: QuestDialogBadge(
            icon: Icons.notifications_active_rounded,
            accentColor: theme.primaryAccentColor,
          ),
          maxWidth: 560,
          onClose: () => Navigator.pop(dialogContext, false),
          actions: [
            QuestDialogSecondaryButton(
              label: '取消',
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            QuestDialogPrimaryButton(
              label: '确认',
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuestDialogInfoCard(
                icon: Icons.info_outline_rounded,
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFF39463B),
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              QuestDialogInfoCard(
                icon: Icons.checklist_rounded,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: [
                    Checkbox(
                      value: dontAskAgain,
                      onChanged: (value) =>
                          setState(() => dontAskAgain = value == true),
                    ),
                    Expanded(
                      child: Text(
                        dontAskLabel,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          color: const Color(0xFF39463B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return ConfirmDialogResult(
    confirmed: res == true,
    dontAskAgain: dontAskAgain,
  );
}
