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
  /// 本条回复引用的记忆片段 ID 列表，用于记忆可见性展示
  final List<String> memoryRefs;

  const GuideDialogMessage({
    required this.role,
    required this.content,
    this.memoryRefCount = 0,
    this.memoryRefs = const <String>[],
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
  final List<String> messageHistory;
  final String inputHintText;
  final String sendLabel;
  final String retryLabel;
  final String closeLabel;
  final String copyMessageTooltip;
  final bool sending;
  final String Function(int count) memoryRefsLabelBuilder;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onCopyMessage;
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
    this.messageHistory = const <String>[],
    required this.inputHintText,
    required this.sendLabel,
    required this.retryLabel,
    required this.closeLabel,
    this.copyMessageTooltip = '',
    required this.sending,
    required this.memoryRefsLabelBuilder,
    required this.onRetry,
    this.onCopyMessage,
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
                              copyMessageTooltip: copyMessageTooltip,
                              onCopyMessage: onCopyMessage,
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
                  messageHistory: messageHistory,
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

/// 对话气泡组件
/// 长按气泡可复制整条消息；SelectableText 支持选中部分文字后通过系统菜单复制。
/// 复制按钮不再常驻，避免气泡臃肿。
/// 助手消息底部显示记忆引用标签，点击可展开查看引用的记忆片段 ID。
class _GuideMessageBubble extends StatefulWidget {
  final GuideDialogMessage message;
  final String memoryRefsLabel;
  final String copyMessageTooltip;
  final ValueChanged<String>? onCopyMessage;
  final QuestTheme theme;

  const _GuideMessageBubble({
    required this.message,
    required this.memoryRefsLabel,
    required this.copyMessageTooltip,
    required this.onCopyMessage,
    required this.theme,
  });

  @override
  State<_GuideMessageBubble> createState() => _GuideMessageBubbleState();
}

class _GuideMessageBubbleState extends State<_GuideMessageBubble> {
  /// 长按后短暂高亮，给用户视觉反馈
  bool _pressed = false;
  /// 记忆片段列表是否展开
  bool _memoryExpanded = false;

  void _handleLongPress() {
    final handler = widget.onCopyMessage;
    if (handler == null) return;
    handler(widget.message.content);
    setState(() => _pressed = true);
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _pressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == GuideDialogRole.user;
    final canCopy = widget.onCopyMessage != null;
    final refs = widget.message.memoryRefs;
    final hasMemory = !isUser && refs.isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: GestureDetector(
          key: ValueKey('bubble-${widget.message.role.name}-${widget.message.content.hashCode}'),
          onLongPress: canCopy ? _handleLongPress : null,
          child: AnimatedOpacity(
            // 长按时短暂降低不透明度作为反馈
            opacity: _pressed ? 0.65 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: isUser
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.theme.primaryAccentColor,
                          widget.theme.mainQuestColor,
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
                  color:
                      isUser ? Colors.transparent : const Color(0x1F4B7D4D),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      widget.message.content,
                      style: AppTextStyles.body.copyWith(
                        height: 1.55,
                        color:
                            isUser ? Colors.white : const Color(0xFF233124),
                      ),
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.editableText(
                          editableTextState: editableTextState,
                        );
                      },
                    ),
                    // 记忆引用标签：可点击展开查看具体片段
                    if (hasMemory) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _memoryExpanded = !_memoryExpanded),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F6E2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.memory_rounded,
                                size: 13,
                                color: Color(0xFF4B694A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.memoryRefsLabel,
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4B694A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _memoryExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 13,
                                color: const Color(0xFF4B694A),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 展开后显示记忆片段 ID 列表
                      if (_memoryExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FCF0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x225B8A58)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: refs.take(8).map((ref) {
                              // 把 ref 格式化为可读标签：mem_recent:uuid → 近期记忆
                              final label = _formatMemoryRef(ref);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '·',
                                      style: TextStyle(
                                        color: Color(0xFF4B694A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: AppTextStyles.caption.copyWith(
                                          color: const Color(0xFF5A7654),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 把内部 ref 格式转换为用户可读标签
  String _formatMemoryRef(String ref) {
    if (ref.startsWith('mem_agentic:')) return '🎯 智能关联记忆';
    if (ref.startsWith('mem_recent:')) return '📅 近期记忆片段';
    if (ref.startsWith('mem_long:')) return '🗂 长期历史回调';
    if (ref.startsWith('mem_cross:')) return '🔗 跨任务关联';
    if (ref.startsWith('quest:')) {
      final id = ref.replaceFirst('quest:', '');
      return '✅ 任务记录 $id';
    }
    if (ref.startsWith('daily_log:')) {
      final date = ref.split(':').elementAtOrNull(1) ?? '';
      return '📊 日志 $date';
    }
    if (ref.startsWith('dialog:')) return '💬 对话历史';
    return ref;
  }
}

class _GuideComposer extends StatefulWidget {
  final TextEditingController controller;
  final List<String> messageHistory;
  final String hintText;
  final String sendLabel;
  final bool sending;
  final ValueChanged<String> onSubmit;

  const _GuideComposer({
    required this.controller,
    required this.messageHistory,
    required this.hintText,
    required this.sendLabel,
    required this.sending,
    required this.onSubmit,
  });

  @override
  State<_GuideComposer> createState() => _GuideComposerState();
}

class _GuideComposerState extends State<_GuideComposer> {
  bool _applyingHistoryValue = false;
  int? _historyIndex;
  String _draftText = '';

  List<String> get _history => widget.messageHistory
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _GuideComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (_historyIndex != null && _history.isEmpty) {
      _historyIndex = null;
      _draftText = '';
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_applyingHistoryValue || _historyIndex == null) return;
    _historyIndex = null;
    _draftText = widget.controller.text;
  }

  bool _isSingleLineInput() => !widget.controller.text.contains('\n');

  bool _canRecallPreviousMessage() {
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return false;
    return _isSingleLineInput() || selection.baseOffset <= 0;
  }

  bool _canRecallNextMessage() {
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return false;
    return _isSingleLineInput() ||
        selection.baseOffset >= widget.controller.text.length;
  }

  void _applyComposerText(String text) {
    _applyingHistoryValue = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _applyingHistoryValue = false;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (widget.sending) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final text = widget.controller.text.trim();
      if (text.isNotEmpty) {
        widget.onSubmit(text);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final history = _history;
      if (history.isEmpty || !_canRecallPreviousMessage()) {
        return KeyEventResult.ignored;
      }
      if (_historyIndex == null) {
        _draftText = widget.controller.text;
        _historyIndex = history.length - 1;
      } else if (_historyIndex! > 0) {
        _historyIndex = _historyIndex! - 1;
      }
      _applyComposerText(history[_historyIndex!]);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final history = _history;
      if (history.isEmpty ||
          _historyIndex == null ||
          !_canRecallNextMessage()) {
        return KeyEventResult.ignored;
      }
      if (_historyIndex! < history.length - 1) {
        _historyIndex = _historyIndex! + 1;
        _applyComposerText(history[_historyIndex!]);
        return KeyEventResult.handled;
      }
      _historyIndex = null;
      _applyComposerText(_draftText);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ??
        QuestTheme.forestAdventure();
    final accent = theme.primaryAccentColor;

    return Row(
      children: [
        Expanded(
          child: Focus(
            onKeyEvent: (_, event) => _handleKeyEvent(event),
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 3,
              cursorColor: accent,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: widget.hintText,
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
          onPressed: widget.sending
              ? null
              : () => widget.onSubmit(widget.controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: accent.withValues(alpha: 0.4),
            minimumSize: const Size(110, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: widget.sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.sendLabel),
        ),
      ],
    );
  }
}
