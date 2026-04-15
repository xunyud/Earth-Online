class SystemRewardDefinition {
  final String id;
  final String zhTitle;
  final String enTitle;
  final String zhDescription;
  final String enDescription;
  final int cost;
  final String icon;
  final Set<String> aliases;

  const SystemRewardDefinition({
    required this.id,
    required this.zhTitle,
    required this.enTitle,
    required this.zhDescription,
    required this.enDescription,
    required this.cost,
    required this.icon,
    required this.aliases,
  });

  String title(bool isEnglish) => isEnglish ? enTitle : zhTitle;

  String description(bool isEnglish) =>
      isEnglish ? enDescription : zhDescription;
}

const List<SystemRewardDefinition> systemRewardCatalog =
    <SystemRewardDefinition>[
  SystemRewardDefinition(
    id: 'listen_song',
    zhTitle: '听一首歌',
    enTitle: 'Listen to One Song',
    zhDescription: '给自己几分钟，安静听完一首喜欢的歌。',
    enDescription: 'Take a few quiet minutes and finish one song you love.',
    cost: 1,
    icon: '🎵',
    aliases: <String>{
      '听一首歌',
      'listen to one song',
      'listen song',
      'song',
    },
  ),
  SystemRewardDefinition(
    id: 'walk_20_minutes',
    zhTitle: '散步二十分钟',
    enTitle: 'Take a 20-Minute Walk',
    zhDescription: '暂时离开任务列表，去走一走换换脑子。',
    enDescription: 'Step away from the task list and take a short walk.',
    cost: 20,
    icon: '🚶',
    aliases: <String>{
      '散步二十分钟',
      'take a 20-minute walk',
      'walk 20 minutes',
      'walk',
    },
  ),
  SystemRewardDefinition(
    id: 'watch_one_episode',
    zhTitle: '看一集喜欢的内容',
    enTitle: 'Watch One Favorite Episode',
    zhDescription: '看一集喜欢的剧、动画或视频。',
    enDescription: 'Watch one episode of a show, anime, or video you enjoy.',
    cost: 30,
    icon: '📺',
    aliases: <String>{
      '看一集喜欢的内容',
      'watch one favorite episode',
      'watch one episode',
      'episode',
    },
  ),
  SystemRewardDefinition(
    id: 'favorite_drink',
    zhTitle: '买一杯喜欢的饮料',
    enTitle: 'Buy a Cup of Favorite Drink',
    zhDescription: '用一杯喜欢的饮料犒劳一下自己。',
    enDescription: 'Treat yourself to a drink you really like.',
    cost: 35,
    icon: '🥤',
    aliases: <String>{
      '买一杯喜欢的饮料',
      'buy a cup of favorite drink',
      'favorite drink',
      'drink',
    },
  ),
  SystemRewardDefinition(
    id: 'rest_half_hour',
    zhTitle: '躺平放空半小时',
    enTitle: 'Zone Out for Half an Hour',
    zhDescription: '什么都不做，专心休息半小时。',
    enDescription: 'Do nothing on purpose and rest for half an hour.',
    cost: 40,
    icon: '🛋️',
    aliases: <String>{
      '躺平放空半小时',
      'zone out for half an hour',
      'rest half an hour',
      'rest',
    },
  ),
  SystemRewardDefinition(
    id: 'milk_tea',
    zhTitle: '喝杯奶茶',
    enTitle: 'Grab a Milk Tea',
    zhDescription: '买一杯奶茶，认真享受一下。',
    enDescription: 'Get yourself a milk tea and enjoy it slowly.',
    cost: 50,
    icon: '🧋',
    aliases: <String>{
      '喝杯奶茶',
      'grab a milk tea',
      'milk tea',
    },
  ),
  SystemRewardDefinition(
    id: 'favorite_dessert',
    zhTitle: '点一份喜欢的小甜点',
    enTitle: 'Order a Favorite Dessert',
    zhDescription: '来一份甜点，给努力一个具体回报。',
    enDescription: 'Order a dessert you like as a concrete reward.',
    cost: 60,
    icon: '🍰',
    aliases: <String>{
      '点一份喜欢的小甜点',
      'order a favorite dessert',
      'dessert',
    },
  ),
  SystemRewardDefinition(
    id: 'game_one_hour',
    zhTitle: '玩游戏一小时',
    enTitle: 'Play Games for One Hour',
    zhDescription: '给自己一小时完整的娱乐时间。',
    enDescription: 'Give yourself one full hour of uninterrupted play time.',
    cost: 80,
    icon: '🎮',
    aliases: <String>{
      '玩游戏一小时',
      'play games for one hour',
      'play games',
      'game',
    },
  ),
];

final Set<String> systemRewardBaseTitles =
    systemRewardCatalog.map((reward) => reward.zhTitle).toSet();

List<Map<String, Object>> buildSystemRewardSeedPayloads() {
  return systemRewardCatalog
      .map(
        (reward) => <String, Object>{
          'title': reward.zhTitle,
          'description': reward.zhDescription,
          'cost': reward.cost,
          'icon': reward.icon,
        },
      )
      .toList(growable: false);
}

SystemRewardDefinition? resolveSystemRewardDefinition(String rawTitle) {
  final normalized = rawTitle.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final reward in systemRewardCatalog) {
    if (reward.zhTitle == rawTitle.trim()) {
      return reward;
    }
    if (reward.aliases.contains(normalized)) {
      return reward;
    }
  }
  return null;
}
