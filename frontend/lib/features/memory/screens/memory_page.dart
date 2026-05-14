import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/theme/quest_theme.dart';
import '../controllers/memory_controller.dart';
import '../widgets/memory_card.dart';
import '../widgets/memory_filter_sheet.dart';
import '../widgets/memory_skeleton.dart';
import '../widgets/portrait_timeline.dart';
import '../widgets/sender_filter_chips.dart';
import '../widgets/voice_mic_button.dart';
import 'memory_detail_page.dart';

/// 记忆面板页面
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final MemoryController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MemoryController()..init();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.disposeSpeech();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<QuestTheme>() ?? QuestTheme.freshBreath();

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
          context.tr('memory.title'),
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _controller.filterActive
                  ? theme.primaryAccentColor
                  : AppColors.textSecondary,
            ),
            tooltip: context.tr('memory.filter.title'),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            tooltip: context.tr('memory.refresh'),
            onPressed: _controller.loading ? null : () => _controller.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPortraitTimeline(theme),
          _buildSearchBar(theme),
          _buildSenderFilterRow(),
          Expanded(child: _buildBody(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.primaryAccentColor,
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildPortraitTimeline(QuestTheme theme) {
    if (_controller.portraitsLoading) return const SizedBox.shrink();

    if (_controller.portraits.length <= 1) {
      return PortraitTimelineGuide(
        portrait: _controller.portraits.isEmpty
            ? null
            : _controller.portraits.first,
        theme: theme,
      );
    }

    return PortraitTimelineCarousel(
      portraits: _controller.portraits,
      initialIndex: _controller.currentPortraitIndex,
      theme: theme,
      onPageChanged: (index) => _controller.setPortraitIndex(index),
    );
  }

  Widget _buildSearchBar(QuestTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x225B8A58)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: context.tr('memory.search.hint'),
                  hintStyle: AppTextStyles.body
                      .copyWith(color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF5A7654)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: AppColors.textSecondary,
                          onPressed: () {
                            _searchController.clear();
                            _controller.loadRecent();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (q) => _controller.search(q),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          VoiceMicButton(
            isListening: _controller.isListening,
            isUploading: _controller.voiceUploading,
            onTap: () => _controller.toggleVoiceInput(
              isEnglish: context.isEnglish,
              onUnavailable: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('memory.voice.unavailable')),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onResult: (text) async {
                // 检查会话有效性
                final session =
                    Supabase.instance.client.auth.currentSession;
                if (session == null || session.isExpired) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(context.tr('quest.parse.auth_retry')),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }

                final success = await _controller.handleVoiceResult(text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr(success
                          ? 'memory.voice.upload_success'
                          : 'memory.voice.upload_failed')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderFilterRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: senderFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (labelKey, senderValue, icon) = senderFilters[index];
          return SenderFilterChip(
            label: context.tr(labelKey),
            icon: icon,
            isSelected: _controller.selectedSender == senderValue,
            onTap: () => _controller.setSenderFilter(senderValue),
          );
        },
      ),
    );
  }

  Widget _buildBody(QuestTheme theme) {
    if (_controller.loading || _controller.searching) {
      return const MemorySkeleton();
    }

    if (_controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 16),
              Text(
                context.tr('memory.error'),
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _controller.loadRecent(),
                child: Text(context.tr('memory.retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.memory_rounded,
                  size: 56, color: Color(0xFFCCDDCC)),
              const SizedBox(height: 16),
              Text(
                context.tr('memory.empty'),
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: theme.primaryAccentColor,
      onRefresh: () => _controller.refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            _controller.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: _controller.items.length +
              (_controller.hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _controller.items.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _controller.loadingMore
                      ? CircularProgressIndicator(
                          color: theme.primaryAccentColor,
                          strokeWidth: 2,
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }
            return MemoryCard(
              item: _controller.items[index],
              onMuted: () => _controller.removeItemAt(index),
              onDetailTap: () => _navigateToDetail(_controller.items[index]),
            );
          },
        ),
      ),
    );
  }

  void _showCreateSheet() {
    final contentController = TextEditingController();
    String selectedKind = 'generic';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('memory.create.title'),
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: context.tr('memory.create.hint'),
                      hintStyle: AppTextStyles.body
                          .copyWith(color: AppColors.textHint),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final kind in [
                        ('generic', 'memory.kind.generic'),
                        ('task_event', 'memory.kind.task'),
                        ('dialog_event', 'memory.kind.dialog'),
                        ('profile_signal', 'memory.kind.profile'),
                      ])
                        ChoiceChip(
                          label: Text(context.tr(kind.$2)),
                          selected: selectedKind == kind.$1,
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() => selectedKind = kind.$1);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = contentController.text.trim();
                        if (text.isEmpty) return;

                        // 检查会话有效性
                        final session =
                            Supabase.instance.client.auth.currentSession;
                        if (session == null || session.isExpired) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    context.tr('quest.parse.auth_retry')),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                          return;
                        }

                        Navigator.pop(ctx);
                        final ok = await _controller.createTextMemory(
                          content: text,
                          memoryKind: selectedKind,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.tr(ok
                                  ? 'memory.create.success'
                                  : 'memory.action.operation_failed')),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A7654),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(context.tr('memory.create.submit')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToDetail(MemoryItem item) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MemoryDetailPage(item: item)),
    ).then((deleted) {
      if (deleted == true) {
        _controller.refresh();
      }
    });
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<MemoryFilterResult>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MemoryFilterSheet(
        currentFilter: MemoryFilterResult(
          dateRange: _controller.dateRange,
          kind: _controller.filterKind,
        ),
      ),
    );
    if (result != null) {
      _controller.setFilter(dateRange: result.dateRange, kind: result.kind);
    }
  }
}
