class LevelProgress {
  final int level;
  final int currentLevelXp;
  final int nextLevelXp;
  final double progress;
  final String title;

  const LevelProgress({
    required this.level,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.progress,
    required this.title,
  });
}

class LevelEngine {
  static const int _baseXp = 500;
  static const double _growth = 1.2;

  static LevelProgress fromTotalXp(int totalXp) {
    var xp = totalXp;
    if (xp < 0) xp = 0;

    var level = 1;
    var cap = _baseXp;

    while (xp >= cap) {
      xp -= cap;
      level += 1;
      cap = (cap * _growth).ceil();
    }

    final progress = cap <= 0 ? 0.0 : xp / cap;
    return LevelProgress(
      level: level,
      currentLevelXp: xp,
      nextLevelXp: cap,
      progress: progress.clamp(0.0, 1.0),
      title: _titleForLevel(level),
    );
  }

  static String _titleForLevel(int level) {
    if (level <= 5) return 'level.title.apprentice_villager';
    if (level <= 10) return 'level.title.junior_adventurer';
    if (level <= 20) return 'level.title.bronze_hero';
    if (level <= 35) return 'level.title.silver_knight';
    if (level <= 50) return 'level.title.golden_fighter';
    if (level <= 70) return 'level.title.platinum_guardian';
    if (level <= 100) return 'level.title.legendary_champion';
    return 'level.title.star_traveler';
  }
}
