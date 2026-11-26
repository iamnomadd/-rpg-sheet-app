// 1.3.64: Inventário, Habilidades e Perícias da ficha — nomes repetidos (A),
// vínculo da munição (B), salvar sem nome (C), ordem dos campos (D), dica da
// ★ (E), lixeira (F), perícias em blocos (G) e plural dos consumíveis (H1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pump(WidgetTester tester, Character character, {RpgSystem? system, String? tab}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setReduceAnimations(true);
  state.systems.insert(0, system ?? RpgSystem(id: 'sys', name: 'Sistema', attributes: ['Força', 'Destreza'], resources: ['Vida', 'Energia']));
  state.characters.add(character);
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(theme: buildAppTheme('classic', false), home: const CharacterScreen(characterId: 'p1')),
  ));
  await _settle(tester);
  if (tab != null) {
    await tester.tap(find.text(tab).first);
    await _settle(tester);
  }
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

Character _char({
  List<String> inventory = const [],
  Map<String, Map<String, dynamic>> inventoryDetails = const {},
  Map<String, String> inventoryDescriptions = const {},
  List<String> abilities = const [],
  Map<String, Map<String, dynamic>> abilityDetails = const {},
  List<String> skills = const [],
}) =>
    Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      attributes: {'Força': 2, 'Destreza': 3},
      resourceValues: {'Vida': 10, 'Energia': 5},
      resourceMaxValues: {'Vida': 10, 'Energia': 5},
      inventory: [...inventory],
      inventoryDetails: {for (final e in inventoryDetails.entries) e.key: {...e.value}},
      inventoryDescriptions: {...inventoryDescriptions},
      abilities: [...abilities],
      abilityDetails: {for (final e in abilityDetails.entries) e.key: {...e.value}},
      skills: [...skills],
    );

Finder get _dialog => find.byType(AlertDialog);

/// Campo de nome do editor (o primeiro TextField do diálogo).
Finder get _nameField => find.descendant(of: _dialog, matching: find.byType(TextField)).first;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.descendant(of: _dialog, matching: find.text('Salvar')));
  await _settle(tester);
}

/// Card da linha do item na lista (aba Inventário/Habilidades).
Finder _row(String name) => find.ancestor(of: find.text(name).last, matching: find.byType(Card)).first;

const _dupItem = 'Já existe um item com esse nome. Aumente a quantidade ou use outro nome.';
const _dupAbility = 'Já existe uma habilidade com esse nome. Use outro nome.';

void main() {
  group('A: nomes repetidos', () {
    testWidgets('adicionar "poção " com "Poção" existente mostra o erro e não altera nada', (tester) async {
      final state = await _pump(tester, _char(inventory: ['Poção'], inventoryDetails: {'Poção': {'category': 'Consumível', 'quantity': 2}}, inventoryDescriptions: {'Poção': 'Cura 10'}), tab: 'Inventário');
      await tester.tap(find.byTooltip('Adicionar'));
      await _settle(tester);
      await tester.enterText(_nameField, 'poção ');
      await _save(tester);
      expect(find.text(_dupItem), findsOneWidget);
      expect(_dialog, findsOneWidget, reason: 'o diálogo continua aberto');
      final c = state.characters.single;
      expect(c.inventory, ['Poção']);
      expect(c.inventoryDetails['Poção']!['quantity'], 2);
      expect(c.inventoryDescriptions['Poção'], 'Cura 10');
      await _finish(tester);
    });

    testWidgets('editar mantendo o próprio nome salva', (tester) async {
      final state = await _pump(tester, _char(inventory: ['Poção'], inventoryDetails: {'Poção': {'category': 'Consumível', 'quantity': 2}}), tab: 'Inventário');
      await tester.tap(_row('Poção'));
      await _settle(tester);
      expect(find.text('Editar item'), findsOneWidget);
      await _save(tester);
      expect(_dialog, findsNothing);
      expect(state.characters.single.inventory, ['Poção']);
      await _finish(tester);
    });

    testWidgets('renomear para o nome de outro item mostra o erro', (tester) async {
      final state = await _pump(tester, _char(inventory: ['Poção', 'Corda'], inventoryDetails: {'Poção': {'category': 'Consumível'}, 'Corda': {'category': 'Ferramenta'}}), tab: 'Inventário');
      await tester.tap(_row('Corda'));
      await _settle(tester);
      await tester.enterText(_nameField, 'POÇÃO');
      await _save(tester);
      expect(find.text(_dupItem), findsOneWidget);
      expect(_dialog, findsOneWidget);
      expect(state.characters.single.inventory, ['Poção', 'Corda']);
      expect(state.characters.single.inventoryDetails['Corda']!['category'], 'Ferramenta');
      await _finish(tester);
    });

    testWidgets('habilidades: mesmo comportamento e mensagem própria; item com o mesmo nome não conta', (tester) async {
      final state = await _pump(
        tester,
        _char(abilities: ['Bola de Fogo'], abilityDetails: {'Bola de Fogo': {'category': 'Magia', 'cost': 2}}, inventory: ['Lanterna'], inventoryDetails: {'Lanterna': {'category': 'Ferramenta'}}),
        tab: 'Habilidades',
      );
      await tester.tap(find.byTooltip('Adicionar'));
      await _settle(tester);
      await tester.enterText(_nameField, ' bola de fogo');
      await _save(tester);
      expect(find.text(_dupAbility), findsOneWidget);
      expect(_dialog, findsOneWidget);
      expect(state.characters.single.abilities, ['Bola de Fogo']);
      expect(state.characters.single.abilityDetails['Bola de Fogo']!['cost'], 2);
      // Uma habilidade pode ter o nome de um item.
      await tester.enterText(_nameField, 'Lanterna');
      await _save(tester);
      expect(_dialog, findsNothing);
      expect(state.characters.single.abilities, ['Bola de Fogo', 'Lanterna']);
      await _finish(tester);
    });

    testWidgets('ficha antiga com nomes repetidos: excluir uma linha mantém os detalhes da outra', (tester) async {
      final state = await _pump(tester, _char(inventory: ['Poção', 'Poção'], inventoryDetails: {'Poção': {'category': 'Consumível', 'quantity': 3}}, inventoryDescriptions: {'Poção': 'Cura 10'}), tab: 'Inventário');
      await tester.tap(find.byTooltip('Excluir').first);
      await _settle(tester);
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Excluir')));
      await _settle(tester);
      final c = state.characters.single;
      expect(c.inventory, ['Poção']);
      expect(c.inventoryDetails['Poção']!['quantity'], 3);
      expect(c.inventoryDescriptions['Poção'], 'Cura 10');
      await _finish(tester);
    });
  });

  group('B: vínculo da munição', () {
    Character armed() => _char(
          inventory: ['Pistola', 'Balas', 'Rifle'],
          inventoryDetails: {
            'Pistola': {'category': 'Arma', 'ammo': 0, 'ammoMax': 6, 'ammoItem': 'Balas'},
            'Balas': {'category': 'Munição', 'quantity': 10},
            'Rifle': {'category': 'Arma', 'ammo': 0, 'ammoMax': 4, 'ammoItem': 'Balas'},
          },
        );

    testWidgets('renomear o estoque atualiza as armas; recarregar depois funciona', (tester) async {
      final state = await _pump(tester, armed(), tab: 'Inventário');
      await tester.tap(_row('Balas'));
      await _settle(tester);
      await tester.enterText(_nameField, 'Balas 9mm');
      await _save(tester);
      final c = state.characters.single;
      expect(c.inventory, contains('Balas 9mm'));
      expect(c.inventoryDetails['Pistola']!['ammoItem'], 'Balas 9mm');
      expect(c.inventoryDetails['Rifle']!['ammoItem'], 'Balas 9mm');
      // Recarregar a Pistola no Em Cena usa o estoque renomeado.
      await tester.tap(find.text('Em Cena').first);
      await _settle(tester);
      final pistolRow = find.ancestor(of: find.text('Pistola').last, matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: pistolRow, matching: find.byTooltip('Recarregar')));
      await _settle(tester);
      expect(c.inventoryDetails['Pistola']!['ammo'], 6);
      expect(c.inventoryDetails['Balas 9mm']!['quantity'], 4);
      await _finish(tester);
    });

    testWidgets('excluir o estoque limpa o vínculo das armas', (tester) async {
      final state = await _pump(tester, armed(), tab: 'Inventário');
      await tester.tap(find.descendant(of: _row('Balas'), matching: find.byTooltip('Excluir')));
      await _settle(tester);
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Excluir')));
      await _settle(tester);
      final c = state.characters.single;
      expect(c.inventory, ['Pistola', 'Rifle']);
      expect(c.inventoryDetails['Pistola']!['ammoItem'], '');
      expect(c.inventoryDetails['Rifle']!['ammoItem'], '');
      await _finish(tester);
    });
  });

  testWidgets('C: salvar sem nome mostra "Dê um nome." e o erro some ao digitar', (tester) async {
    final state = await _pump(tester, _char(), tab: 'Inventário');
    await tester.tap(find.byTooltip('Adicionar'));
    await _settle(tester);
    await _save(tester);
    expect(find.text('Dê um nome.'), findsOneWidget);
    expect(_dialog, findsOneWidget);
    expect(state.characters.single.inventory, isEmpty);
    await tester.enterText(_nameField, 'C');
    await tester.pump();
    expect(find.text('Dê um nome.'), findsNothing);
    await _finish(tester);
  });

  group('D: a Descrição é o último campo do editor', () {
    String lastLabel(WidgetTester tester) {
      final decorators = tester.widgetList<InputDecorator>(find.descendant(of: _dialog, matching: find.byType(InputDecorator))).toList();
      decorators.sort((a, b) => tester.getTopLeft(find.byWidget(a)).dy.compareTo(tester.getTopLeft(find.byWidget(b)).dy));
      return decorators.last.decoration.labelText ?? '';
    }

    String firstLabel(WidgetTester tester) => tester.widget<TextField>(_nameField).decoration?.labelText ?? '';

    testWidgets('item (arma, com dano, munição e estoque)', (tester) async {
      await _pump(tester, _char(inventory: ['Pistola'], inventoryDetails: {'Pistola': {'category': 'Arma', 'ammoMax': 6}}), tab: 'Inventário');
      await tester.tap(_row('Pistola'));
      await _settle(tester);
      expect(firstLabel(tester), 'Nome do item');
      expect(lastLabel(tester), 'Descrição');
      await _finish(tester);
    });

    testWidgets('habilidade (magia, com custo e duração por turnos)', (tester) async {
      await _pump(tester, _char(abilities: ['Bola de Fogo'], abilityDetails: {'Bola de Fogo': {'category': 'Magia', 'durationType': 'turns', 'turns': '2'}}), tab: 'Habilidades');
      await tester.tap(_row('Bola de Fogo'));
      await _settle(tester);
      expect(firstLabel(tester), 'Nome da habilidade');
      expect(lastLabel(tester), 'Descrição');
      await _finish(tester);
    });
  });

  testWidgets('E: dica da ★ "Fixar no Em Cena" / "Desafixar do Em Cena"', (tester) async {
    final state = await _pump(tester, _char(inventory: ['Corda'], inventoryDetails: {'Corda': {'category': 'Ferramenta'}}), tab: 'Inventário');
    expect(find.byTooltip('Fixar no Em Cena'), findsOneWidget);
    expect(find.byTooltip('Em Cena'), findsNothing);
    await tester.tap(find.byTooltip('Fixar no Em Cena'));
    await _settle(tester);
    expect(state.characters.single.inventoryDetails['Corda']!['showInScene'], isTrue);
    expect(find.byTooltip('Desafixar do Em Cena'), findsOneWidget);
    expect(find.byTooltip('Remover de Em Cena'), findsNothing);
    await _finish(tester);
  });

  group('F: lixeira no lugar dos três pontinhos', () {
    for (final tab in ['Inventário', 'Habilidades']) {
      testWidgets('$tab: sem PopupMenuButton nas linhas; a lixeira pede confirmação e exclui; tocar abre a edição', (tester) async {
        final ability = tab == 'Habilidades';
        final state = await _pump(
          tester,
          ability
              ? _char(abilities: ['Golpe', 'Sentidos', 'Escudo'], abilityDetails: {'Golpe': {'category': 'Técnica'}, 'Sentidos': {'category': 'Passiva'}, 'Escudo': {'category': 'Magia'}})
              : _char(inventory: ['Espada', 'Poção', 'Corda'], inventoryDetails: {'Espada': {'category': 'Arma'}, 'Poção': {'category': 'Consumível'}, 'Corda': {'category': 'Ferramenta'}}),
          tab: tab,
        );
        final names = ability ? ['Golpe', 'Sentidos', 'Escudo'] : ['Espada', 'Poção', 'Corda'];
        for (final name in names) {
          expect(find.descendant(of: _row(name), matching: find.byWidgetPredicate((w) => w is PopupMenuButton)), findsNothing, reason: name);
          final trash = tester.widget<IconButton>(find.descendant(of: _row(name), matching: find.widgetWithIcon(IconButton, Icons.delete_outline)));
          expect(trash.tooltip, 'Excluir');
          expect((trash.icon as Icon).size, 20);
        }
        // Tocar na linha abre a edição.
        await tester.tap(find.text(names.first).last);
        await _settle(tester);
        expect(find.text(ability ? 'Editar habilidade' : 'Editar item'), findsOneWidget);
        await tester.tap(find.descendant(of: _dialog, matching: find.text('Cancelar')));
        await _settle(tester);
        // A lixeira pede confirmação: cancelar não exclui; confirmar exclui.
        await tester.tap(find.descendant(of: _row(names[1]), matching: find.byTooltip('Excluir')));
        await _settle(tester);
        expect(find.textContaining('será removido desta ficha'), findsOneWidget);
        await tester.tap(find.descendant(of: _dialog, matching: find.text('Cancelar')));
        await _settle(tester);
        final list = ability ? state.characters.single.abilities : state.characters.single.inventory;
        expect(list, names);
        await tester.tap(find.descendant(of: _row(names[1]), matching: find.byTooltip('Excluir')));
        await _settle(tester);
        await tester.tap(find.descendant(of: _dialog, matching: find.text('Excluir')));
        await _settle(tester);
        expect(list, [names[0], names[2]]);
        await _finish(tester);
      });
    }
  });

  group('G: perícias', () {
    final system = RpgSystem(
      id: 'sys',
      name: 'Sistema',
      attributes: ['Força', 'Destreza'],
      resources: ['Vida', 'Energia'],
      skills: ['Furtividade', 'Atletismo', 'Percepção'],
      skillAttributes: {'Furtividade': 'Destreza', 'Percepção': 'Força'},
    );

    testWidgets('blocos Treinadas/Outras, atributo do toque e marcar move de bloco', (tester) async {
      await _pump(tester, _char(skills: ['Percepção']), system: system, tab: 'Perícias');
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(find.text('Treinadas'), findsOneWidget);
      expect(find.text('Outras'), findsOneWidget);
      expect(y('Treinadas'), lessThan(y('Percepção')));
      expect(y('Percepção'), lessThan(y('Outras')));
      // Outras, na ordem do sistema.
      expect(y('Outras'), lessThan(y('Furtividade')));
      expect(y('Furtividade'), lessThan(y('Atletismo')));
      // Atributo do toque.
      final furtividade = find.ancestor(of: find.text('Furtividade'), matching: find.byType(ListTile));
      expect(find.descendant(of: furtividade, matching: find.text('Rola com Destreza')), findsOneWidget);
      final atletismo = find.ancestor(of: find.text('Atletismo'), matching: find.byType(ListTile));
      expect(find.descendant(of: atletismo, matching: find.text('Segure para escolher o atributo')), findsOneWidget);
      expect(find.textContaining('Perícias selecionadas'), findsNothing);
      // Marcar Atletismo: vai para Treinadas, na ordem do sistema (antes de Percepção).
      await tester.tap(find.descendant(of: atletismo, matching: find.byType(Checkbox)));
      await _settle(tester);
      expect(y('Treinadas'), lessThan(y('Atletismo')));
      expect(y('Atletismo'), lessThan(y('Percepção')));
      expect(y('Percepção'), lessThan(y('Outras')));
      expect(y('Outras'), lessThan(y('Furtividade')));
      await _finish(tester);
    });

    testWidgets('bloco vazio não mostra o título', (tester) async {
      await _pump(tester, _char(), system: system, tab: 'Perícias');
      expect(find.text('Treinadas'), findsNothing);
      expect(find.text('Outras'), findsOneWidget);
      await _finish(tester);
      await _pump(tester, _char(skills: ['Furtividade', 'Atletismo', 'Percepção']), system: system, tab: 'Perícias');
      expect(find.text('Treinadas'), findsOneWidget);
      expect(find.text('Outras'), findsNothing);
      await _finish(tester);
    });
  });

  group('H1: plural da pílula de consumíveis', () {
    for (final (count, label) in [(1, '1 consumível'), (3, '3 consumíveis')]) {
      testWidgets(label, (tester) async {
        await _pump(tester, _char(
          inventory: [for (var i = 0; i < count; i++) 'Poção $i'],
          inventoryDetails: {for (var i = 0; i < count; i++) 'Poção $i': {'category': 'Consumível'}},
        ));
        expect(find.text(label), findsOneWidget);
        expect(find.textContaining('consumívelis'), findsNothing);
        await _finish(tester);
      });
    }
  });
}
