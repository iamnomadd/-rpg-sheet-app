import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';
import 'package:rpg_sheet_app/screens/character/resource_quick_adjust.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('readVida', () {
    test('usa resourceValues/resourceMaxValues de Vida quando existem', () {
      final sheet = Character(id: 'n', name: 'Goblin', hp: 3, maxHp: 4)
        ..resourceValues['Vida'] = 7
        ..resourceMaxValues['Vida'] = 12;
      expect(readVida(sheet), (current: 7, max: 12));
    });

    test('sem Vida nos recursos usa hp/maxHp', () {
      final sheet = Character(id: 'n', name: 'Goblin', hp: 3, maxHp: 4);
      sheet.resourceValues.remove('Vida');
      sheet.resourceMaxValues.remove('Vida');
      expect(readVida(sheet), (current: 3, max: 4));
    });
  });

  group('applyVida', () {
    test('grava nos recursos e em hp/maxHp', () {
      final sheet = Character(id: 'n', name: 'Goblin', hp: 10, maxHp: 10);
      applyVida(sheet, const ResourceValues(current: 4, max: 10));
      expect(sheet.resourceValues['Vida'], 4);
      expect(sheet.resourceMaxValues['Vida'], 10);
      expect(sheet.hp, 4);
      expect(sheet.maxHp, 10);
    });

    test('clamp do atual entre 0 e o máximo', () {
      final sheet = Character(id: 'n', name: 'Goblin', hp: 10, maxHp: 10);
      applyVida(sheet, const ResourceValues(current: 15, max: 10));
      expect(readVida(sheet), (current: 10, max: 10));
      applyVida(sheet, const ResourceValues(current: -3, max: 10));
      expect(readVida(sheet), (current: 0, max: 10));
    });

    test('máximo editado', () {
      final sheet = Character(id: 'n', name: 'Goblin', hp: 10, maxHp: 10);
      applyVida(sheet, const ResourceValues(current: 18, max: 20));
      expect(readVida(sheet), (current: 18, max: 20));
      expect(sheet.maxHp, 20);
      applyVida(sheet, const ResourceValues(current: 18, max: 5));
      expect(readVida(sheet), (current: 5, max: 5));
    });
  });

  group('SessionToolsScreen — vida na iniciativa', () {
    late AppState state;
    late Campaign campaign;

    setUp(() {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      final goblin = Character(id: 'g1', name: 'Goblin', hp: 6, maxHp: 9)
        ..resourceValues['Vida'] = 6
        ..resourceMaxValues['Vida'] = 9;
      final hero = Character(id: 'p1', name: 'Ana', hp: 14, maxHp: 20)
        ..resourceValues['Vida'] = 14
        ..resourceMaxValues['Vida'] = 20;
      state.characters.add(hero);
      campaign = Campaign(
        id: 'c1',
        name: 'Mesa',
        characterIds: ['p1'],
        npcSheets: [
          {'id': 'g1', 'name': 'Goblin', 'kind': 'NPC', 'sheet': goblin.toJson()},
        ],
        initiative: [
          {'id': 'npc:g1', 'name': 'Goblin', 'type': 'npc', 'value': 15, 'done': false},
          {'id': 'p1', 'name': 'Ana', 'type': 'player', 'value': 12, 'done': false},
          {'id': 'manual:1', 'name': 'Lobo', 'type': 'manual', 'value': 8, 'done': false},
        ],
      )..combatActive = true;
      state.campaigns.add(campaign);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: SessionToolsScreen(campaignId: 'c1')),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('NPC mostra a barra e abre a folha ao tocar', (tester) async {
      await pump(tester);
      expect(find.text('6 / 9'), findsOneWidget);
      expect(find.byType(ResourceBarTapTarget), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Ajustar vida de Goblin')), findsOneWidget);

      await tester.tap(find.byType(ResourceBarTapTarget));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Valor atual')).controller!.text, '6');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Valor máximo')).controller!.text, '9');
    });

    testWidgets('dano no NPC grava na ficha e no log', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(ResourceBarTapTarget));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Quantidade'), '4');
      await tester.tap(find.text('Receber dano'));
      await tester.pumpAndSettle();

      final sheet = Character.fromJson(Map<String, dynamic>.from(campaign.npcSheets.first['sheet'] as Map));
      expect(sheet.resourceValues['Vida'], 2);
      expect(sheet.hp, 2);
      expect(campaign.sessionLog.last, 'Goblin: vida 6/9 → 2/9');
      expect(find.text('2 / 9'), findsOneWidget);
    });

    testWidgets('jogador mostra a vida só para leitura; avulso sem barra', (tester) async {
      await pump(tester);
      expect(find.text('14 / 20'), findsOneWidget);
      // Só o NPC tem área de toque de vida.
      expect(find.byType(ResourceBarTapTarget), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Ajustar vida de Ana')), findsNothing);

      await tester.tap(find.text('14 / 20'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Valor atual'), findsNothing);
      expect(state.characters.first.resourceValues['Vida'], 14);
    });
  });
}
