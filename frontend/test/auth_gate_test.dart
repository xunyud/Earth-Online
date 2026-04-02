import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  test('shows home when a session exists', () {
    expect(shouldShowHomeForSession(hasSession: true), isTrue);
  });

  test('stays on login when no session exists', () {
    expect(shouldShowHomeForSession(hasSession: false), isFalse);
  });

  test('web builds use the latest forest login experience', () {
    expect(
      shouldUseForestLoginExperience(
        isWeb: true,
        platform: TargetPlatform.windows,
      ),
      isTrue,
    );
  });

  test('Windows desktop keeps the forest webview login experience', () {
    expect(
      shouldUseForestLoginExperience(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      isTrue,
    );
  });

  test('non-Windows native platforms fall back to the Flutter login screen', () {
    expect(
      shouldUseForestLoginExperience(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
  });
}
