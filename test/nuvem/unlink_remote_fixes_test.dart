import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';

void main() {
  group('canRemoveLinkLocally', () {
    test('DELETE apagou a linha: remove', () {
      expect(canRemoveLinkLocally(deleted: true), isTrue);
    });

    test('nada apagado e a linha já não existe: remove (sucesso)', () {
      expect(canRemoveLinkLocally(deleted: false, stillExists: false), isTrue);
    });

    test('nada apagado e a linha ainda existe: falha real, não remove', () {
      expect(canRemoveLinkLocally(deleted: false, stillExists: true), isFalse);
    });

    test('nada apagado e a consulta falhou: não remove', () {
      expect(canRemoveLinkLocally(deleted: false, stillExists: null), isFalse);
    });
  });
}
