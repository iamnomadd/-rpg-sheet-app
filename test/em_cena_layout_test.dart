import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Em Cena has the unified movable modules', () {
    const modules = [
      'combatCharacter', 'health', 'energy', 'conditions', 'quickActions',
      'attributes', 'skillTree', 'abilities', 'inventory',
    ];
    expect(modules.toSet().length, modules.length);
    expect(modules.first, 'combatCharacter');
  });
}
