import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/quest/screens/home_page.dart';

void main() {
  test('HomePage 向导改版相关代码可以通过编译导入', () {
    expect(const HomePage(), isA<HomePage>());
  });
}
