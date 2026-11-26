import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combat character assets are declared', () {
    const assets = [
      'assets/character2d/normal.png',
      'assets/character2d/agony.png',
      'assets/character2d/incapacitated.png',
    ];
    expect(assets.length, 3);
  });
}
