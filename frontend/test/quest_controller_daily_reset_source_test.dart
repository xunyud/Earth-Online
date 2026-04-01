import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QuestController should include daily reset logic and dedicated daily deadline field', () async {
    final file = File('lib/features/quest/controllers/quest_controller.dart');
    final content = await file.readAsString();

    expect(
      content.contains('shouldResetDailyQuest(') &&
          content.contains("quest.questTier == 'Daily'") &&
          content.contains('daily_due_minutes') &&
          content.contains('update({') &&
          content.contains("'is_completed': false") &&
          content.contains("'completed_at': null"),
      isTrue,
      reason: 'Daily quests should reset on a new local day and persist their daily deadline separately.',
    );
  });
}
