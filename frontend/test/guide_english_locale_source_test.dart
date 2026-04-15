import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomePage passes locale context into guide bootstrap and chat', () async {
    final source =
        await File('lib/features/quest/screens/home_page.dart').readAsString();

    expect(
      source,
      contains(
        "'language_code': AppLocaleController.instance.locale.languageCode",
      ),
    );
    expect(
      source,
      contains("'is_english': AppLocaleController.instance.isEnglish"),
    );
    expect(
      source,
      contains("final result = await _guideService.bootstrap("),
    );
    expect(
      source,
      contains("clientContext: _buildGuideClientContext(),"),
    );
    expect(
      source,
      contains('clientContext: _buildGuideClientContext(),'),
    );
  });

  test('QuickAddBar speech locale follows the app language', () async {
    final source =
        await File('lib/features/quest/widgets/quick_add_bar.dart')
            .readAsString();

    expect(
      source,
      contains("localeId: context.isEnglish ? 'en_US' : 'zh_CN'"),
    );
  });
}
