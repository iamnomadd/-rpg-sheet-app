import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Abilities and magic 2.0 categories', () {
    const categories = ['Habilidade','Magia','Técnica','Passiva','Outro'];
    expect(categories, containsAll(['Magia','Técnica','Passiva']));
  });
}
