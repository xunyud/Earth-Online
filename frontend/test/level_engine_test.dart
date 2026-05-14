import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/level_engine.dart';

void main() {
  group('LevelEngine.fromTotalXp', () {
    test('0 XP returns level 1 with 0 progress', () {
      final p = LevelEngine.fromTotalXp(0);
      expect(p.level, 1);
      expect(p.currentLevelXp, 0);
      expect(p.nextLevelXp, 500);
      expect(p.progress, 0.0);
    });

    test('negative XP is clamped to 0', () {
      final p = LevelEngine.fromTotalXp(-100);
      expect(p.level, 1);
      expect(p.currentLevelXp, 0);
      expect(p.progress, 0.0);
    });

    test('XP exactly at level boundary advances to next level', () {
      // Level 1 cap = 500, so 500 XP → level 2 with 0 progress
      final p = LevelEngine.fromTotalXp(500);
      expect(p.level, 2);
      expect(p.currentLevelXp, 0);
    });

    test('XP just below boundary stays at current level', () {
      final p = LevelEngine.fromTotalXp(499);
      expect(p.level, 1);
      expect(p.currentLevelXp, 499);
      expect(p.progress, closeTo(499 / 500, 0.001));
    });

    test('level 2 cap = 500 * 1.2 = 600', () {
      // 500 (level 1) + 300 into level 2
      final p = LevelEngine.fromTotalXp(800);
      expect(p.level, 2);
      expect(p.currentLevelXp, 300);
      expect(p.nextLevelXp, 600); // ceil(500 * 1.2)
    });

    test('multi-level progression is correct', () {
      // L1: 500, L2: 600, L3: 720, L4: 864, L5: 1037
      // Total to reach L3: 500 + 600 = 1100
      final p = LevelEngine.fromTotalXp(1100);
      expect(p.level, 3);
      expect(p.currentLevelXp, 0);
    });

    test('progress is clamped to [0.0, 1.0]', () {
      final p = LevelEngine.fromTotalXp(250);
      expect(p.progress, greaterThanOrEqualTo(0.0));
      expect(p.progress, lessThanOrEqualTo(1.0));
    });

    test('large XP does not crash', () {
      final p = LevelEngine.fromTotalXp(1000000);
      expect(p.level, greaterThan(1));
      expect(p.progress, greaterThanOrEqualTo(0.0));
      expect(p.progress, lessThanOrEqualTo(1.0));
    });
  });

  group('LevelEngine title thresholds', () {
    test('level 1-5 → apprentice_villager', () {
      expect(LevelEngine.fromTotalXp(0).title, 'level.title.apprentice_villager');
      // Level 5 boundary: 500+600+720+864 = 2684 → at 2684 we're level 5 with 0 xp
      expect(LevelEngine.fromTotalXp(2684).title, 'level.title.apprentice_villager');
    });

    test('level 6 → junior_adventurer', () {
      // 2684 + 1037 = 3721 → level 6
      final p = LevelEngine.fromTotalXp(3721);
      expect(p.level, 6);
      expect(p.title, 'level.title.junior_adventurer');
    });

    test('level 11 → bronze_hero', () {
      // Accumulate XP to reach level 11
      int xp = 0;
      int cap = 500;
      for (int i = 0; i < 10; i++) {
        xp += cap;
        cap = (cap * 1.2).ceil();
      }
      final p = LevelEngine.fromTotalXp(xp);
      expect(p.level, 11);
      expect(p.title, 'level.title.bronze_hero');
    });

    test('level 101 → star_traveler', () {
      // Accumulate XP to reach level 101
      int xp = 0;
      int cap = 500;
      for (int i = 0; i < 100; i++) {
        xp += cap;
        cap = (cap * 1.2).ceil();
      }
      final p = LevelEngine.fromTotalXp(xp);
      expect(p.level, 101);
      expect(p.title, 'level.title.star_traveler');
    });
  });
}
