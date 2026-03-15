import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('设置面板改为浅色卡片结构且不再暴露黑暗模式入口', () async {
    final homePage =
        await File('lib/features/quest/screens/home_page.dart').readAsString();
    final localeFile =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(
      homePage.contains('_SettingsSectionCard(') &&
          homePage.contains('_SettingsChoicePill(') &&
          homePage.contains("['forest_adventure', 'default']") &&
          !homePage.contains("['forest_adventure', 'default', 'dark_souls']") &&
          !localeFile.contains('settings.theme.dark'),
      isTrue,
      reason: '设置页应只保留浅色主题方案，并改成新的卡片式结构。',
    );
  });
}
