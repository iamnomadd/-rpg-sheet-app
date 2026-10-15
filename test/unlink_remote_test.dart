import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _link(String code, String id, {String status = 'approved'}) => {
      if (status == 'approved') 'requestId': 'req-$code',
      'shareCode': code,
      'status': status,
      'snapshot': {'id': id, 'name': 'Ficha $id'},
      'ownerId': 'owner-$id',
    };

Campaign _campaign({List<Map<String, dynamic>>? links, List<Map<String, dynamic>>? initiative, int current = 0}) =>
    Campaign(id: 'c1', name: 'Mesa', linkedCharacters: links, initiative: initiative)
      ..combatActive = (initiative ?? []).isNotEmpty
      ..currentTurnIndex = current;

Map<String, dynamic> _entry(String id, int value, {String type = 'player'}) =>
    {'id': id, 'name': id, 'type': type, 'value': value, 'done': false};

void main() {
  group('staleRemoteLinks', () {
    final local = [_link('AAA', 'p1'), _link('BBB', 'p2'), _link('CCC', 'p3', status: 'pending')];

    test('remove aprovados que não estão mais entre os aprovados da nuvem', () {
      final stale = staleRemoteLinks(local: local, approvedCodes: {'AAA'}, missingSharedCodes: {});
      expect(stale.map((e) => e['shareCode']), ['BBB']);
    });

    test('remove quando a ficha compartilhada foi apagada (shared null)', () {
      final stale = staleRemoteLinks(local: local, approvedCodes: {'AAA', 'BBB'}, missingSharedCodes: {'AAA'});
      expect(stale.map((e) => e['shareCode']), ['AAA']);
    });

    test('não toca pendentes', () {
      final stale = staleRemoteLinks(local: local, approvedCodes: <String>{}, missingSharedCodes: {'CCC'});
      expect(stale.map((e) => e['shareCode']), ['AAA', 'BBB']);
    });

    test('busca bem-sucedida e vazia remove todos os aprovados; busca que falhou não remove nada', () {
      expect(staleRemoteLinks(local: local, approvedCodes: <String>{}, missingSharedCodes: {}).length, 2);
      expect(staleRemoteLinks(local: local, approvedCodes: null, missingSharedCodes: {'AAA'}), isEmpty);
    });
  });

  group('removeRemoteLink', () {
    // Ordem por iniciativa: a(20), p1(15), b(10).
    List<Map<String, dynamic>> init() => [_entry('a', 20, type: 'npc'), _entry('p1', 15), _entry('b', 10, type: 'npc')];

    test('remove o vínculo e a entrada do jogador; turno antes do removido continua', () {
      final c = _campaign(links: [_link('AAA', 'p1'), _link('BBB', 'p2')], initiative: init(), current: 0);
      expect(removeRemoteLink(c, c.linkedCharacters.first), isTrue);
      expect(c.linkedCharacters.map((e) => e['shareCode']), ['BBB']);
      expect(c.initiative.map((e) => e['id']), ['a', 'b']);
      expect(c.currentTurnIndex, 0);
    });

    test('removendo quem está no turno, o turno passa para o próximo', () {
      final c = _campaign(links: [_link('AAA', 'p1')], initiative: init(), current: 1);
      removeRemoteLink(c, c.linkedCharacters.first);
      expect(c.initiative.map((e) => e['id']), ['a', 'b']);
      expect(c.currentTurnIndex, 1);
      expect(c.combatActive, isTrue);
    });

    test('turno depois do removido continua no mesmo participante', () {
      final c = _campaign(links: [_link('AAA', 'p1')], initiative: init(), current: 2);
      removeRemoteLink(c, c.linkedCharacters.first);
      expect(c.initiative[c.currentTurnIndex]['id'], 'b');
    });

    test('combate sem participantes é encerrado', () {
      final c = _campaign(links: [_link('AAA', 'p1')], initiative: [_entry('p1', 15)], current: 0);
      expect(removeRemoteLink(c, c.linkedCharacters.first), isTrue);
      expect(c.initiative, isEmpty);
      expect(c.combatActive, isFalse);
      expect(c.currentTurnIndex, 0);
    });

    test('NPC com o mesmo id não sai; sem entrada na iniciativa devolve false', () {
      final c = _campaign(links: [_link('AAA', 'p1')], initiative: [_entry('p1', 15, type: 'npc')]);
      expect(removeRemoteLink(c, c.linkedCharacters.first), isFalse);
      expect(c.initiative.length, 1);
      expect(c.linkedCharacters, isEmpty);
    });
  });

  group('AppState.deleteCharacter', () {
    late AppState state;
    late List<String> cleanupCalls;
    late int notifications;

    setUp(() {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      cleanupCalls = [];
      notifications = 0;
      state.addListener(() => notifications++);
    });

    test('ficha sem shareCode não chama a nuvem', () async {
      state.characters.add(Character(id: 'a', name: 'A'));
      state.deleteSharedCleanup = (id, code) async => cleanupCalls.add('$id|$code');
      await state.deleteCharacter('a');
      await Future<void>.delayed(Duration.zero);
      expect(state.characters, isEmpty);
      expect(notifications, greaterThan(0));
      expect(cleanupCalls, isEmpty);
    });

    test('ficha compartilhada: remove local, notifica e pede a limpeza na nuvem', () async {
      state.characters.add(Character(id: 'b', name: 'B')..shareCode = 'ABCD-1234');
      state.deleteSharedCleanup = (id, code) async => cleanupCalls.add('$id|$code');
      await state.deleteCharacter('b');
      await Future<void>.delayed(Duration.zero);
      expect(state.characters, isEmpty);
      expect(notifications, greaterThan(0));
      expect(cleanupCalls, ['b|ABCD-1234']);
    });

    test('falha na limpeza da nuvem não impede a remoção local', () async {
      state.characters.add(Character(id: 'c', name: 'C')..shareCode = 'ABCD-5678');
      state.deleteSharedCleanup = (id, code) async => throw Exception('offline');
      await state.deleteCharacter('c');
      await Future<void>.delayed(Duration.zero);
      expect(state.characters, isEmpty);
      expect(notifications, greaterThan(0));
    });
  });

  testWidgets('"Desvincular" pede confirmação e Cancelar não altera a lista', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    final campaign = _campaign(links: [_link('AAA', 'r1')]);
    state.campaigns.add(campaign);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: MasterScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Jogadores')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.widgetWithText(Card, 'Ficha r1'), matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desvincular'));
    await tester.pumpAndSettle();
    expect(find.text('Desvincular ficha?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(campaign.linkedCharacters.length, 1);
    expect(find.text('Ficha r1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
