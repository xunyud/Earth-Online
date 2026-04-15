import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text styles declare locale-aware latin and CJK font stacks', () async {
    final source =
        await File('lib/core/constants/app_text_styles.dart').readAsString();

    expect(source, contains('englishFontFamily'));
    expect(source, contains('chineseFontFamily'));
    expect(source, contains('englishFontFamilyFallback'));
    expect(source, contains('chineseFontFamilyFallback'));
    expect(source, contains("'Segoe UI'"));
    expect(source, contains("'Noto Sans SC'"));
    expect(source, contains("'PingFang SC'"));
    expect(source, contains("'Microsoft YaHei'"));
  });

  test('app theme applies locale-aware fallback fonts to text themes',
      () async {
    final source = await File('lib/main.dart').readAsString();

    expect(
      source,
      contains('AppTextStyles.applyFontFallback('),
    );
    expect(source, contains('isEnglish: _localeController.isEnglish'));
    expect(
      source,
      contains('baseTheme.primaryTextTheme'),
    );
  });

  test('stats text styles reuse shared locale-aware font helper', () async {
    final source = await File('lib/features/stats/theme/stats_text_styles.dart')
        .readAsString();

    expect(source, contains('static TextStyle get heroValue'));
    expect(source, contains('AppTextStyles.withFontFallback'));
  });
}
