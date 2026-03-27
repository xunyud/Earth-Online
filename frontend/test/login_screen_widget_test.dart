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

    // 登录模式默认文案
    expect(find.text('欢迎来到地球Online'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('继续登录'), findsOneWidget);

    // 切换到注册模式
    await tester.tap(find.text('注册'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('创建账号'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);

    // 切换回登录模式
    await tester.tap(find.text('登录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('继续登录'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });
}
