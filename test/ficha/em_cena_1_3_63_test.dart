// 1.3.63: Em Cena — cards de fixados (A), Personalizar (B), pílulas do Sessão
// (C) e consumíveis zerados no fim do grupo (D).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _todayCards = ['sessionOverview', 'combatCharacter', 'health', 'energy', 'conditions', 'quickActions', 'attributes', 'abilities', 'inventory'];

/// Sessão em cima; Condições e Ações bem abaixo.
const _sessionFirst = ['sessionOverview', 'combatCharacter', 'attributes', 'health', 'energy', 'abilities', 'inventory', 'conditions', 'quickActions'];

Character _character({bool pinned = false}) => Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      attributes: {'Força': 2},
      resourceValues: {'Vida': 10, 'Energia': 5},
      resourceMaxValues: {'Vida': 10, 'Energia': 5},
      conditions: ['Envenenado'],
      abilities: ['Bola de Fogo'],
      abilityDetails: {'Bola de Fogo': {'category': 'Magia', if (pinned) 'showInScene': true}},
      inventory: ['Espada', 'Elixir', 'Poção', 'Corda'],
      inventoryDetails: {
        'Espada': {'category': 'Arma', if (pinned) 'showInScene': true},
        'Elixir': {'category': 'Consumível', 'quantity': 0},
        'Poção': {'category': 'Consumível', 'quantity': 2},
        'Corda': {'category': 'Consumível', 'quantity': 1},
      },
    );

Future<AppState> _pump(WidgetTester tester, {Character? character, double height = 2400}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setReduceAnimations(true);
  state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', attributes: ['Força'], resources: ['Vida', 'Energia']));
  state.characters.add(character ?? _character());
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(theme: buildAppTheme('classic', false), home: const CharacterScreen(characterId: 'p1')),
  ));
  await _settle(tester);
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder _card(String id) => find.byKey(ValueKey('general-item-$id'));

Future<void> _openCustomize(WidgetTester tester) async {
  // O botão do Em Cena é o primeiro "Personalizar" (o do card Ações vem depois).
  await tester.tap(find.byTooltip('Personalizar').first);
  await _settle(tester);
  expect(find.text('Personalizar Em Cena'), findsOneWidget);
}

/// O item da folha (rola a lista da folha até ele).
Future<Finder> _tile(WidgetTester tester, String label, {bool up = false}) async {
  final list = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
  final tile = find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(SwitchListTile, label));
  await tester.scrollUntilVisible(tile, up ? -60 : 60, scrollable: list);
  return tile;
}

void main() {
  group('A: cards de fixados', () {
    testWidgets('sem nada fixado: títulos novos, "0 fixado(s)" e os avisos', (tester) async {
      await _pump(tester);
      expect(find.text('Itens fixados'), findsOneWidget);
      expect(find.text('Habilidades fixadas'), findsOneWidget);
      expect(find.text('0 fixado(s)'), findsNWidgets(2));
      expect(find.text('Toque na ★ no Inventário para fixar itens aqui.'), findsOneWidget);
      expect(find.text('Toque na ★ em Habilidades para fixar aqui.'), findsOneWidget);
      expect(find.text('Nenhum item.'), findsNothing);
      expect(find.text('Nenhuma habilidade.'), findsNothing);
      await _finish(tester);
    });

    testWidgets('com fixados (showInScene): "1 fixado(s)" e os nomes', (tester) async {
      await _pump(tester, character: _character(pinned: true));
      expect(find.text('1 fixado(s)'), findsNWidgets(2));
      expect(find.descendant(of: _card('inventory'), matching: find.text('Espada')), findsOneWidget);
      expect(find.descendant(of: _card('abilities'), matching: find.text('Bola de Fogo')), findsOneWidget);
      await _finish(tester);
    });
  });

  group('B: Personalizar do Em Cena', () {
    testWidgets('sem alças "=" nos cards; ficha sem a chave mostra os mesmos cards de hoje', (tester) async {
      final json = _character().toJson()..remove('hiddenGeneralCards');
      await _pump(tester, character: Character.fromJson(json));
      final emCena = find.byKey(const ValueKey('em-cena-scroll'));
      expect(find.descendant(of: emCena, matching: find.byIcon(Icons.drag_handle)), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      for (final id in _todayCards) {
        expect(_card(id), findsOneWidget, reason: id);
      }
      expect(_card('skillTree'), findsNothing);
      await _finish(tester);
    });

    testWidgets('a folha abre com os nomes; skillTree desligado', (tester) async {
      await _pump(tester);
      await _openCustomize(tester);
      expect(find.text('Arraste os cards e escolha quais aparecem.'), findsOneWidget);
      for (final label in ['Sessão', 'Personagem 2D', 'Vida', 'Energia', 'Condições', 'Ações', 'Atributos', 'Habilidades fixadas', 'Itens fixados', 'Árvore de Habilidades']) {
        expect(await _tile(tester, label), findsOneWidget, reason: label);
      }
      expect(tester.widget<SwitchListTile>(await _tile(tester, 'Árvore de Habilidades')).value, isFalse);
      expect(tester.widget<SwitchListTile>(await _tile(tester, 'Atributos')).value, isTrue);
      await _finish(tester);
    });

    testWidgets('arrastar muda a ordem, desligar esconde e salvar persiste', (tester) async {
      final state = await _pump(tester, character: _character()..generalOrder = [..._todayCards]);
      await _openCustomize(tester);
      // Desliga Atributos e liga a Árvore (o último da lista).
      await tester.tap(await _tile(tester, 'Atributos'));
      await tester.pump();
      await tester.tap(await _tile(tester, 'Árvore de Habilidades'));
      await tester.pump();
      // Volta ao topo e arrasta "Sessão" (o primeiro) para baixo de "Personagem 2D".
      final sessionTile = await _tile(tester, 'Sessão', up: true);
      await tester.pump();
      final first = tester.getCenter(sessionTile);
      final second = tester.getCenter(await _tile(tester, 'Personagem 2D', up: true));
      final gesture = await tester.startGesture(first, kind: PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(0, (second.dy - first.dy) + 20));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await _settle(tester);
      await tester.tap(find.text('Salvar'));
      await _settle(tester);

      final c = state.characters.single;
      expect(c.generalOrder.take(2).toList(), ['combatCharacter', 'sessionOverview']);
      expect(c.hiddenGeneralCards, contains('attributes'));
      expect(c.hiddenGeneralCards, isNot(contains('skillTree')));
      final saved = Character.fromJson(c.toJson());
      expect(saved.generalOrder, c.generalOrder);
      expect(saved.hiddenGeneralCards, c.hiddenGeneralCards);

      expect(_card('attributes'), findsNothing);
      expect(_card('skillTree'), findsOneWidget);
      expect(find.byKey(const ValueKey('general-skill-tree')), findsOneWidget);
      expect(tester.getTopLeft(_card('combatCharacter')).dy, lessThan(tester.getTopLeft(_card('sessionOverview')).dy));
      await _finish(tester);
    });

    testWidgets('todos escondidos: aviso abaixo do botão', (tester) async {
      await _pump(tester, character: _character()..hiddenGeneralCards = [..._todayCards, 'skillTree']);
      expect(find.text('Nenhum card visível. Toque em Personalizar para escolher.'), findsOneWidget);
      expect(find.byTooltip('Personalizar'), findsOneWidget);
      await _finish(tester);
    });

    test('toJson/fromJson: hiddenGeneralCards (e o padrão sem a chave)', () {
      final c = _character()..hiddenGeneralCards = ['attributes'];
      final json = c.toJson();
      expect(json['hiddenGeneralCards'], ['attributes']);
      expect(Character.fromJson(json).hiddenGeneralCards, ['attributes']);
      expect(Character.fromJson(json..remove('hiddenGeneralCards')).hiddenGeneralCards, ['skillTree']);
      expect(Character(id: 'x', name: 'X', systemId: 's').hiddenGeneralCards, ['skillTree']);
    });
  });

  group('C: pílulas do Sessão', () {
    for (final (pill, header) in [('1 arma', 'Armas'), ('1 magia', 'Magias'), ('3 consumív', 'Consumíveis'), ('1 negativo', 'Condições ativas')]) {
      testWidgets('"$pill" rola até "$header"', (tester) async {
        // Ordem com o card Sessão em cima e Condições/Ações bem abaixo.
        final c = _character()..generalOrder = [..._sessionFirst];
        await _pump(tester, character: c, height: 700);
        expect(find.text(header).hitTestable(), findsNothing, reason: 'fora da tela antes do toque');
        await tester.tap(find.textContaining(pill));
        await _settle(tester);
        expect(find.text(header).hitTestable(), findsOneWidget);
        await _finish(tester);
      });
    }

    testWidgets('grupo oculto nas Ações: só mostra a mensagem', (tester) async {
      final c = _character()
        ..generalOrder = [..._sessionFirst]
        ..hiddenActionGroups = ['weapons'];
      await _pump(tester, character: c, height: 700);
      await tester.tap(find.text('1 arma'));
      await tester.pump();
      expect(find.text('Esse grupo está oculto. Ative em Personalizar.'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('card Ações escondido no Em Cena: mesma mensagem', (tester) async {
      final c = _character()
        ..generalOrder = [..._sessionFirst]
        ..hiddenGeneralCards = ['skillTree', 'quickActions'];
      await _pump(tester, character: c, height: 700);
      await tester.tap(find.text('1 magia'));
      await tester.pump();
      expect(find.text('Esse grupo está oculto. Ative em Personalizar.'), findsOneWidget);
      await _finish(tester);
    });
  });

  testWidgets('D: consumível com Qtd. 0 vai para o fim do grupo, a 60%', (tester) async {
    await _pump(tester);
    final actions = _card('quickActions');
    double y(String name) => tester.getTopLeft(find.descendant(of: actions, matching: find.text(name))).dy;
    // Ordem do inventário: Elixir (0), Poção, Corda → Poção, Corda, Elixir.
    expect(y('Poção'), lessThan(y('Corda')));
    expect(y('Corda'), lessThan(y('Elixir')));
    final zeroed = tester.widget<Opacity>(find.byKey(const ValueKey('zeroed-Elixir')));
    expect(zeroed.opacity, .6);
    expect(find.byKey(const ValueKey('zeroed-Poção')), findsNothing);
    expect(find.byKey(const ValueKey('zeroed-Corda')), findsNothing);
    // O botão continua desabilitado.
    final button = tester.widget<ButtonStyleButton>(find.descendant(of: find.byKey(const ValueKey('zeroed-Elixir')), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(button.onPressed, isNull);
    // Armas e magias não mudam (sem opacidade).
    expect(find.ancestor(of: find.descendant(of: actions, matching: find.text('Espada')), matching: find.byType(Opacity)), findsNothing);
    await _finish(tester);
  });
}
