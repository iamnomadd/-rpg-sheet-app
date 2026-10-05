import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Inventory 2.0 categories', () {
    const categories = ['Arma','Armadura','Consumível','Munição','Acessório','Ferramenta','Outro'];
    expect(categories, contains('Munição'));
    expect(categories, hasLength(7));
  });
}
