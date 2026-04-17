import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
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
  final List<String> examplePrompts;
  final TextEditingController inputController;
  final String inputHintText;
  final String sendLabel;
  final String retryLabel;
  final String closeLabel;
  final bool sending;
  final String Function(int count) memoryRefsLabelBuilder;
  final VoidCallback? onRetry;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onQuickActionTap;
  final ValueChanged<String> onExamplePromptTap;
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
    required this.examplePrompts,
    required this.inputController,
    required this.inputHintText,
    required this.sendLabel,
    required this.retryLabel,
    required this.closeLabel,
    required this.sending,
    required this.memoryRefsLabelBuilder,
    required this.onRetry,
    required this.onSubmit,
    required this.onQuickActionTap,
    required this.onExamplePromptTap,
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
                        if (messages.isNotEmpty) const SizedBox(height: 14),
                        ...messages.map(
                          (message) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GuideMessageBubble(
                              message: message,
                              memoryRefsLabel: memoryRefsLabelBuilder(
                                message.memoryRefCount,
                              ),
                              theme: theme,
                            ),
                          ),
                        ),
                        if (quickActions.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            key: const ValueKey('guide-entry-actions'),
                            child: Wrap(
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
                                      labelStyle:
                                          AppTextStyles.caption.copyWith(
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
                          ),
                        ],
                        if (examplePrompts.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            key: const ValueKey('guide-dynamic-actions'),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: examplePrompts
                                  .map(
                                    (prompt) => ActionChip(
                                      label: Text(prompt),
                                      avatar: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                        color: Color(0xFF4A6B49),
                                      ),
                                      backgroundColor: const Color(0xFFF6FBEA),
                                      side: const BorderSide(
                                        color: Color(0x22547250),
                                      ),
                                      labelStyle:
                                          AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF355537),
                                      ),
                                      onPressed: sending
                                          ? null
                                          : () => onExamplePromptTap(prompt),
                                    ),
                                  )
                                  .toList(),
                            ),
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
    final canEditGuideName = onEditGuideName != null;

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
                      title.characters.first,
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Tooltip(
                    message: editNameLabel,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('guide-name-trigger'),
                        onTap: onEditGuideName,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: AppTextStyles.heading2.copyWith(
                                        color: const Color(0xFF1F3721),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (canEditGuideName) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: Color(0xFF5A7654),
                                    ),
                                  ],
                                ],
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
                      ),
                    ),
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
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final accent = theme.primaryAccentColor;

    return Row(
      children: [
        Expanded(
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (sending) return;
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                final text = controller.text.trim();
                if (text.isNotEmpty) onSubmit(text);
              }
            },
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              cursorColor: accent,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textHint,
                ),
                filled: true,
                fillColor: theme.surfaceColor.withValues(alpha: 0.85),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: accent.withValues(alpha: 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: accent.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: accent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: sending ? null : () => onSubmit(controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: accent.withValues(alpha: 0.4),
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
