import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDrawer 资料头部仅保留昵称编辑入口，头像点击直接触发修改', () async {
    final source =
        await File('lib/core/widgets/app_drawer.dart').readAsString();

    expect(
      source.contains('Icons.edit_rounded') &&
          source.contains("drawer.profile.edit_name") &&
          !source.contains("drawer.profile.badge") &&
          !source.contains("drawer.profile.change_avatar") &&
          source.contains('onTap: _handleAvatarChange'),
      isTrue,
      reason: '抽屉资料头部应删除本地资料标签和重复头像入口，点击头像本身即可修改。',
    );
  });
}
