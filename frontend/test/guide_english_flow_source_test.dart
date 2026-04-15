import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomePage 会把当前语言放进 guide client context', () async {
    final source = await File(
      'lib/features/quest/screens/home_page.dart',
    ).readAsString();

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
  });

  test('HomePage 首次 bootstrap 会把语言上下文传给 guide 服务', () async {
    final source = await File(
      'lib/features/quest/screens/home_page.dart',
    ).readAsString();

    expect(
      source,
      contains("await _guideService.bootstrap("),
    );
    expect(
      source,
      contains("clientContext: _buildGuideClientContext()"),
    );
  });

  test('QuickAddBar 的语音识别 locale 会跟随当前语言', () async {
    final source = await File(
      'lib/features/quest/widgets/quick_add_bar.dart',
    ).readAsString();

    expect(
      source,
      contains("localeId: context.isEnglish ? 'en_US' : 'zh_CN'"),
    );
  });
}
