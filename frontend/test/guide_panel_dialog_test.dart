import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/features/quest/widgets/guide_panel_dialog.dart';

void main() {
  testWidgets('GuidePanelDialog 保留记忆卡片与对话消息', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 620));

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: GuidePanelDialog(
            title: '小忆',
            guideName: '小忆',
            subtitle: '小忆记得你的节奏，也陪你把今天拆成能开始的一步。',
            guideMemoryTitle: '小忆记得',
            guideMemorySummary: '最近 3 天你连续推进会议准备，但睡眠和放松记录偏少。',
            guideMemorySignals: const ['连续推进', '精力偏紧', '适合轻量恢复'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [
              GuideDialogMessage(
                role: GuideDialogRole.assistant,
                content: '我记得你这几天一直在往前推，今天更想继续推进，还是先把状态拉回来？',
                memoryRefCount: 2,
              ),
              GuideDialogMessage(
                role: GuideDialogRole.user,
                content: '我想先恢复一下，但不能完全停。',
              ),
            ],
            quickActions: const ['继续聊今天', '给我一个恢复任务'],
            examplePrompts: const ['帮我拆解今天的任务', '最近我完成了什么？'],
            inputController: controller,
            inputHintText: '告诉小忆你现在的状态…',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            sending: false,
            memoryRefsLabelBuilder: (count) => '参考了 $count 段近期记忆',
            onRetry: () {},
            onSubmit: (_) {},
            onQuickActionTap: (_) {},
            onExamplePromptTap: (_) {},
            onEditGuideName: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('小忆'), findsWidgets);
    expect(find.byTooltip('修改名字'), findsOneWidget);
    expect(find.text('小忆记得'), findsOneWidget);
    expect(find.text('连续推进'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('GuidePanelDialog 不再展示过程轨迹与审批气泡', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 620));
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: GuidePanelDialog(
            title: '小忆',
            guideName: '小忆',
            subtitle: '帮你稳稳推进今天的目标。',
            guideMemoryTitle: '小忆记得',
            guideMemorySummary: '最近你正在集中推进真正的聊天体验。',
            guideMemorySignals: const ['聚焦实现', '需要验证'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [
              GuideDialogMessage(
                role: GuideDialogRole.assistant,
                content: '我们继续聊你的目标本身，不展示执行过程。',
              ),
            ],
            quickActions: const [],
            examplePrompts: const [],
            inputController: controller,
            inputHintText: '告诉小忆你现在的目标',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            sending: false,
            memoryRefsLabelBuilder: (count) => '参考了 $count 段记忆',
            onRetry: () {},
            onSubmit: (_) {},
            onQuickActionTap: (_) {},
            onExamplePromptTap: (_) {},
            onEditGuideName: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('执行轨迹', skipOffstage: false), findsNothing);
    expect(find.text('确认执行', skipOffstage: false), findsNothing);
    expect(find.text('取消', skipOffstage: false), findsNothing);
    expect(find.text('处理中', skipOffstage: false), findsNothing);
    expect(find.text('执行结果', skipOffstage: false), findsNothing);
  });

  testWidgets('GuidePanelDialog 仍保留快捷动作与输入区', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 620));
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: GuidePanelDialog(
            title: '小贾',
            guideName: '小贾',
            subtitle: '帮你推进今天的任务。',
            guideMemoryTitle: '小贾记得',
            guideMemorySummary: '最近你在学习 Python。',
            guideMemorySignals: const ['学习中'],
            statusText: '小贾在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [],
            quickActions: const ['新建任务'],
            examplePrompts: const ['帮我拆一下'],
            inputController: controller,
            inputHintText: '告诉小贾你现在的状态…',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            sending: false,
            memoryRefsLabelBuilder: (count) => '参考了 $count 段记忆',
            onRetry: () {},
            onSubmit: (_) {},
            onQuickActionTap: (_) {},
            onExamplePromptTap: (_) {},
            onEditGuideName: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新建任务'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
  });

  testWidgets('GuidePanelDialog 支持复制用户和助手消息', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 900));

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final copiedMessages = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: GuidePanelDialog(
            title: '小忆',
            guideName: '小忆',
            subtitle: '帮你把聊天继续接住。',
            guideMemoryTitle: '小忆记得',
            guideMemorySummary: '最近你在验证聊天交互。',
            guideMemorySignals: const ['需要复制'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [
              GuideDialogMessage(
                role: GuideDialogRole.assistant,
                content: '先把这条助手消息复制下来。',
              ),
              GuideDialogMessage(
                role: GuideDialogRole.user,
                content: '这是一条用户消息。',
              ),
            ],
            quickActions: const [],
            examplePrompts: const [],
            inputController: controller,
            inputHintText: '继续输入',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            copyMessageTooltip: '复制',
            sending: false,
            memoryRefsLabelBuilder: (count) => '参考了 $count 段记忆',
            onRetry: () {},
            onCopyMessage: copiedMessages.add,
            onSubmit: (_) {},
            onQuickActionTap: (_) {},
            onExamplePromptTap: (_) {},
            onEditGuideName: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 复制按钮已改为长按气泡触发，不再有常驻 IconButton
    expect(find.byTooltip('复制'), findsNothing);

    // 验证气泡容器（GestureDetector）存在且绑定了 onLongPress
    final assistantBubble = find.byKey(
      ValueKey('bubble-assistant-${'先把这条助手消息复制下来。'.hashCode}'),
    );
    expect(assistantBubble, findsOneWidget);
    final assistantGesture = tester.widget<GestureDetector>(assistantBubble);
    expect(assistantGesture.onLongPress, isNotNull);

    // 用户气泡同样绑定了 onLongPress（skipOffstage: false 穿透 ListView 懒加载）
    final userBubble = find.byKey(
      ValueKey('bubble-user-${'这是一条用户消息。'.hashCode}'),
      skipOffstage: false,
    );
    expect(userBubble, findsOneWidget);
    final userGesture = tester.widget<GestureDetector>(userBubble);
    expect(userGesture.onLongPress, isNotNull);
  });

  testWidgets('GuidePanelDialog 支持上下键回填已发送消息并恢复草稿', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 620));

    final controller = TextEditingController(text: '临时草稿');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: GuidePanelDialog(
            title: '小忆',
            guideName: '小忆',
            subtitle: '帮你找回刚刚发过的话。',
            guideMemoryTitle: '小忆记得',
            guideMemorySummary: '最近你在调试输入历史。',
            guideMemorySignals: const ['命令历史'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [],
            quickActions: const [],
            examplePrompts: const [],
            inputController: controller,
            messageHistory: const ['第一条消息', '第二条消息'],
            inputHintText: '继续输入',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            sending: false,
            memoryRefsLabelBuilder: (count) => '参考了 $count 段记忆',
            onRetry: () {},
            onSubmit: (_) {},
            onQuickActionTap: (_) {},
            onExamplePromptTap: (_) {},
            onEditGuideName: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.text, '第二条消息');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.text, '第一条消息');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.text, '第二条消息');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.text, '临时草稿');
  });

  testWidgets('GuidePanelDialog 消息内容支持自由选择复制', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // 单条消息场景，不受 ListView 懒加载影响
    await tester.binding.setSurfaceSize(const Size(900, 900));

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: GuidePanelDialog(
            title: '小忆',
            guideName: '小忆',
            subtitle: '现在这段聊天应该能被拖选复制。',
            guideMemoryTitle: '小忆记得',
            guideMemorySummary: '最近你希望像普通聊天窗口那样自由复制文本。',
            guideMemorySignals: const ['可选文本'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [
              GuideDialogMessage(
                role: GuideDialogRole.assistant,
                content: '这里是一段可以自由选择的助手回复。',
              ),
            ],
            quickActions: const [],
            examplePrompts: const [],
            inputController: controller,
            inputHintText: '继续输入',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            copyMessageTooltip: '复制',
            sending: false,
            memoryRefsLabelBuilder: (count) => '参考了 $count 段记忆',
            onRetry: () {},
            onCopyMessage: (_) {},
            onSubmit: (_) {},
            onQuickActionTap: (_) {},
            onExamplePromptTap: (_) {},
            onEditGuideName: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 单条消息，SelectableText 应该可见
    expect(find.byType(SelectableText), findsOneWidget);
    // SelectableText 的文本内容可通过 find.text 找到
    expect(find.text('这里是一段可以自由选择的助手回复。'), findsOneWidget);
  });
}
