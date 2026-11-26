import 'package:flutter_test/flutter_test.dart';

void main() {
  test('former Actions modules are part of Em Cena reorder model', () {
    const visibleEmCenaModules = [
      'combatCharacter',
      'health',
      'energy',
      'conditions',
      'quickActions',
      'attributes',
      'skillTree',
      'abilities',
      'inventory',
    ];
    expect(visibleEmCenaModules, contains('combatCharacter'));
    expect(visibleEmCenaModules, contains('conditions'));
    expect(visibleEmCenaModules, contains('quickActions'));
  });
}
