import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/theme/quest_theme.dart';
import '../widgets/image_thumbnail.dart';
import '../widgets/sender_filter_chips.dart';
import '../widgets/voice_playback_row.dart';

/// 记忆详情页
class MemoryDetailPage extends StatefulWidget {
  final MemoryItem item;

  const MemoryDetailPage({super.key, required this.item});

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  late bool _pinned;
  bool _pinLoading = false;
  bool _muteLoading = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.item.pinned;
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<QuestTheme>() ?? QuestTheme.freshBreath();
    final item = widget.item;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F6EB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('memory.detail.title'),
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：类型 + 来源 + 时间
            _buildHeader(item, context),
            const SizedBox(height: 16),
            // 摘要
            Text(
              item.summary,
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            // 完整内容
            if (item.content != item.summary && item.content.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FCF0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1A5B8A58)),
                ),
                child: Text(
                  item.content,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            // 语音播放
            if (item.eventType == 'voice_memory') ...[
              const SizedBox(height: 16),
              VoicePlaybackRow(audioUrl: item.audioUrl),
            ],
            // 图片
            if (item.eventType == 'image_recognition' &&
                item.imageUrl != null &&
                item.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ImageThumbnail(imageUrl: item.imageUrl!),
            ],
            // 来源任务
            if (item.sourceTaskTitle.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.task_alt_rounded,
                      size: 16, color: Color(0xFF5A7654)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.sourceTaskTitle,
                      style: AppTextStyles.body.copyWith(
                        color: const Color(0xFF5A7654),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0x1A5B8A58)),
            const SizedBox(height: 16),
            // 操作按钮
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MemoryItem item, BuildContext context) {
    final kindLabel = _kindLabel(item.memoryKind, item.eventType, context);
    final sender = item.sender.isEmpty ? 'user-manual' : item.sender;
    final senderIcon = senderIcons[sender] ?? '';
    final senderLabelKey = senderLabelKeys[sender];
    final timeStr = _formatTime(item.createdAt);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kindColor(item.memoryKind).withAlpha(24),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_kindIcon(item.memoryKind)} $kindLabel',
            style: AppTextStyles.caption.copyWith(
              color: _kindColor(item.memoryKind),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_pinned) const Text('📌', style: TextStyle(fontSize: 14)),
        if (senderLabelKey != null)
          Text(
            '$senderIcon ${context.tr(senderLabelKey)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
            ),
          ),
        if (timeStr.isNotEmpty)
          Text(
            timeStr,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
            ),
          ),
      ],
    );
  }

  Widget _buildActions(QuestTheme theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pinLoading ? null : _handleTogglePin,
            icon: _pinLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Icon(
                    _pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                  ),
            label: Text(context.tr(
              _pinned ? 'memory.action.unpin' : 'memory.action.pin',
            )),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryAccentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _muteLoading ? null : _handleMute,
            icon: _muteLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(context.tr('memory.action.mute')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTogglePin() async {
    final newPinned = !_pinned;
    setState(() {
      _pinLoading = true;
      _pinned = newPinned;
    });
    final ok = await MemoryService().togglePin(widget.item.id, newPinned);
    if (mounted) {
      setState(() => _pinLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ok
                ? (newPinned
                    ? 'memory.action.pin_success'
                    : 'memory.action.unpin_success')
                : 'memory.action.operation_failed',
          )),
          duration: const Duration(seconds: 2),
        ),
      );
      if (!ok) setState(() => _pinned = !newPinned);
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
    final ok = await MemoryService().muteMemory(widget.item.id);
    if (mounted) {
      if (ok) {
        Navigator.pop(context, true); // 返回 true 表示已删除
      } else {
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}/${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
