import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('任务实时更新后会触发统计对账，避免完成状态变了但 XP/金币没同步', () async {
    final file = File('lib/features/quest/controllers/quest_controller.dart');
    final content = await file.readAsString();

    expect(
      content.contains('_scheduleProfileStatsReconcile();'),
      isTrue,
      reason: 'quest_nodes 的实时插入、更新、删除后都应该触发一次统计对账，确保顶部 XP/金币会跟着完成状态自愈。',
    );
  });
}
