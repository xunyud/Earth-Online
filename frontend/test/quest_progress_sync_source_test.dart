import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QuestController 会对已完成任务的经验与金币做下限对账', () async {
    final file = File('lib/features/quest/controllers/quest_controller.dart');
    final content = await file.readAsString();

    expect(
      content.contains('_reconcileProfileStatsFloor(') &&
          content.contains('completedXpFloor') &&
          content.contains('completedGoldFloor'),
      isTrue,
      reason: '已完成任务的奖励需要和 profiles 做下限对账，否则历史漏记或同步失败后顶部 XP/金币会长期偏低。',
    );
  });
}
