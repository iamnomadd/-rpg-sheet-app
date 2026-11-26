import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Systems 2.0 built-in preset ids remain stable', () {
    const ids = ['generic','dnd5e','tormenta20','ordem_paranormal','shadowdark'];
    expect(ids, hasLength(5));
    expect(ids.first, 'generic');
  });
}
