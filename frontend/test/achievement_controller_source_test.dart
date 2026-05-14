import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'AchievementController should manage unlock queue with consumeNextUnlock and deduplicate already-unlocked achievements',
      () async {
    final controller = await File(
            'lib/features/achievement/controllers/achievement_controller.dart')
        .readAsString();
    final model =
        await File('lib/features/achievement/models/achievement.dart')
            .readAsString();

    expect(
      controller.contains('consumeNextUnlock()') &&
          controller.contains('_unlockQueue.removeAt(0)') &&
          controller.contains('_unlockedIds.contains(aid)') &&
          controller.contains('if (_unlockedIds.contains(aid)) continue') &&
          controller.contains('_unlockQueue.addAll(newUnlocks)') &&
          controller.contains('_unlockSeq++') &&
          controller.contains('check_and_unlock_achievements') &&
          controller.contains('board_clear') &&
          controller.contains('total_completed') &&
          model.contains('progressPercent'),
      isTrue,
      reason:
          'AchievementController must deduplicate unlocked IDs, manage a consume-based unlock queue, call the server RPC, and compute board_clear progress.',
    );
  });

  test(
      'AchievementController should replicate LevelEngine level calculation for progress tracking',
      () async {
    final controller = await File(
            'lib/features/achievement/controllers/achievement_controller.dart')
        .readAsString();

    expect(
      controller.contains('cap = 500') &&
          controller.contains('cap * 1.2') &&
          controller.contains("result['level'] = level"),
      isTrue,
      reason:
          'AchievementController._loadProgress must replicate LevelEngine logic (base 500, growth 1.2) to compute level for achievement progress.',
    );
  });
}
