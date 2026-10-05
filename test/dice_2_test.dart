import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Dice 2.0 damage expressions supported', () {
    final exp = RegExp(r'^(\d*)d(\d+)([+-]\d+)?$');
    expect(exp.hasMatch('1d8'), isTrue);
    expect(exp.hasMatch('2d6+3'), isTrue);
  });
}
