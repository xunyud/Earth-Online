import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'settings locale entries stay readable and do not degrade to placeholders',
      () async {
    final content =
        await File('lib/core/i18n/app_locale_controller.dart').readAsString();

    expect(content, contains("'settings.subtitle'"));
    expect(content, contains("'settings.section.guide_desc'"));
    expect(content, contains("'settings.theme.forest'"));
    expect(content, contains("'settings.lang.zh'"));
    expect(content, contains("'settings.saved'"));
    expect(content, isNot(contains("'settings.title': {'zh': '????'")));
    expect(content, isNot(contains("'settings.theme.forest': {'zh': '????'")));
    expect(content, isNot(contains("'settings.lang.zh': {'zh': '??'")));
  });
}
