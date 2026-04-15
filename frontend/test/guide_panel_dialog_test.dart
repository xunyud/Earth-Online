import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/features/quest/models/agent_run.dart';
import 'package:frontend/features/quest/models/agent_step.dart';
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
            agentRun: AgentRun.fromJson(const {
              'id': 'run-1',
              'user_id': 'user-1',
              'goal': '读取 README',
              'status': 'waiting_approval',
              'summary': '准备读取本地 README 文件',
            }),
            agentSteps: [
              AgentStep.fromJson(const {
                'id': 'step-1',
                'run_id': 'run-1',
                'step_index': 0,
                'kind': 'tool_call',
                'tool_name': 'file.read_text',
                'risk_level': 'medium',
                'needs_confirmation': true,
                'status': 'waiting_approval',
                'summary': '读取 README.md',
                'arguments_json': {
                  'path': 'README.md',
                },
              }),
            ],
            onApproveAgentStep: () {},
            onRejectAgentStep: () {},
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

  testWidgets('GuidePanelDialog 会展示多步时间线与审批卡', (tester) async {
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
            guideMemorySummary: '最近你正在集中推进 agent phase 2。',
            guideMemorySignals: const ['聚焦实现', '需要验证'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [],
            quickActions: const [],
            examplePrompts: const [],
            currentMessageCard: null,
            currentResultCard: null,
            inputController: controller,
            inputHintText: '告诉小忆你现在的目标',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            sending: false,
            agentRun: AgentRun.fromJson(const {
              'id': 'run-1',
              'user_id': 'user-1',
              'goal': '读取 README',
              'status': 'waiting_approval',
              'summary': '等待你确认执行本地工具',
            }),
            agentSteps: [
              AgentStep.fromJson(const {
                'id': 'step-1',
                'run_id': 'run-1',
                'step_index': 0,
                'kind': 'message',
                'status': 'succeeded',
                'summary': '已理解目标',
                'output_text': '准备检查仓库文档',
              }),
              AgentStep.fromJson(const {
                'id': 'step-2',
                'run_id': 'run-1',
                'step_index': 1,
                'kind': 'tool_call',
                'tool_name': 'file.read_text',
                'risk_level': 'medium',
                'needs_confirmation': true,
                'status': 'waiting_approval',
                'summary': '读取 README.md',
                'arguments_json': {
                  'path': 'README.md',
                },
              }),
            ],
            onApproveAgentStep: () {},
            onRejectAgentStep: () {},
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

    expect(find.text('执行轨迹', skipOffstage: false), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text('确认执行', skipOffstage: false), findsOneWidget);
    expect(find.text('取消', skipOffstage: false), findsOneWidget);
    expect(find.text('读取 README.md'), findsWidgets);
  });

  testWidgets('GuidePanelDialog 终态时会隐藏审批卡并显示结果摘要', (tester) async {
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
            subtitle: '帮你复盘本地执行结果。',
            guideMemoryTitle: '小忆记得',
            guideMemorySummary: '最近你多次通过 agent 读取项目文档。',
            guideMemorySignals: const ['多步执行', '本地总结'],
            statusText: '小忆在线',
            editNameLabel: '修改名字',
            closeTooltip: '关闭',
            statusReady: true,
            messages: const [],
            quickActions: const [],
            examplePrompts: const [],
            currentMessageCard: null,
            currentResultCard: null,
            inputController: controller,
            inputHintText: '告诉小忆你现在的目标',
            sendLabel: '发送',
            retryLabel: '重试',
            closeLabel: '关闭',
            sending: false,
            agentRun: AgentRun.fromJson(const {
              'id': 'run-2',
              'user_id': 'user-1',
              'goal': '分析 README',
              'status': 'succeeded',
              'summary': '本地工具执行完成',
            }),
            agentSteps: [
              AgentStep.fromJson(const {
                'id': 'step-1',
                'run_id': 'run-2',
                'step_index': 0,
                'kind': 'tool_call',
                'tool_name': 'file.read_text',
                'risk_level': 'low',
                'needs_confirmation': false,
                'status': 'succeeded',
                'summary': '读取 README.md',
                'output_text': '已读取 README.md（1024 字符）',
              }),
              AgentStep.fromJson(const {
                'id': 'step-2',
                'run_id': 'run-2',
                'step_index': 1,
                'kind': 'done',
                'status': 'succeeded',
                'summary': '输出总结',
                'output_text': 'README 主要介绍了项目定位和运行方式。',
              }),
            ],
            onApproveAgentStep: () {},
            onRejectAgentStep: () {},
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

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();

    expect(find.text('确认执行', skipOffstage: false), findsNothing);
    expect(
      find.text('README 主要介绍了项目定位和运行方式。', skipOffstage: false),
      findsOneWidget,
    );
  });
}
