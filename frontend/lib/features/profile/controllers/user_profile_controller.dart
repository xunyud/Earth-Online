import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/preferences_service.dart';

typedef ProfileDisplayNameReader = Future<String?> Function();
typedef ProfileDisplayNameWriter = Future<void> Function(String? value);
typedef ProfileAvatarReader = Future<String?> Function();
typedef ProfileAvatarWriter = Future<void> Function(String? value);

class UserProfileController extends ChangeNotifier {
  UserProfileController({
    required String? email,
    ProfileDisplayNameReader? readDisplayName,
    ProfileDisplayNameWriter? writeDisplayName,
    ProfileAvatarReader? readAvatarBase64,
    ProfileAvatarWriter? writeAvatarBase64,
  })  : _email = email?.trim(),
        _readDisplayName =
            readDisplayName ?? PreferencesService.profileDisplayName,
        _writeDisplayName =
            writeDisplayName ?? PreferencesService.setProfileDisplayName,
        _readAvatarBase64 =
            readAvatarBase64 ?? PreferencesService.profileAvatarBase64,
        _writeAvatarBase64 =
            writeAvatarBase64 ?? PreferencesService.setProfileAvatarBase64;

  @visibleForTesting
  factory UserProfileController.test({
    required String? email,
    required ProfileDisplayNameReader readDisplayName,
    required ProfileDisplayNameWriter writeDisplayName,
    required ProfileAvatarReader readAvatarBase64,
    required ProfileAvatarWriter writeAvatarBase64,
  }) {
    return UserProfileController(
      email: email,
      readDisplayName: readDisplayName,
      writeDisplayName: writeDisplayName,
      readAvatarBase64: readAvatarBase64,
      writeAvatarBase64: writeAvatarBase64,
    );
  }

  final String? _email;
  final ProfileDisplayNameReader _readDisplayName;
  final ProfileDisplayNameWriter _writeDisplayName;
  final ProfileAvatarReader _readAvatarBase64;
  final ProfileAvatarWriter _writeAvatarBase64;

  String? _displayName;
  String? _avatarBase64;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  String get email => _email ?? '';

  String get displayName {
    final customDisplayName = _displayName?.trim() ?? '';
    if (customDisplayName.isNotEmpty) {
      return customDisplayName;
    }

    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return '';
    }

    final emailPrefix = normalizedEmail.split('@').first.trim();
    if (emailPrefix.isNotEmpty) {
      return emailPrefix;
    }
    return normalizedEmail;
  }

  String? get avatarBase64 {
    final normalized = _normalizeValue(_avatarBase64);
    return normalized;
  }

  Uint8List? get avatarBytes {
    final normalized = avatarBase64;
    if (normalized == null) {
      return null;
    }

    try {
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final nextDisplayName = await _readDisplayName();
    final nextAvatar = await _readAvatarBase64();
    _displayName = _normalizeValue(nextDisplayName);
    _avatarBase64 = _normalizeValue(nextAvatar);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateDisplayName(String value) async {
    final normalized = _normalizeValue(value);
    if (_displayName == normalized) {
      return;
    }
    _displayName = normalized;
    notifyListeners();
    await _writeDisplayName(normalized);
  }

  Future<void> updateAvatarBase64(String? value) async {
    final normalized = _normalizeValue(value);
    if (_avatarBase64 == normalized) {
      return;
    }
    _avatarBase64 = normalized;
    notifyListeners();
    await _writeAvatarBase64(normalized);
  }

  static String? _normalizeValue(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
