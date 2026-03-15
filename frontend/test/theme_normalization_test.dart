import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  test('旧的 dark_souls 配置会被归一化到森林主题', () {
    expect(normalizeThemeId('dark_souls'), 'forest_adventure');
  });

  test('合法浅色主题会原样保留，未知主题回退到森林主题', () {
    expect(normalizeThemeId('default'), 'default');
    expect(normalizeThemeId('forest_adventure'), 'forest_adventure');
    expect(normalizeThemeId('unknown_theme'), 'forest_adventure');
  });
}
