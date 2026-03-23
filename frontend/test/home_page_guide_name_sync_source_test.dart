import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GuideService 会把已有本地向导名字补写到服务端', () async {
    final source = await File(
      'lib/core/services/guide_service.dart',
    ).readAsString();

    expect(
      source,
      contains("if (normalizedLocal != null) 'display_name': normalizedLocal,"),
    );
  });

  test('HomePage 会将本地向导名字与服务端同步', () async {
    final source = await File(
      'lib/features/quest/screens/home_page.dart',
    ).readAsString();

    expect(
      source,
      contains('_guideService.resolveDisplayName(localFallback: stored)'),
    );
    expect(
        source, contains('await _guideService.saveDisplayName(normalized);'));
  });
}
