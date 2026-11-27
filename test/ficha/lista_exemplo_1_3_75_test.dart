// 1.3.75 — bloco "Criar uma nova ficha" no fim da lista, ficha de exemplo
// com 5 nomes e intervalo de 10 s com shareCode sem campanha.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/player_turn_banner.dart';
import 'package:rpg_sheet_app/screens/home/home_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/example_character.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Random fixo: nextInt devolve sempre [value] (limitado ao máximo).
class _FixedRandom implements Random {
  final int value;
  _FixedRandom(this.value);
  @override
  int nextInt(int max) => value % max;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

Future<AppState> _state({List<String> names = const []}) async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.load();
  for (final name in names) {
    await state.addCharacter(name: name);
  }
  return state;
}

void main() {
  group('A: bloco de criação no fim da lista', () {
    Future<AppState> pumpHome(WidgetTester tester, {List<String> names = const [], Size size = const Size(600, 1600), double textScale = 1.0}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = await _state(names: names);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: HomeScreen())));
      await tester.pump(const Duration(milliseconds: 300));
      return state;
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('com fichas, o último item é o bloco com estrelas, título e os 2 botões', (tester) async {
      await pumpHome(tester, names: ['Ana', 'Bia']);
      final block = find.byKey(const ValueKey('create-block-Sua aventura continua'));
      expect(block, findsOneWidget);
      expect(find.text('2 fichas'), findsOneWidget);
      expect(find.descendant(of: block, matching: find.text('Crie outra ficha ou explore uma ficha de exemplo.')), findsOneWidget);
      final stars = tester.widget<Icon>(find.descendant(of: block, matching: find.byIcon(Icons.auto_awesome)));
      expect(stars.size, 48);
      expect(stars.color, isNull, reason: 'cor do tema, como na tela vazia');
      expect(find.descendant(of: block, matching: find.widgetWithText(FilledButton, 'Criar uma nova ficha')), findsOneWidget);
      expect(find.descendant(of: block, matching: find.widgetWithText(OutlinedButton, 'Criar uma nova ficha de exemplo')), findsOneWidget);
      // Depois da última ficha, dentro da lista (rola junto).
      expect(tester.getTopLeft(block).dy, greaterThan(tester.getBottomLeft(find.text('Bia')).dy));
      expect(find.ancestor(of: block, matching: find.byType(ListView)), findsOneWidget);
      // O "+" do topo continua.
      expect(find.byTooltip('Nova ficha'), findsOneWidget);
      // Os textos da tela vazia não aparecem.
      expect(find.text('Sua aventura começa aqui'), findsNothing);
      await finish(tester);
    });

    testWidgets('"Criar uma nova ficha" abre o fluxo de nova ficha', (tester) async {
      await pumpHome(tester, names: ['Ana']);
      await tester.tap(find.text('Criar uma nova ficha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Nova ficha'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Nome do personagem'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 400));
      await finish(tester);
    });

    testWidgets('"Criar uma nova ficha de exemplo" cria a ficha de exemplo e abre', (tester) async {
      final state = await pumpHome(tester, names: ['Ana']);
      await tester.tap(find.text('Criar uma nova ficha de exemplo'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(state.characters.map((c) => c.name), ['Ana', 'Aaron']);
      expect(find.byType(CharacterScreen), findsOneWidget);
      await finish(tester);
    });

    testWidgets('sem fichas, a tela vazia continua igual', (tester) async {
      await pumpHome(tester);
      expect(find.text('Sua aventura começa aqui'), findsOneWidget);
      expect(find.text('Crie sua primeira ficha e organize personagens, atributos, inventário e habilidades.'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.auto_awesome)).size, 72);
      expect(find.widgetWithText(FilledButton, 'Criar primeira ficha'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Criar ficha de exemplo'), findsOneWidget);
      expect(find.text('Sua aventura continua'), findsNothing);
      expect(find.byType(ListView), findsNothing);
      await finish(tester);
    });

    for (final scale in [1.15, 2.0]) {
      testWidgets('sem estouro com texto $scale em 320 px', (tester) async {
        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            overflows.add(text);
          } else {
            previous?.call(details);
          }
        };
        addTearDown(() => FlutterError.onError = previous);
        await pumpHome(tester, names: ['Ana'], size: const Size(320, 2400), textScale: scale);
        expect(find.text('Sua aventura continua'), findsOneWidget);
        await finish(tester);
        FlutterError.onError = previous;
        expect(overflows, isEmpty);
      });
    }
  });

  group('B: ficha de exemplo com 5 nomes', () {
    test('a primeira ficha de exemplo se chama "Aaron" (masculino)', () async {
      final state = await _state();
      final c = (await createExampleCharacter(state))!;
      expect(c.name, 'Aaron');
      expect(c.sectionNotes['Anotações'],
          'Aaron é um aventureiro que cresceu nas docas e aprendeu magia sozinho. Procura o irmão desaparecido e confia em poucas pessoas. Prefere resolver as coisas com astúcia antes de sacar a espada.');
    });

    test('com "Aaron" existente, sorteia um dos outros 4 ainda sem ficha', () {
      expect(pickExampleCharacterName(['Aaron'], random: _FixedRandom(0)).name, 'Kael');
      expect(pickExampleCharacterName(['Aaron'], random: _FixedRandom(1)).name, 'Selene');
      expect(pickExampleCharacterName(['Aaron'], random: _FixedRandom(3)).name, 'Mira');
      // Kael e Selene já usados: sorteio entre Dorian e Mira.
      expect(pickExampleCharacterName(['aaron', 'Kael', 'SELENE '], random: _FixedRandom(0)).name, 'Dorian');
      expect(pickExampleCharacterName(['aaron', 'Kael', 'SELENE '], random: _FixedRandom(1)).name, 'Mira');
      // Sem "Aaron", sempre "Aaron" (o sorteio não importa).
      expect(pickExampleCharacterName(['Kael'], random: _FixedRandom(2)).name, 'Aaron');
    });

    test('com os 5 em uso, aplica a regra "(2)", "(3)"', () {
      const all = ['Aaron', 'Kael', 'Selene', 'Dorian', 'Mira'];
      expect(pickExampleCharacterName(all, random: _FixedRandom(1)).name, 'Kael (2)');
      expect(pickExampleCharacterName([...all, 'Mira (2)'], random: _FixedRandom(4)).name, 'Mira (3)');
    });

    test('nome feminino usa o resumo feminino', () async {
      final state = await _state(names: ['Aaron']);
      final c = (await createExampleCharacter(state, random: _FixedRandom(1)))!;
      expect(c.name, 'Selene');
      expect(c.sectionNotes['Anotações'],
          'Selene é uma aventureira que cresceu nas docas e aprendeu magia sozinha. Procura o irmão desaparecido e confia em poucas pessoas. Prefere resolver as coisas com astúcia antes de sacar a espada.');
      // O resto da ficha continua igual.
      expect(c.systemId, 'tormenta20');
      expect(c.resourceValues, {'PV': 18, 'PM': 7});
      expect(c.inventory, hasLength(7));
      expect(c.abilities, hasLength(5));
      expect(c.skills, ['Furtividade']);
    });

    test('com sufixo, o resumo usa o nome sem "(2)"', () async {
      final state = await _state(names: ['Aaron', 'Kael', 'Selene', 'Dorian', 'Mira']);
      final c = (await createExampleCharacter(state, random: _FixedRandom(2)))!;
      expect(c.name, 'Selene (2)');
      expect(c.sectionNotes['Anotações'], startsWith('Selene é uma aventureira'));
    });

    test('fichas "Lyra (exemplo)" já criadas não são alteradas', () async {
      final state = await _state();
      final lyra = Character(id: 'lyra', name: 'Lyra (exemplo)', systemId: 'tormenta20', sectionNotes: {'Anotações': 'Lyra é uma aventureira que cresceu nas docas.'});
      state.characters.add(lyra);
      final before = lyra.toJson().toString();
      final c = (await createExampleCharacter(state))!;
      expect(c.name, 'Aaron');
      expect(state.characters.firstWhere((x) => x.id == 'lyra').toJson().toString(), before);
    });
  });

  test('C: shareCode sem campanha consulta a cada 10 s; os outros casos não mudam', () {
    expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: false, hasShareCode: true, hasCampaigns: false), const Duration(seconds: 10));
    expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: true, hasShareCode: true, hasCampaigns: false), const Duration(seconds: 10));
    expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: false, hasShareCode: false, hasCampaigns: false), const Duration(seconds: 60));
    expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: true, hasShareCode: true, hasCampaigns: true), const Duration(seconds: 15));
    expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: false, hasShareCode: true, hasCampaigns: true), const Duration(milliseconds: 1200));
    expect(playerTurnRefreshDelay(failures: 1, realtimeConnected: false, hasShareCode: true, hasCampaigns: false), const Duration(seconds: 4));
    expect(playerTurnRefreshDelay(failures: 3, realtimeConnected: false, hasShareCode: true, hasCampaigns: false), const Duration(seconds: 12));
  });
}
