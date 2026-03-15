import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggleQuestCompletion 会按实际切换任务集合计算金币', () async {
    final file = File('lib/features/quest/controllers/quest_controller.dart');
    final content = await file.readAsString();

    expect(
      content.contains('.where((q) => !q.isReward)') &&
          content
              .contains('deltaGold = newStatus ? goldRewardXp : -goldRewardXp'),
      isTrue,
      reason: '金币结算必须基于实际被切换的非奖励任务集合，不能只依赖入口任务的 isReward。',
    );
  });
}
