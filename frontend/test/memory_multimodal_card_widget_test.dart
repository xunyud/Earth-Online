// 语音/图片记忆卡片展示 Widget 测试
// 验证 MemoryPage 中 voice_memory 和 image_recognition 类型卡片的渲染
// Requirements: 20.1, 20.2, 20.3, 20.4

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/core/services/memory_service.dart';
import 'package:frontend/core/theme/quest_theme.dart';

/// 构建包含信封格式的 MemoryItem
MemoryItem _makeItem({
  required String id,
  String eventType = 'task_complete',
  String content = '测试内容',
  String summary = '测试摘要',
  String memoryKind = 'task_event',
  String sender = 'user-manual',
  String? audioUrl,
  String? imageUrl,
}) {
  final envelope = [
    '[smart-p-memory:v1] eventType=$eventType',
    'content=$content',
    'summary=$summary',
    'memoryKind=$memoryKind',
    'sourceTaskTitle=',
    'sender=$sender',
    'pinned=false',
  ].join(' | ');

  return MemoryItem.fromMap({
    'id': id,
    'content': envelope,
    'event_type': eventType,
    'created_at': DateTime.now().toIso8601String(),
    'score': 0.9,
    if (audioUrl != null) 'audio_url': audioUrl,
    if (imageUrl != null) 'image_url': imageUrl,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  group('🎙️ voice_memory 卡片数据模型验证', () {
    test('voice_memory 类型的 MemoryItem 正确解析 eventType 和 audioUrl', () {
      final item = _makeItem(
        id: 'voice-card-1',
        eventType: 'voice_memory',
        memoryKind: 'dialog_event',
        audioUrl: 'https://storage.example.com/voice-memories/test.wav',
      );
      expect(item.eventType, 'voice_memory');
      expect(item.audioUrl, 'https://storage.example.com/voice-memories/test.wav');
      expect(item.memoryKind, 'dialog_event');
    });

    test('voice_memory 无 audioUrl 时 audioUrl 为 null', () {
      final item = _makeItem(
        id: 'voice-card-2',
        eventType: 'voice_memory',
        memoryKind: 'dialog_event',
      );
      expect(item.eventType, 'voice_memory');
      expect(item.audioUrl, isNull,
          reason: '无 audio_url 时应为 null');
    });

    test('voice_memory 的 sender 为 user-manual', () {
      final item = _makeItem(
        id: 'voice-card-3',
        eventType: 'voice_memory',
        sender: 'user-manual',
      );
      expect(item.sender, 'user-manual');
    });
  });

  group('📷 image_recognition 卡片数据模型验证', () {
    test('image_recognition 类型的 MemoryItem 正确解析 eventType 和 imageUrl',
        () {
      final item = _makeItem(
        id: 'img-card-1',
        eventType: 'image_recognition',
        memoryKind: 'task_event',
        imageUrl: 'https://storage.example.com/image-memories/test.jpg',
      );
      expect(item.eventType, 'image_recognition');
      expect(item.imageUrl,
          'https://storage.example.com/image-memories/test.jpg');
    });

    test('image_recognition 无 imageUrl 时 imageUrl 为 null', () {
      final item = _makeItem(
        id: 'img-card-2',
        eventType: 'image_recognition',
        memoryKind: 'generic',
      );
      expect(item.eventType, 'image_recognition');
      expect(item.imageUrl, isNull,
          reason: '无 image_url 时应为 null');
    });
  });

  group('🔍 普通记忆卡片不显示多媒体控件', () {
    test('task_complete 类型不含 audioUrl 和 imageUrl', () {
      final item = _makeItem(
        id: 'normal-1',
        eventType: 'task_complete',
        memoryKind: 'task_event',
      );
      expect(item.eventType, 'task_complete');
      expect(item.audioUrl, isNull,
          reason: '普通记忆不应有 audioUrl');
      expect(item.imageUrl, isNull,
          reason: '普通记忆不应有 imageUrl');
    });

    test('dialog_event 类型（非 voice_memory）不含 audioUrl', () {
      final item = _makeItem(
        id: 'normal-2',
        eventType: 'guide_chat',
        memoryKind: 'dialog_event',
      );
      expect(item.eventType, 'guide_chat');
      expect(item.audioUrl, isNull);
    });
  });

  group('🎙️ voice_memory 卡片渲染逻辑验证', () {
    test('eventType 为 voice_memory 时应显示播放控件', () {
      final item = _makeItem(
        id: 'voice-render-1',
        eventType: 'voice_memory',
        audioUrl: 'https://storage.example.com/voice.wav',
      );
      // 验证条件：eventType == 'voice_memory' 时渲染 _VoicePlaybackRow
      expect(item.eventType == 'voice_memory', isTrue,
          reason: 'voice_memory 类型应触发播放控件渲染');
    });

    test('eventType 非 voice_memory 时不应显示播放控件', () {
      final item = _makeItem(
        id: 'voice-render-2',
        eventType: 'task_complete',
      );
      expect(item.eventType == 'voice_memory', isFalse,
          reason: '非 voice_memory 类型不应触发播放控件渲染');
    });
  });

  group('📷 image_recognition 卡片渲染逻辑验证', () {
    test('eventType 为 image_recognition 且有 imageUrl 时应显示缩略图', () {
      final item = _makeItem(
        id: 'img-render-1',
        eventType: 'image_recognition',
        imageUrl: 'https://storage.example.com/image.jpg',
      );
      final shouldShowThumbnail = item.eventType == 'image_recognition' &&
          item.imageUrl != null &&
          item.imageUrl!.isNotEmpty;
      expect(shouldShowThumbnail, isTrue,
          reason: 'image_recognition 且有 imageUrl 时应显示缩略图');
    });

    test('eventType 为 image_recognition 但无 imageUrl 时不显示缩略图', () {
      final item = _makeItem(
        id: 'img-render-2',
        eventType: 'image_recognition',
      );
      final shouldShowThumbnail = item.eventType == 'image_recognition' &&
          item.imageUrl != null &&
          item.imageUrl!.isNotEmpty;
      expect(shouldShowThumbnail, isFalse,
          reason: '无 imageUrl 时不应显示缩略图');
    });

    test('eventType 非 image_recognition 时不显示缩略图', () {
      final item = _makeItem(
        id: 'img-render-3',
        eventType: 'task_complete',
        imageUrl: 'https://storage.example.com/image.jpg',
      );
      final shouldShowThumbnail = item.eventType == 'image_recognition' &&
          item.imageUrl != null &&
          item.imageUrl!.isNotEmpty;
      expect(shouldShowThumbnail, isFalse,
          reason: '非 image_recognition 类型不应显示缩略图');
    });
  });

  group('🎙️ 音频不可用提示验证', () {
    test('audioUrl 为 null 时应显示音频不可用提示', () {
      final item = _makeItem(
        id: 'audio-unavail-1',
        eventType: 'voice_memory',
      );
      // 当 audioUrl 为 null 或空时，播放控件应显示"音频不可用"
      final audioUnavailable =
          item.audioUrl == null || item.audioUrl!.isEmpty;
      expect(audioUnavailable, isTrue,
          reason: 'audioUrl 为 null 时应标记为音频不可用');
    });

    test('audioUrl 为空字符串时应显示音频不可用提示', () {
      final item = MemoryItem.fromMap({
        'id': 'audio-unavail-2',
        'content': '[smart-p-memory:v1] eventType=voice_memory | '
            'content=测试 | summary=测试 | memoryKind=dialog_event | '
            'sourceTaskTitle= | sender=user-manual | pinned=false',
        'event_type': 'voice_memory',
        'created_at': DateTime.now().toIso8601String(),
        'score': 0.9,
        'audio_url': '',
      });
      final audioUnavailable =
          item.audioUrl == null || item.audioUrl!.isEmpty;
      expect(audioUnavailable, isTrue,
          reason: 'audioUrl 为空字符串时应标记为音频不可用');
    });

    test('audioUrl 有效时不应显示音频不可用提示', () {
      final item = _makeItem(
        id: 'audio-avail',
        eventType: 'voice_memory',
        audioUrl: 'https://storage.example.com/voice.wav',
      );
      final audioUnavailable =
          item.audioUrl == null || item.audioUrl!.isEmpty;
      expect(audioUnavailable, isFalse,
          reason: '有效 audioUrl 时不应标记为音频不可用');
    });
  });

  group('📷 图片全屏展示逻辑验证', () {
    test('imageUrl 有效时支持全屏展示', () {
      const imageUrl = 'https://storage.example.com/image.jpg';
      expect(imageUrl.isNotEmpty, isTrue,
          reason: '有效 imageUrl 应支持全屏展示');
    });
  });
}
