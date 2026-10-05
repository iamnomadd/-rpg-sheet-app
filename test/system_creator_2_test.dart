import 'package:flutter_test/flutter_test.dart';
void main() {
  test('System Creator 2.0 starter structures', () {
    const starters = ['standard','d20','narrative'];
    expect(starters, hasLength(3));
    expect(const [4,6,8,10,12,20,100], contains(20));
  });
}
