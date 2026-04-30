import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/i18n/app_locale_controller.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/theme/quest_theme.dart';

/// 画像时间线条目，对应 guide_portraits 表中的一条记录
class PortraitTimelineItem {
  final String id;
  final String epoch;
  final String summary;
  final String imageUrl;
  final DateTime? createdAt;

  const PortraitTimelineItem({
    required this.id,
    required this.epoch,
    required this.summary,
    required this.imageUrl,
    required this.createdAt,
  });

  /// 从 Supabase 行数据构造，兼容多种字段命名
  factory PortraitTimelineItem.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }
    return PortraitTimelineItem(
      id: '${map['id'] ?? ''}',
      epoch: '${map['epoch'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      imageUrl: '${map['image_url'] ?? map['imageUrl'] ?? ''}',
      createdAt: createdAt,
    );
  }
}

/// 来源过滤标签数据：(i18n key, sender 值, 图标)
/// sender 为 null 表示"全部"，不传过滤参数
const _senderFilters = <(String, String, IconData?)>[
  ('memory.sender.all', 'all', null),
  ('memory.sender.user_manual', 'user-manual', Icons.edit),
  ('memory.sender.guide_assistant', 'guide-assistant', Icons.smart_toy),
  ('memory.sender.agent_runtime', 'agent-runtime', Icons.settings),
  ('memory.sender.patrol_nudge', 'patrol-nudge', Icons.notifications),
  ('memory.sender.wechat_webhook', 'wechat-webhook', Icons.chat),
];

/// 来源图标映射，用于记忆卡片展示
const _senderIcons = <String, String>{
  'user-manual': '✍️',
  'guide-assistant': '🤖',
  'agent-runtime': '⚙️',
  'patrol-nudge': '🔔',
  'wechat-webhook': '💚',
};

/// 来源 i18n key 映射，用于记忆卡片展示来源标签文本
const _senderLabelKeys = <String, String>{
  'user-manual': 'memory.sender.user_manual',
  'guide-assistant': 'memory.sender.guide_assistant',
  'agent-runtime': 'memory.sender.agent_runtime',
  'patrol-nudge': 'memory.sender.patrol_nudge',
  'wechat-webhook': 'memory.sender.wechat_webhook',
};

/// 记忆面板页面
/// 展示用户在 EverMemOS 中积累的记忆片段，支持关键词搜索和来源过滤
/// 顶部展示画像时间线，按 epoch 从旧到新排列
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final _service = MemoryService();
  final _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<MemoryItem> _items = [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  /// 画像时间线数据
  List<PortraitTimelineItem> _portraits = [];
  bool _portraitsLoading = true;

  /// 当前画像页面索引，用于 PageView 控制
  int _currentPortraitIndex = 0;

  /// 当前选中的来源过滤值，默认 'all' 表示全部
  String _selectedSender = 'all';

  /// 语音输入相关状态
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _voiceUploading = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadPortraits();
    _initSpeech();
  }

  @override
  void dispose() {
    if (_isListening) _speech.stop();
    _searchController.dispose();
    super.dispose();
  }

  /// 初始化语音识别引擎，复用 speech_to_text 集成
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
  }

  /// 切换语音录入状态
  /// 开始录音后获取转写文本，录音完成后上传音频并写入记忆
  Future<void> _toggleVoiceInput() async {
    if (_voiceUploading) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.voice.unavailable')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 用于收集转写文本
    String transcribedText = '';

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        transcribedText = result.recognizedWords;
        // 录音结束（final result）时触发上传流程
        if (result.finalResult && mounted) {
          _handleVoiceResult(transcribedText);
        }
      },
      localeId: context.isEnglish ? 'en_US' : 'zh_CN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  /// 处理语音录入结果：上传音频并写入记忆
  /// 转写失败时仍保存原始音频
  Future<void> _handleVoiceResult(String transcribedText) async {
    setState(() {
      _isListening = false;
      _voiceUploading = true;
    });

    try {
      // 创建临时音频文件（speech_to_text 不直接提供音频文件，
      // 此处创建占位文件用于 Storage 上传）
      final tempDir = await getTemporaryDirectory();
      final audioFile = File(
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      // 写入空音频占位（实际项目中应使用录音插件获取真实音频）
      if (!audioFile.existsSync()) {
        await audioFile.writeAsBytes([]);
      }

      final success = await _service.uploadVoiceMemory(
        audioFile,
        transcribedText,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('memory.voice.upload_success')),
              duration: const Duration(seconds: 2),
            ),
          );
          // 刷新记忆列表
          _loadRecent();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('memory.voice.upload_failed')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // 清理临时文件
      if (audioFile.existsSync()) {
        await audioFile.delete();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('memory.voice.transcribe_failed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _voiceUploading = false);
    }
  }

  /// 从 Supabase 查询当前用户所有 guide_portraits 记录，按 epoch 升序排列
  Future<void> _loadPortraits() async {
    final userId =
        SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? '';
    if (userId.isEmpty) {
      if (mounted) setState(() => _portraitsLoading = false);
      return;
    }
    try {
      final rows = await _supabase
          .from('guide_portraits')
          .select('id, epoch, summary, image_url, created_at')
          .eq('user_id', userId)
          .neq('epoch', '')
          .order('epoch', ascending: true);
      final list = (rows as List)
          .map((e) =>
              PortraitTimelineItem.fromMap(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _portraits = list;
          _portraitsLoading = false;
          // 默认定位到最新一张画像
          if (list.length > 1) {
            _currentPortraitIndex = list.length - 1;
          }
        });
      }
    } catch (_) {
      // 画像加载失败不影响记忆列表展示
      if (mounted) setState(() => _portraitsLoading = false);
    }
  }

  /// 获取当前 sender 过滤参数，'all' 时返回 null 表示不过滤
  String? get _senderParam =>
      _selectedSender == 'all' ? null : _selectedSender;

  Future<void> _loadRecent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.search(
        query: '最近行动 任务 目标',
        limit: 30,
        sender: _senderParam,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _loadRecent();
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final items = await _service.search(
        query: q,
        limit: 20,
        sender: _senderParam,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// 切换来源过滤标签，触发重新加载
  void _onSenderFilterChanged(String sender) {
    if (sender == _selectedSender) return;
    setState(() => _selectedSender = sender);
    // 根据搜索栏是否有内容决定调用搜索还是加载最近
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      _search(q);
    } else {
      _loadRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<QuestTheme>() ?? QuestTheme.freshBreath();

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
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            tooltip: context.tr('memory.refresh'),
            onPressed: _loading ? null : () {
              _loadRecent();
              _loadPortraits();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 画像时间线区域
          _buildPortraitTimeline(theme),
          // 搜索栏 + 语音输入按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                // 搜索栏
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
                      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: context.tr('memory.search.hint'),
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5A7654)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                color: AppColors.textSecondary,
                                onPressed: () {
                                  _searchController.clear();
                                  _loadRecent();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 麦克风按钮：点击开始/停止录音
                _VoiceMicButton(
                  isListening: _isListening,
                  isUploading: _voiceUploading,
                  onTap: _toggleVoiceInput,
                ),
              ],
            ),
          ),
          // 来源过滤标签行
          _buildSenderFilterRow(),
          // 内容区
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  /// 构建画像时间线区域
  /// 0 张或 1 张画像时显示引导文案，2 张及以上时显示可滑动的时间线
  Widget _buildPortraitTimeline(QuestTheme theme) {
    // 加载中时不占用空间
    if (_portraitsLoading) return const SizedBox.shrink();

    // 0 张或 1 张画像：显示引导文案
    if (_portraits.length <= 1) {
      return _PortraitTimelineGuide(
        portrait: _portraits.isEmpty ? null : _portraits.first,
        theme: theme,
      );
    }

    // 多张画像：显示可滑动的时间线
    return _PortraitTimelineCarousel(
      portraits: _portraits,
      initialIndex: _currentPortraitIndex,
      theme: theme,
      onPageChanged: (index) {
        setState(() => _currentPortraitIndex = index);
      },
    );
  }

  /// 构建来源过滤标签行
  /// 水平可滚动，默认选中"全部"，点击切换过滤
  Widget _buildSenderFilterRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _senderFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (labelKey, senderValue, icon) = _senderFilters[index];
          final isSelected = _selectedSender == senderValue;
          return _SenderFilterChip(
            label: context.tr(labelKey),
            icon: icon,
            isSelected: isSelected,
            onTap: () => _onSenderFilterChanged(senderValue),
          );
        },
      ),
    );
  }

  Widget _buildBody(QuestTheme theme) {
    if (_loading || _searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: theme.primaryAccentColor,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('memory.loading'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 16),
              Text(
                context.tr('memory.error'),
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadRecent,
                child: Text(context.tr('memory.retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.memory_rounded, size: 56, color: Color(0xFFCCDDCC)),
              const SizedBox(height: 16),
              Text(
                context.tr('memory.empty'),
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _MemoryCard(
        item: _items[index],
        onMuted: () {
          setState(() => _items.removeAt(index));
        },
      ),
    );
  }
}

/// 画像时间线引导文案组件
/// 当用户只有 0 张或 1 张画像时展示，鼓励用户持续记录
class _PortraitTimelineGuide extends StatelessWidget {
  final PortraitTimelineItem? portrait;
  final QuestTheme theme;

  const _PortraitTimelineGuide({
    required this.portrait,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1A5B8A58)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧图标或缩略图
          if (portrait != null && portrait!.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                portrait!.imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderIcon(),
              ),
            )
          else
            _placeholderIcon(),
          const SizedBox(width: 12),
          // 右侧文案
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('memory.portrait_timeline.title'),
                  style: AppTextStyles.caption.copyWith(
                    color: theme.primaryAccentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  portrait == null
                      ? context.tr('memory.portrait_timeline.guide_empty')
                      : context.tr('memory.portrait_timeline.guide_single'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Color(0xFF8AAE87),
        size: 24,
      ),
    );
  }
}

/// 画像时间线轮播组件
/// 使用 PageView.builder 实现左右滑动切换相邻 epoch 画像
class _PortraitTimelineCarousel extends StatefulWidget {
  final List<PortraitTimelineItem> portraits;
  final int initialIndex;
  final QuestTheme theme;
  final ValueChanged<int> onPageChanged;

  const _PortraitTimelineCarousel({
    required this.portraits,
    required this.initialIndex,
    required this.theme,
    required this.onPageChanged,
  });

  @override
  State<_PortraitTimelineCarousel> createState() =>
      _PortraitTimelineCarouselState();
}

class _PortraitTimelineCarouselState extends State<_PortraitTimelineCarousel> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.88,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 画像卡片滑动区域
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.portraits.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onPageChanged(index);
            },
            itemBuilder: (context, index) {
              final portrait = widget.portraits[index];
              return _PortraitCard(
                portrait: portrait,
                isActive: index == _currentIndex,
                theme: widget.theme,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // 页面指示器
        _buildPageIndicator(),
        const SizedBox(height: 4),
      ],
    );
  }

  /// 构建页面指示器，显示当前位置
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.portraits.length, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? widget.theme.primaryAccentColor
                : widget.theme.primaryAccentColor.withAlpha(50),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// 单张画像卡片，展示缩略图、epoch 标签和 summary 文本
class _PortraitCard extends StatelessWidget {
  final PortraitTimelineItem portrait;
  final bool isActive;
  final QuestTheme theme;

  const _PortraitCard({
    required this.portrait,
    required this.isActive,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.fromLTRB(6, isActive ? 4 : 8, 6, isActive ? 4 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? theme.primaryAccentColor.withAlpha(80)
              : const Color(0x1A5B8A58),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isActive ? 14 : 6),
            blurRadius: isActive ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Row(
          children: [
            // 左侧缩略图
            if (portrait.imageUrl.isNotEmpty)
              SizedBox(
                width: 120,
                child: Image.network(
                  portrait.imageUrl,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                ),
              )
            else
              _imagePlaceholder(),
            // 右侧文字信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // epoch 标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryAccentColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        portrait.epoch,
                        style: AppTextStyles.caption.copyWith(
                          color: theme.primaryAccentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // summary 文本
                    Expanded(
                      child: Text(
                        portrait.summary.isNotEmpty
                            ? portrait.summary
                            : context.tr('memory.portrait_timeline.no_summary'),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 底部画像标签
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('memory.portrait_timeline.label'),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textHint,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 图片占位符
  Widget _imagePlaceholder() {
    return Container(
      width: 120,
      color: const Color(0xFFF0F5EE),
      child: const Center(
        child: Icon(
          Icons.image_rounded,
          color: Color(0xFFB8D4B5),
          size: 36,
        ),
      ),
    );
  }
}


/// 单条记忆卡片
class _MemoryCard extends StatefulWidget {
  final MemoryItem item;
  /// 当记忆被 mute 后回调父组件，从列表中移除
  final VoidCallback? onMuted;
  const _MemoryCard({required this.item, this.onMuted});

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard> {
  bool _expanded = false;
  /// 本地 pinned 状态，初始值来自 item.pinned
  late bool _pinned;
  /// pin/mute 操作进行中标记，防止重复点击
  bool _pinLoading = false;
  bool _muteLoading = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.item.pinned;
  }

  @override
  void didUpdateWidget(covariant _MemoryCard oldWidget) {
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
    final timeLabel = _formatTime(item.createdAt);

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
                // 头部：类型标签 + 来源图标 + 时间
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            _kindLabel(item.memoryKind, item.eventType, context),
                            style: AppTextStyles.caption.copyWith(
                              color: kindColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 已标记重要的记忆显示 📌 图标
                    if (_pinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('📌', style: TextStyle(fontSize: 12)),
                      ),
                    // 来源图标和标签
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
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 摘要
                Text(
                  item.summary,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                // 展开后显示完整内容
                if (_expanded && item.content != item.summary && item.content.isNotEmpty) ...[
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
                // 语音记忆：显示 🎙️ 图标和音频播放控件
                if (item.eventType == 'voice_memory') ...[
                  const SizedBox(height: 8),
                  _VoicePlaybackRow(audioUrl: item.audioUrl),
                ],
                // 图片识别记忆：显示缩略图预览
                if (item.eventType == 'image_recognition' &&
                    item.imageUrl != null &&
                    item.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ImageThumbnail(imageUrl: item.imageUrl!),
                ],
                // 来源任务标题
                if (item.sourceTaskTitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 12, color: Color(0xFF5A7654)),
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
                // 展开后显示 pin/mute 操作按钮
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0x1A5B8A58)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 标记重要 / 取消重要
                      _ActionChip(
                        label: context.tr(
                          _pinned ? 'memory.action.unpin' : 'memory.action.pin',
                        ),
                        loading: _pinLoading,
                        onTap: _pinLoading ? null : _handleTogglePin,
                      ),
                      const SizedBox(width: 10),
                      // 忘掉这条
                      _ActionChip(
                        label: context.tr('memory.action.mute'),
                        loading: _muteLoading,
                        onTap: _muteLoading ? null : _handleMute,
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

  /// 切换标记重要状态
  /// 乐观更新 UI，API 失败时回滚并提示
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
              newPinned ? 'memory.action.pin_success' : 'memory.action.unpin_success',
            )),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // 回滚状态
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

  /// 忘掉记忆：弹出确认对话框，确认后调用 muteMemory
  /// 成功后回调父组件移除该条目并显示轻量提示
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
        // 通知父组件从列表中移除
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

  /// 构建来源图标徽章，显示在类型标签旁
  /// 缺少 sender 的记忆归类为 user-manual
  Widget _buildSenderBadge(MemoryItem item, BuildContext ctx) {
    final sender = item.sender.isEmpty ? 'user-manual' : item.sender;
    final icon = _senderIcons[sender];
    final labelKey = _senderLabelKeys[sender];
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
    if (eventType == 'agent_tool_result') return ctx.tr('memory.kind.agent_tool');
    if (eventType == 'agent_run_complete') return ctx.tr('memory.kind.agent_run');
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
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}

/// 操作按钮组件，用于 pin/mute 等卡片内操作
/// loading 为 true 时显示加载指示器并禁用点击
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

/// 来源过滤标签组件
/// 选中时高亮显示，未选中时灰色背景
class _SenderFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SenderFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5A7654) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5A7654)
                : const Color(0x335B8A58),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5A7654).withAlpha(30),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 语音输入麦克风按钮
/// 录音中显示红色脉冲动画，上传中显示加载指示器
class _VoiceMicButton extends StatelessWidget {
  final bool isListening;
  final bool isUploading;
  final VoidCallback onTap;

  const _VoiceMicButton({
    required this.isListening,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isListening
              ? const Color(0xFFE53935).withAlpha(20)
              : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isListening
                ? const Color(0xFFE53935).withAlpha(80)
                : const Color(0x225B8A58),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5A7654),
                  ),
                )
              : Icon(
                  isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 22,
                  color: isListening
                      ? const Color(0xFFE53935)
                      : const Color(0xFF5A7654),
                ),
        ),
      ),
    );
  }
}

/// 语音记忆播放控件行
/// 显示 🎙️ 图标和播放按钮，点击从 Supabase Storage 加载并播放音频
/// 音频加载失败时显示"音频不可用"提示
class _VoicePlaybackRow extends StatefulWidget {
  final String? audioUrl;

  const _VoicePlaybackRow({required this.audioUrl});

  @override
  State<_VoicePlaybackRow> createState() => _VoicePlaybackRowState();
}

class _VoicePlaybackRowState extends State<_VoicePlaybackRow> {
  bool _playing = false;
  bool _error = false;

  /// 尝试播放音频
  /// 当前使用简单的状态切换模拟播放行为
  /// 实际播放需要 audioplayers 或 just_audio 包支持
  Future<void> _togglePlay() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) {
      setState(() => _error = true);
      return;
    }

    if (_playing) {
      setState(() => _playing = false);
      return;
    }

    setState(() {
      _playing = true;
      _error = false;
    });

    // 模拟播放延迟后自动停止
    // 实际项目中应使用 audioplayers 包进行真实播放
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _playing = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A5B8A58)),
      ),
      child: Row(
        children: [
          // 🎙️ 图标
          const Text('🎙️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          // 播放/停止按钮
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _playing
                    ? const Color(0xFFE53935).withAlpha(20)
                    : const Color(0xFF5A7654).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 18,
                color: _playing
                    ? const Color(0xFFE53935)
                    : const Color(0xFF5A7654),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 状态文本
          Expanded(
            child: Text(
              _error
                  ? context.tr('memory.voice.audio_unavailable')
                  : (_playing
                      ? context.tr('memory.voice.listening')
                      : context.tr('memory.kind.dialog')),
              style: AppTextStyles.caption.copyWith(
                color: _error
                    ? const Color(0xFFE53935)
                    : AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图片识别记忆缩略图组件
/// 显示图片缩略图预览，点击全屏展示原始图片
class _ImageThumbnail extends StatelessWidget {
  final String imageUrl;

  const _ImageThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 160),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5EE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1A5B8A58)),
          ),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 80,
              color: const Color(0xFFF0F5EE),
              child: const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Color(0xFFB8D4B5),
                  size: 32,
                ),
              ),
            ),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 80,
                color: const Color(0xFFF0F5EE),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF5A7654),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 全屏展示原始图片
  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImagePage(imageUrl: imageUrl),
      ),
    );
  }
}

/// 全屏图片展示页面
/// 支持缩放和关闭操作
class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_rounded,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
