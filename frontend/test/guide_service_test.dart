import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/guide_service.dart';

void main() {
  test('GuidePortraitResult.fromMap 兼容多种图片地址字段', () {
    final portrait = GuidePortraitResult.fromMap(const {
      'imageUrl': 'https://example.com/camel-case.png',
      'model': 'flux',
      'seed': 7,
      'style': 'ink',
      'summary': '画像摘要',
      'memory_refs': ['m1'],
    });

    expect(portrait.imageUrl, 'https://example.com/camel-case.png');
    expect(portrait.model, 'flux');
    expect(portrait.seed, 7);
    expect(portrait.style, 'ink');
    expect(portrait.memoryRefs, ['m1']);
  });

  test('GuidePortraitResult.fromMap 在主字段缺失时回退到 url', () {
    final portrait = GuidePortraitResult.fromMap(const {
      'url': 'https://example.com/fallback.png',
      'summary': '回退地址',
    });

    expect(portrait.imageUrl, 'https://example.com/fallback.png');
  });
}
