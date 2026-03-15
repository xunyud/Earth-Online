import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PreferencesService 提供昵称与头像资料存储接口', () async {
    final source =
        await File('lib/core/services/preferences_service.dart').readAsString();

    expect(
      source.contains("_keyProfileDisplayName = 'profile_display_name'") &&
          source.contains('profileDisplayName()') &&
          source.contains('setProfileDisplayName(') &&
          source
              .contains("_keyProfileAvatarBase64 = 'profile_avatar_base64'") &&
          source.contains('profileAvatarBase64()') &&
          source.contains('setProfileAvatarBase64('),
      isTrue,
      reason: '抽屉个人资料编辑需要稳定的昵称与头像本地读写接口。',
    );
  });
}
