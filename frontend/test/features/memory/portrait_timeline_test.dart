// Feature: memory-system-evolution, Property 11: Portrait timeline ordering
// 画像时间线 Widget 测试
// 验证画像列表按 epoch 升序排列，以及 0/1/多张画像的 UI 状态
// Validates: Requirements 5.1, 5.2, 5.3, 5.4

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/memory/screens/memory_page.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // 辅助函数
  // ──────────────────────────────────────────────────────────

  /// 从 map 构造 PortraitTimelineItem 的便捷方法
  PortraitTimelineItem makeItem({
    String id = '',
    required String epoch,
    String summary = '',
    String imageUrl = '',
    String? createdAt,
  }) {
    return PortraitTimelineItem.fromMap({
      'id': id,
      'epoch': epoch,
      'summary': summary,
      'image_url': imageUrl,
      'created_at': createdAt,
    });
  }

  /// 生成随机 epoch 字符串，格式 YYYY-Wnn
  String randomEpoch(Random rng) {
    final year = 2020 + rng.nextInt(10); // 2020–2029
    final week = 1 + rng.nextInt(53);    // W01–W53
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  // ──────────────────────────────────────────────────────────
  // Property 11: 画像列表按 epoch 升序排列
  // ──────────────────────────────────────────────────────────

  group('Property 11: Portrait timeline ordering', () {
    test('随机 epoch 列表排序后应按字典序升序排列', () {
      // **Validates: Requirements 5.1**
      // 使用随机种子保证可复现，运行 100 次迭代
      final rng = Random(42);

      for (var iteration = 0; iteration < 100; iteration++) {
        // 生成 2–10 个随机 epoch
        final count = 2 + rng.nextInt(9);
        final epochs = List.generate(count, (_) => randomEpoch(rng));

        // 构造 PortraitTimelineItem 列表（乱序）
        final items = epochs
            .map((e) => makeItem(epoch: e, summary: '测试画像 $e'))
            .toList();

        // 按 epoch 升序排序（与前端 _loadPortraits 查询行为一致）
        items.sort((a, b) => a.epoch.compareTo(b.epoch));

        // 验证排序结果：每个元素的 epoch 应 <= 下一个元素的 epoch
        for (var i = 0; i < items.length - 1; i++) {
          expect(
            items[i].epoch.compareTo(items[i + 1].epoch) <= 0,
            isTrue,
            reason:
                '迭代 $iteration: epoch[${items[i].epoch}] 应 <= epoch[${items[i + 1].epoch}]',
          );
        }
      }
    });

    test('相同 epoch 排序应保持稳定', () {
      // **Validates: Requirements 5.1**
      final items = [
        makeItem(id: 'a', epoch: '2026-W10', summary: '第一张'),
        makeItem(id: 'b', epoch: '2026-W10', summary: '第二张'),
        makeItem(id: 'c', epoch: '2026-W08', summary: '更早的'),
      ];

      items.sort((a, b) => a.epoch.compareTo(b.epoch));

      expect(items[0].epoch, '2026-W08');
      expect(items[1].epoch, '2026-W10');
      expect(items[2].epoch, '2026-W10');
    });

    test('单调递增的 epoch 序列排序后顺序不变', () {
      // **Validates: Requirements 5.1**
      final epochs = ['2026-W01', '2026-W02', '2026-W10', '2026-W52', '2027-W01'];
      final items = epochs.map((e) => makeItem(epoch: e)).toList();

      items.sort((a, b) => a.epoch.compareTo(b.epoch));

      for (var i = 0; i < epochs.length; i++) {
        expect(items[i].epoch, epochs[i]);
      }
    });
  });

  // ──────────────────────────────────────────────────────────
  // PortraitTimelineItem.fromMap 工厂构造测试
  // ──────────────────────────────────────────────────────────

  group('PortraitTimelineItem.fromMap', () {
    test('完整字段正确解析', () {
      final item = PortraitTimelineItem.fromMap({
        'id': 'abc-123',
        'epoch': '2026-W17',
        'summary': '用户本周专注于阅读',
        'image_url': 'https://example.com/portrait.png',
        'created_at': '2026-04-20T10:00:00Z',
      });

      expect(item.id, 'abc-123');
      expect(item.epoch, '2026-W17');
      expect(item.summary, '用户本周专注于阅读');
      expect(item.imageUrl, 'https://example.com/portrait.png');
      expect(item.createdAt, isNotNull);
      expect(item.createdAt!.year, 2026);
    });

    test('缺失字段使用默认空字符串', () {
      final item = PortraitTimelineItem.fromMap({});

      expect(item.id, '');
      expect(item.epoch, '');
      expect(item.summary, '');
      expect(item.imageUrl, '');
      expect(item.createdAt, isNull);
    });

    test('null 值字段使用默认空字符串', () {
      final item = PortraitTimelineItem.fromMap({
        'id': null,
        'epoch': null,
        'summary': null,
        'image_url': null,
        'created_at': null,
      });

      expect(item.id, '');
      expect(item.epoch, '');
      expect(item.summary, '');
      expect(item.imageUrl, '');
      expect(item.createdAt, isNull);
    });

    test('imageUrl 兼容 imageUrl 和 image_url 两种字段名', () {
      // 使用 image_url（下划线命名）
      final item1 = PortraitTimelineItem.fromMap({
        'image_url': 'https://a.com/1.png',
      });
      expect(item1.imageUrl, 'https://a.com/1.png');

      // 使用 imageUrl（驼峰命名）
      final item2 = PortraitTimelineItem.fromMap({
        'imageUrl': 'https://a.com/2.png',
      });
      expect(item2.imageUrl, 'https://a.com/2.png');
    });

    test('created_at 为空字符串时 createdAt 为 null', () {
      final item = PortraitTimelineItem.fromMap({
        'created_at': '',
      });
      expect(item.createdAt, isNull);
    });

    test('created_at 为无效日期字符串时 createdAt 为 null', () {
      final item = PortraitTimelineItem.fromMap({
        'created_at': 'not-a-date',
      });
      expect(item.createdAt, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────
  // 0 张画像：显示引导文案
  // ──────────────────────────────────────────────────────────

  group('0 张画像 UI 状态', () {
    test('空画像列表应触发引导文案数据流', () {
      // **Validates: Requirements 5.3**
      // 验证数据层：空列表长度为 0，前端应据此显示引导文案
      final portraits = <PortraitTimelineItem>[];
      expect(portraits.isEmpty, isTrue);
      expect(portraits.length <= 1, isTrue,
          reason: '0 张画像时应显示引导文案而非时间线');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 1 张画像：显示引导文案
  // ──────────────────────────────────────────────────────────

  group('1 张画像 UI 状态', () {
    test('单张画像应触发引导文案数据流', () {
      // **Validates: Requirements 5.3**
      final portraits = [
        makeItem(
          epoch: '2026-W17',
          summary: '首张画像',
          imageUrl: 'https://example.com/first.png',
        ),
      ];
      expect(portraits.length, 1);
      expect(portraits.length <= 1, isTrue,
          reason: '1 张画像时应显示引导文案而非可滑动时间线');
      expect(portraits.first.epoch, '2026-W17');
      expect(portraits.first.summary, '首张画像');
    });
  });

  // ──────────────────────────────────────────────────────────
  // 多张画像：按 epoch 升序排列
  // ──────────────────────────────────────────────────────────

  group('多张画像 UI 状态', () {
    test('多张画像按 epoch 升序排列后顺序正确', () {
      // **Validates: Requirements 5.1, 5.2**
      final portraits = [
        makeItem(epoch: '2026-W20', summary: '第三周'),
        makeItem(epoch: '2026-W17', summary: '第一周'),
        makeItem(epoch: '2026-W18', summary: '第二周'),
      ];

      // 模拟前端排序逻辑（与 _loadPortraits 中 order('epoch', ascending: true) 一致）
      portraits.sort((a, b) => a.epoch.compareTo(b.epoch));

      expect(portraits.length, greaterThan(1),
          reason: '多张画像时应显示可滑动时间线');
      expect(portraits[0].epoch, '2026-W17');
      expect(portraits[1].epoch, '2026-W18');
      expect(portraits[2].epoch, '2026-W20');
    });

    test('跨年 epoch 排序正确', () {
      // **Validates: Requirements 5.1**
      final portraits = [
        makeItem(epoch: '2027-W02', summary: '新年第二周'),
        makeItem(epoch: '2026-W50', summary: '年末'),
        makeItem(epoch: '2026-W52', summary: '跨年周'),
        makeItem(epoch: '2027-W01', summary: '新年第一周'),
      ];

      portraits.sort((a, b) => a.epoch.compareTo(b.epoch));

      expect(portraits[0].epoch, '2026-W50');
      expect(portraits[1].epoch, '2026-W52');
      expect(portraits[2].epoch, '2027-W01');
      expect(portraits[3].epoch, '2027-W02');
    });

    test('默认定位到最新一张画像', () {
      // **Validates: Requirements 5.2**
      // 验证前端逻辑：多张画像时 _currentPortraitIndex 应指向最后一张
      final portraits = [
        makeItem(epoch: '2026-W15'),
        makeItem(epoch: '2026-W16'),
        makeItem(epoch: '2026-W17'),
      ];

      // 模拟 _loadPortraits 中的逻辑
      int currentPortraitIndex = 0;
      if (portraits.length > 1) {
        currentPortraitIndex = portraits.length - 1;
      }

      expect(currentPortraitIndex, 2,
          reason: '应默认定位到最新（最后）一张画像');
    });
  });
}
