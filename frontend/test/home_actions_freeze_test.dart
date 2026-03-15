import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home app bar actions order stays frozen', () async {
    final file = File('lib/features/quest/screens/home_page.dart');
    final content = await file.readAsString();

    const iconsInOrder = <String>[
      'Icons.smart_toy_rounded',
      'Icons.auto_awesome_rounded',
      'Icons.cloud_upload_rounded',
      'Icons.bar_chart_rounded',
      'Icons.emoji_events_rounded',
      'Icons.shopping_bag_rounded',
      'Icons.backpack_rounded',
      'Icons.delete_sweep_rounded',
    ];

    var cursor = 0;
    for (final icon in iconsInOrder) {
      final next = content.indexOf(icon, cursor);
      expect(
        next >= 0,
        isTrue,
        reason: 'Missing frozen icon in app bar actions: $icon',
      );
      cursor = next + icon.length;
    }
  });
}
