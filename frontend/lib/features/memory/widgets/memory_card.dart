import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/memory_service.dart';
import 'image_thumbnail.dart';
import 'sender_filter_chips.dart';
import 'voice_playback_row.dart';

/// 单条记忆卡片
class MemoryCard extends StatefulWidget {
  final MemoryItem item;
  final VoidCallback? onMuted;
  final VoidCallback? onDetailTap;

  const MemoryCard({super.key, required this.item, this.onMuted, this.onDetailTap});

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  bool _expanded = false;
  late bool _pinned;
  bool _pinLoading = false;
  bool _muteLoading = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.item.pinned;
  }

  @override
  void didUpdateWidget(covariant MemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _pinned = widget.item.pinned;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final kindIcon = _kindIcon(item.memoryKind);
    final kindColor = _kindColor(item.memoryKind);
    final timeLabel = _formatTime(item.createdAt, context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1A5B8A58)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kindColor.withAlpha(24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(kindIcon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            _kindLabel(
                              item.memoryKind,
                              item.eventType,
                              context,
                            ),
                            style: AppTextStyles.caption.copyWith(
                              color: kindColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('📌', style: TextStyle(fontSize: 12)),
                      ),
                    _buildSenderBadge(item, context),
                    const Spacer(),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.summary,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                  maxLines: _expanded ? null : 2,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (_expanded &&
                    item.content != item.summary &&
                    item.content.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FCF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A5B8A58)),
                    ),
                    child: Text(
                      item.content,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (item.eventType == 'voice_memory') ...[
                  const SizedBox(height: 8),
                  VoicePlaybackRow(audioUrl: item.audioUrl),
                ],
                if (item.eventType == 'image_recognition' &&
                    item.imageUrl != null &&
                    item.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ImageThumbnail(imageUrl: item.imageUrl!),
                ],
                if (item.sourceTaskTitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.task_alt_rounded,
                        size: 12,
                        color: Color(0xFF5A7654),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.sourceTaskTitle,
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF5A7654),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0x1A5B8A58)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ActionChip(
                        label: context.tr(
                          _pinned
                              ? 'memory.action.unpin'
                              : 'memory.action.pin',
                        ),
                        loading: _pinLoading,
                        onTap: _pinLoading ? null : _handleTogglePin,
                      ),
                      const SizedBox(width: 10),
                      _ActionChip(
                        label: context.tr('memory.action.mute'),
                        loading: _muteLoading,
                        onTap: _muteLoading ? null : _handleMute,
                      ),
                      const Spacer(),
                      if (widget.onDetailTap != null)
                        GestureDetector(
                          onTap: widget.onDetailTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('memory.detail.title'),
                                style: AppTextStyles.caption.copyWith(
                                  color: const Color(0xFF5A7654),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: Color(0xFF5A7654),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTogglePin() async {
    final newPinned = !_pinned;
    setState(() {
      _pinLoading = true;
      _pinned = newPinned;
    });
    try {
      final ok = await MemoryService().togglePin(widget.item.id, newPinned);
      if (!ok) throw Exception('API returned false');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(
              newPinned
                  ? 'memory.action.pin_success'
                  : 'memory.action.unpin_success',
            )),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pinned = !newPinned);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.action.operation_failed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pinLoading = false);
    }
  }

  Future<void> _handleMute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('memory.action.mute_confirm_title')),
        content: Text(ctx.tr('memory.action.mute_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('memory.action.mute_confirm_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('memory.action.mute_confirm_yes')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _muteLoading = true);
    try {
      final ok = await MemoryService().muteMemory(widget.item.id);
      if (!ok) throw Exception('API returned false');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.action.mute_success')),
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onMuted?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _muteLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.action.operation_failed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildSenderBadge(MemoryItem item, BuildContext ctx) {
    final sender = item.sender.isEmpty ? 'user-manual' : item.sender;
    final icon = senderIcons[sender];
    final labelKey = senderLabelKeys[sender];
    if (icon == null || labelKey == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 2),
          Text(
            ctx.tr(labelKey),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _kindIcon(String kind) {
    switch (kind) {
      case 'task_event':
        return '✅';
      case 'dialog_event':
        return '💬';
      case 'profile_signal':
        return '👤';
      default:
        return '🧠';
    }
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'task_event':
        return const Color(0xFF2E7D32);
      case 'dialog_event':
        return const Color(0xFF1565C0);
      case 'profile_signal':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF4A6B49);
    }
  }

  String _kindLabel(String kind, String eventType, BuildContext ctx) {
    if (eventType == 'agent_goal') return ctx.tr('memory.kind.agent_goal');
    if (eventType == 'agent_tool_result') {
      return ctx.tr('memory.kind.agent_tool');
    }
    if (eventType == 'agent_run_complete') {
      return ctx.tr('memory.kind.agent_run');
    }
    if (eventType == 'patrol_nudge') return ctx.tr('memory.kind.patrol');
    switch (kind) {
      case 'task_event':
        return ctx.tr('memory.kind.task');
      case 'dialog_event':
        return ctx.tr('memory.kind.dialog');
      case 'profile_signal':
        return ctx.tr('memory.kind.profile');
      default:
        return ctx.tr('memory.kind.generic');
    }
  }

  String _formatTime(DateTime? dt, BuildContext context) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return context.tr('memory.time.minutes_ago', params: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return context.tr('memory.time.hours_ago', params: {'n': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return context.tr('memory.time.days_ago', params: {'n': '${diff.inDays}'});
    }
    return '${dt.month}/${dt.day}';
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.label,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A5B8A58)),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
