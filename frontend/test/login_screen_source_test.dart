import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('登录页保留柔和背景与入场动画', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      content.contains('SoftAuthBackground') &&
          content.contains('FadeTransition(') &&
          content.contains('SlideTransition(') &&
          content.contains('ScaleTransition('),
      isTrue,
      reason: '登录页需要使用 SoftAuthBackground 背景，并保留现有动效层次。',
    );
  });

  test('登录页不再展示轻微动态氛围入口', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      !content.contains('轻微动态氛围'),
      isTrue,
      reason: '登录页顶部入口应该聚焦认证主流程，不再保留无关入口。',
    );
  });

  test('登录页提供注册入口与注册模式文案', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      content.contains("'登录'") &&
          content.contains("'注册'") &&
          content.contains('欢迎来到地球Online') &&
          content.contains('创建账号'),
      isTrue,
      reason: '登录页需要明确提供注册模式，并显示独立的注册引导文案。',
    );
  });
}
