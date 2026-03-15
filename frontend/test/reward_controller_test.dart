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
}
