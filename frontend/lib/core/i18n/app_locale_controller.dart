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
  'app.title': {'zh': 'Quest Log', 'en': 'Quest Log'},
  'home.guide.tooltip': {'zh': '专属向导', 'en': 'Personal Guide'},
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
    'zh': '向导暂时离线，请稍后重试。',
    'en': 'Guide is offline for now. Please try again later.'
  },
  'home.event.title': {'zh': '地球突发事件', 'en': 'Earth Dynamic Event'},
  'home.event.reward': {
    'zh': '奖励：+{xp} XP / +{gold} 金币',
    'en': 'Reward: +{xp} XP / +{gold} Gold'
  },
  'home.event.reason': {'zh': '记忆依据：{reason}', 'en': 'Memory Basis: {reason}'},
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
  'guide.title': {'zh': '专属地球向导', 'en': 'Personal Earth Guide'},
  'guide.name.default': {'zh': '小忆', 'en': 'Xiaoyi'},
  'guide.name.edit': {'zh': '修改名字', 'en': 'Rename'},
  'guide.name.dialog_title': {'zh': '给{name}起个名字', 'en': 'Name {name}'},
  'guide.name.dialog_hint': {
    'zh': '输入你想怎么叫它',
    'en': 'Choose what to call your guide'
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
  'guide.input.hint': {
    'zh': '告诉{name}你现在的状态...',
    'en': 'Tell {name} how you feel now...'
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
  'profile.title': {'zh': 'AI 记忆画像', 'en': 'AI Memory Portrait'},
  'profile.generate_fail': {
    'zh': '画像生成失败，请稍后重试。',
    'en': 'Portrait generation failed. Please retry later.'
  },
  'profile.generate_latest': {'zh': '生成最新画像', 'en': 'Generate Latest Portrait'},
  'profile.source_label': {'zh': '记忆驱动画像', 'en': 'Memory-Driven Portrait'},
  'profile.loading': {'zh': '正在生成画像...', 'en': 'Generating portrait...'},
  'settings.title': {'zh': '设置中心', 'en': 'Settings'},
  'settings.subtitle': {
    'zh': '把向导、外观和语言整理到一个清爽面板里。',
    'en': 'Keep guide, appearance, and language in one calm panel.'
  },
  'settings.section.guide': {'zh': '向导', 'en': 'Guide'},
  'settings.section.guide_desc': {
    'zh': '决定 AI 什么时候陪你开场，什么时候安静待机。',
    'en': 'Choose when the guide should proactively reach out or stay quiet.'
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
  'settings.guide_enabled': {'zh': '启用专属向导', 'en': 'Enable Personal Guide'},
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
  'drawer.guide': {'zh': '专属向导', 'en': 'Personal Guide'},
  'drawer.guide.desc': {'zh': '打开记忆对话面板', 'en': 'Open memory chat panel'},
  'drawer.binding': {'zh': '微信绑定', 'en': 'WeChat Binding'},
  'drawer.binding.desc': {'zh': '同步微信消息', 'en': 'Sync WeChat messages'},
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
