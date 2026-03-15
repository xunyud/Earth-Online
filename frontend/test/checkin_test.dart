import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/quest/controllers/quest_controller.dart';

void main() {
  group('multiplierForStreak', () {
    test('returns base multiplier for streaks below 3 days', () {
      expect(QuestController.multiplierForStreak(-5), 1.0);
      expect(QuestController.multiplierForStreak(0), 1.0);
      expect(QuestController.multiplierForStreak(1), 1.0);
      expect(QuestController.multiplierForStreak(2), 1.0);
    });

    test('returns 1.5x for streaks from 3 to 6 days', () {
      expect(QuestController.multiplierForStreak(3), 1.5);
      expect(QuestController.multiplierForStreak(6), 1.5);
    });

    test('returns 2.0x for streaks from 7 to 13 days', () {
      expect(QuestController.multiplierForStreak(7), 2.0);
      expect(QuestController.multiplierForStreak(13), 2.0);
    });

    test('returns 2.5x for streaks from 14 to 29 days', () {
      expect(QuestController.multiplierForStreak(14), 2.5);
      expect(QuestController.multiplierForStreak(29), 2.5);
    });

    test('caps multiplier at 3.0x from 30 days onward', () {
      expect(QuestController.multiplierForStreak(30), 3.0);
      expect(QuestController.multiplierForStreak(100), 3.0);
    });
  });
}
