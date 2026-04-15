import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/reward/controllers/reward_controller.dart';
import 'package:frontend/features/reward/models/reward.dart';

void main() {
  test('isDeprecatedSystemReward 能识别废弃主题商品', () {
    const deprecated = Reward(
      id: '1',
      title: '深海主题',
      cost: 500,
      category: 'theme',
      effectType: 'theme_unlock',
      effectValue: 'ocean_deep',
      isSystem: true,
    );
    const active = Reward(
      id: '2',
      title: '双倍 XP 卡',
      cost: 200,
      category: 'effect',
      effectType: 'xp_boost',
      effectValue: '2.0',
      isSystem: true,
    );

    expect(RewardController.isDeprecatedSystemReward(deprecated), isTrue);
    expect(RewardController.isDeprecatedSystemReward(active), isFalse);
  });

  test('isDeprecatedSystemReward 不会误伤新的低价系统日常奖励', () {
    const dailyReward = Reward(
      id: 'daily-1',
      title: '听一首歌',
      cost: 1,
      description: '安静听完一首喜欢的歌',
      category: 'custom',
      isSystem: true,
    );

    expect(RewardController.isDeprecatedSystemReward(dailyReward), isFalse);
  });

  test('isSupportedSystemReward 只保留日常奖励型系统商品', () {
    const dailyReward = Reward(
      id: 'daily-1',
      title: '喝杯奶茶',
      cost: 50,
      category: 'custom',
      isSystem: true,
    );
    const effectReward = Reward(
      id: 'effect-1',
      title: '双倍 XP 卡',
      cost: 200,
      category: 'effect',
      effectType: 'xp_boost',
      effectValue: '2.0',
      isSystem: true,
    );
    const cosmeticReward = Reward(
      id: 'cosmetic-1',
      title: '金色边框',
      cost: 1000,
      category: 'cosmetic',
      effectType: 'card_border',
      effectValue: 'gold',
      isSystem: true,
    );

    expect(RewardController.isSupportedSystemReward(dailyReward), isTrue);
    expect(RewardController.isSupportedSystemReward(effectReward), isFalse);
    expect(RewardController.isSupportedSystemReward(cosmeticReward), isFalse);
  });
  test('localizedSystemRewardTitle returns English copy for known system reward',
      () {
    const reward = Reward(
      id: 'daily-1',
      title: '鍚竴棣栨瓕',
      cost: 1,
      description: '瀹夐潤鍚畬涓€棣栧枩娆㈢殑姝?,
      category: 'custom',
      isSystem: true,
    );

    expect(
      RewardController.localizedSystemRewardTitle(
        reward,
        languageCode: 'en',
      ),
      'Listen to One Song',
    );
    expect(
      RewardController.localizedSystemRewardDescription(
        reward,
        languageCode: 'en',
      ),
      'Give yourself a few quiet minutes to listen through one favorite song.',
    );
  });

  test('localizedSystemRewardTitle keeps custom rewards unchanged', () {
    const reward = Reward(
      id: 'custom-1',
      title: 'Buy fresh flowers',
      cost: 30,
      description: 'Pick something bright for the desk.',
      category: 'custom',
      isSystem: false,
    );

    expect(
      RewardController.localizedSystemRewardTitle(
        reward,
        languageCode: 'en',
      ),
      reward.title,
    );
    expect(
      RewardController.localizedSystemRewardDescription(
        reward,
        languageCode: 'en',
      ),
      reward.description,
    );
  });
}
