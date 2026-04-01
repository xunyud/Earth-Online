import 'package:flutter/material.dart';

import 'profile_analysis_texts.dart';
import '../services/preferences_service.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();

  Locale _locale = const Locale('zh', 'CN');
  Locale get locale => _locale;

  bool get isEnglish => _locale.languageCode == 'en';

  Future<void> load() async {
    final saved = await PreferencesService.appLocale();
    final next = _normalizeLocale(saved);
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
  }

  Future<void> setLanguageCode(String languageCode) async {
    final next = _normalizeLocale(languageCode);
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
    await PreferencesService.setAppLocale(next.languageCode);
  }

  String t(String key, {Map<String, String> params = const {}}) {
    final bundle = _localizedTexts[key] ?? profileAnalysisTexts[key];
    var text = bundle?[_locale.languageCode] ?? bundle?['zh'] ?? key;
    for (final entry in params.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  Locale _normalizeLocale(String raw) {
    final code = raw.toLowerCase();
    if (code.startsWith('en')) return const Locale('en', 'US');
    return const Locale('zh', 'CN');
  }
}

extension AppLocaleBuildContextX on BuildContext {
  String tr(String key, {Map<String, String> params = const {}}) {
    return AppLocaleController.instance.t(key, params: params);
  }

  bool get isEnglish => AppLocaleController.instance.isEnglish;
}

const Map<String, Map<String, String>> _localizedTexts =
    <String, Map<String, String>>{
  'common.close': {'zh': '关闭', 'en': 'Close'},
  'common.cancel': {'zh': '取消', 'en': 'Cancel'},
  'common.confirm': {'zh': '确认', 'en': 'Confirm'},
  'common.retry': {'zh': '重试', 'en': 'Retry'},
  'common.refresh': {'zh': '刷新', 'en': 'Refresh'},
  'common.skip_today': {'zh': '仅跳过今天', 'en': 'Skip Today'},
  'common.accept_task': {'zh': '接受任务', 'en': 'Accept Quest'},
  'common.add_task': {'zh': '加入任务', 'en': 'Add Quest'},
  'common.send': {'zh': '发送', 'en': 'Send'},
  'common.loading': {'zh': '加载中...', 'en': 'Loading...'},
  'common.not_available': {'zh': '暂不可用', 'en': 'Unavailable'},
  'common.not_logged_in': {'zh': '未登录', 'en': 'Not Signed In'},
  'app.title': {'zh': '{name}的日志', 'en': "{name}'s Log"},
  'app.title.default': {'zh': '日志', 'en': 'Log'},
  'quest.analyzing': {'zh': '{name}正在思考...', 'en': '{name} is thinking...'},
  'home.guide.tooltip': {'zh': '专属助手', 'en': 'Personal Assistant'},
  'home.profile.tooltip': {'zh': '记忆画像', 'en': 'Memory Portrait'},
  'home.sync.tooltip': {'zh': '上传今日记忆', 'en': 'Upload Today Memory'},
  'home.stats.tooltip': {'zh': '数据统计', 'en': 'Stats'},
  'home.achievement.tooltip': {'zh': '成就中心', 'en': 'Achievements'},
  'home.shop.tooltip': {'zh': '奖励商店', 'en': 'Reward Shop'},
  'home.bag.tooltip': {'zh': '我的背包', 'en': 'Inventory'},
  'home.delete_all.tooltip': {'zh': '清空任务', 'en': 'Clear All'},
  'home.all_done': {
    'zh': '所有任务完成，干得漂亮。',
    'en': 'All quests completed. Nice work.'
  },
  'home.xp_gold_bar': {'zh': '经验与金币', 'en': 'XP & Gold'},
  'home.gold_label': {'zh': '金币', 'en': 'Gold'},
  'home.level_label': {'zh': '等级', 'en': 'Level'},
  'home.bootstrap.offline': {
    'zh': '助手暂时离线，请稍后重试。',
    'en': 'Assistant is offline for now. Please try again later.'
  },
  'home.event.title': {'zh': '地球突发事件', 'en': 'Earth Dynamic Event'},
  'home.event.reward': {
    'zh': '奖励：+{xp} XP / +{gold} 金币',
    'en': 'Reward: +{xp} XP / +{gold} Gold'
  },
  'home.event.reason': {'zh': '记忆依据：{reason}', 'en': 'Memory Basis: {reason}'},
  'home.event.reason_badge': {'zh': '记忆依据', 'en': 'Memory Basis'},
  'home.event.accepted': {
    'zh': '事件已加入任务板：+{xp} XP / +{gold} 金币',
    'en': 'Event added to quest board: +{xp} XP / +{gold} Gold'
  },
  'home.event.dismissed': {'zh': '今日事件已跳过。', 'en': 'Today event skipped.'},
  'home.event.failed': {
    'zh': '事件处理失败，请稍后重试。',
    'en': 'Failed to process the event. Please retry.'
  },
  'home.event.badge': {'zh': '今日事件', 'en': 'Today Event'},
  'home.delete_all.title': {'zh': '确认删除', 'en': 'Confirm Deletion'},
  'home.delete_all.message': {
    'zh': '将所有任务移入回收站。',
    'en': 'Move all quests to recycle bin.'
  },
  'home.delete_all.confirm': {'zh': '确认删除', 'en': 'Delete All'},
  'guide.title': {'zh': '专属助手', 'en': 'Personal Assistant'},
  'guide.name.default': {'zh': '小忆', 'en': 'Xiaoyi'},
  'guide.name.edit': {'zh': '修改名字', 'en': 'Rename'},
  'guide.name.dialog_title': {'zh': '给{name}起个名字', 'en': 'Name {name}'},
  'guide.name.dialog_hint': {
    'zh': '输入你想怎么叫它',
    'en': 'Choose what to call your assistant'
  },
  'guide.name.dialog_action': {'zh': '保存名字', 'en': 'Save Name'},
  'guide.hero.subtitle': {
    'zh': '{name}记得你的节奏，也陪你把今天拆成能开始的一步。',
    'en':
        '{name} remembers your rhythm and helps you turn today into one doable step.'
  },
  'guide.daily_open.title': {'zh': '{name}上线了', 'en': '{name} is here'},
  'guide.cta.later': {'zh': '稍后再聊', 'en': 'Later'},
  'guide.cta.continue': {'zh': '继续聊聊', 'en': 'Continue'},
  'guide.default_opening': {
    'zh': '{name}在。你可以让我继续聊今天、回看上周，或给你一个恢复任务。',
    'en':
        '{name} is here. Ask me to continue today, review last week, or create a recovery quest.'
  },
  'guide.quick.today': {'zh': '继续聊今天', 'en': 'Continue Today'},
  'guide.quick.week': {'zh': '回看上周', 'en': 'Review Last Week'},
  'guide.quick.recovery': {'zh': '给我一个恢复任务', 'en': 'Give Me Recovery Quest'},
  'guide.quick.listen_more': {'zh': '继续说说', 'en': 'Keep talking'},
  'guide.quick.stay_with_me': {'zh': '陪我聊聊', 'en': 'Stay with me'},
  'guide.quick.hardest_part': {
    'zh': '最难的是哪一块',
    'en': 'Which part feels hardest'
  },
  'guide.quick.help_sort': {'zh': '帮我理一下', 'en': 'Help me sort it out'},
  'guide.quick.ask_advice': {'zh': '给我一个建议', 'en': 'Give me advice'},
  'guide.quick.push_or_rest': {
    'zh': '现在更适合推进还是休息',
    'en': 'Push or rest right now'
  },
  'guide.quick.generate_task': {'zh': '把这句变成任务', 'en': 'Turn this into a task'},
  'guide.quick.open_stats': {'zh': '帮我看统计', 'en': 'Open stats'},
  'guide.quick.view_weekly': {'zh': '看看这周怎么样', 'en': 'Show this week'},
  'guide.mode.generate_task': {'zh': '生成任务', 'en': 'Create Task'},
  'guide.mode.modify_task': {'zh': '修改任务', 'en': 'Edit Task'},
  'guide.mode.companion': {'zh': '陪我聊聊', 'en': 'Talk With Me'},
  'guide.examples.title': {'zh': '试试这些说法', 'en': 'Try saying it like this'},
  'guide.examples.generate': {
    'zh': '直接说一句要做的事，我会把它整理成任务。',
    'en': 'Say the thing you want to do and I will turn it into a task.',
  },
  'guide.examples.modify': {
    'zh': '说出任务名和想改的内容，我会继续帮你调整。',
    'en': 'Tell me the task name and what to change, and I will update it.',
  },
  'guide.examples.companion': {
    'zh': '不用把话说完整，先从最想说的那一块开始就行。',
    'en':
        'You do not need the full story. Start with the part you want to say first.',
  },
  'guide.input.hint': {
    'zh': '告诉{name}你现在的状态...',
    'en': 'Tell {name} how you feel now...'
  },
  'guide.input.generate_hint': {
    'zh': '例如：把“准备周会开场白”变成任务',
    'en': 'For example: Turn "Prepare the meeting opening" into a task',
  },
  'guide.input.modify_hint': {
    'zh': '例如：修改任务“开会”，截止时间是 3 月 20 日',
    'en': 'For example: Edit task "Meeting", due on March 20',
  },
  'guide.input.companion_hint': {
    'zh': '例如：我现在有点乱，陪我聊聊',
    'en': 'For example: I feel scattered right now, stay with me',
  },
  'guide.memory.title': {'zh': '{name}记得', 'en': '{name} Remembers'},
  'guide.memory.empty': {
    'zh': '{name}还在熟悉你的节奏，先聊聊今天发生了什么。',
    'en':
        '{name} is still learning your rhythm. Start by sharing what happened today.'
  },
  'guide.memory.refs': {
    'zh': '参考了 {count} 段近期记忆',
    'en': 'Based on {count} recent memories'
  },
  'guide.proposal.title': {'zh': '{name}提案', 'en': '{name} Suggests'},
  'guide.fallback.reply': {
    'zh': '我在。先从今天最小的一步开始吧。',
    'en': 'I am here. Let us start with one tiny step today.'
  },
  'guide.quick.week.prompt': {
    'zh': '帮我回看上周的节奏，并给一个提醒。',
    'en': 'Review my rhythm from last week and give me one reminder.'
  },
  'guide.quick.recovery.prompt': {
    'zh': '给我一个轻量且可执行的恢复任务。',
    'en': 'Give me a light and practical recovery quest.'
  },
  'guide.quick.today.prompt': {'zh': '继续聊今天。', 'en': 'Continue with today.'},
  'guide.network_fallback': {
    'zh': '网络有点抖动，我先离线陪你：先推进一件最小任务。',
    'en': 'Network is unstable. Let us do one tiny task first.'
  },
  'guide.added_task': {
    'zh': '{name}的任务建议已加入任务板。',
    'en': '{name}\'s quest has been added.'
  },
  'guide.onboarding.dialog_title': {'zh': '新手教程', 'en': 'Getting Started'},
  'guide.onboarding.badge': {'zh': '上手任务', 'en': 'Starter Tasks'},
  'guide.onboarding.accepted': {
    'zh': '新手教程已加入任务板。',
    'en': 'Starter tutorial added to your board.'
  },
  'guide.onboarding.dismissed': {
    'zh': '新手教程已先跳过。',
    'en': 'Starter tutorial skipped for now.'
  },
  'guide.onboarding.failed': {
    'zh': '新手教程生成失败，请稍后重试。',
    'en': 'Failed to create starter tutorial. Please retry later.'
  },
  'guide.onboarding.reason_badge': {'zh': '教程说明', 'en': 'Why start here'},
  'guide.onboarding.event.title': {
    'zh': '新手教程：5 步开始你的旅程',
    'en': 'Starter Tutorial: Begin Your Journey in 5 Steps'
  },
  'guide.onboarding.event.description': {
    'zh': '这组任务会带你走一遍输入任务、完成任务、签到打卡、和助手对话、逛奖励商店五个核心功能。',
    'en':
        'These starter tasks walk you through adding a task, completing one, checking in, chatting with your assistant, and visiting the reward shop.'
  },
  'guide.onboarding.event.reason': {
    'zh': '当前账户还是空白状态，先用一组上手任务带你认识这个软件最常用的功能。',
    'en':
        'Your account is still fresh, so this starter set is the fastest way to learn the core features.'
  },
  'guide.onboarding.step.checkin.title': {
    'zh': '签到打卡',
    'en': 'Daily Check-In'
  },
  'guide.onboarding.step.checkin.description': {
    'zh': '打开成长仪表盘，完成今日签到，开始积累连续天数。',
    'en':
        'Open the growth dashboard and check in today to start building your streak.'
  },
  'guide.onboarding.step.shop.title': {
    'zh': '逛逛奖励商店',
    'en': 'Visit the Reward Shop'
  },
  'guide.onboarding.step.shop.description': {
    'zh': '看看金币可以兑换什么，给自己设定一个小目标。',
    'en': 'See what your gold can buy and set a small reward goal for yourself.'
  },
  'guide.onboarding.parent.title': {
    'zh': '新手教程：开始你的旅程',
    'en': 'Starter Tutorial: Begin Your Journey'
  },
  'guide.onboarding.parent.description': {
    'zh': '跟着下面 5 个小步骤走一遍核心功能：输入任务、完成任务、签到打卡、聊助手、逛商店，完成后再回来勾掉这条总任务。',
    'en':
        'Follow the 5 steps below to explore core features: add a task, complete it, check in, chat with your assistant, and visit the shop — then come back and mark this main quest done.'
  },
  'guide.onboarding.step.capture.title': {
    'zh': '输入一句今天要做的事',
    'en': 'Type One Thing for Today'
  },
  'guide.onboarding.step.capture.description': {
    'zh': '在底部输入栏写一句待办，体验系统怎样帮你整理成任务。',
    'en':
        'Use the bottom input bar to type one thing you want to do and watch the app turn it into quests.'
  },
  'guide.onboarding.step.complete.title': {
    'zh': '完成一个最小动作',
    'en': 'Finish One Tiny Step'
  },
  'guide.onboarding.step.complete.description': {
    'zh': '勾掉一项已经做完的小事，看看 XP 和金币是怎么变化的。',
    'en':
        'Check off one tiny task you already finished and notice how XP and gold change.'
  },
  'guide.onboarding.step.assistant.title': {
    'zh': '和{name}说一句话',
    'en': 'Say One Line to {name}'
  },
  'guide.onboarding.step.assistant.description': {
    'zh': '打开专属助手，说一句你现在的状态，感受它怎么陪你整理今天。',
    'en':
        'Open your personal assistant, share how you feel, and see how it helps you sort out today.'
  },
  'guide.onboarding.step.portrait.title': {
    'zh': '看一眼记忆画像',
    'en': 'Open Your Memory Portrait'
  },
  'guide.onboarding.step.portrait.description': {
    'zh': '试试上传今日记忆，或打开记忆画像，看看系统怎样理解你的状态。',
    'en':
        'Try uploading today’s memory or open the memory portrait to see how the app reads your current state.'
  },
  // Coach Marks 新手引导
  'coach.step1.title': {'zh': '写下第一个任务', 'en': 'Write Your First Quest'},
  'coach.step1.description': {
    'zh': '在底部输入框输入一件今天想做的事，系统会帮你整理成任务。',
    'en': 'Type one thing you want to do today in the input bar below.'
  },
  'coach.step2.title': {'zh': '完成它，获得经验', 'en': 'Complete It, Earn XP'},
  'coach.step2.description': {
    'zh': '点击任务左侧圆圈标记完成，获得经验值和金币奖励。',
    'en':
        'Tap the circle on the left side of a quest to mark it done and earn rewards.'
  },
  'coach.step3.title': {'zh': '签到打卡', 'en': 'Daily Check-In'},
  'coach.step3.description': {
    'zh': '打开成长仪表盘，完成今日签到，保持连续天数。',
    'en':
        'Open the growth dashboard and check in today to keep your streak alive.'
  },
  'coach.step4.title': {'zh': '和助手聊一句', 'en': 'Chat With Your Assistant'},
  'coach.step4.description': {
    'zh': '打开助手面板，随便说点什么，它会帮你整理今天。',
    'en':
        'Open the assistant panel and share anything — it helps you sort out your day.'
  },
  'coach.step5.title': {'zh': '逛逛奖励商店', 'en': 'Visit the Reward Shop'},
  'coach.step5.description': {
    'zh': '看看金币可以兑换什么，给自己设定一个小目标。',
    'en': 'See what your gold can buy and set a small reward goal for yourself.'
  },
  'coach.next': {'zh': '下一步', 'en': 'Next'},
  'coach.skip': {'zh': '跳过引导', 'en': 'Skip Tour'},
  'coach.finish': {'zh': '开始冒险', 'en': 'Start Adventure'},
  'coach.step_label': {
    'zh': '第{current}步 / 共{total}步',
    'en': 'Step {current} of {total}'
  },
  'guide.status.ready': {'zh': '{name}在线', 'en': '{name} is online'},
  'guide.status.auth': {'zh': '登录已过期', 'en': 'Session Expired'},
  'guide.status.network': {'zh': '网络异常', 'en': 'Network Error'},
  'guide.status.service': {'zh': '服务暂不可用', 'en': 'Service Unavailable'},
  'guide.status.retry': {'zh': '点击重试连接{name}', 'en': 'Tap to reconnect {name}'},
  'night.title': {'zh': '营地夜话', 'en': 'Campfire Reflection'},
  'night.keep_only': {'zh': '仅记录不加任务', 'en': 'Record Only'},
  'night.add_tomorrow': {'zh': '加入明日任务', 'en': 'Add Tomorrow Quest'},
  'night.uploading': {'zh': '正在上传今日记忆...', 'en': 'Uploading today memory...'},
  'night.upload_queued': {
    'zh': '记忆已排队，正在处理中...',
    'en': 'Memory queued, processing...'
  },
  'night.upload_success': {
    'zh': '上传成功，准备开启夜话。',
    'en': 'Upload complete. Opening reflection...'
  },
  'night.upload_fail': {
    'zh': '上传失败，请稍后重试。',
    'en': 'Upload failed. Please retry later.'
  },
  'night.poll_success': {
    'zh': '记忆处理完成，进入夜话。',
    'en': 'Memory processed. Entering reflection.'
  },
  'night.poll_pending': {
    'zh': '记忆处理中，请稍后再试。',
    'en': 'Memory is processing. Please retry later.'
  },
  'night.poll_fail': {
    'zh': '轮询状态失败，请稍后重试。',
    'en': 'Status check failed. Please retry later.'
  },
  'night.fallback.opening': {
    'zh': '今天上传成功，我已经把你的进展记录下来了。',
    'en': 'Today upload succeeded. I have recorded your progress.'
  },
  'night.fallback.question': {
    'zh': '要不要我帮你加一个明天的恢复任务？',
    'en': 'Do you want me to add a recovery quest for tomorrow?'
  },
  'night.fallback.task_title': {
    'zh': '明日恢复支线：拉伸 10 分钟',
    'en': 'Tomorrow Recovery: 10-Min Stretch'
  },
  'night.fallback.task_desc': {
    'zh': '用一个小动作，降低明天的启动压力。',
    'en': 'Use a tiny action to reduce tomorrow start-up pressure.'
  },
  'night.record_only_message': {
    'zh': '夜话复盘：仅记录不加任务',
    'en': 'Night reflection: record only, no task'
  },
  'profile.title': {'zh': '{name}记忆画像', 'en': '{name} Memory Portrait'},
  'profile.generate_fail': {
    'zh': '画像生成失败，请稍后重试。',
    'en': 'Portrait generation failed. Please retry later.'
  },
  'profile.generate_latest': {'zh': '生成最新画像', 'en': 'Generate Latest Portrait'},
  'profile.source_label': {'zh': '记忆驱动画像', 'en': 'Memory-Driven Portrait'},
  'profile.loading': {'zh': '正在生成画像...', 'en': 'Generating portrait...'},
  'settings.title': {'zh': '设置中心', 'en': 'Settings'},
  'settings.subtitle': {
    'zh': '把助手、外观和语言整理到一个清爽面板里。',
    'en': 'Keep assistant, appearance, and language in one calm panel.'
  },
  'settings.section.guide': {'zh': '助手', 'en': 'Assistant'},
  'settings.section.guide_desc': {
    'zh': '决定助手什么时候陪你开场，什么时候安静待机。',
    'en':
        'Choose when the assistant should proactively reach out or stay quiet.'
  },
  'settings.section.appearance': {'zh': '外观', 'en': 'Appearance'},
  'settings.section.appearance_desc': {
    'zh': '只保留明亮主题，让任务面板始终轻盈耐看。',
    'en': 'Bright-only themes keep the quest board calm and easy to scan.'
  },
  'settings.section.language': {'zh': '语言', 'en': 'Language'},
  'settings.section.language_desc': {
    'zh': '切换界面语言，文案会立即同步。',
    'en': 'Switch the interface language and refresh copy instantly.'
  },
  'settings.guide_enabled': {'zh': '启用专属助手', 'en': 'Enable Personal Assistant'},
  'settings.guide_enabled_desc': {
    'zh': '关闭后不再主动触达，但可手动开启。',
    'en':
        'When disabled, proactive touches stop but manual opening remains available.'
  },
  'settings.proactive_enabled': {
    'zh': '每日首次主动触达',
    'en': 'Daily First-Open Proactive'
  },
  'settings.proactive_enabled_desc': {
    'zh': '每天首次进入首页时主动发起一句问候。',
    'en': 'Send one proactive greeting on first home open each day.'
  },
  'settings.memory_mode': {
    'zh': '记忆模式：最近 + 长期',
    'en': 'Memory Mode: Recent + Long-Term'
  },
  'settings.theme.forest': {'zh': '森林冒险', 'en': 'Forest Adventure'},
  'settings.theme.forest_desc': {
    'zh': '暖色冒险感，更适合推进任务和保留节奏。',
    'en': 'Warm and adventurous, great for momentum and steady progress.'
  },
  'settings.theme.default': {'zh': '清新呼吸', 'en': 'Fresh Breath'},
  'settings.theme.default_desc': {
    'zh': '更通透的留白感，适合轻盈、低压的日常。',
    'en': 'Airy and open, ideal for a light and low-pressure routine.'
  },
  'settings.lang.zh': {'zh': '中文', 'en': 'Chinese'},
  'settings.lang.zh_desc': {
    'zh': '保留中文任务语境和提示语气。',
    'en': 'Use Chinese labels and guidance throughout the app.'
  },
  'settings.lang.en': {'zh': 'English', 'en': 'English'},
  'settings.lang.en_desc': {
    'zh': '切换到英文界面，适合双语整理与练习。',
    'en': 'Switch to English for a bilingual or English-first flow.'
  },
  'settings.saved': {'zh': '设置已保存。', 'en': 'Settings saved.'},
  'settings.footer_note': {
    'zh': '设置会自动保存，下次打开会延续你现在的选择。',
    'en': 'Preferences are saved automatically and will be restored next time.'
  },
  'drawer.diary': {'zh': '生活日记', 'en': 'Life Diary'},
  'drawer.diary.desc': {'zh': '记录你的现实副本', 'en': 'Record your real-world run'},
  'drawer.recycle': {'zh': '回收站', 'en': 'Recycle Bin'},
  'drawer.recycle.desc': {'zh': '查看已删除任务', 'en': 'View deleted quests'},
  'drawer.guide': {'zh': '专属助手', 'en': 'Personal Assistant'},
  'drawer.guide.desc': {'zh': '打开专属助手对话', 'en': 'Open assistant chat'},
  'drawer.binding': {'zh': '微信绑定', 'en': 'WeChat Binding'},
  'drawer.binding.desc': {'zh': '同步微信消息', 'en': 'Sync WeChat messages'},
  'drawer.tutorial': {'zh': '使用说明', 'en': 'User Guide'},
  'drawer.tutorial.desc': {'zh': '重新查看功能引导', 'en': 'Replay the feature walkthrough'},
  'drawer.settings': {'zh': '设置中心', 'en': 'Settings'},
  'drawer.settings.desc': {'zh': '个性化配置', 'en': 'Personalize preferences'},
  'drawer.logout': {'zh': '退出登录', 'en': 'Sign Out'},
  'drawer.logout.desc': {'zh': '离开现实副本', 'en': 'Leave current session'},
  'drawer.logout.title': {'zh': '确认退出', 'en': 'Confirm Sign Out'},
  'drawer.logout.message': {
    'zh': '确定要退出登录吗？',
    'en': 'Are you sure you want to sign out?'
  },
  'drawer.logout.confirm': {'zh': '退出', 'en': 'Sign Out'},
  'diary.title': {'zh': '人生日记', 'en': 'Life Diary'},
  'diary.load_failed': {'zh': '加载失败', 'en': 'Load Failed'},
  'diary.completed_count': {
    'zh': '完成了 {count} 项任务',
    'en': 'Completed {count} quests'
  },
  'diary.weekly.tooltip_idle': {
    'zh': '📜 召唤村长周报',
    'en': '📜 Generate Weekly Report'
  },
  'diary.weekly.tooltip_running': {
    'zh': '📜 周报生成中',
    'en': '📜 Weekly Report Running'
  },
  'diary.weekly.not_logged_in': {
    'zh': '未登录，无法召唤周报',
    'en': 'Sign in to generate a weekly report.'
  },
  'diary.weekly.queued': {
    'zh': '周报已加入生成队列，你可以先去别处逛逛，完成后我会弹窗提醒你。',
    'en':
        'Your weekly report is queued. Feel free to leave this page and I will alert you when it is ready.'
  },
  'diary.weekly.ready_now': {
    'zh': '刚刚的周报已经生成完成，你现在可以直接查看。',
    'en': 'Your latest weekly report is already ready to view.'
  },
  'diary.weekly.failed': {
    'zh': '召唤失败：{error}',
    'en': 'Failed to start weekly report: {error}'
  },
  'diary.weekly.card_title': {'zh': '村长的信', 'en': 'Village Chief Letter'},
  'diary.push_wechat.tooltip': {
    'zh': '📩 推送周报到微信',
    'en': '📩 Push Report to WeChat'
  },
  'diary.push_wechat.not_logged_in': {
    'zh': '未登录，无法推送',
    'en': 'Sign in to push the report.'
  },
  'diary.push_wechat.empty': {
    'zh': '暂无可推送内容',
    'en': 'No report is available to push yet.'
  },
  'diary.push_wechat.success': {
    'zh': '📩 周报已推送到微信！',
    'en': '📩 Weekly report pushed to WeChat!'
  },
  'diary.push_wechat.failed': {
    'zh': '推送失败：{error}',
    'en': 'Failed to push report: {error}'
  },
  'weekly.summary.ready_title': {'zh': '本周周报已生成', 'en': 'Weekly Report Ready'},
  'weekly.summary.failed_title': {
    'zh': '本周周报生成失败',
    'en': 'Weekly Report Failed'
  },
  'weekly.summary.ready_body': {
    'zh': '村长已经写完本周周报，你现在可以直接去查看。',
    'en':
        "Your village chief has finished this week's report. You can open it now."
  },
  'weekly.summary.failed_body': {
    'zh': '这次周报没有顺利生成，请稍后再试一次。',
    'en':
        'This weekly report did not finish successfully. Please try again later.'
  },
  'weekly.summary.later': {'zh': '稍后再看', 'en': 'Later'},
  'weekly.summary.acknowledge': {'zh': '知道了', 'en': 'OK'},
  'weekly.summary.open_now': {'zh': '查看周报', 'en': 'Open Report'},
  'confirm_dialog.dont_ask': {
    'zh': '下次不再提醒',
    'en': 'Skip this reminder next time'
  },
  'quick_add.hint': {
    'zh': '输入任务情报 (例如: "筹备下周会议...")',
    'en':
        "Enter quest details (for example: \"Prepare next week's meeting...\")"
  },
  'quick_add.menu.create': {'zh': '快速创建任务', 'en': 'Quick Create Task'},
  'quick_add.menu.create_desc': {
    'zh': '直接输入标题，不经过AI解析',
    'en': 'Enter title directly, no AI parsing'
  },
  'quick_add.menu.image': {'zh': '图片解析', 'en': 'Image Parsing'},
  'quick_add.menu.image_desc': {
    'zh': '拍照或选图识别任务',
    'en': 'Take photo or select image to recognize tasks'
  },
  'quick_add.menu.coming_soon': {'zh': '即将推出', 'en': 'Coming Soon'},
  'quick_add.create.title': {'zh': '快速创建', 'en': 'Quick Create'},
  'quick_add.create.hint': {'zh': '任务标题', 'en': 'Task title'},
  'quick_add.create.confirm': {'zh': '创建', 'en': 'Create'},
  'quick_add.create.success': {'zh': '任务已创建', 'en': 'Task created'},
  'quick_add.create.tier_main': {'zh': '主线任务', 'en': 'Main Quest'},
  'quick_add.create.tier_side': {'zh': '支线任务', 'en': 'Side Quest'},
  'quick_add.create.tier_daily': {'zh': '日常任务', 'en': 'Daily'},
  'quick_add.voice.listening': {'zh': '正在听...', 'en': 'Listening...'},
  'quick_add.voice.unavailable': {
    'zh': '语音识别不可用',
    'en': 'Speech recognition unavailable'
  },
  'achievement.page_title': {'zh': '成就殿堂', 'en': 'Achievements'},
  'achievement.category.quest': {'zh': '任务成就', 'en': 'Quest Achievements'},
  'achievement.category.streak': {'zh': '签到成就', 'en': 'Streak Achievements'},
  'achievement.category.xp': {'zh': '经验成就', 'en': 'XP Achievements'},
  'achievement.category.special': {'zh': '特殊成就', 'en': 'Special Achievements'},
  'achievement.unlocked_progress': {
    'zh': '已解锁 {unlocked} / {total}',
    'en': 'Unlocked {unlocked} / {total}'
  },
  'achievement.empty_title': {
    'zh': '成就系统加载中',
    'en': 'Achievements are loading'
  },
  'achievement.empty_body': {
    'zh': '完成任务和签到来解锁成就徽章',
    'en': 'Complete quests and daily check-ins to unlock achievement badges'
  },
  'achievement.unlocked_badge': {'zh': '成就解锁', 'en': 'Achievement Unlocked'},
  'achievement.detail_title': {'zh': '成就详情', 'en': 'Achievement Details'},
  'achievement.status_label': {'zh': '状态', 'en': 'Status'},
  'achievement.status_unlocked': {'zh': '已解锁', 'en': 'Unlocked'},
  'achievement.status_locked': {'zh': '未解锁', 'en': 'Locked'},
  'achievement.progress_label': {'zh': '当前进度', 'en': 'Progress'},
  'achievement.target_label': {'zh': '目标', 'en': 'Target'},
  'achievement.rule_label': {'zh': '规则说明', 'en': 'Rule'},
  'achievement.unlocked_at_label': {'zh': '解锁时间', 'en': 'Unlocked At'},
  'achievement.reward_label': {'zh': '解锁奖励', 'en': 'Reward'},
  'achievement.acknowledge': {'zh': '我知道了', 'en': 'Got It'},
  'achievement.progress.total_completed': {
    'zh': '{current}/{target} 任务',
    'en': '{current}/{target} quests'
  },
  'achievement.progress.streak': {
    'zh': '{current}/{target} 天',
    'en': '{current}/{target} days'
  },
  'achievement.progress.total_xp': {
    'zh': '{current}/{target} XP',
    'en': '{current}/{target} XP'
  },
  'achievement.progress.level': {
    'zh': 'Lv.{current}/{target}',
    'en': 'Lv.{current}/{target}'
  },
  'achievement.progress.board_clear': {
    'zh': '{current}/{target} 次',
    'en': '{current}/{target} times'
  },
  'achievement.progress.first_wechat': {
    'zh': '{current}/{target} 次',
    'en': '{current}/{target} times'
  },
  'achievement.target.total_completed': {
    'zh': '目标：累计完成 {target} 个任务',
    'en': 'Goal: complete {target} quests in total'
  },
  'achievement.target.streak': {
    'zh': '目标：连续签到 {target} 天',
    'en': 'Goal: keep a {target}-day streak'
  },
  'achievement.target.total_xp': {
    'zh': '目标：累计获得 {target} XP',
    'en': 'Goal: earn {target} XP in total'
  },
  'achievement.target.level': {
    'zh': '目标：达到 {target} 级',
    'en': 'Goal: reach level {target}'
  },
  'achievement.target.board_clear': {
    'zh': '目标：首次清空任务面板',
    'en': 'Goal: clear the quest board once'
  },
  'achievement.target.first_wechat': {
    'zh': '目标：首次通过微信创建任务',
    'en': 'Goal: create a quest from WeChat once'
  },
  'achievement.target.default': {
    'zh': '目标：达到条件',
    'en': 'Goal: meet the requirement'
  },
  'stats.title': {'zh': '数据统计', 'en': 'Stats'},
  'stats.empty_title': {'zh': '还没有统计数据', 'en': 'No stats yet'},
  'stats.empty_body': {
    'zh': '完成任务后，这里会展示你的成长轨迹',
    'en': 'Finish quests and this page will show your growth path'
  },
  'stats.highlight.weekly_completed': {'zh': '本周完成', 'en': 'This Week'},
  'stats.highlight.total_xp': {'zh': '累计 XP', 'en': 'Total XP'},
  'stats.highlight.longest_streak': {'zh': '最长连续', 'en': 'Longest Streak'},
  'stats.highlight.best_day': {'zh': '最高效一天', 'en': 'Best Day'},
  'stats.highlight.longest_streak_value': {
    'zh': '{count}天',
    'en': '{count} days'
  },
  'stats.highlight.best_day_value': {
    'zh': '{count}个任务',
    'en': '{count} quests'
  },
  'level.title.apprentice_villager': {
    'zh': '见习村民',
    'en': 'Apprentice Villager'
  },
  'level.title.junior_adventurer': {'zh': '初级冒险者', 'en': 'Junior Adventurer'},
  'level.title.bronze_hero': {'zh': '青铜勇者', 'en': 'Bronze Hero'},
  'level.title.silver_knight': {'zh': '白银骑士', 'en': 'Silver Knight'},
  'level.title.golden_fighter': {'zh': '黄金斗士', 'en': 'Golden Fighter'},
  'level.title.platinum_guardian': {'zh': '铂金守护者', 'en': 'Platinum Guardian'},
  'level.title.legendary_champion': {'zh': '传奇王者', 'en': 'Legendary Champion'},
  'level.title.star_traveler': {'zh': '星辰旅者', 'en': 'Star Traveler'},
  'shop.title': {'zh': '奖励商店', 'en': 'Reward Shop'},
  'shop.add_reward': {'zh': '添加奖励', 'en': 'Add Reward'},
  'shop.add_hint': {
    'zh': '奖励将展示在商店列表中，金币必须为正整数。',
    'en':
        'Rewards appear in the shop list. Gold cost must be a positive integer.'
  },
  'shop.reward_name': {'zh': '奖励名称', 'en': 'Reward Name'},
  'shop.reward_cost': {'zh': '所需金币', 'en': 'Gold Cost'},
  'shop.gold_unit': {'zh': '金币', 'en': 'Gold'},
  'shop.input_name_required': {
    'zh': '请输入奖励名称',
    'en': 'Please enter reward name'
  },
  'shop.input_gold_required': {
    'zh': '请输入金币数量',
    'en': 'Please enter gold amount'
  },
  'shop.input_gold_positive': {
    'zh': '金币必须为正整数',
    'en': 'Gold must be a positive integer'
  },
  'shop.save': {'zh': '保存', 'en': 'Save'},
  'shop.saving': {'zh': '保存中...', 'en': 'Saving...'},
  'shop.added': {'zh': '已添加奖励', 'en': 'Reward added'},
  'shop.add_failed': {
    'zh': '添加失败，请检查输入后重试。',
    'en': 'Add failed. Please check input and retry.'
  },
  'shop.buy_success': {
    'zh': '购买成功！物品已放入背包。',
    'en': 'Purchased! Item added to inventory.'
  },
  'shop.buy_failed_gold': {
    'zh': '金币不足，去完成任务赚金币吧！',
    'en': 'Not enough gold. Finish quests to earn more!'
  },
  'shop.delete_title': {'zh': '删除奖励', 'en': 'Delete Reward'},
  'shop.delete_message': {
    'zh': '确定要删除“{title}”吗？删除后不可恢复。',
    'en': 'Delete "{title}"? This action cannot be undone.'
  },
  'shop.deleted': {'zh': '已删除', 'en': 'Deleted'},
  'shop.gold_balance': {'zh': '金币余额', 'en': 'Gold Balance'},
  'shop.system_title': {'zh': '系统商城', 'en': 'System Shop'},
  'shop.custom_title': {'zh': '自定义奖励', 'en': 'Custom Rewards'},
  'shop.system_empty': {
    'zh': '系统商品还没有上架，请稍后再来看看。',
    'en': 'System rewards are not available yet. Please check back later.'
  },
  'shop.empty': {
    'zh': '还没有上架自定义商品，先添加一个吧。',
    'en': 'No custom rewards yet. Add your first one.'
  },
  'shop.buy_btn': {'zh': '兑换', 'en': 'Redeem'},
  'shop.unnamed': {'zh': '未命名商品', 'en': 'Unnamed Reward'},
  'inventory.title': {'zh': '我的背包', 'en': 'Inventory'},
  'inventory.empty': {
    'zh': '背包空空如也，快去商店看看吧。',
    'en': 'Inventory is empty. Visit the shop!'
  },
  'inventory.section.usable': {'zh': '可使用道具', 'en': 'Usable Items'},
  'inventory.section.equipped': {'zh': '已装备', 'en': 'Equipped'},
  'inventory.section.unequipped': {'zh': '未装备', 'en': 'Unequipped'},
  'inventory.section.custom': {'zh': '自定义奖励', 'en': 'Custom Rewards'},
  'inventory.use': {'zh': '使用', 'en': 'Use'},
  'inventory.active': {'zh': '生效中', 'en': 'Active'},
  'inventory.equip': {'zh': '装备', 'en': 'Equip'},
  'inventory.unequip': {'zh': '卸下', 'en': 'Unequip'},
  'inventory.used': {'zh': '道具已生效', 'en': 'Item effect applied'},
  'inventory.used_custom': {
    'zh': '已使用 {title}，去好好享受吧！',
    'en': 'Used {title}. Enjoy it!'
  },
  'inventory.equipped_toast': {'zh': '已装备 {title}', 'en': 'Equipped {title}'},
  'inventory.unequipped_toast': {
    'zh': '已卸下 {title}',
    'en': 'Unequipped {title}'
  },
  'quest.completed.xp_only': {
    'zh': '任务完成！获得 +{xp} XP（{count} 项）',
    'en': 'Quest complete! +{xp} XP ({count} item(s))'
  },
  'quest.completed.xp_gold': {
    'zh': '任务完成！获得 +{xp} XP 与 +{gold} 金币（{count} 项）',
    'en': 'Quest complete! +{xp} XP and +{gold} Gold ({count} item(s))'
  },
  'quest.completed.no_reward': {
    'zh': '任务已标记完成（{count} 项）',
    'en': 'Quest marked complete ({count} item(s))'
  },
  'quest.undo.xp_only': {
    'zh': '已撤销任务：-{xp} XP（{count} 项）',
    'en': 'Quest reverted: -{xp} XP ({count} item(s))'
  },
  'quest.undo.xp_gold': {
    'zh': '已撤销任务：-{xp} XP 与 -{gold} 金币（{count} 项）',
    'en': 'Quest reverted: -{xp} XP and -{gold} Gold ({count} item(s))'
  },
  'quest.undo.no_reward': {
    'zh': '已撤销任务（{count} 项）',
    'en': 'Quest reverted ({count} item(s))'
  },
  'quest.level_up': {
    'zh': '恭喜升级！当前等级 {level}',
    'en': 'Level up! Current level {level}'
  },
  'quest.error.no_session': {
    'zh': '未检测到登录状态，无法添加任务。',
    'en': 'No active session. Unable to add quest.'
  },
  'quest.error.title_required': {
    'zh': '任务标题不能为空。',
    'en': 'Quest title cannot be empty.'
  },
  'quest.error.guide_insert_failed': {
    'zh': '向导任务写入失败，请稍后重试。',
    'en': 'Failed to insert guide quest. Please retry later.'
  },
  'quest.error.stats_update_failed': {
    'zh': '经验与金币更新失败，请检查网络后重试。',
    'en': 'Failed to update XP and Gold. Please retry later.'
  },
  'quest.error.stats_sync_failed': {
    'zh': '经验与金币同步失败，请稍后重试。',
    'en': 'Failed to sync XP and Gold. Please retry later.'
  },
  'quest.error.save_failed': {
    'zh': '保存失败，请检查网络。',
    'en': 'Save failed. Please check network.'
  },
  'quest.error.weekly_push_save_failed': {
    'zh': '微信推送设置保存失败，请检查网络。',
    'en': 'Failed to save weekly push setting. Please check network.'
  },
  'quest.error.quest_locked': {
    'zh': '此任务不可修改。',
    'en': 'This quest cannot be edited.'
  },
  'drawer.profile.badge': {'zh': '本地资料', 'en': 'Local Profile'},
  'drawer.profile.edit_name': {'zh': '修改昵称', 'en': 'Edit Name'},
  'drawer.profile.change_avatar': {'zh': '更换头像', 'en': 'Change Avatar'},
  'drawer.profile.change_avatar_desc': {
    'zh': '从本地相册或文件中选一张照片作为头像',
    'en': 'Pick a local photo to use as your avatar.'
  },
  'drawer.profile.remove_avatar': {'zh': '移除头像', 'en': 'Remove Avatar'},
  'drawer.profile.remove_avatar_desc': {
    'zh': '恢复为默认人物头像',
    'en': 'Restore the default profile avatar.'
  },
  'drawer.profile.name_title': {'zh': '修改昵称', 'en': 'Edit Display Name'},
  'drawer.profile.name_hint': {
    'zh': '输入你想显示的昵称',
    'en': 'Enter the name you want to show.'
  },
  'drawer.profile.name_action': {'zh': '保存昵称', 'en': 'Save Name'},
  'drawer.profile.name_saved': {'zh': '昵称已保存', 'en': 'Display name saved.'},
  'drawer.profile.avatar_saved': {'zh': '头像已更新', 'en': 'Avatar updated.'},
  'drawer.profile.avatar_removed': {'zh': '头像已移除', 'en': 'Avatar removed.'},
  'drawer.profile.avatar_failed': {
    'zh': '头像更新失败，请重试',
    'en': 'Failed to update avatar. Please try again.'
  },
  'drawer.profile.progress_hint': {
    'zh': '再获得 {xp} XP 就能继续升级',
    'en': 'Earn {xp} more XP to keep leveling up.'
  },
};
