import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomePage 顶部统计区会监听 QuestController 刷新并保留经验条', () async {
    final file = File('lib/features/quest/screens/home_page.dart');
    final content = await file.readAsString();

    expect(
      content.contains('bottom: PreferredSize(') &&
          content.contains('child: AnimatedBuilder(') &&
          content.contains('LinearProgressIndicator(') &&
          content.contains('statsLevel.progress') &&
          content.contains("label: '\${_controller.totalXp} XP'") &&
          content.contains("label: '\${_controller.currentGold}'"),
      isTrue,
      reason: '顶部 XP/金币统计与经验条必须同时绑定 QuestController，避免任务完成后数字或进度不同步。',
    );
  });
}
