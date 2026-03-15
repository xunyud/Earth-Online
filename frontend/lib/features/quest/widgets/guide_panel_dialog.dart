import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/theme/quest_theme.dart';

enum GuideDialogRole {
  assistant,
  user,
}

class GuideDialogMessage {
  final GuideDialogRole role;
  final String content;
  final int memoryRefCount;

  const GuideDialogMessage({
    required this.role,
    required this.content,
    this.memoryRefCount = 0,
  });
}

class GuidePanelDialog extends StatelessWidget {
  final String title;
  final String guideName;
  final String subtitle;
  final String guideMemoryTitle;
  final String guideMemorySummary;
  final List<String> guideMemorySignals;
  final String statusText;
  final String editNameLabel;
  final String closeTooltip;
  final bool statusReady;
  final List<GuideDialogMessage> messages;
  final List<String> quickActions;
  final GuideSuggestedTask? suggestedTask;
  final TextEditingController inputController;
  final String inputHintText;
  final String sendLabel;
  final String retryLabel;
  final String addTaskLabel;
  final String proposalTitle;
  final String closeLabel;
  final bool sending;
  final String Function(int count) memoryRefsLabelBuilder;
  final VoidCallback? onRetry;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onQuickActionTap;
  final VoidCallback? onAddSuggestedTask;
  final VoidCallback? onEditGuideName;
  final VoidCallback onClose;

  const GuidePanelDialog({
    super.key,
    required this.title,
    required this.guideName,
    required this.subtitle,
    required this.guideMemoryTitle,
    required this.guideMemorySummary,
    required this.guideMemorySignals,
    required this.statusText,
    required this.editNameLabel,
    required this.closeTooltip,
    required this.statusReady,
    required this.messages,
    required this.quickActions,
    required this.suggestedTask,
    required this.inputController,
    required this.inputHintText,
    required this.sendLabel,
    required this.retryLabel,
    required this.addTaskLabel,
    required this.proposalTitle,
    required this.closeLabel,
    required this.sending,
    required this.memoryRefsLabelBuilder,
    required this.onRetry,
    required this.onSubmit,
    required this.onQuickActionTap,
    required this.onAddSuggestedTask,
    required this.onEditGuideName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<QuestTheme>() ?? QuestTheme.freshBreath();
    final viewport = MediaQuery.sizeOf(context);
    final dialogHeight = math.min(viewport.height * 0.82, 760.0);
    final dialogWidth = math.min(viewport.width - 32, 860.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF9F6EB),
                Color(0xFFF5EFD9),
              ],
            ),
            border: Border.all(color: const Color(0x1F4B7D4D)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(34),
                blurRadius: 34,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideHeader(
                  title: title,
                  guideName: guideName,
                  subtitle: subtitle,
                  statusText: statusText,
                  editNameLabel: editNameLabel,
                  closeTooltip: closeTooltip,
                  statusReady: statusReady,
                  retryLabel: retryLabel,
                  sending: sending,
                  onRetry: onRetry,
                  onEditGuideName: onEditGuideName,
                  onClose: onClose,
                  theme: theme,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(118),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0x1F50744C)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      children: [
                        _GuideMemoryCard(
                          title: guideMemoryTitle,
                          summary: guideMemorySummary,
                          signals: guideMemorySignals,
                        ),
                        const SizedBox(height: 14),
                        ...messages.map((message) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GuideMessageBubble(
                              message: message,
                              memoryRefsLabel: memoryRefsLabelBuilder(
                                message.memoryRefCount,
                              ),
                              theme: theme,
                            ),
                          );
                        }),
                        if (suggestedTask != null) ...[
                          const SizedBox(height: 2),
                          _GuideSuggestedTaskCard(
                            proposalTitle: proposalTitle,
                            task: suggestedTask!,
                            addTaskLabel: addTaskLabel,
                            enabled: !sending,
                            onAddSuggestedTask: onAddSuggestedTask,
                            theme: theme,
                          ),
                        ],
                        if (quickActions.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: quickActions
                                .map(
                                  (action) => ActionChip(
                                    label: Text(action),
                                    backgroundColor:
                                        Colors.white.withAlpha(205),
                                    side: const BorderSide(
                                      color: Color(0x22547250),
                                    ),
                                    labelStyle: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF355537),
                                    ),
                                    onPressed: sending
                                        ? null
                                        : () => onQuickActionTap(action),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _GuideComposer(
                  controller: inputController,
                  hintText: inputHintText,
                  sendLabel: sendLabel,
                  sending: sending,
                  onSubmit: onSubmit,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onClose,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(closeLabel),
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

class _GuideHeader extends StatelessWidget {
  final String title;
  final String guideName;
  final String subtitle;
  final String statusText;
  final String editNameLabel;
  final String closeTooltip;
  final bool statusReady;
  final String retryLabel;
  final bool sending;
  final VoidCallback? onRetry;
  final VoidCallback? onEditGuideName;
  final VoidCallback onClose;
  final QuestTheme theme;

  const _GuideHeader({
    required this.title,
    required this.guideName,
    required this.subtitle,
    required this.statusText,
    required this.editNameLabel,
    required this.closeTooltip,
    required this.statusReady,
    required this.retryLabel,
    required this.sending,
    required this.onRetry,
    required this.onEditGuideName,
    required this.onClose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryAccentColor.withAlpha(48),
            const Color(0xFFFFF6DB),
          ],
        ),
        border: Border.all(color: const Color(0x1E4B7D4D)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.primaryAccentColor,
                        theme.mainQuestColor,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      guideName.characters.first,
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.heading2.copyWith(
                          color: const Color(0xFF1F3721),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: closeTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(176),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x164E744A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusReady
                            ? Icons.check_circle_rounded
                            : Icons.wifi_tethering_error_rounded,
                        size: 16,
                        color: statusReady
                            ? theme.primaryAccentColor
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF355537),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onEditGuideName,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(editNameLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF355537),
                    side: const BorderSide(color: Color(0x22547250)),
                    backgroundColor: Colors.white.withAlpha(168),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (!statusReady)
                  TextButton(
                    onPressed: sending ? null : onRetry,
                    child: Text(retryLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideMemoryCard extends StatelessWidget {
  final String title;
  final String summary;
  final List<String> signals;

  const _GuideMemoryCard({
    required this.title,
    required this.summary,
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDFEF6),
            Color(0xFFF4F8E5),
          ],
        ),
        border: Border.all(color: const Color(0x225B8A58)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4F724D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              style: AppTextStyles.body.copyWith(
                fontSize: 18,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF243826),
              ),
            ),
            if (signals.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: signals
                    .map(
                      (signal) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF8DC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x225B8A58)),
                        ),
                        child: Text(
                          signal,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4B694A),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideMessageBubble extends StatelessWidget {
  final GuideDialogMessage message;
  final String memoryRefsLabel;
  final QuestTheme theme;

  const _GuideMessageBubble({
    required this.message,
    required this.memoryRefsLabel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == GuideDialogRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: isUser
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryAccentColor,
                      theme.mainQuestColor,
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFF9F7F1),
                    ],
                  ),
            border: Border.all(
              color: isUser ? Colors.transparent : const Color(0x1F4B7D4D),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: AppTextStyles.body.copyWith(
                    height: 1.55,
                    color: isUser ? Colors.white : const Color(0xFF233124),
                  ),
                ),
                if (!isUser && message.memoryRefCount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F6E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      memoryRefsLabel,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4B694A),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideSuggestedTaskCard extends StatelessWidget {
  final String proposalTitle;
  final GuideSuggestedTask task;
  final String addTaskLabel;
  final bool enabled;
  final VoidCallback? onAddSuggestedTask;
  final QuestTheme theme;

  const _GuideSuggestedTaskCard({
    required this.proposalTitle,
    required this.task,
    required this.addTaskLabel,
    required this.enabled,
    required this.onAddSuggestedTask,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6FDEB),
            Color(0xFFF8F5E8),
          ],
        ),
        border: Border.all(color: const Color(0x255B8A58)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    proposalTitle,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4E6F4F),
                    ),
                  ),
                ),
                Text(
                  '+${task.xpReward} XP',
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 16,
                    color: const Color(0xFF4E6F4F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.title,
              style: AppTextStyles.heading2.copyWith(
                fontSize: 22,
                color: const Color(0xFF243826),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              task.description,
              style: AppTextStyles.body.copyWith(
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: enabled ? onAddSuggestedTask : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primaryAccentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(addTaskLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String sendLabel;
  final bool sending;
  final ValueChanged<String> onSubmit;

  const _GuideComposer({
    required this.controller,
    required this.hintText,
    required this.sendLabel,
    required this.sending,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: Colors.white.withAlpha(214),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0x255B8A58)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
            onSubmitted: sending ? null : onSubmit,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: sending ? null : () => onSubmit(controller.text),
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(sendLabel),
        ),
      ],
    );
  }
}
