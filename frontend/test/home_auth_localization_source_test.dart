import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home page keeps generated guide copy locale-aware', () async {
    final source =
        await File('lib/features/quest/screens/home_page.dart').readAsString();

    expect(source, contains("'+\${event.rewardGold} gold'"));
    expect(source, contains('Stand up and stretch for 5 minutes'));
    expect(source, contains("normalized == 'yes'"));
    expect(source, contains("normalized == 'cancel'"));
    expect(source, contains("'I want to keep talking.'"));
    expect(source, contains("\${_controller.longestStreak} days"));
    expect(source, contains('required bool isEnglish'));
    expect(source, contains('isEnglish: context.isEnglish'));
  });

  test('login screen drives language toggle labels from localized auth copy',
      () async {
    final source = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(source, contains('chineseLabel: copy.chineseLanguageLabel'));
    expect(source, contains('englishLabel: copy.englishLanguageLabel'));
    expect(
        source, contains("_languageLabel('auth.language.chinese', 'Chinese')"));
    expect(
        source, contains("_languageLabel('auth.language.english', 'English')"));
  });
}
