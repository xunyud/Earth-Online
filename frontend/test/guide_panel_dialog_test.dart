import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/features/quest/widgets/guide_panel_dialog.dart';

void main() {
  testWidgets('GuidePanelDialog 展示小忆记忆胶囊与对话消息', (tester) async {
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
            currentMessageCard: null,
            currentResultCard: null,
            inputController: controller,
            inputHintText: '告诉小忆你现在的状态...',
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
    expect(find.text('参考了 2 段近期记忆'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });
}
