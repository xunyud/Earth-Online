import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/services/preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetCache();
  });

  test('app locale defaults to zh and can persist en', () async {
    final initial = await PreferencesService.appLocale();
    expect(initial, 'zh');

    await PreferencesService.setAppLocale('en');

    final next = await PreferencesService.appLocale();
    expect(next, 'en');
  });

  test('guide bootstrap date can be stored and cleared', () async {
    final initial = await PreferencesService.guideLastBootstrapDate();
    expect(initial, isNull);

    await PreferencesService.setGuideLastBootstrapDate('2026-03-13');
    final stored = await PreferencesService.guideLastBootstrapDate();
    expect(stored, '2026-03-13');

    await PreferencesService.clearGuideLastBootstrapDate();
    final cleared = await PreferencesService.guideLastBootstrapDate();
    expect(cleared, isNull);
  });

  test('guide switches default to enabled and can be turned off', () async {
    final guideEnabled = await PreferencesService.guideEnabled();
    final proactiveEnabled = await PreferencesService.guideProactiveEnabled();
    expect(guideEnabled, isTrue);
    expect(proactiveEnabled, isTrue);

    await PreferencesService.setGuideEnabled(false);
    await PreferencesService.setGuideProactiveEnabled(false);

    final guideEnabledAfter = await PreferencesService.guideEnabled();
    final proactiveEnabledAfter =
        await PreferencesService.guideProactiveEnabled();
    expect(guideEnabledAfter, isFalse);
    expect(proactiveEnabledAfter, isFalse);
  });

  test('guide display name defaults to null and can persist', () async {
    final initial = await PreferencesService.guideDisplayName();
    expect(initial, isNull);

    await PreferencesService.setGuideDisplayName('  小忆  ');
    final stored = await PreferencesService.guideDisplayName();
    expect(stored, '小忆');

    await PreferencesService.setGuideDisplayName('');
    final cleared = await PreferencesService.guideDisplayName();
    expect(cleared, isNull);
  });

  test('profile data defaults to null and can persist', () async {
    final initialDisplayName = await PreferencesService.profileDisplayName();
    final initialAvatar = await PreferencesService.profileAvatarBase64();
    expect(initialDisplayName, isNull);
    expect(initialAvatar, isNull);

    await PreferencesService.setProfileDisplayName('  森林旅人  ');
    await PreferencesService.setProfileAvatarBase64('  avatar-base64  ');

    final storedDisplayName = await PreferencesService.profileDisplayName();
    final storedAvatar = await PreferencesService.profileAvatarBase64();
    expect(storedDisplayName, '森林旅人');
    expect(storedAvatar, 'avatar-base64');

    await PreferencesService.setProfileDisplayName(null);
    await PreferencesService.setProfileAvatarBase64('');

    final clearedDisplayName = await PreferencesService.profileDisplayName();
    final clearedAvatar = await PreferencesService.profileAvatarBase64();
    expect(clearedDisplayName, isNull);
    expect(clearedAvatar, isNull);
  });
}
