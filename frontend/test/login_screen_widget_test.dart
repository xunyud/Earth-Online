import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/quest_theme.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('登录页默认展示登录模式，并支持切换到注册模式', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [QuestTheme.forestAdventure()],
        ),
        home: LoginScreen(
          homeBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('地球 Online'), findsOneWidget);
    expect(find.text('登录你的现实副本'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);

    await tester.tap(find.text('注册'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('创建你的现实副本'), findsOneWidget);
    expect(find.text('发送注册验证码'), findsOneWidget);
    expect(find.text('开始注册'), findsOneWidget);

    await tester.tap(find.text('登录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('登录你的现实副本'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });
}
