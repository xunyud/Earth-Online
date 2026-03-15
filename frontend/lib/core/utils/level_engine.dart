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
    if (level <= 5) return '见习村民';
    if (level <= 10) return '初级冒险者';
    if (level <= 20) return '青铜勇者';
    if (level <= 35) return '白银骑士';
    if (level <= 50) return '黄金斗士';
    if (level <= 70) return '铂金守护者';
    if (level <= 100) return '传奇王者';
    return '星辰旅者';
  }
}

