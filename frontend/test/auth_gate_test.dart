import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  test('有会话时应进入主页', () {
    expect(shouldShowHomeForSession(hasSession: true), isTrue);
  });

  test('无会话时应停留登录页', () {
    expect(shouldShowHomeForSession(hasSession: false), isFalse);
  });
}
