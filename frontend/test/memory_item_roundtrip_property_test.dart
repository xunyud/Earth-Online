// Feature: memory-moat, Property 14: MemoryItem serialization round-trip
// 验证 MemoryItem 序列化后再反序列化产生等价对象（round-trip 属性）
// 使用 glados 生成随机 MemoryItem 实例，覆盖 sender、pinned、audioUrl、imageUrl 等字段
// **Validates: Requirements 11.1, 11.2, 11.4, 20.5**

import 'dart:math';

import 'package:glados/glados.dart';

import 'package:frontend/core/services/memory_service.dart';

/// 有效的 sender 名称集合
const _validSenders = [
  'user-manual',
  'guide-assistant',
  'agent-runtime',
  'patrol-nudge',
  'wechat-webhook',
  '', // 空字符串表示无 sender
];

/// 有效的 memoryKind 集合
const _validMemoryKinds = [
  'generic',
  'task_event',
  'dialog_event',
  'milestone',
];

/// 有效的 eventType 集合
const _validEventTypes = [
  'task_complete',
  'guide_chat',
  'night_reflection',
  'voice_memory',
  'image_recognition',
  'agent_goal',
  'patrol_nudge',
];

/// 模拟 URL 集合（用于 audioUrl / imageUrl）
const _sampleUrls = [
  'https://storage.example.com/voice-memories/audio1.mp3',
  'https://storage.example.com/voice-memories/audio2.wav',
  'https://storage.example.com/image-memories/img1.png',
  'https://storage.example.com/image-memories/img2.jpg',
  'https://cdn.example.com/files/test.mp3',
];

/// 扩展 Any 命名空间，注册 MemoryItem 自定义生成器
extension AnyMemoryItem on Any {
  /// 生成不含管道符 `|` 和等号 `=` 的安全字符串
  /// 信封格式使用 `|` 分隔键值对、`=` 分隔键和值，这些字符会破坏解析
  Generator<String> safeString({int maxLen = 30}) => simple(
        generate: (random, size) {
          // 安全字符集：排除 | 和 =
          const chars =
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ0123456789 -_.,!?:;中文测试记忆';
          final len = random.nextInt(maxLen.clamp(1, maxLen)) + 1;
          return String.fromCharCodes(
            List.generate(len, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
          );
        },
        shrink: (value) sync* {
          if (value.length > 1) yield value.substring(1);
        },
      );

  /// 生成随机 DateTime（2024-2027 范围内）
  Generator<DateTime> get memoryDateTime => simple(
        generate: (random, size) {
          final start = DateTime(2024).millisecondsSinceEpoch;
          final end = DateTime(2028).millisecondsSinceEpoch;
          final ms = start + random.nextInt(end - start);
          return DateTime.fromMillisecondsSinceEpoch(ms);
        },
        shrink: (value) sync* {
          // 收缩到更早的时间
          final earlier = value.subtract(const Duration(days: 1));
          if (earlier.isAfter(DateTime(2024))) yield earlier;
        },
      );

  /// 生成随机 score（0.0 到 1.0）
  Generator<double> get memoryScore => simple(
        generate: (random, size) => random.nextInt(1001) / 1000.0,
        shrink: (value) sync* {
          if (value > 0.0) yield 0.0;
        },
      );

  /// 生成可选的 URL（null 或有效 URL）
  Generator<String?> get optionalUrl => simple(
        generate: (random, size) {
          // 约 50% 概率返回 null
          if (random.nextBool()) return null;
          return _sampleUrls[random.nextInt(_sampleUrls.length)];
        },
        shrink: (value) sync* {
          if (value != null) yield null;
        },
      );

  /// 生成完整的随机 MemoryItem 用于 round-trip 测试
  Generator<MemoryItem> get memoryItem => simple(
        generate: (random, size) {
          final sender = _validSenders[random.nextInt(_validSenders.length)];
          final pinned = random.nextBool();
          final memoryKind =
              _validMemoryKinds[random.nextInt(_validMemoryKinds.length)];
          final eventType =
              _validEventTypes[random.nextInt(_validEventTypes.length)];

          // 生成安全字符串（不含 | 和 =，且无前后空格以确保信封解析 round-trip）
          String safeName(int len) {
            // 非空格安全字符集
            const nonSpaceChars =
                'abcdefghijklmnopqrstuvwxyz0123456789-_.,中文测试记忆';
            // 含空格的安全字符集（用于中间字符）
            const allChars =
                'abcdefghijklmnopqrstuvwxyz0123456789 -_.,中文测试记忆';
            final actualLen = random.nextInt(len.clamp(1, len)) + 1;
            if (actualLen == 1) {
              // 单字符：不能是空格
              return String.fromCharCodes([
                nonSpaceChars.codeUnitAt(random.nextInt(nonSpaceChars.length))
              ]);
            }
            // 首尾字符不能是空格，中间字符可以含空格
            final chars = List.generate(actualLen, (i) {
              if (i == 0 || i == actualLen - 1) {
                return nonSpaceChars.codeUnitAt(random.nextInt(nonSpaceChars.length));
              }
              return allChars.codeUnitAt(random.nextInt(allChars.length));
            });
            return String.fromCharCodes(chars);
          }

          final id = safeName(10);
          final content = safeName(30);
          final summary = safeName(20);
          final sourceTaskTitle = safeName(15);
          final score = random.nextInt(1001) / 1000.0;

          // 随机 DateTime（使用天数偏移避免 nextInt 溢出）
          final baseDays = DateTime(2024).millisecondsSinceEpoch ~/ 86400000;
          final rangeDays = 4 * 365; // 约 4 年
          final dayOffset = random.nextInt(rangeDays);
          final hourOffset = random.nextInt(24);
          final minuteOffset = random.nextInt(60);
          final createdAt = DateTime(2024)
              .add(Duration(days: dayOffset, hours: hourOffset, minutes: minuteOffset));

          // 可选 URL
          final audioUrl =
              random.nextBool() ? _sampleUrls[random.nextInt(_sampleUrls.length)] : null;
          final imageUrl =
              random.nextBool() ? _sampleUrls[random.nextInt(_sampleUrls.length)] : null;

          return MemoryItem(
            id: id,
            content: content,
            summary: summary,
            memoryKind: memoryKind,
            eventType: eventType,
            sourceTaskTitle: sourceTaskTitle,
            createdAt: createdAt,
            score: score,
            sender: sender,
            pinned: pinned,
            audioUrl: audioUrl,
            imageUrl: imageUrl,
          );
        },
        shrink: (item) sync* {
          // 收缩策略：逐步简化字段
          if (item.content.length > 1) {
            yield MemoryItem(
              id: item.id,
              content: item.content.substring(1),
              summary: item.summary,
              memoryKind: item.memoryKind,
              eventType: item.eventType,
              sourceTaskTitle: item.sourceTaskTitle,
              createdAt: item.createdAt,
              score: item.score,
              sender: item.sender,
              pinned: item.pinned,
              audioUrl: item.audioUrl,
              imageUrl: item.imageUrl,
            );
          }
          if (item.audioUrl != null) {
            yield MemoryItem(
              id: item.id,
              content: item.content,
              summary: item.summary,
              memoryKind: item.memoryKind,
              eventType: item.eventType,
              sourceTaskTitle: item.sourceTaskTitle,
              createdAt: item.createdAt,
              score: item.score,
              sender: item.sender,
              pinned: item.pinned,
              audioUrl: null,
              imageUrl: item.imageUrl,
            );
          }
          if (item.imageUrl != null) {
            yield MemoryItem(
              id: item.id,
              content: item.content,
              summary: item.summary,
              memoryKind: item.memoryKind,
              eventType: item.eventType,
              sourceTaskTitle: item.sourceTaskTitle,
              createdAt: item.createdAt,
              score: item.score,
              sender: item.sender,
              pinned: item.pinned,
              audioUrl: item.audioUrl,
              imageUrl: null,
            );
          }
        },
      );
}

void main() {
  // ──────────────────────────────────────────────────────────
  // Property 14: MemoryItem serialization round-trip
  // 对任意有效 MemoryItem 实例，toMap() → fromMap() 应产生等价对象
  // ──────────────────────────────────────────────────────────

  group('Property 14: MemoryItem serialization round-trip', () {
    // 使用 ExploreConfig 确保至少运行 100 次迭代
    Glados(any.memoryItem, ExploreConfig(numRuns: 150)).test(
      '随机 MemoryItem 经 toMap → fromMap 后所有字段应保持一致',
      (original) {
        // 序列化
        final map = original.toMap();

        // 反序列化
        final restored = MemoryItem.fromMap(map);

        // 验证所有字段等价
        expect(restored.id, original.id,
            reason: 'id 应保持一致');
        expect(restored.content, original.content,
            reason: 'content 应保持一致');
        expect(restored.summary, original.summary,
            reason: 'summary 应保持一致');
        expect(restored.memoryKind, original.memoryKind,
            reason: 'memoryKind 应保持一致');
        expect(restored.eventType, original.eventType,
            reason: 'eventType 应保持一致');
        expect(restored.sourceTaskTitle, original.sourceTaskTitle,
            reason: 'sourceTaskTitle 应保持一致');
        expect(restored.sender, original.sender,
            reason: 'sender 应保持一致');
        expect(restored.pinned, original.pinned,
            reason: 'pinned 应保持一致');
        expect(restored.score, original.score,
            reason: 'score 应保持一致');
        expect(restored.audioUrl, original.audioUrl,
            reason: 'audioUrl 应保持一致');
        expect(restored.imageUrl, original.imageUrl,
            reason: 'imageUrl 应保持一致');

        // createdAt 通过 ISO 8601 字符串序列化，精度可能有微秒差异
        // 比较到秒级精度
        if (original.createdAt != null) {
          expect(restored.createdAt, isNotNull,
              reason: 'createdAt 不应为 null');
          expect(
            restored.createdAt!.difference(original.createdAt!).inSeconds.abs(),
            lessThanOrEqualTo(1),
            reason: 'createdAt 应在 1 秒精度内一致',
          );
        } else {
          expect(restored.createdAt, isNull,
              reason: 'createdAt 原始为 null 时恢复也应为 null');
        }
      },
    );
  });
}
