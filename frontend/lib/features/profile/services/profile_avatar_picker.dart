import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

class ProfileAvatarPicker {
  const ProfileAvatarPicker();

  Future<String?> pickAvatarBase64() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return null;
    }
    if (bytes.isEmpty) {
      return null;
    }
    return encodeAvatar(bytes);
  }

  static Future<String?> encodeAvatar(
    Uint8List bytes, {
    int targetSize = 256,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetSize,
      targetHeight: targetSize,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      return null;
    }
    return base64Encode(byteData.buffer.asUint8List());
  }
}
