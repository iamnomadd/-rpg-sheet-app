import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('npcSecondaryResourceNames', () {
    test('sistema com vários recursos: os secundários na ordem do sistema', () {
      expect(
        npcSecondaryResourceNames(
          systemResources: ['Vida', 'PV temporarios', 'Energia', 'Êxtase'],
          values: {'Vida': 10, 'Energia': 0},
          maxValues: {'Vida': 10, 'Energia': 0},
        ),
        ['PV temporarios', 'Energia', 'Êxtase'],
      );
    });

    test("sistema sem Energia não mostra a 'Energia' 0/0 criada pelo fromJson", () {
      expect(
        npcSecondaryResourceNames(
          systemResources: ['PV', 'PM'],
          values: {'PV': 7, 'PM': 3, 'Vida': 7, 'Energia': 0},
          maxValues: {'PV': 10, 'PM': 5, 'Vida': 10, 'Energia': 0},
        ),
        ['PM'],
      );
    });

    test('chave extra com valor fora do sistema entra', () {
      expect(
        npcSecondaryResourceNames(
          systemResources: ['PV', 'PM'],
          values: {'PM': 3, 'Escudo': 3, 'Vazio': 0},
          maxValues: {'PM': 5, 'Vazio': 0},
        ),
        ['PM', 'Escudo'],
      );
      expect(
        npcSecondaryResourceNames(systemResources: ['PV'], values: {'Carga': 0}, maxValues: {'Carga': 4}),
        ['Carga'],
      );
    });

    test('chave de vida nunca entra', () {
      expect(
        npcSecondaryResourceNames(
          systemResources: ['Vida', 'PV', ' pv '],
          values: {'Vida': 5, 'PV': 5},
          maxValues: {'Vida': 5, 'PV': 5},
        ),
        isEmpty,
      );
    });

    test('sistema não encontrado: todas as chaves que não são de vida', () {
      expect(
        npcSecondaryResourceNames(
          systemResources: null,
          values: {'Vida': 5, 'Energia': 0, 'Fúria': 2},
          maxValues: {'Vida': 5, 'Energia': 0, 'Fúria': 4},
        ),
        ['Energia', 'Fúria'],
      );
    });

    test('sem duplicatas (trim + minúsculas)', () {
      expect(
        npcSecondaryResourceNames(
          systemResources: ['Mana', ' mana', 'Energia'],
          values: {'MANA': 3, 'energia ': 1},
          maxValues: {'MANA': 5},
        ),
        ['Mana', 'Energia'],
      );
    });
  });

  testWidgets('ficha do NPC mostra todos os recursos do sistema e tocar abre o diálogo', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'PV temporarios', 'Energia']));
    final npc = Character.fromJson(Character(
      id: 'o1',
      name: 'Orc',
      systemId: 'sys',
      resourceValues: {'Vida': 8, 'PV temporarios': 2, 'Energia': 4},
      resourceMaxValues: {'Vida': 10, 'PV temporarios': 5, 'Energia': 6},
    ).toJson());
    state.campaigns.add(Campaign(id: 'c1', name: 'Mesa', npcSheets: [
      {'id': 'o1', 'name': 'Orc', 'kind': 'NPC', 'sheet': npc.toJson()},
    ]));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: NpcSheetScreen(campaignId: 'c1', npcId: 'o1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PV temporarios'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('Energia'), findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget);
    expect(find.text('8 / 10'), findsOneWidget);

    await tester.tap(find.text('PV temporarios'));
    await tester.pumpAndSettle();
    expect(find.text('Configurar PV temporarios'), findsOneWidget);
    // Fecha a tela sem passar pelo descarte dos campos do diálogo (bug antigo,
    // fora do escopo deste PR).
    await tester.pumpWidget(const SizedBox());
  });
}
