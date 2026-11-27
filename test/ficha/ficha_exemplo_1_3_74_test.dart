// 1.3.74 — "Ficha de exemplo".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/home/home_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/example_character.dart';
import 'package:rpg_sheet_app/utils/action_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.load();
  return state;
}

void main() {
  test('o Tormenta20 é um sistema padrão com PV, PM e Furtividade (nenhum sistema alterado)', () async {
    final state = await _state();
    final system = state.systems.firstWhere((s) => s.id == 'tormenta20');
    expect(system.resources, ['PV', 'PM']);
    expect(system.skills, contains('Furtividade'));
    expect(system.sections, contains('Anotações'));
  });

  test('conteúdo da ficha de exemplo', () async {
    final state = await _state();
    final systemsBefore = state.systems.map((s) => s.toJson().toString()).toList();
    final c = (await createExampleCharacter(state))!;
    expect(c.name, 'Aaron');
    expect(c.systemId, 'tormenta20');
    expect(state.characters.single.id, c.id, reason: 'é uma ficha normal, salva no estado');
    // Barras de PV e PM abaixo do máximo.
    expect(c.resourceValues, {'PV': 18, 'PM': 7});
    expect(c.resourceMaxValues, {'PV': 24, 'PM': 10});
    // Atributos do sistema, todos preenchidos.
    final system = state.systems.firstWhere((s) => s.id == 'tormenta20');
    expect(c.attributes.keys.toSet(), system.attributes.toSet());
    // 1 item de cada uma das 7 categorias.
    final itemCategories = [for (final i in c.inventory) c.inventoryDetails[i]!['category']];
    expect(itemCategories, ['Arma', 'Armadura', 'Consumível', 'Munição', 'Acessório', 'Ferramenta', 'Outro']);
    expect(c.inventory, ['Espada curta', 'Gibão de couro', 'Poção de cura', 'Flechas', 'Amuleto de prata', 'Kit de ladino', 'Mapa rasgado']);
    expect(c.inventoryDetails['Espada curta']!['damage'], isNotEmpty);
    expect(c.inventoryDetails['Poção de cura']!['quantity'], 2);
    expect(c.inventoryDetails['Flechas']!['quantity'], 20);
    expect(c.inventoryDetails['Espada curta']!['ammoItem'], '', reason: 'munição sem vínculo');
    for (final item in c.inventory) {
      expect(c.inventoryDescriptions[item], isNotEmpty, reason: item);
      expect(c.inventoryDetails[item]!['showInScene'], isFalse, reason: item);
    }
    // 1 habilidade de cada uma das 5 categorias.
    final abilityCategories = [for (final a in c.abilities) c.abilityDetails[a]!['category']];
    expect(abilityCategories, ['Habilidade', 'Magia', 'Técnica', 'Passiva', 'Outro']);
    expect(c.abilities, ['Golpe preciso', 'Seta arcana', 'Esquiva acrobática', 'Visão no escuro', 'Contatos na guilda']);
    expect(c.abilityDetails['Seta arcana']!['cost'], 2);
    expect(c.abilityDetails['Seta arcana']!['resource'], 'PM');
    for (final ability in c.abilities) {
      expect(c.abilityDescriptions[ability], isNotEmpty, reason: ability);
      expect(c.abilityDetails[ability]!['showInScene'], isFalse, reason: ability);
    }
    // Resumo na seção "Anotações", com 2 a 4 frases.
    final summary = c.sectionNotes['Anotações']!;
    final sentences = summary.split('.').where((s) => s.trim().isNotEmpty).length;
    expect(sentences, inInclusiveRange(2, 4));
    expect(summary, startsWith('Aaron é um aventureiro'));
    // Perícia treinada do sistema.
    expect(c.skills, ['Furtividade']);
    // Sem condições.
    expect(c.conditions, isEmpty);
    // Nenhum sistema mudou.
    expect(state.systems.map((s) => s.toJson().toString()).toList(), systemsBefore);
  });

  test('o detector de arte reconhece os itens e magias como qualquer outro', () async {
    final state = await _state();
    final c = (await createExampleCharacter(state))!;
    String? art(ActionArtKind kind, String name, Map<String, Map<String, dynamic>> details, Map<String, String> descriptions) =>
        ActionArtResolver.resolve(kind: kind, name: name, description: descriptions[name] ?? '', category: '${details[name]!['category']}');
    expect(art(ActionArtKind.weapon, 'Espada curta', c.inventoryDetails, c.inventoryDescriptions), isNotNull);
    expect(art(ActionArtKind.item, 'Poção de cura', c.inventoryDetails, c.inventoryDescriptions), isNotNull);
    expect(art(ActionArtKind.spell, 'Seta arcana', c.abilityDetails, c.abilityDescriptions), isNotNull);
  });

  test('criar duas vezes gera nomes diferentes', () async {
    final state = await _state();
    final a = await createExampleCharacter(state);
    final b = await createExampleCharacter(state);
    final c = await createExampleCharacter(state);
    // 1.3.75: nomes da lista de 5 (o primeiro é sempre "Aaron").
    expect(a!.name, 'Aaron');
    expect({a.name, b!.name, c!.name}, hasLength(3));
  });

  test('a ficha de exemplo pode ser apagada', () async {
    final state = await _state();
    final c = await createExampleCharacter(state);
    await state.deleteCharacter(c!.id);
    expect(state.characters, isEmpty);
  });

  Future<AppState> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _state();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: HomeScreen())));
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('lista vazia: botão "Criar ficha de exemplo" cria e abre a ficha, com barras PV e PM', (tester) async {
    final state = await pumpHome(tester);
    expect(find.text('Criar primeira ficha'), findsOneWidget);
    expect(find.text('Criar ficha de exemplo'), findsOneWidget);
    await tester.tap(find.text('Criar ficha de exemplo'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.characters.single.name, 'Aaron');
    expect(find.byType(CharacterScreen), findsOneWidget);
    expect(find.text('18 / 24'), findsOneWidget);
    expect(find.text('7 / 10'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('"Ficha de exemplo" também no fluxo de nova ficha', (tester) async {
    final state = await pumpHome(tester);
    await createExampleCharacter(state);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Criar ficha de exemplo'), findsNothing, reason: 'só no estado vazio');
    await tester.tap(find.byTooltip('Nova ficha'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ficha de exemplo'), findsOneWidget);
    await tester.tap(find.text('Ficha de exemplo'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.characters.first.name, 'Aaron');
    expect(state.characters, hasLength(2));
    expect(state.characters.last.name, isIn(['Kael', 'Selene', 'Dorian', 'Mira']));
    expect(find.byType(CharacterScreen), findsOneWidget);
    await finish(tester);
  });
}
