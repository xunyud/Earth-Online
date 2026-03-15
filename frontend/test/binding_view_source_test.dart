import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binding view keeps the new quest layout structure', () async {
    final content = await File('lib/features/binding/screens/binding_view.dart')
        .readAsString();

    expect(
      content.contains("Key('binding-hero-card')") &&
          content.contains("Key('binding-main-panel')") &&
          content.contains("Key('binding-guide-rail')") &&
          content.contains("Key('binding-code-card')") &&
          content.contains("Key('binding-action-card')") &&
          content.contains('_BindingHeroCard(') &&
          content.contains('_BindingGuideRail('),
      isTrue,
      reason:
          'The binding page should keep the new hero, content panel, and guide rail layout.',
    );
  });

  test('binding view keeps the refreshed binding flow copy and actions',
      () async {
    final content = await File('lib/features/binding/screens/binding_view.dart')
        .readAsString();

    expect(
      content.contains(r"'\u7ed1\u5b9a\u5fae\u4fe1'") &&
          content.contains(r"'\u751f\u6210\u9a8c\u8bc1\u7801'") &&
          content.contains(r"'\u89e3\u9664\u7ed1\u5b9a'") &&
          content.contains('showConfirmDialog(') &&
          content.contains('_generateCode()') &&
          content.contains('_unbind()'),
      isTrue,
      reason:
          'The binding page should keep the refreshed copy and the bind/unbind actions.',
    );
  });
}
