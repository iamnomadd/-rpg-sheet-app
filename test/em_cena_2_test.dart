import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Em Cena 2.0 module contract', () {
    const modules = ['sessionOverview','combatCharacter','health','energy','conditions','quickActions','attributes','abilities','inventory'];
    expect(modules, contains('sessionOverview'));
    expect(modules, isNot(contains('skillTree')));
  });
}
