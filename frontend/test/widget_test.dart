import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/features/quest/widgets/quick_add_bar.dart';

void main() {
  testWidgets('QuickAddBar 提交后触发回调并清空输入', (WidgetTester tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.freshBreath()],
        ),
        home: Scaffold(
          body: QuickAddBar(
            onSubmitted: (value) => submitted = value,
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.enterText(field, '测试任务');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    expect(submitted, '测试任务');
    final textField = tester.widget<TextField>(field);
    expect(textField.controller?.text ?? '', '');
  });
}
