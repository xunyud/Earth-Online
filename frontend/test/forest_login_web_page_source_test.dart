import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web forest login bridge does not discard iframe auth messages by source identity', () async {
    final content =
        await File('lib/features/auth/screens/forest_login_web_page_web.dart')
            .readAsString();

    expect(
      content.contains('case \'guest\':') &&
          content.contains('case \'sendOtp\':') &&
          content.contains('case \'login\':') &&
          !content.contains('event.source != _iframe.contentWindow'),
      isTrue,
      reason:
          'The web auth bridge must keep handling guest, otp, and login actions even when iframe source identity does not compare equal.',
    );
  });
}
