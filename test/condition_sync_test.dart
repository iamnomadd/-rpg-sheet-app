import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('conditionsFromRaw', () {
    test('ausente ou tipo errado vira lista vazia', () {
      expect(conditionsFromRaw(null), isEmpty);
      expect(conditionsFromRaw('Envenenado'), isEmpty);
      expect(conditionsFromRaw({'a': 1}), isEmpty);
    });

    test('itens viram texto e vazios são ignorados', () {
      expect(conditionsFromRaw(['Caído', 2, '  ']), ['Caído', '2']);
    });
  });

  group('mergeConditions', () {
    test('une sem duplicar, sem diferenciar maiúsculas, mantendo a primeira grafia', () {
      expect(mergeConditions(['Envenenado', 'Cego'], ['envenenado', 'Caído']), ['Envenenado', 'Cego', 'Caído']);
    });

    test('listas vazias', () {
      expect(mergeConditions(const [], const []), isEmpty);
      expect(mergeConditions(const [], ['Caído']), ['Caído']);
    });
  });

  group('patchedConditions', () {
    test('adicionar', () {
      expect(patchedConditions(['Cego'], add: 'Envenenado'), ['Cego', 'Envenenado']);
    });

    test('adicionar duplicada não repete', () {
      expect(patchedConditions(['Envenenado'], add: 'ENVENENADO'), ['Envenenado']);
    });

    test('remover sem diferenciar maiúsculas', () {
      expect(patchedConditions(['Envenenado', 'Cego'], remove: 'envenenado'), ['Cego']);
    });

    test('remover ausente não muda', () {
      expect(patchedConditions(['Cego'], remove: 'Caído'), ['Cego']);
    });

    test('lista atual com duplicadas é limpa', () {
      expect(patchedConditions(['Cego', 'cego']), ['Cego']);
    });
  });

  group('patch do mestre no jogador', () {
    test('só condições (sem resourceValues ou com mapa vazio) aplica sozinho', () {
      expect(isConditionsOnlyPatch({'conditions': ['Envenenado']}), isTrue);
      expect(isConditionsOnlyPatch({'conditions': [], 'resourceValues': {}}), isTrue);
    });

    test('com resourceValues ou sem lista de condições continua manual', () {
      expect(isConditionsOnlyPatch({'conditions': ['Cego'], 'resourceValues': {'PM': 2}}), isFalse);
      expect(isConditionsOnlyPatch({'resourceValues': {'PM': 2}}), isFalse);
      expect(isConditionsOnlyPatch({'conditions': 'Cego'}), isFalse);
    });

    test('aplicar manual ignora Vida e PV', () {
      expect(
        patchResourcesWithoutLife({'Vida': 1, 'PV': 2, ' pv ': 3, 'PM': 4, 'Energia': 5.0, 'Sanidade': 'x'}),
        {'PM': 4, 'Energia': 5},
      );
      expect(patchResourcesWithoutLife(null), isEmpty);
      expect(patchResourcesWithoutLife(['Vida']), isEmpty);
    });
  });

  group('SessionToolsScreen — condições do jogador', () {
    late AppState state;
    late Campaign campaign;

    setUp(() {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      state.characters.add(Character(id: 'p1', name: 'Ana')..conditions = ['Cego']);
      campaign = Campaign(
        id: 'c1',
        name: 'Mesa',
        characterIds: ['p1'],
        linkedCharacters: [
          {
            'shareCode': 'ABC123',
            'status': 'approved',
            'snapshot': {'id': 'r1', 'name': 'Bia', 'conditions': ['Caído']},
          },
        ],
        initiative: [
          {'id': 'p1', 'name': 'Ana', 'type': 'player', 'value': 12, 'done': false},
          {'id': 'r1', 'name': 'Bia', 'type': 'player', 'value': 10, 'done': false},
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

    testWidgets('seletor mostra presets e "Outra..." normaliza para o nome do preset', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Adicionar condição a Lobo'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Envenenado')), findsOneWidget);
      await tester.ensureVisible(find.text('Outra...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outra...'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'envenenado');
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(campaign.initiative.last['conditions'], ['Envenenado']);
    });

    testWidgets('jogador local: adicionar e remover vão para a ficha, sem mexer na vida', (tester) async {
      final ana = state.characters.first;
      final vidaAntes = Map.of(ana.resourceValues);
      await pump(tester);
      await tester.tap(find.byTooltip('Adicionar condição a Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Envenenado')));
      await tester.pumpAndSettle();
      expect(ana.conditions, ['Cego', 'Envenenado']);
      expect(campaign.sessionLog.last, 'Ana ficou com Envenenado.');

      ana.conditions = ['Cego', 'Envenenado'];
      await tester.tap(find.widgetWithText(InputChip, 'Envenenado'));
      await tester.pumpAndSettle();
      expect(ana.conditions, ['Cego']);
      expect(campaign.sessionLog.last, 'Ana não está mais com Envenenado.');
      expect(ana.resourceValues, vidaAntes);
    });

    testWidgets('jogador remoto: falha ao enviar mostra aviso e não registra no log', (tester) async {
      await pump(tester);
      final logAntes = List.of(campaign.sessionLog);
      await tester.tap(find.byTooltip('Adicionar condição a Bia'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Envenenado')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível enviar a condição'), findsOneWidget);
      expect(campaign.sessionLog, logAntes);
      expect(campaign.initiative[1].containsKey('conditions'), isFalse);
    });

    testWidgets('chips do jogador unem a ficha e a iniciativa, sem duplicar', (tester) async {
      campaign.initiative[0]['conditions'] = ['cego', 'Envenenado'];
      campaign.initiative[1]['conditions'] = 'tipo errado';
      await pump(tester);
      // Ana (local): 'Cego' da ficha + 'Envenenado' da iniciativa; 'cego' não repete.
      expect(find.widgetWithText(InputChip, 'Cego'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'cego'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Envenenado'), findsOneWidget);
      // Bia (remota): 'Caído' do snapshot, mesmo com conditions de tipo errado.
      expect(find.widgetWithText(InputChip, 'Caído'), findsOneWidget);
    });
  });
}
