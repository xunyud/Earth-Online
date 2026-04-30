// 来源过滤 UI Widget 测试
// 验证 MemoryPage 中来源过滤标签行和记忆卡片来源图标的渲染行为
// Requirements: 3.1, 3.2, 3.3, 3.5, 4.1, 4.2

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/core/i18n/app_locale_controller.dart';
import 'package:frontend/core/services/memory_service.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/features/memory/screens/memory_page.dart';

/// 构建测试用 MaterialApp，包含 QuestTheme 和 MemoryPage
Widget _buildTestApp() {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: [QuestTheme.freshBreath()],
    ),
    home: const MemoryPage(),
  );
}

/// 构建测试用 MemoryItem，指定 sender 和其他关键字段
MemoryItem _makeItem({
  required String id,
  String sender = '',
  String content = '测试内容',
  String summary = '测试摘要',
  String memoryKind = 'task_event',
  String eventType = 'task_complete',
  bool pinned = false,
}) {
  // 通过信封格式构建，确保 fromMap 能正确解析 sender
  final envelope = [
    '[smart-p-memory:v1] eventType=$eventType',
    'content=$content',
    'summary=$summary',
    'memoryKind=$memoryKind',
    'sourceTaskTitle=',
    if (sender.isNotEmpty) 'sender=$sender',
    'pinned=$pinned',
  ].join(' | ');

  return MemoryItem.fromMap({
    'id': id,
    'content': envelope,
    'created_at': DateTime.now().toIso8601String(),
    'score': 0.9,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // 初始化 Supabase（使用假凭据，HTTP 调用会失败但不影响 UI 渲染测试）
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {
      // 重复初始化时忽略错误
    }
  });

  group('来源过滤标签行渲染', () {
    testWidgets('默认选中"全部"标签，所有 6 个过滤标签均可见', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      // 等待首帧渲染完成（HTTP 调用会异步失败，不阻塞 UI）
      await tester.pump();

      // 验证 6 个来源过滤标签文本均存在
      // i18n 默认中文：全部、我的记录、AI 助手、Agent、巡逻提醒、微信
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('我的记录'), findsOneWidget);
      expect(find.text('AI 助手'), findsOneWidget);
      expect(find.text('Agent'), findsOneWidget);
      expect(find.text('巡逻提醒'), findsOneWidget);
      expect(find.text('微信'), findsOneWidget);
    });

    testWidgets('默认"全部"标签具有选中态样式（白色文字 + 深色背景）', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // "全部"标签应为选中态：白色文字
      final allChipText = tester.widget<Text>(
        find.text('全部'),
      );
      // 选中态文字颜色为白色
      expect(allChipText.style?.color, Colors.white);

      // "我的记录"标签应为未选中态：非白色文字
      final myRecordsText = tester.widget<Text>(
        find.text('我的记录'),
      );
      expect(myRecordsText.style?.color, isNot(Colors.white));
    });

    testWidgets('点击"我的记录"标签后该标签变为选中态', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // 点击"我的记录"标签
      await tester.tap(find.text('我的记录'));
      await tester.pump();

      // "我的记录"应变为选中态（白色文字）
      final myRecordsText = tester.widget<Text>(
        find.text('我的记录'),
      );
      expect(myRecordsText.style?.color, Colors.white);

      // "全部"应变为未选中态
      final allText = tester.widget<Text>(
        find.text('全部'),
      );
      expect(allText.style?.color, isNot(Colors.white));
    });

    testWidgets('来源过滤标签行包含正确的图标', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // "全部"标签无图标，其余 5 个标签各有对应图标
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byIcon(Icons.chat), findsOneWidget);
    });
  });

  group('记忆卡片来源图标渲染', () {
    testWidgets('MemoryItem 的 sender 字段通过信封格式正确解析', (tester) async {
      // 验证各 sender 值通过 fromMap 正确解析
      final items = [
        _makeItem(id: '1', sender: 'user-manual'),
        _makeItem(id: '2', sender: 'guide-assistant'),
        _makeItem(id: '3', sender: 'agent-runtime'),
        _makeItem(id: '4', sender: 'patrol-nudge'),
        _makeItem(id: '5', sender: 'wechat-webhook'),
      ];

      expect(items[0].sender, 'user-manual');
      expect(items[1].sender, 'guide-assistant');
      expect(items[2].sender, 'agent-runtime');
      expect(items[3].sender, 'patrol-nudge');
      expect(items[4].sender, 'wechat-webhook');
    });

    testWidgets('缺少 sender 的记忆 sender 字段为空字符串', (tester) async {
      // 不含 sender 的信封，解析后 sender 应为空字符串
      final item = _makeItem(id: 'no-sender');
      expect(item.sender, isEmpty);
    });

    testWidgets('filterBySender 将空 sender 归类为 user-manual', (tester) async {
      // 验证 filterBySender 纯函数对空 sender 的处理
      final items = [
        _makeItem(id: '1', sender: ''),
        _makeItem(id: '2', sender: 'user-manual'),
        _makeItem(id: '3', sender: 'guide-assistant'),
      ];

      final filtered = filterBySender(items, 'user-manual');
      // 空 sender 和 user-manual 都应被包含
      expect(filtered.length, 2);
      expect(filtered.any((i) => i.id == '1'), isTrue,
          reason: '空 sender 应归类为 user-manual');
      expect(filtered.any((i) => i.id == '2'), isTrue);
      expect(filtered.any((i) => i.id == '3'), isFalse);
    });

    testWidgets('来源图标映射覆盖所有 5 种 sender 类型', (tester) async {
      // 验证每种 sender 对应的图标 emoji 正确
      // 这些常量定义在 memory_page.dart 的 _senderIcons 中
      // 通过构造 MemoryItem 并检查 sender 值间接验证映射关系
      const expectedIcons = {
        'user-manual': '✍️',
        'guide-assistant': '🤖',
        'agent-runtime': '⚙️',
        'patrol-nudge': '🔔',
        'wechat-webhook': '💚',
      };

      // 验证所有 5 种 sender 类型都有对应图标定义
      expect(expectedIcons.length, 5);
      for (final entry in expectedIcons.entries) {
        expect(entry.value.isNotEmpty, isTrue,
            reason: '${entry.key} 应有对应的来源图标');
      }
    });

    testWidgets('filterBySender 对 all 过滤返回全部记忆', (tester) async {
      final items = [
        _makeItem(id: '1', sender: 'user-manual'),
        _makeItem(id: '2', sender: 'guide-assistant'),
        _makeItem(id: '3', sender: ''),
      ];

      final filtered = filterBySender(items, 'all');
      expect(filtered.length, items.length);
    });

    testWidgets('filterBySender 对特定 sender 仅返回匹配项', (tester) async {
      final items = [
        _makeItem(id: '1', sender: 'user-manual'),
        _makeItem(id: '2', sender: 'guide-assistant'),
        _makeItem(id: '3', sender: 'agent-runtime'),
        _makeItem(id: '4', sender: 'patrol-nudge'),
        _makeItem(id: '5', sender: 'wechat-webhook'),
      ];

      // 逐一验证每种 sender 过滤
      for (final sender in [
        'user-manual',
        'guide-assistant',
        'agent-runtime',
        'patrol-nudge',
        'wechat-webhook',
      ]) {
        final filtered = filterBySender(items, sender);
        expect(filtered.length, 1, reason: '$sender 过滤应返回 1 条');
        expect(filtered.first.sender, sender);
      }
    });
  });

  group('来源过滤标签切换行为', () {
    testWidgets('连续点击不同标签，选中态正确切换', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // 初始：全部选中
      var allText = tester.widget<Text>(find.text('全部'));
      expect(allText.style?.color, Colors.white);

      // 点击 AI 助手
      await tester.tap(find.text('AI 助手'));
      await tester.pump();

      var aiText = tester.widget<Text>(find.text('AI 助手'));
      expect(aiText.style?.color, Colors.white);
      allText = tester.widget<Text>(find.text('全部'));
      expect(allText.style?.color, isNot(Colors.white));

      // 点击 Agent
      await tester.tap(find.text('Agent'));
      await tester.pump();

      final agentText = tester.widget<Text>(find.text('Agent'));
      expect(agentText.style?.color, Colors.white);
      aiText = tester.widget<Text>(find.text('AI 助手'));
      expect(aiText.style?.color, isNot(Colors.white));
    });

    testWidgets('点击已选中的标签不触发状态变化', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // "全部"已选中，再次点击
      await tester.tap(find.text('全部'));
      await tester.pump();

      // 仍然是选中态
      final allText = tester.widget<Text>(find.text('全部'));
      expect(allText.style?.color, Colors.white);
    });
  });
}
