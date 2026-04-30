// Feature: memory-moat, Property 23: Muted memory list removal
// 验证 mute 操作后列表长度减 1 且不含被 mute 的条目
// 使用 glados 生成随机记忆列表，从中随机选取一条执行 removeById
// **Validates: Requirements 9.4**

import 'dart:math';

import 'package:glados/glados.dart';
import 'package:test/test.dart';

import 'package:frontend/core/services/memory_service.dart';

/// 有效的 sender 名称集合
const _validSenders = [
  'user-manual',
  'guide-assistant',
  'agent-runtime',
  'patrol-nudge',
  'wechat-webhook',
  '',
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
];

/// 生成不含管道符和等号的安全字符串（信封格式保留字符）
String _safeName(Random random, int maxLen) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789中文测试';
  final len = random.nextInt(maxLen.clamp(1, maxLen)) + 1;
  return String.fromCharCodes(
    List.generate(len, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}

/// 生成单个随机 MemoryItem（确保 ID 唯一性由调用方控制）
MemoryItem _generateOneItem(Random random, String id) {
  final sender = _validSenders[random.nextInt(_validSenders.length)];
  final memoryKind =
      _validMemoryKinds[random.nextInt(_validMemoryKinds.length)];
  final eventType =
      _validEventTypes[random.nextInt(_validEventTypes.length)];
  final pinned = random.nextBool();

  final content = _safeName(random, 20);
  final summary = _safeName(random, 15);
  final sourceTaskTitle = _safeName(random, 10);
  final score = random.nextInt(1001) / 1000.0;

  // 随机日期（2024–2027）
  final dayOffset = random.nextInt(4 * 365);
  final createdAt = DateTime(2024).add(Duration(days: dayOffset));

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
  );
}

/// 测试输入：一个非空记忆列表 + 被 mute 的条目索引
class MuteTestInput {
  final List<MemoryItem> items;
  final int mutedIndex; // 被 mute 的条目在列表中的索引

  const MuteTestInput(this.items, this.mutedIndex);

  /// 被 mute 的条目 ID
  String get mutedId => items[mutedIndex].id;
}

/// 扩展 Any 命名空间，注册自定义生成器
extension AnyMuteRemoval on Any {
  /// 生成非空记忆列表 + 随机选取的 mute 目标索引
  /// 列表长度 1–30，每条记忆 ID 唯一
  Generator<MuteTestInput> get muteTestInput => simple(
        generate: (random, size) {
          // 至少 1 条，最多 30 条
          final len = random.nextInt(30) + 1;
          // 生成唯一 ID 列表
          final ids = List.generate(len, (i) => 'mem-$i-${_safeName(random, 6)}');
          final items = ids.map((id) => _generateOneItem(random, id)).toList();
          final mutedIndex = random.nextInt(len);
          return MuteTestInput(items, mutedIndex);
        },
        shrink: (input) sync* {
          // 收缩策略：减少列表长度（保留被 mute 的条目）
          if (input.items.length > 1) {
            // 移除非目标条目来缩小列表
            final newItems = <MemoryItem>[];
            int newMutedIndex = 0;
            for (var i = 0; i < input.items.length; i++) {
              if (i == input.mutedIndex) {
                newMutedIndex = newItems.length;
                newItems.add(input.items[i]);
              } else if (newItems.length < input.items.length - 1) {
                newItems.add(input.items[i]);
              }
            }
            if (newItems.length < input.items.length) {
              yield MuteTestInput(newItems, newMutedIndex);
            }
          }
        },
      );
}

void main() {
  // ──────────────────────────────────────────────────────────
  // Property 23: Muted memory list removal
  // 对任意非空记忆列表，mute 操作后列表长度减 1 且不含被 mute 的条目
  // ──────────────────────────────────────────────────────────

  group('Property 23: Muted memory list removal', () {
    // 属性 23a：mute 后列表长度恰好减 1
    Glados(any.muteTestInput, ExploreConfig(numRuns: 150)).test(
      'mute 操作后列表长度应恰好减 1',
      (input) {
        final originalLen = input.items.length;
        final result = removeById(input.items, input.mutedId);

        expect(result.length, originalLen - 1,
            reason: 'mute 后列表长度应为原始长度 - 1，'
                '原始长度=$originalLen，mutedId="${input.mutedId}"');
      },
    );

    // 属性 23b：mute 后结果列表不含被 mute 的条目 ID
    Glados(any.muteTestInput, ExploreConfig(numRuns: 150)).test(
      'mute 操作后结果列表不应包含被 mute 的条目',
      (input) {
        final result = removeById(input.items, input.mutedId);
        final resultIds = result.map((item) => item.id).toSet();

        expect(resultIds.contains(input.mutedId), isFalse,
            reason: '结果列表不应包含 mutedId="${input.mutedId}"');
      },
    );

    // 属性 23c：mute 不影响其他条目（保序性和完整性）
    Glados(any.muteTestInput, ExploreConfig(numRuns: 150)).test(
      'mute 操作不应影响其他条目的顺序和内容',
      (input) {
        final result = removeById(input.items, input.mutedId);

        // 手动构建期望结果：移除 mutedIndex 位置的条目
        final expected = <MemoryItem>[];
        for (var i = 0; i < input.items.length; i++) {
          if (i != input.mutedIndex) {
            expected.add(input.items[i]);
          }
        }

        expect(result.length, expected.length,
            reason: '结果长度应与手动计算一致');

        for (var i = 0; i < result.length; i++) {
          expect(result[i].id, expected[i].id,
              reason: '第 $i 条记忆 ID 应保持一致');
          expect(result[i].content, expected[i].content,
              reason: '第 $i 条记忆 content 应保持一致');
        }
      },
    );
  });
}
