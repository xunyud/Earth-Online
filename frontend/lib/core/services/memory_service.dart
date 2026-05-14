import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/memory/models/image_recognition_result.dart';
import '../../features/memory/models/memory_item.dart';
import '../config/app_config.dart';
import 'supabase_auth_service.dart';

export '../../features/memory/models/memory_item.dart';
export '../../features/memory/models/image_recognition_result.dart';

/// 记忆服务：直接调用 EverMemOS v1 REST API
class MemoryService {
  static final String _baseUrl =
      '${AppConfig.evermemosBaseUrl.replaceAll(RegExp(r'/+$'), '')}/memories';
  static const _apiKey = AppConfig.evermemosApiKey;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
      };

  String get _userId =>
      SupabaseAuthService.instance.getCurrentUserId()?.trim() ?? '';

  /// 搜索记忆，支持关键词查询和来源过滤
  Future<List<MemoryItem>> search({
    required String query,
    int limit = 20,
    String retrieveMethod = 'hybrid',
    String? sender,
  }) async {
    final uid = _userId;
    if (uid.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/search');
    final body = <String, dynamic>{
      'query': query,
      'user_id': uid,
      'retrieve_method': retrieveMethod,
      'memory_types': ['episodic_memory'],
      'limit': limit,
    };
    if (sender != null && sender.isNotEmpty) {
      body['sender'] = sender;
    }
    final resp = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = _extractList(data);
    return items.map((item) => MemoryItem.fromMap(item)).toList();
  }

  /// 标记/取消标记记忆为重要
  Future<bool> togglePin(String memoryId, bool pinned) async {
    try {
      final uri = Uri.parse('$_baseUrl/$memoryId/metadata');
      final resp = await http
          .put(
            uri,
            headers: _headers,
            body: jsonEncode({
              'metadata': {'pinned': pinned},
            }),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 忘掉记忆（设置 sourceStatus 为 muted）
  Future<bool> muteMemory(String memoryId) async {
    try {
      final uri = Uri.parse('$_baseUrl/$memoryId');
      final resp = await http
          .patch(
            uri,
            headers: _headers,
            body: jsonEncode({'source_status': 'muted'}),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 上传语音记忆
  Future<bool> uploadVoiceMemory(File audioFile, String transcribedText) async {
    final uid = _userId;
    if (uid.isEmpty) return false;

    try {
      final supabase = Supabase.instance.client;
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.wav';

      await supabase.storage.from('voice-memories').upload(fileName, audioFile);

      final audioUrl =
          supabase.storage.from('voice-memories').getPublicUrl(fileName);

      final content =
          transcribedText.isNotEmpty ? transcribedText : '[语音记忆：转写失败，原始音频已保存]';
      final summary = transcribedText.isNotEmpty
          ? transcribedText.substring(0, transcribedText.length.clamp(0, 60))
          : '语音记忆';

      await supabase.functions.invoke(
        'sync-user-memory',
        body: {
          'user_id': uid,
          'event_type': 'voice_memory',
          'content': content,
          'memory_kind': 'dialog_event',
          'summary': summary,
          'sender': 'user-manual',
          'extra': {'audio_url': audioUrl},
        },
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 上传图片并调用多模态 LLM 识别内容
  Future<ImageRecognitionResult?> recognizeImage(File imageFile) async {
    final uid = _userId;
    if (uid.isEmpty) return null;

    try {
      final supabase = Supabase.instance.client;
      final ext = imageFile.path.split('.').last;
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('image-memories').upload(fileName, imageFile);

      final imageUrl =
          supabase.storage.from('image-memories').getPublicUrl(fileName);

      final resp = await supabase.functions.invoke(
        'sync-user-memory',
        body: {
          'user_id': uid,
          'event_type': 'image_recognition',
          'content': '',
          'memory_kind': 'generic',
          'summary': '图片识别',
          'sender': 'user-manual',
          'extra': {'image_url': imageUrl},
          'recognize_image': true,
        },
      );

      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final textContent = '${data['text_content'] ?? data['content'] ?? ''}';
        final suggestedTitle = '${data['suggested_task_title'] ?? ''}';
        final sceneDesc = '${data['scene_description'] ?? ''}';

        final memoryKind = suggestedTitle.isNotEmpty ? 'task_event' : 'generic';
        final content = textContent.isNotEmpty
            ? textContent
            : (sceneDesc.isNotEmpty ? sceneDesc : '图片识别结果');

        await supabase.functions.invoke(
          'sync-user-memory',
          body: {
            'user_id': uid,
            'event_type': 'image_recognition',
            'content': content,
            'memory_kind': memoryKind,
            'summary': content.substring(0, content.length.clamp(0, 60)),
            'sender': 'user-manual',
            'extra': {
              'image_url': imageUrl,
              if (suggestedTitle.isNotEmpty)
                'suggested_task_title': suggestedTitle,
            },
          },
        );

        return ImageRecognitionResult(
          textContent: textContent,
          suggestedTaskTitle: suggestedTitle,
          sceneDescription: sceneDesc,
          imageUrl: imageUrl,
        );
      }

      await supabase.functions.invoke(
        'sync-user-memory',
        body: {
          'user_id': uid,
          'event_type': 'image_recognition',
          'content': '图片记忆',
          'memory_kind': 'generic',
          'summary': '图片记忆',
          'sender': 'user-manual',
          'extra': {'image_url': imageUrl},
        },
      );

      return ImageRecognitionResult(
        textContent: '',
        suggestedTaskTitle: '',
        sceneDescription: '',
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// 加载最近记忆
  Future<List<MemoryItem>> loadRecent({int limit = 30}) async {
    return search(query: '最近行动 任务 目标', limit: limit);
  }

  /// 手动创建文本记忆
  Future<bool> createTextMemory({
    required String content,
    required String memoryKind,
    String? summary,
  }) async {
    final uid = _userId;
    if (uid.isEmpty) {
      debugPrint('[MemoryService] createTextMemory: userId 为空，会话可能已失效');
      return false;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'sync-user-memory',
        body: {
          'user_id': uid,
          'event_type': 'manual_input',
          'content': content,
          'memory_kind': memoryKind,
          'summary': summary ?? content.substring(0, content.length.clamp(0, 60)),
          'sender': 'user-manual',
        },
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final synced = data['synced'] == true;
      if (!synced) {
        debugPrint('[MemoryService] createTextMemory: Edge Function 返回 synced=false，EverMemOS 同步跳过');
      }
      return true;
    } catch (e) {
      debugPrint('[MemoryService] createTextMemory 异常: $e');
      return false;
    }
  }

  /// 提取响应中的记忆列表
  static List<Map<String, dynamic>> _extractList(Map<String, dynamic> data) {
    for (final key in ['memories', 'results', 'items', 'data']) {
      final v = data[key];
      if (v is List) {
        return v.whereType<Map<String, dynamic>>().toList();
      }
    }
    if (data['result'] is Map) {
      final inner = data['result'] as Map;
      for (final key in ['memories', 'results', 'items']) {
        final v = inner[key];
        if (v is List) {
          return v.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return [];
  }
}
