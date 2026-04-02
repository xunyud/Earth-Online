import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login screen keeps the forest scene layers and intro transitions', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      content.contains('ParallaxBackground(') &&
          content.contains('ForestAtmosphere()') &&
          content.contains('ForestParticles()') &&
          content.contains('FadeTransition(') &&
          content.contains('SlideTransition(') &&
          content.contains('ScaleTransition('),
      isTrue,
      reason: 'The anonymous web login must render the forest scene with the existing intro transitions.',
    );
  });

  test('login screen keeps sign-in and sign-up labels in the auth copy', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      content.contains("String get signInLabel =>") &&
          content.contains("String get signUpLabel =>") &&
          content.contains("Welcome to Earth Online"),
      isTrue,
      reason: 'The login screen copy should keep explicit sign-in and sign-up labels plus the welcome title.',
    );
  });

  test('login screen keeps account creation and continue actions', () async {
    final content = await File('lib/features/auth/screens/login_screen.dart')
        .readAsString();

    expect(
      content.contains('Create account') && content.contains('Continue'),
      isTrue,
      reason: 'The auth flow should continue to expose account creation and continue actions.',
    );
  });
}
