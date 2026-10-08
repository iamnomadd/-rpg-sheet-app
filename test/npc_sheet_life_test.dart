import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/screens/character/resource_quick_adjust.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('isLifeResourceKey', () {
    expect(isLifeResourceKey('Vida'), isTrue);
    expect(isLifeResourceKey('vida'), isTrue);
    expect(isLifeResourceKey(' PV '), isTrue);
    expect(isLifeResourceKey('pv'), isTrue);
    expect(isLifeResourceKey('Energia'), isFalse);
    expect(isLifeResourceKey('PV Temporários'), isFalse);
  });

  // Mesma gravação que _editResource faz para a vida ao salvar o diálogo.
  test('salvar a vida de NPC com PV (vindo do fromJson) deixa PV, Vida e hp iguais', () {
    final sheet = Character.fromJson(Character(
      id: 'o1',
      name: 'Orc',
      hp: 99,
      maxHp: 99,
      resourceValues: {'PV': 7, 'PM': 3},
      resourceMaxValues: {'PV': 10, 'PM': 5},
    ).toJson());
    expect(readVida(sheet), (current: 7, max: 10));
    applyVida(sheet, const ResourceValues(current: 4, max: 10));
    expect(sheet.resourceValues['PV'], 4);
    expect(sheet.resourceValues['Vida'], 4);
    expect(sheet.resourceMaxValues['Vida'], 10);
    expect(sheet.hp, 4);
    expect(sheet.resourceValues['PM'], 3);
  });

  group('NpcSheetScreen — vida', () {
    late AppState state;
    late Campaign campaign;

    Future<void> pump(WidgetTester tester, Character npc) async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      // Passa por toJson/fromJson como a ficha real guardada na campanha.
      final sheet = Character.fromJson(npc.toJson());
      campaign = Campaign(id: 'c1', name: 'Mesa', npcSheets: [
        {'id': npc.id, 'name': npc.name, 'kind': 'NPC', 'sheet': sheet.toJson()},
      ]);
      state.campaigns.add(campaign);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: NpcSheetScreen(campaignId: 'c1', npcId: npc.id)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('sistema com PV: card de vida lê o PV e o PV não aparece como segundo recurso', (tester) async {
      await pump(
        tester,
        Character(
          id: 'o1',
          name: 'Orc',
          hp: 99,
          maxHp: 99,
          resourceValues: {'PV': 7, 'PM': 3},
          resourceMaxValues: {'PV': 10, 'PM': 5},
        ),
      );
      expect(find.text('7 / 10'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
      expect(find.text('PV'), findsNothing);
      expect(find.text('99 / 99'), findsNothing);
    });

    testWidgets('NPC só com Vida mostra como antes', (tester) async {
      await pump(
        tester,
        Character(
          id: 'g1',
          name: 'Goblin',
          hp: 6,
          maxHp: 9,
          resourceValues: {'Vida': 6, 'Energia': 2},
          resourceMaxValues: {'Vida': 9, 'Energia': 4},
        ),
      );
      expect(find.text('6 / 9'), findsOneWidget);
      expect(find.text('Energia'), findsOneWidget);
      expect(find.text('2 / 4'), findsOneWidget);
    });
  });
}
