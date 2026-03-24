import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RewardShopPage 会渲染标题卡切换与滑动分页', () async {
    final source =
        await File('lib/features/reward/screens/reward_shop_page.dart')
            .readAsString();

    expect(source, contains("context.tr('shop.system_title')"));
    expect(source, contains("context.tr('shop.custom_title')"));
    expect(source, contains('PageController'));
    expect(source, contains('PageView('));
    expect(source, contains('_buildShopSwitcher('));
    expect(source, contains('_selectedTab'));
  });

  test('RewardShopPage 的系统商品页不带删除入口', () async {
    final source =
        await File('lib/features/reward/screens/reward_shop_page.dart')
            .readAsString();

    expect(source, contains('_buildSystemRewardActions('));
    expect(
      source.contains('_buildSystemRewardActions(') &&
          !source.contains('_buildSystemRewardActions(theme, r, deleting)'),
      isTrue,
      reason: '系统商品区域应只有兑换行为，不应复用带删除按钮的动作区。',
    );
  });

  test('RewardShopPage 的自定义奖励页继续保留删除入口', () async {
    final source =
        await File('lib/features/reward/screens/reward_shop_page.dart')
            .readAsString();

    expect(source, contains('_buildCustomRewardActions('));
    expect(source, contains('Icons.delete_outline_rounded'));
    expect(source, contains('_deleteReward(reward)'));
  });

  test('RewardShopPage 的兑换按钮使用高对比样式', () async {
    final source =
        await File('lib/features/reward/screens/reward_shop_page.dart')
            .readAsString();

    expect(source, contains('_buildRedeemButtonStyle('));
    expect(source, contains('foregroundColor: Colors.white'));
    expect(
        source, contains('disabledForegroundColor: AppColors.textSecondary'));
  });

  test('RewardShopPage 的标题切换条使用细长磨砂玻璃分段样式', () async {
    final source =
        await File('lib/features/reward/screens/reward_shop_page.dart')
            .readAsString();

    expect(source, contains('BackdropFilter'));
    expect(source, contains('ImageFilter.blur'));
    expect(source, contains('BorderRadius.zero'));
    expect(source, contains('width: 1'));
  });
}
