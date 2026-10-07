import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/services/app_update_service.dart';

void main() {
  group('isNewerVersion', () {
    test('versão remota mais nova', () {
      expect(isNewerVersion('1.3.42+142', '1.3.41+141'), isTrue);
      expect(isNewerVersion('1.4.0+1', '1.3.99+999'), isTrue);
      expect(isNewerVersion('1.3.41+142', '1.3.41+141'), isTrue);
      expect(isNewerVersion('1.3.10+1', '1.3.9+999'), isTrue);
      expect(isNewerVersion('2.0.0+0', '1.99.99+99'), isTrue);
    });

    test('versão igual ou mais antiga', () {
      expect(isNewerVersion('1.3.41+141', '1.3.41+141'), isFalse);
      expect(isNewerVersion('1.3.40+140', '1.3.41+141'), isFalse);
      expect(isNewerVersion('1.3.9+999', '1.3.10+1'), isFalse);
    });

    test('entrada inválida em qualquer lado', () {
      for (final invalid in ['', 'abc', '1.3.41', '1.3.x+1']) {
        expect(isNewerVersion(invalid, '1.3.41+141'), isFalse, reason: 'remota "$invalid"');
        expect(isNewerVersion('1.3.42+142', invalid), isFalse, reason: 'local "$invalid"');
      }
    });
  });

  test('fora da web fetchRemoteFullVersion devolve null', () async {
    expect(await fetchRemoteFullVersion(), isNull);
  });
}
