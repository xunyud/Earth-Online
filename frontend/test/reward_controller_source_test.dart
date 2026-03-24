import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RewardController 会在缺少日常奖励时补写兜底商品', () async {
    final source = await File(
      'lib/features/reward/controllers/reward_controller.dart',
    ).readAsString();

    expect(source, contains('_ensureDailySystemRewardsFallback('));
    expect(source, contains(".from('rewards').insert("));
    expect(source, contains('_isDailySystemShopReward('));
  });
}
