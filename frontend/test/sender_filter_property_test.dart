// Feature: memory-moat, Property 4: Sender-based memory filtering
// 验证 filterBySender 纯函数对任意 MemoryItem 列表和任意 sender 过滤值的正确性
// 使用 glados 生成随机 MemoryItem 列表和随机 sender 过滤值
// **Validates: Requirements 3.2, 3.5**

import 'dart:math';

import 'package:glados/glados.dart';
import 'package:test/test.dart';

import 'package:frontend/core/services/memory_service.dart';

/// 有效的 sender 名称集合（含空字符串表示无 sender）
const _validSenders = [
  'user-manual',
  'guide-assistant',
  'agent-runtime',
  'patrol-nudge',
  'wechat-webhook',
  '', // 空字符串 → 归类为 user-manual
];

/// 有效的过滤值集合（含 'all' 表示不过滤）
const _validFilters = [
  'all',
  'user-manual',
  'guide-assistant',
  'agent-runtime',
  'patrol-nudge',
  'wechat-webhook',
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

/// 生成单个随机 MemoryItem（顶层辅助函数，供列表生成器调用）
MemoryItem _generateOneItem(Random random) {
  final sender = _validSenders[random.nextInt(_validSenders.length)];
  final memoryKind =
      _validMemoryKinds[random.nextInt(_validMemoryKinds.length)];
  final eventType =
      _validEventTypes[random.nextInt(_validEventTypes.length)];
  final pinned = random.nextBool();

  final id = _safeName(random, 10);
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

/// 扩展 Any 命名空间，注册自定义生成器
extension AnySenderFilter on Any {
  /// 生成随机长度的 MemoryItem 列表（0–30 条）
  Generator<List<MemoryItem>> get memoryItemList => simple(
        generate: (random, size) {
          final len = random.nextInt(31); // 0–30 条
          return List.generate(len, (_) => _generateOneItem(random));
        },
        shrink: (list) sync* {
          if (list.length > 1) yield list.sublist(1);
          if (list.length > 2) yield list.sublist(0, list.length - 1);
        },
      );

  /// 生成随机 sender 过滤值
  Generator<String> get senderFilter => simple(
        generate: (random, size) =>
            _validFilters[random.nextInt(_validFilters.length)],
        shrink: (value) sync* {
          if (value != 'all') yield 'all';
        },
      );
}

void main() {
  // ──────────────────────────────────────────────────────────
  // Property 4: Sender-based memory filtering
  // 对任意 MemoryItem 列表和任意 sender 过滤值，
  // filterBySender 应返回正确的过滤结果
  // ──────────────────────────────────────────────────────────

  group('Property 4: Sender-based memory filtering', () {
    // 属性 4a：filter='all' 时返回全部记忆
    Glados(any.memoryItemList, ExploreConfig(numRuns: 150)).test(
      'filter=all 时应返回全部记忆，长度和内容不变',
      (items) {
        final result = filterBySender(items, 'all');
        expect(result.length, items.length,
            reason: 'all 过滤应返回全部记忆');
        // 验证返回的是原始列表引用
        for (var i = 0; i < items.length; i++) {
          expect(identical(result[i], items[i]), isTrue,
              reason: 'all 过滤应返回原始列表引用');
        }
      },
    );

    // 属性 4b：过滤结果中每条记忆的 effectiveSender 都匹配过滤值
    Glados2(any.memoryItemList, any.senderFilter,
            ExploreConfig(numRuns: 150))
        .test(
      '过滤结果中每条记忆的 effectiveSender 应匹配过滤值',
      (items, filter) {
        final result = filterBySender(items, filter);

        if (filter == 'all') {
          expect(result.length, items.length);
          return;
        }

        // 验证结果中每条记忆的 effectiveSender 匹配
        for (final item in result) {
          final effectiveSender =
              item.sender.isEmpty ? 'user-manual' : item.sender;
          expect(effectiveSender, filter,
              reason:
                  '过滤结果中的记忆 effectiveSender 应为 $filter，'
                  '实际 sender="${item.sender}"');
        }
      },
    );

    // 属性 4c：过滤不会遗漏匹配项（完备性）
    Glados2(any.memoryItemList, any.senderFilter,
            ExploreConfig(numRuns: 150))
        .test(
      '过滤不应遗漏任何匹配项',
      (items, filter) {
        final result = filterBySender(items, filter);

        if (filter == 'all') {
          expect(result.length, items.length);
          return;
        }

        // 手动计算期望匹配数
        final expectedCount = items.where((item) {
          final effectiveSender =
              item.sender.isEmpty ? 'user-manual' : item.sender;
          return effectiveSender == filter;
        }).length;

        expect(result.length, expectedCount,
            reason: '过滤结果数量应等于手动计算的匹配数');
      },
    );

    // 属性 4d：空 sender 的记忆应匹配 'user-manual' 过滤
    Glados(any.memoryItemList, ExploreConfig(numRuns: 150)).test(
      '空 sender 的记忆在 user-manual 过滤下应被包含',
      (items) {
        final result = filterBySender(items, 'user-manual');

        // 所有空 sender 的记忆都应在结果中
        final emptySenderItems =
            items.where((item) => item.sender.isEmpty).toList();
        for (final item in emptySenderItems) {
          expect(result.contains(item), isTrue,
              reason: '空 sender 的记忆应归类为 user-manual');
        }

        // 所有 sender='user-manual' 的记忆也应在结果中
        final userManualItems =
            items.where((item) => item.sender == 'user-manual').toList();
        for (final item in userManualItems) {
          expect(result.contains(item), isTrue,
              reason: 'sender=user-manual 的记忆应在结果中');
        }
      },
    );
  });
}
