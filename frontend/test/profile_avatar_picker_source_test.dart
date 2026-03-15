import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('头像选择服务使用文件选择器而不是 image_picker', () async {
    final source =
        await File('lib/features/profile/services/profile_avatar_picker.dart')
            .readAsString();

    expect(
      source.contains("package:file_picker/file_picker.dart") &&
          source.contains('FilePicker.platform.pickFiles(') &&
          !source.contains("package:image_picker/image_picker.dart"),
      isTrue,
      reason: '桌面端头像上传应直接走文件选择器，避免 image_picker 桌面链路不稳定。',
    );
  });
}
