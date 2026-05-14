import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/memory_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../models/portrait_timeline_item.dart';

/// 语音录入结果回调
typedef VoiceResultCallback = void Function(String transcribedText);

/// 记忆页面控制器，封装所有状态和业务逻辑
class MemoryController extends ChangeNotifier {
  final MemoryService _service = MemoryService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final stt.SpeechToText _speech = stt.SpeechToText();

  // ── 列表状态 ──
  List<MemoryItem> _items = [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  List<MemoryItem> get items => _items;
  bool get loading => _loading;
  bool get searching => _searching;
  String? get error => _error;

  // ── 画像时间线 ──
  List<PortraitTimelineItem> _portraits = [];
  bool _portraitsLoading = true;
  int _currentPortraitIndex = 0;

  List<PortraitTimelineItem> get portraits => _portraits;
  bool get portraitsLoading => _portraitsLoading;
  int get currentPortraitIndex => _currentPortraitIndex;

  // ── 来源过滤 ──
  String _selectedSender = 'all';

  String get selectedSender => _selectedSender;

  String? get _senderParam =>
      _selectedSender == 'all' ? null : _selectedSender;

  // ── 高级筛选 ──
  String? _dateRange; // '7d', '30d', null(全部)
  String? _filterKind; // memory kind, null(全部)

  String? get dateRange => _dateRange;
  String? get filterKind => _filterKind;
  bool get filterActive => _dateRange != null || _filterKind != null;

  // ── 语音输入 ──
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _voiceUploading = false;

  bool get isListening => _isListening;
  bool get speechAvailable => _speechAvailable;
  bool get voiceUploading => _voiceUploading;

  // ── 分页 ──
  bool _hasMore = true;
  bool _loadingMore = false;
  static const int _pageSize = 30;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  // ── 初始化 ──

  Future<void> init() async {
    await Future.wait([
      loadRecent(),
      loadPortraits(),
      initSpeech(),
    ]);
  }

  Future<void> initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) {
        _isListening = false;
        notifyListeners();
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          notifyListeners();
        }
      },
    );
  }

  void disposeSpeech() {
    if (_isListening) _speech.stop();
  }

  // ── 数据加载 ──

  Future<void> loadRecent() async {
    _loading = true;
    _error = null;
    _hasMore = true;
    notifyListeners();

    // 尝试读取缓存，命中则立即展示
    final cached = await _readCache();
    if (cached != null) {
      _items = cached;
      _loading = false;
      notifyListeners();
      // 后台静默刷新
      _fetchLatest();
      return;
    }

    await _fetchLatest();
  }

  Future<void> _fetchLatest() async {
    try {
      final items = await _service.search(
        query: '最近行动 任务 目标',
        limit: _pageSize,
        sender: _senderParam,
      );
      _items = items;
      _hasMore = items.length >= _pageSize;
      _error = null;
      _writeCache(items);
    } catch (e) {
      if (_items.isEmpty) _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      await loadRecent();
      return;
    }

    _searching = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _service.search(
        query: q,
        limit: 20,
        sender: _senderParam,
      );
      _items = items;
      _hasMore = false; // 搜索结果不分页
    } catch (e) {
      _error = '$e';
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _loading || _searching) return;

    _loadingMore = true;
    notifyListeners();

    try {
      final moreItems = await _service.search(
        query: '最近行动 任务 目标',
        limit: _pageSize,
        sender: _senderParam,
      );
      if (moreItems.isEmpty) {
        _hasMore = false;
      } else {
        // 去重
        final existingIds = _items.map((e) => e.id).toSet();
        final newItems =
            moreItems.where((e) => !existingIds.contains(e.id)).toList();
        if (newItems.isEmpty) {
          _hasMore = false;
        } else {
          _items = [..._items, ...newItems];
          _hasMore = moreItems.length >= _pageSize;
        }
      }
    } catch (_) {
      // 加载更多失败静默处理
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadRecent(),
      loadPortraits(),
    ]);
  }

  // ── 本地缓存 ──

  String get _cacheKey {
    final userId =
        SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? 'anon';
    return 'memory_cache_$userId';
  }

  Future<List<MemoryItem>?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      if (json == null) return null;
      final map = jsonDecode(json) as Map<String, dynamic>;
      final ts = map['ts'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheExpiry.inMilliseconds) return null;
      final list = map['items'] as List;
      return list
          .map((e) => MemoryItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<MemoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'items': items.map((e) => e.toMap()).toList(),
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (_) {
      // 缓存写入失败不影响主流程
    }
  }

  // ── 画像时间线 ──

  Future<void> loadPortraits() async {
    final userId =
        SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? '';
    if (userId.isEmpty) {
      _portraitsLoading = false;
      notifyListeners();
      return;
    }

    try {
      final rows = await _supabase
          .from('guide_portraits')
          .select('id, epoch, summary, image_url, created_at')
          .eq('user_id', userId)
          .neq('epoch', '')
          .order('epoch', ascending: true);
      _portraits = (rows as List)
          .map((e) =>
              PortraitTimelineItem.fromMap(e as Map<String, dynamic>))
          .toList();
      if (_portraits.length > 1) {
        _currentPortraitIndex = _portraits.length - 1;
      }
    } catch (_) {
      // 画像加载失败不影响记忆列表
    } finally {
      _portraitsLoading = false;
      notifyListeners();
    }
  }

  void setPortraitIndex(int index) {
    _currentPortraitIndex = index;
    notifyListeners();
  }

  // ── 来源过滤 ──

  void setSenderFilter(String sender) {
    if (sender == _selectedSender) return;
    _selectedSender = sender;
    notifyListeners();
    loadRecent();
  }

  void setFilter({String? dateRange, String? kind}) {
    _dateRange = dateRange;
    _filterKind = kind;
    notifyListeners();
    loadRecent();
  }

  // ── 语音输入 ──

  Future<void> toggleVoiceInput({
    required bool isEnglish,
    required VoidCallback onUnavailable,
    required VoiceResultCallback onResult,
  }) async {
    if (_voiceUploading) return;

    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
      return;
    }

    if (!_speechAvailable) {
      onUnavailable();
      return;
    }

    String transcribedText = '';
    _isListening = true;
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        transcribedText = result.recognizedWords;
        if (result.finalResult) {
          onResult(transcribedText);
        }
      },
      localeId: isEnglish ? 'en_US' : 'zh_CN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<bool> handleVoiceResult(String transcribedText) async {
    _isListening = false;
    _voiceUploading = true;
    notifyListeners();

    try {
      final tempDir = await getTemporaryDirectory();
      final audioFile = File(
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      if (!audioFile.existsSync()) {
        await audioFile.writeAsBytes([]);
      }

      final success = await _service.uploadVoiceMemory(
        audioFile,
        transcribedText,
      );

      if (audioFile.existsSync()) {
        await audioFile.delete();
      }

      if (success) {
        await loadRecent();
      }
      return success;
    } catch (_) {
      return false;
    } finally {
      _voiceUploading = false;
      notifyListeners();
    }
  }

  // ── 记忆操作 ──

  Future<bool> togglePin(int index, bool pinned) async {
    if (index < 0 || index >= _items.length) return false;
    final item = _items[index];
    final success = await _service.togglePin(item.id, pinned);
    if (success) {
      // 乐观更新
      _items[index] = MemoryItem(
        id: item.id,
        content: item.content,
        summary: item.summary,
        memoryKind: item.memoryKind,
        eventType: item.eventType,
        sourceTaskTitle: item.sourceTaskTitle,
        createdAt: item.createdAt,
        score: item.score,
        sender: item.sender,
        pinned: pinned,
        audioUrl: item.audioUrl,
        imageUrl: item.imageUrl,
      );
      notifyListeners();
    }
    return success;
  }

  Future<bool> muteMemory(int index) async {
    if (index < 0 || index >= _items.length) return false;
    final item = _items[index];
    final success = await _service.muteMemory(item.id);
    if (success) {
      _items = removeById(_items, item.id);
      notifyListeners();
    }
    return success;
  }

  Future<bool> createTextMemory({
    required String content,
    required String memoryKind,
    String? summary,
  }) async {
    final success = await _service.createTextMemory(
      content: content,
      memoryKind: memoryKind,
      summary: summary,
    );
    if (success) {
      await loadRecent();
    }
    return success;
  }

  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items = List.from(_items)..removeAt(index);
      notifyListeners();
    }
  }
}
