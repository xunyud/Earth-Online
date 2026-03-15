import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/reward/models/reward.dart';

void main() {
  test('Reward.fromJson 对非字符串字段具备容错能力', () {
    final reward = Reward.fromJson({
      'id': 123,
      'title': 456,
      'cost': '88',
      'description': 789,
      'category': null,
      'effect_type': null,
      'effect_value': 2.0,
      'is_system': true,
    });

    expect(reward.id, '123');
    expect(reward.title, '456');
    expect(reward.cost, 88);
    expect(reward.description, '789');
    expect(reward.category, 'custom');
    expect(reward.effectType, isNull);
    expect(reward.effectValue, '2.0');
    expect(reward.isSystem, isTrue);
  });

  test('Reward.fromJson 在空值输入下返回安全默认值', () {
    final reward = Reward.fromJson(const <String, dynamic>{});

    expect(reward.id, isEmpty);
    expect(reward.title, isEmpty);
    expect(reward.cost, 0);
    expect(reward.category, 'custom');
    expect(reward.isSystem, isFalse);
  });
}
