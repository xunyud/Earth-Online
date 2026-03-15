import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('登录页保留森林主题背景与入场动画', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      content.contains('assets/images/backgrounds/forest/login_backdrop.png') &&
          content.contains('FadeTransition(') &&
          content.contains('SlideTransition(') &&
          content.contains('ScaleTransition(') &&
          content.contains('AnimatedSize('),
      isTrue,
      reason: '登录页需要延续当前森林主题，并保留现有动效层次。',
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
          content.contains('创建你的现实副本') &&
          content.contains('开始注册'),
      isTrue,
      reason: '登录页需要明确提供注册模式，并显示独立的注册引导文案。',
    );
  });
}
