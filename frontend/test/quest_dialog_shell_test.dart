import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/shared/widgets/quest_dialog_shell.dart';

void main() {
  testWidgets('QuestDialogShell 渲染统一标题区与操作区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: QuestDialogShell(
            title: '测试弹窗',
            subtitle: '保持森林主题的一致层次',
            leading: const QuestDialogBadge(
              icon: Icons.auto_awesome_rounded,
            ),
            onClose: () {},
            actions: const [
              QuestDialogSecondaryButton(
                label: '稍后',
                onPressed: null,
              ),
              QuestDialogPrimaryButton(
                label: '继续',
                onPressed: null,
              ),
            ],
            child: const QuestDialogInfoCard(
              label: '测试内容',
              icon: Icons.eco_rounded,
              child: Text('这里是共享弹窗内容区。'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('测试弹窗'), findsOneWidget);
    expect(find.text('保持森林主题的一致层次'), findsOneWidget);
    expect(find.text('测试内容'), findsOneWidget);
    expect(find.text('这里是共享弹窗内容区。'), findsOneWidget);
    expect(find.text('稍后'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
  });
}
