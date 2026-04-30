import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'supabase_auth_service.dart';

/// 单条记忆片段
class MemoryItem {
  final String id;
  final String content;
  final String summary;
  final String memoryKind;
  final String eventType;
  final String sourceTaskTitle;
  final DateTime? createdAt;
  final double score;
  final String sender; // 来源标识，默认空字符串
  final bool pinned; // 是否标记重要，默认 false
  final String? audioUrl; // 语音记忆音频 URL
  final String? imageUrl; // 图片记忆图片 URL

  const MemoryItem({
    required this.id,
    required this.content,
    required this.summary,
    required this.memoryKind,
    required this.eventType,
    required this.sourceTaskTitle,
    required this.createdAt,
    required this.score,
    this.sender = '',
    this.pinned = false,
    this.audioUrl,
    this.imageUrl,
  });

  factory MemoryItem.fromMap(Map<String, dynamic> map) {
    // EverMemOS 返回的记忆内容可能在 content / text / memory 字段
    final rawContent = _str(map['content']) ??
        _str(map['text']) ??
        _str(map['memory']) ??
        _str((map['data'] as Map?)?['content']) ??
        '';

    // 解析 smart-p-memory 信封格式
    final parsed = _parseEnvelope(rawContent);

    final createdRaw = map['created_at'] ?? map['create_time'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    } else if (createdRaw is num) {
      // Unix 毫秒
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw.toInt());
    }

    final scoreRaw = map['score'] ?? map['similarity'] ?? map['relevance'];
    final score = scoreRaw is num ? scoreRaw.toDouble() : 0.0;

    return MemoryItem(
      id: _str(map['id']) ??
          _str(map['message_id']) ??
          _str((map['data'] as Map?)?['id']) ??
          '',
      content: parsed['content'] ?? rawContent,
      summary: parsed['summary'] ??
          rawContent.substring(0, rawContent.length.clamp(0, 60)),
      memoryKind: parsed['memoryKind'] ?? _str(map['memory_kind']) ?? 'generic',
      eventType: parsed['eventType'] ?? _str(map['event_type']) ?? '',
      sourceTaskTitle: parsed['sourceTaskTitle'] ?? '',
      createdAt: createdAt,
      score: score,
      sender: parsed['sender'] ?? '',
      pinned: parsed['pinned'] == 'true',
      audioUrl: _str(map['audio_url']) ??
          _str((map['metadata'] as Map?)?['audio_url']),
      imageUrl: _str(map['image_url']) ??
          _str((map['metadata'] as Map?)?['image_url']),
    );
  }

  /// 序列化为 Map，用于 round-trip 测试和数据传递
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': _buildEnvelopeContent(),
      'created_at': createdAt?.toIso8601String(),
      'score': score,
      'memory_kind': memoryKind,
      'event_type': eventType,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  /// 构建包含所有字段的信封格式内容
  String _buildEnvelopeContent() {
    final parts = <String>[
      '[smart-p-memory:v1] eventType=$eventType',
      'content=$content',
      'summary=$summary',
      'memoryKind=$memoryKind',
      'sourceTaskTitle=$sourceTaskTitle',
    ];
    if (sender.isNotEmpty) {
      parts.add('sender=$sender');
    }
    parts.add('pinned=$pinned');
    return parts.join(' | ');
  }

  /// 解析 [smart-p-memory:v1] 信封格式，支持 sender 和 pinned 字段
  static Map<String, String> _parseEnvelope(String raw) {
    if (!raw.contains('[smart-p-memory:v1]')) return {};
    final result = <String, String>{};
    final parts = raw.split('|');
    for (final part in parts) {
      final kv = part.trim();
      final eqIdx = kv.indexOf('=');
      if (eqIdx < 0) continue;
      final key = kv.substring(0, eqIdx).trim();
      final value = kv.substring(eqIdx + 1).trim();
      switch (key) {
        case 'content':
          result['content'] = value;
        case 'summary':
          result['summary'] = value;
        case 'memoryKind':
          result['memoryKind'] = value;
        case 'eventType':
          result['eventType'] = value;
        case 'sourceTaskTitle':
          result['sourceTaskTitle'] = value;
        case 'sender':
          result['sender'] = value;
        case 'pinned':
          result['pinned'] = value;
      }
    }
    return result;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }
}

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
    // 传递 sender 过滤参数到 EverMemOS 搜索请求
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
  ///
  /// 调用 EverMemOS API 更新 metadata 中的 pinned 字段。
  /// 超时时间 5 秒，成功返回 true，失败返回 false。
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
  ///
  /// 调用 EverMemOS API 更新 sourceStatus，Guide 将不再引用该记忆。
  /// 超时时间 5 秒，成功返回 true，失败返回 false。
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

  /// 上传语音记忆：将音频文件上传到 Supabase Storage，然后写入 EverMemOS
  ///
  /// 流程：
  /// 1. 上传音频到 Supabase Storage voice-memories bucket
  /// 2. 获取公开 URL
  /// 3. 调用 sync-user-memory 写入记忆（eventType: voice_memory, sender: user-manual）
  /// 4. metadata 中保存 audio_url
  ///
  /// [audioFile] 原始音频文件
  /// [transcribedText] 语音转写文本，转写失败时可为空字符串
  /// 返回 true 表示写入成功，false 表示失败
  Future<bool> uploadVoiceMemory(File audioFile, String transcribedText) async {
    final uid = _userId;
    if (uid.isEmpty) return false;

    try {
      final supabase = Supabase.instance.client;
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.wav';

      // 1. 上传音频到 Supabase Storage voice-memories bucket
      await supabase.storage.from('voice-memories').upload(fileName, audioFile);

      // 2. 获取公开 URL
      final audioUrl =
          supabase.storage.from('voice-memories').getPublicUrl(fileName);

      // 3. 调用 sync-user-memory 写入记忆
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
  ///
  /// 流程：
  /// 1. 上传图片到 Supabase Storage image-memories bucket
  /// 2. 获取公开 URL
  /// 3. 调用 sync-user-memory 触发后端多模态 LLM 识别
  /// 4. 返回识别结果（含 suggested_task_title）
  ///
  /// [imageFile] 用户选择的图片文件
  /// 返回 ImageRecognitionResult，失败时返回 null
  Future<ImageRecognitionResult?> recognizeImage(File imageFile) async {
    final uid = _userId;
    if (uid.isEmpty) return null;

    try {
      final supabase = Supabase.instance.client;
      final ext = imageFile.path.split('.').last;
      final fileName = '${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // 1. 上传图片到 Supabase Storage image-memories bucket
      await supabase.storage.from('image-memories').upload(fileName, imageFile);

      // 2. 获取公开 URL
      final imageUrl =
          supabase.storage.from('image-memories').getPublicUrl(fileName);

      // 3. 调用后端多模态 LLM 识别（通过 Edge Function）
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

      // 4. 解析识别结果
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final textContent = '${data['text_content'] ?? data['content'] ?? ''}';
        final suggestedTitle = '${data['suggested_task_title'] ?? ''}';
        final sceneDesc = '${data['scene_description'] ?? ''}';

        // 写入记忆：根据是否含任务决定 memoryKind
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

      // 后端未返回结构化结果，仅保存图片记忆
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

  /// 加载最近记忆（用"最近行动"作为查询词）
  Future<List<MemoryItem>> loadRecent({int limit = 30}) async {
    return search(query: '最近行动 任务 目标', limit: limit);
  }

  /// 提取响应中的记忆列表，兼容多种返回格式
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

/// 图片识别结果，对应后端 callMultimodalLLM 返回的结构化数据
class ImageRecognitionResult {
  final String textContent;
  final String suggestedTaskTitle;
  final String sceneDescription;
  final String imageUrl;

  const ImageRecognitionResult({
    required this.textContent,
    required this.suggestedTaskTitle,
    required this.sceneDescription,
    required this.imageUrl,
  });
}

/// 按来源过滤记忆列表（纯函数，不依赖 UI）
///
/// [senderFilter] 为 'all' 时返回全部记忆；
/// 其他值时仅返回 sender 匹配的条目。
/// sender 为空字符串的记忆视为 'user-manual'。
List<MemoryItem> filterBySender(List<MemoryItem> items, String senderFilter) {
  if (senderFilter == 'all') return items;
  return items.where((item) {
    final effectiveSender = item.sender.isEmpty ? 'user-manual' : item.sender;
    return effectiveSender == senderFilter;
  }).toList();
}

/// 模拟 mute 操作后的列表移除（纯函数）
///
/// 从记忆列表中移除指定 ID 的条目，返回新列表。
/// 用于 mute 操作成功后在前端更新列表状态。
List<MemoryItem> removeById(List<MemoryItem> items, String mutedId) {
  return items.where((item) => item.id != mutedId).toList();
}
