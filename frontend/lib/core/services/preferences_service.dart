import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyHideShopDeleteConfirm = 'hide_shop_delete_confirm';
  static bool? _cachedHideShopDeleteConfirm;

  static const String _keySelectedTheme = 'selected_theme';
  static String? _cachedSelectedTheme;

  static const String _keyAppLocale = 'app_locale';
  static String? _cachedAppLocale;

  static const String _keyGuideEnabled = 'guide_enabled';
  static bool? _cachedGuideEnabled;

  static const String _keyGuideProactiveEnabled = 'guide_proactive_enabled';
  static bool? _cachedGuideProactiveEnabled;

  static const String _keyGuideLastBootstrapDate = 'guide_last_bootstrap_date';
  static String? _cachedGuideLastBootstrapDate;

  static const String _keyGuideDisplayName = 'guide_display_name';
  static String? _cachedGuideDisplayName;

  static const String _keyGuideOnboardingSeenUserId =
      'guide_onboarding_seen_user_id';
  static String? _cachedGuideOnboardingSeenUserId;

  static const String _keyCoachMarksSeenUserId = 'coach_marks_seen_user_id';
  static String? _cachedCoachMarksSeenUserId;

  static const String _keyProfileDisplayName = 'profile_display_name';
  static String? _cachedProfileDisplayName;

  static const String _keyProfileAvatarBase64 = 'profile_avatar_base64';
  static String? _cachedProfileAvatarBase64;

  static Future<bool> hideShopDeleteConfirm() async {
    final cached = _cachedHideShopDeleteConfirm;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_keyHideShopDeleteConfirm) ?? false;
    _cachedHideShopDeleteConfirm = value;
    return value;
  }

  static Future<void> setHideShopDeleteConfirm(bool value) async {
    _cachedHideShopDeleteConfirm = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideShopDeleteConfirm, value);
  }

  static Future<String> selectedTheme() async {
    final cached = _cachedSelectedTheme;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keySelectedTheme) ?? 'forest_adventure';
    _cachedSelectedTheme = value;
    return value;
  }

  static Future<void> setSelectedTheme(String value) async {
    _cachedSelectedTheme = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedTheme, value);
  }

  static Future<String> appLocale() async {
    final cached = _cachedAppLocale;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyAppLocale) ?? 'zh';
    _cachedAppLocale = value;
    return value;
  }

  static Future<void> setAppLocale(String languageCode) async {
    _cachedAppLocale = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLocale, languageCode);
  }

  static Future<bool> guideEnabled() async {
    final cached = _cachedGuideEnabled;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_keyGuideEnabled) ?? true;
    _cachedGuideEnabled = value;
    return value;
  }

  static Future<void> setGuideEnabled(bool value) async {
    _cachedGuideEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGuideEnabled, value);
  }

  static Future<bool> guideProactiveEnabled() async {
    final cached = _cachedGuideProactiveEnabled;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_keyGuideProactiveEnabled) ?? true;
    _cachedGuideProactiveEnabled = value;
    return value;
  }

  static Future<void> setGuideProactiveEnabled(bool value) async {
    _cachedGuideProactiveEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGuideProactiveEnabled, value);
  }

  static Future<String?> guideLastBootstrapDate() async {
    final cached = _cachedGuideLastBootstrapDate;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyGuideLastBootstrapDate);
    _cachedGuideLastBootstrapDate = value;
    return value;
  }

  static Future<void> setGuideLastBootstrapDate(String dateId) async {
    _cachedGuideLastBootstrapDate = dateId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGuideLastBootstrapDate, dateId);
  }

  static Future<void> clearGuideLastBootstrapDate() async {
    _cachedGuideLastBootstrapDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGuideLastBootstrapDate);
  }

  static Future<String?> guideDisplayName() async {
    final cached = _cachedGuideDisplayName;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyGuideDisplayName);
    _cachedGuideDisplayName = value;
    return value;
  }

  static Future<void> setGuideDisplayName(String? value) async {
    final normalized = _normalizeOptionalString(value);
    _cachedGuideDisplayName = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_keyGuideDisplayName);
      return;
    }
    await prefs.setString(_keyGuideDisplayName, normalized);
  }

  static Future<String?> guideOnboardingSeenUserId() async {
    final cached = _cachedGuideOnboardingSeenUserId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyGuideOnboardingSeenUserId);
    _cachedGuideOnboardingSeenUserId = value;
    return value;
  }

  static Future<void> setGuideOnboardingSeenUserId(String? value) async {
    final normalized = _normalizeOptionalString(value);
    _cachedGuideOnboardingSeenUserId = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_keyGuideOnboardingSeenUserId);
      return;
    }
    await prefs.setString(_keyGuideOnboardingSeenUserId, normalized);
  }

  static Future<String?> coachMarksSeenUserId() async {
    final cached = _cachedCoachMarksSeenUserId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyCoachMarksSeenUserId);
    _cachedCoachMarksSeenUserId = value;
    return value;
  }

  static Future<void> setCoachMarksSeenUserId(String? value) async {
    final normalized = _normalizeOptionalString(value);
    _cachedCoachMarksSeenUserId = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_keyCoachMarksSeenUserId);
      return;
    }
    await prefs.setString(_keyCoachMarksSeenUserId, normalized);
  }

  static Future<String?> profileDisplayName() async {
    final cached = _cachedProfileDisplayName;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyProfileDisplayName);
    _cachedProfileDisplayName = value;
    return value;
  }

  static Future<void> setProfileDisplayName(String? value) async {
    final normalized = _normalizeOptionalString(value);
    _cachedProfileDisplayName = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_keyProfileDisplayName);
      return;
    }
    await prefs.setString(_keyProfileDisplayName, normalized);
  }

  static Future<String?> profileAvatarBase64() async {
    final cached = _cachedProfileAvatarBase64;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyProfileAvatarBase64);
    _cachedProfileAvatarBase64 = value;
    return value;
  }

  static Future<void> setProfileAvatarBase64(String? value) async {
    final normalized = _normalizeOptionalString(value);
    _cachedProfileAvatarBase64 = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_keyProfileAvatarBase64);
      return;
    }
    await prefs.setString(_keyProfileAvatarBase64, normalized);
  }

  static String? _normalizeOptionalString(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  @visibleForTesting
  static void resetCache() {
    _cachedHideShopDeleteConfirm = null;
    _cachedSelectedTheme = null;
    _cachedAppLocale = null;
    _cachedGuideEnabled = null;
    _cachedGuideProactiveEnabled = null;
    _cachedGuideLastBootstrapDate = null;
    _cachedGuideDisplayName = null;
    _cachedGuideOnboardingSeenUserId = null;
    _cachedCoachMarksSeenUserId = null;
    _cachedProfileDisplayName = null;
    _cachedProfileAvatarBase64 = null;
  }
}
