import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guide controller keeps generated guide copy locale-aware', () async {
    final source = await File('lib/features/quest/controllers/guide_controller.dart')
        .readAsString();

    expect(source, contains("normalized == 'yes'"));
    expect(source, contains("normalized == 'cancel'"));
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
