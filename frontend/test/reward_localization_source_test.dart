import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system reward localization catalog exposes English reward copy', () async {
    final source =
        await File('lib/features/reward/models/system_reward_catalog.dart')
            .readAsString();

    expect(source, contains('listen_song'));
    expect(source, contains('Listen to One Song'));
    expect(source, contains('Take a 20-Minute Walk'));
    expect(source, contains('Buy a Cup of Favorite Drink'));
  });

  test('reward shop renders localized system reward title and description', () async {
    final source =
        await File('lib/features/reward/screens/reward_shop_page.dart')
            .readAsString();

    expect(source, contains('reward.localizedTitle(context.isEnglish)'));
    expect(
      source,
      contains('reward.localizedDescription(context.isEnglish)'),
    );
  });

  test('inventory renders localized reward titles for system rewards', () async {
    final source =
        await File('lib/features/reward/screens/inventory_page.dart')
            .readAsString();

    expect(source, contains('item.localizedRewardTitle(context.isEnglish)'));
  });
}
