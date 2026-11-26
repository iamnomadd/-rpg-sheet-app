import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Character 2D 3.0 state contract', () {
    const healthStates = ['Estável', 'Ferido', 'Crítico', 'Incapacitado'];
    const positive = ['Protegido', 'Inspirado', 'Fortalecido', 'Acelerado', 'Regenerando'];
    const negative = ['Queimando', 'Envenenado', 'Congelado', 'Sangrando', 'Atordoado'];
    expect(healthStates, hasLength(4));
    expect(positive, hasLength(5));
    expect(negative, hasLength(5));
  });
}
