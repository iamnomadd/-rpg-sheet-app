import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/models/character.dart';

void main() {
  group('Character', () {
    test('mantém dados importantes após serializar e restaurar', () {
      final original = Character(
        id: 'char-1',
        name: 'Teste',
        hp: 8,
        maxHp: 12,
        energy: 4,
        maxEnergy: 10,
        conditions: ['Envenenado'],
        actionOrder: ['consumables', 'weapons'],
        hiddenActionGroups: ['spells'],
        fullBodyPath: 'data:image/png;base64,AAAA',
        inventory: ['Pistola', 'Munição 9mm'],
        inventoryDetails: {
          'Pistola': {
            'category': 'Arma',
            'damage': '1d10',
            'ammo': 5,
            'maxAmmo': 15,
          },
          'Munição 9mm': {
            'category': 'Munição',
            'quantity': 30,
          },
        },
      );

      final restored = Character.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.conditions, contains('Envenenado'));
      expect(restored.actionOrder, ['consumables', 'weapons']);
      expect(restored.hiddenActionGroups, ['spells']);
      expect(restored.fullBodyPath, startsWith('data:image/png'));
      expect(restored.inventory, containsAll(['Pistola', 'Munição 9mm']));
      expect(restored.inventoryDetails['Pistola']?['maxAmmo'], 15);
      expect(restored.inventoryDetails['Munição 9mm']?['category'], 'Munição');
    });

    test('migra Vida e Energia de fichas antigas', () {
      final restored = Character.fromJson({
        'id': 'legacy',
        'name': 'Antigo',
        'hp': 7,
        'maxHp': 11,
        'energy': 3,
        'maxEnergy': 9,
      });

      expect(restored.resourceValues['Vida'], 7);
      expect(restored.resourceMaxValues['Vida'], 11);
      expect(restored.resourceValues['Energia'], 3);
      expect(restored.resourceMaxValues['Energia'], 9);
    });
  });
}
