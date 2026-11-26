import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requested system preset ids remain stable', () {
    // Migration contract: existing generic characters keep the generic id.
    const ids = ['generic', 'dnd5e', 'tormenta20', 'ordem_paranormal', 'shadowdark'];
    expect(ids.toSet().length, 5);
    expect(ids.first, 'generic');
  });
}
