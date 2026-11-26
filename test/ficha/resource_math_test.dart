import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/utils/resource_math.dart';

void main() {
  test('dano reduz vida automaticamente', () {
    expect(applyResourceDelta(current: 20, maximum: 20, delta: -15), 5);
  });

  test('dano nunca deixa vida negativa', () {
    expect(applyResourceDelta(current: 8, maximum: 20, delta: -20), 0);
  });

  test('cura respeita vida máxima', () {
    expect(applyResourceDelta(current: 15, maximum: 20, delta: 10), 20);
  });
}
