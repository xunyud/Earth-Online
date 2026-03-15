import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/controllers/user_profile_controller.dart';

void main() {
  test('用户资料控制层会回退到邮箱名并支持保存昵称', () async {
    String? storedDisplayName;
    String? storedAvatarBase64;
    final controller = UserProfileController.test(
      email: 'forest.hero@qq.com',
      readDisplayName: () async => storedDisplayName,
      writeDisplayName: (value) async {
        storedDisplayName = value;
      },
      readAvatarBase64: () async => storedAvatarBase64,
      writeAvatarBase64: (value) async {
        storedAvatarBase64 = value;
      },
    );

    await controller.load();
    expect(controller.displayName, 'forest.hero');

    await controller.updateDisplayName('  森林旅人  ');
    expect(controller.displayName, '森林旅人');
    expect(storedDisplayName, '森林旅人');

    await controller.updateDisplayName('   ');
    expect(controller.displayName, 'forest.hero');
    expect(storedDisplayName, isNull);
  });

  test('用户资料控制层会解码并清空头像数据', () async {
    String? storedDisplayName;
    String? storedAvatarBase64 = base64Encode(Uint8List.fromList([1, 2, 3]));
    final controller = UserProfileController.test(
      email: 'forest.hero@qq.com',
      readDisplayName: () async => storedDisplayName,
      writeDisplayName: (value) async {
        storedDisplayName = value;
      },
      readAvatarBase64: () async => storedAvatarBase64,
      writeAvatarBase64: (value) async {
        storedAvatarBase64 = value;
      },
    );

    await controller.load();
    expect(controller.avatarBytes, Uint8List.fromList([1, 2, 3]));

    await controller.updateAvatarBase64(null);
    expect(controller.avatarBytes, isNull);
    expect(storedAvatarBase64, isNull);
  });
}
