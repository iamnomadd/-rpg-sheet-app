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

  group('initiativeConditions', () {
    test('sem a chave devolve lista vazia', () {
      expect(initiativeConditions({'id': 'p1'}), isEmpty);
    });

    test('lista vazia', () {
      expect(initiativeConditions({'conditions': []}), isEmpty);
    });

    test('tipo errado não quebra', () {
      expect(initiativeConditions({'conditions': 'Envenenado'}), isEmpty);
      expect(initiativeConditions({'conditions': 3}), isEmpty);
      expect(initiativeConditions({'conditions': ['Caído', 2]}), ['Caído', '2']);
    });

    test('devolve uma cópia', () {
      final entry = <String, dynamic>{'conditions': ['Caído']};
      initiativeConditions(entry).add('Cego');
      expect(entry['conditions'], ['Caído']);
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

    Future<void> addCondition(WidgetTester tester, String participant, String condition) async {
      await tester.tap(find.byTooltip('Adicionar condição a $participant'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), condition);
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
    }

    testWidgets('condição por participante: adiciona, mostra chip, loga e remove', (tester) async {
      await pump(tester);
      await addCondition(tester, 'Goblin', 'Envenenado');
      await addCondition(tester, 'Ana', 'Envenenado');

      expect(find.widgetWithText(InputChip, 'Envenenado'), findsNWidgets(2));
      expect(campaign.initiative.firstWhere((e) => e['id'] == 'npc:g1')['conditions'], ['Envenenado']);
      expect(campaign.initiative.firstWhere((e) => e['id'] == 'p1')['conditions'], ['Envenenado']);
      expect(campaign.sessionLog, containsAll(['Goblin ficou com Envenenado.', 'Ana ficou com Envenenado.']));
      // Não mexe na ficha do jogador nem nas condições gerais.
      expect(state.characters.first.conditions, isEmpty);
      expect(campaign.conditions, isEmpty);

      await tester.tap(find.widgetWithText(InputChip, 'Envenenado').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Envenenado'), findsOneWidget);
      expect(campaign.initiative.firstWhere((e) => e['id'] == 'npc:g1')['conditions'], isEmpty);
      expect(campaign.sessionLog.last, 'Goblin não está mais com Envenenado.');
    });

    testWidgets('card geral se chama Condições gerais e continua gravando na campanha', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Condições gerais'), 200);
      expect(find.text('Condições gerais'), findsOneWidget);
      final addGeneral = find.widgetWithIcon(IconButton, Icons.add);
      await tester.ensureVisible(addGeneral);
      await tester.pumpAndSettle();
      await tester.tap(addGeneral);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Neblina');
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(campaign.conditions, ['Neblina']);
      expect(campaign.initiative.every((e) => !e.containsKey('conditions')), isTrue);
    });

    testWidgets('combate salvo antes (sem conditions) abre normalmente em tela estreita', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      campaign.initiative.first['conditions'] = 'tipo errado';
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Goblin'), findsWidgets);
    });
  });
}
