// 1.3.77 — as funções da Árvore de Habilidades são ligadas/desligadas no
// SISTEMA (todas desligadas por padrão) e correção do achado da 1.3.76.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/screens/systems/system_editor_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/skill_tree_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _flags = ['treeBranches', 'treeTiers', 'treeRanks', 'treeExclusive', 'treeAbilityLink'];

RpgSystem _system({
  bool branches = false,
  bool tiers = false,
  bool ranks = false,
  bool exclusive = false,
  bool requirement = false,
  bool abilityLink = false,
}) =>
    RpgSystem(
      id: 'sys',
      name: 'Sistema',
      attributes: ['Força'],
      resources: ['PV', 'PM'],
      treeBranches: branches,
      treeTiers: tiers,
      treeRanks: ranks,
      treeExclusive: exclusive,
      treeAttributeRequirement: requirement,
      treeAbilityLink: abilityLink,
    );

/// Árvore com TODOS os dados da 1.3.76 salvos (ramo, tipo, níveis, grupo,
/// requisito e habilidade).
List<Map<String, dynamic>> _richTree() => [
      {'id': 'a', 'name': 'Nó a', 'description': 'A', 'parentId': '', 'level': 1, 'unlocked': true, 'tier': 'lenda', 'maxRank': 3, 'rank': 2, 'branchId': 'r1', 'exclusiveGroup': 'g'},
      {'id': 'b', 'name': 'Nó b', 'description': 'B', 'parentId': '', 'level': 1, 'unlocked': false, 'exclusiveGroup': 'g', 'addToAbilities': true, 'ability': {'category': 'Magia', 'cost': 2, 'resource': 'PM'}},
    ];

Character _character(List<Map<String, dynamic>> tree) => Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      attributes: {'Força': 10},
      resourceValues: {'PV': 10, 'PM': 5},
      resourceMaxValues: {'PV': 10, 'PM': 5},
      skillTree: tree,
      skillTreeBranches: [
        {'id': 'r1', 'name': 'Fúria', 'color': 0xFFFF6B6B},
      ],
    );

void main() {
  group('RpgSystem', () {
    test('os 5 campos novos começam false, só vão para o JSON quando true e JSON antigo abre sem erro', () {
      final plain = RpgSystem(id: 'x', name: 'Novo');
      expect([plain.treeBranches, plain.treeTiers, plain.treeRanks, plain.treeExclusive, plain.treeAbilityLink], everyElement(isFalse));
      final json = plain.toJson();
      for (final flag in _flags) {
        expect(json.containsKey(flag), isFalse, reason: flag);
      }
      final old = RpgSystem.fromJson({'id': 'old', 'name': 'Antigo', 'attributes': ['FOR']});
      expect([old.treeBranches, old.treeTiers, old.treeRanks, old.treeExclusive, old.treeAbilityLink, old.treeAttributeRequirement], everyElement(isFalse));
      final all = _system(branches: true, tiers: true, ranks: true, exclusive: true, requirement: true, abilityLink: true);
      final written = all.toJson();
      for (final flag in [..._flags, 'treeAttributeRequirement']) {
        expect(written[flag], isTrue, reason: flag);
      }
      final back = RpgSystem.fromJson(jsonDecode(jsonEncode(written)) as Map<String, dynamic>);
      expect([back.treeBranches, back.treeTiers, back.treeRanks, back.treeExclusive, back.treeAbilityLink, back.treeAttributeRequirement], everyElement(isTrue));
    });

    test('cópia, duplicar e exportar/importar levam os interruptores', () async {
      final source = _system(branches: true, ranks: true, abilityLink: true);
      final copy = source.copyWith(id: 'novo', name: 'Cópia');
      expect([copy.treeBranches, copy.treeTiers, copy.treeRanks, copy.treeExclusive, copy.treeAbilityLink], [true, false, true, false, true]);
      // Exportar = toJson; importar = fromJson + copyWith (id e nome novos).
      final imported = RpgSystem.fromJson(jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>).copyWith(id: 'imp', name: 'Importado');
      expect([imported.treeBranches, imported.treeRanks, imported.treeAbilityLink], everyElement(isTrue));
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      state.systems.add(source);
      final duplicated = (await state.duplicateSystem('sys'))!;
      expect([duplicated.treeBranches, duplicated.treeRanks, duplicated.treeAbilityLink], everyElement(isTrue));
      expect(duplicated.treeTiers, isFalse);
    });

    test('os sistemas padrão começam com tudo desligado', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();
      for (final s in state.systems) {
        expect(SkillTreeFeatures.of(s).anyMoreOptions || s.treeBranches, isFalse, reason: s.id);
      }
      expect(SkillTreeFeatures.of(null).anyMoreOptions, isFalse, reason: 'sistema apagado: tudo desligado');
    });
  });

  testWidgets('editor de sistemas: seção "Árvore de Habilidades" com os interruptores desligados (1.3.78: sem "Tipos")', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    await state.load();
    final system = RpgSystem(id: 'novo', name: 'Novo');
    state.systems.add(system);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(home: SystemEditorScreen(system: system))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Árvore de Habilidades'), findsOneWidget);
    final expected = {
      'tree-branches': ('Ramos', 'Divide a árvore em ramos com nome e cor.'),
      'tree-ranks': ('Aprimoramento', 'Cada habilidade sobe até 3 pontos: Talento → Façanha → Lenda.'),
      'tree-exclusive': ('Escolhas exclusivas', "Permite 'escolha uma das duas'."),
      'tree-attribute-requirement': ('Requisito de atributo', 'Exige um atributo mínimo para desbloquear.'),
      'tree-ability-link': ('Adicionar às Habilidades', 'Ao desbloquear, a habilidade aparece em Habilidades e Ações.'),
    };
    expect(find.byKey(const ValueKey('tree-tiers')), findsNothing);
    for (final entry in expected.entries) {
      final tile = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(tile);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse, reason: entry.key);
      expect(find.descendant(of: tile, matching: find.text(entry.value.$1)), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text(entry.value.$2)), findsOneWidget);
    }
    // Ligar e salvar grava no sistema.
    await tester.tap(find.byKey(const ValueKey('tree-ranks')));
    await tester.pump();
    await tester.ensureVisible(find.text('Salvar sistema'));
    await tester.tap(find.text('Salvar sistema'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.systems.firstWhere((s) => s.id == 'novo').treeRanks, isTrue);
  });

  group('a árvore obedece ao sistema', () {
    late AppState state;

    Future<Character> pump(WidgetTester tester, RpgSystem system, {List<Map<String, dynamic>>? tree}) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      await state.load();
      state.systems.insert(0, system);
      final character = _character(tree ?? _richTree());
      state.characters.add(character);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('abyss', false), home: SkillTreeScreen(characterId: character.id)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      return character;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> openNewEditor(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Nova habilidade'));
      await settle(tester);
    }

    Future<void> setSystem(WidgetTester tester, RpgSystem system) async {
      state.systems[0] = system;
      await state.updateCharacter(state.characters.single);
      await settle(tester);
    }

    testWidgets('tudo desligado: árvore como antes da 1.3.76 e editor sem "Mais opções" (dados guardados)', (tester) async {
      final c = await pump(tester, _system());
      final before = jsonEncode(c.toJson()['skillTree']);
      expect(find.text('Nível 1 • Desbloqueada'), findsOneWidget, reason: 'sem "2/3"');
      expect(find.text('Nível 1 • Disponível'), findsOneWidget, reason: 'nada fechado');
      expect(find.textContaining('/3'), findsNothing);
      expect(find.text('Lenda'), findsNothing);
      expect(find.text('Geral'), findsNothing);
      expect(find.text('Fúria'), findsNothing);
      expect(find.byTooltip('Ramos'), findsNothing);
      expect(find.byKey(const ValueKey('skill-tree-tier-legend')), findsNothing);
      await openNewEditor(tester);
      expect(find.text('Mais opções'), findsNothing);
      expect(find.byKey(const ValueKey('node-branch')), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      // Desligar só esconde.
      expect(jsonEncode(c.toJson()['skillTree']), before);
      expect(c.skillTreeBranches, hasLength(1));
    });

    testWidgets('cada interruptor ligado sozinho mostra só a sua função', (tester) async {
      await pump(tester, _system());
      Future<void> editorShows(Set<String> keys) async {
        await openNewEditor(tester);
        // Ramos fica no editor principal; "Mais opções" só com as outras.
        if (keys.difference({'branches'}).isEmpty) {
          expect(find.text('Mais opções'), findsNothing);
        } else {
          await tester.tap(find.text('Mais opções'));
          await settle(tester);
        }
        // 1.3.78: sem Tipo e sem quantidade de níveis; com Aprimoramento, os 3 textos.
        expect(find.byKey(const ValueKey('node-tier')), findsNothing);
        expect(find.byKey(const ValueKey('node-max-rank')), findsNothing);
        expect(find.byKey(const ValueKey('node-rank-text-3')), keys.contains('ranks') ? findsOneWidget : findsNothing);
        expect(find.text('Escolha exclusiva com…'), keys.contains('exclusive') ? findsOneWidget : findsNothing);
        expect(find.byKey(const ValueKey('node-req-attribute')), keys.contains('requirement') ? findsOneWidget : findsNothing);
        expect(find.byKey(const ValueKey('node-add-ability')), keys.contains('ability') ? findsOneWidget : findsNothing);
        expect(find.byKey(const ValueKey('node-branch')), keys.contains('branches') ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Cancelar'));
        await settle(tester);
      }

      // Ramos: seções e gerenciador; o campo Ramo fica no editor principal.
      await setSystem(tester, _system(branches: true));
      expect(find.byTooltip('Ramos'), findsOneWidget);
      expect(find.text('Fúria'), findsOneWidget);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Lenda'), findsNothing);
      await editorShows({'branches'});

      // 1.3.78: um sistema salvo só com "Tipos" conta como Aprimoramento ligado.
      // O nó com nível 2 aparece como Façanha (o tier 'lenda' salvo é ignorado).
      await setSystem(tester, _system(tiers: true));
      expect(find.text('Façanha'), findsOneWidget);
      expect(find.text('Lenda'), findsNothing);
      expect(find.byKey(const ValueKey('skill-tree-tier-legend')), findsOneWidget);
      expect(find.text('Fúria'), findsNothing);
      await editorShows({'ranks'});

      // Aprimoramento: selo pelo nível, sem "2/3".
      await setSystem(tester, _system(ranks: true));
      expect(find.text('Nível 1 • Desbloqueada'), findsOneWidget);
      expect(find.textContaining('/3'), findsNothing);
      expect(find.text('Façanha'), findsOneWidget);
      await editorShows({'ranks'});

      // Escolhas exclusivas: B fica fechada.
      await setSystem(tester, _system(exclusive: true));
      expect(find.text('Nível 1 • Fechada'), findsOneWidget);
      await editorShows({'exclusive'});

      await setSystem(tester, _system(requirement: true));
      await editorShows({'requirement'});

      await setSystem(tester, _system(abilityLink: true));
      await editorShows({'ability'});

      // Desligar de novo: tudo volta a ficar escondido, e os dados continuam.
      await setSystem(tester, _system());
      expect(find.text('Nível 1 • Disponível'), findsOneWidget);
      final a = state.characters.single.skillTree.first;
      expect([a['tier'], a['maxRank'], a['rank'], a['branchId'], a['exclusiveGroup']], ['lenda', 3, 2, 'r1', 'g']);
    });

    testWidgets('editar um nó com funções desligadas não apaga os dados delas', (tester) async {
      final c = await pump(tester, _system());
      await tester.tap(find.text('Nó a'));
      await settle(tester);
      await tester.tap(find.byTooltip('Editar'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Nova descrição');
      await tester.tap(find.text('Salvar'));
      await settle(tester);
      final a = c.skillTree.first;
      expect(a['description'], 'Nova descrição');
      expect([a['tier'], a['maxRank'], a['rank'], a['branchId'], a['exclusiveGroup']], ['lenda', 3, 2, 'r1', 'g']);
      expect(c.skillTree.last['ability'], {'category': 'Magia', 'cost': 2, 'resource': 'PM'});
    });

    testWidgets('Aprimoramento desligado: o botão é Bloquear; o nível salvo fica guardado enquanto desbloqueado', (tester) async {
      final c = await pump(tester, _system(), tree: [
        {'id': 'a', 'name': 'Nó a', 'parentId': '', 'level': 1, 'unlocked': true, 'maxRank': 3, 'rank': 2},
      ]);
      expect(find.text('Nível 1 • Desbloqueada'), findsOneWidget);
      await tester.tap(find.text('Nó a'));
      await settle(tester);
      expect(find.text('Aprimorar'), findsNothing);
      expect(find.text('Reduzir'), findsNothing);
      expect(find.text('Bloquear'), findsOneWidget);
      expect(nodeRank(c.skillTree.single), 2);
      await tester.tap(find.text('Bloquear'));
      await settle(tester);
      expect(nodeRank(c.skillTree.single), 0);
    });

    testWidgets('Adicionar às Habilidades desligado: desbloquear não cria habilidade e bloquear não pergunta', (tester) async {
      final c = await pump(tester, _system(), tree: [
        {'id': 'b', 'name': 'Nó b', 'parentId': '', 'level': 1, 'unlocked': false, 'addToAbilities': true, 'ability': {'category': 'Magia'}},
      ]);
      await tester.tap(find.byTooltip('Desbloquear'));
      await settle(tester);
      expect(nodeRank(c.skillTree.single), 1);
      expect(c.abilities, isEmpty);
      // Habilidade já criada antes continua; bloquear não pergunta nem remove.
      c.abilities.add('Nó b');
      c.abilityDetails['Nó b'] = {'category': 'Magia', 'fromTree': 'b'};
      await tester.tap(find.byTooltip('Bloquear'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(nodeRank(c.skillTree.single), 0);
      expect(c.abilities, ['Nó b']);
    });
  });

  group('achado da 1.3.76: editar o nó não apaga ajustes da habilidade', () {
    testWidgets('editar só a descrição mantém custo/dano ajustados; mudar o custo no nó atualiza o custo', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      state.systems.insert(0, _system(abilityLink: true));
      final node = <String, dynamic>{
        'id': 'a',
        'name': 'Seta arcana',
        'description': 'Raio mágico.',
        'parentId': '',
        'level': 1,
        'unlocked': true,
        'rank': 1,
        'addToAbilities': true,
        'ability': {'category': 'Magia', 'cost': 2, 'resource': 'PM', 'damage': '1d6', 'durationType': 'instant', 'turns': ''},
      };
      final c = _character([node]);
      syncNodeAbility(c, node);
      // Ajuste feito na aba Habilidades.
      c.abilityDetails['Seta arcana']!['cost'] = 5;
      c.abilityDetails['Seta arcana']!['damage'] = '3d6';
      state.characters.add(c);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('abyss', false), home: SkillTreeScreen(characterId: c.id)),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      Future<void> openEditor() async {
        await tester.tap(find.text('Seta arcana'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byTooltip('Editar'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> save() async {
        await tester.tap(find.text('Salvar'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await openEditor();
      await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Raio mágico que nunca erra.');
      await save();
      expect(c.abilityDescriptions['Seta arcana'], 'Raio mágico que nunca erra.');
      expect(c.abilityDetails['Seta arcana']!['cost'], 5, reason: 'ajuste da aba Habilidades mantido');
      expect(c.abilityDetails['Seta arcana']!['damage'], '3d6');
      expect(c.abilityDetails['Seta arcana']!['fromTree'], 'a');

      await openEditor();
      await tester.tap(find.text('Mais opções'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.enterText(find.widgetWithText(TextField, 'Custo'), '4');
      await save();
      expect(c.abilityDetails['Seta arcana']!['cost'], 4, reason: 'custo mudado no editor do nó');
    });

    test('desbloquear pela primeira vez cria a habilidade com todos os campos do nó', () {
      final node = <String, dynamic>{'id': 'a', 'name': 'Golpe', 'addToAbilities': true, 'ability': {'category': 'Técnica', 'cost': 3, 'resource': 'PM', 'damage': '2d6'}};
      final c = _character([node]);
      setNodeRank(node, 1);
      expect(syncNodeAbility(c, node), isTrue);
      expect(c.abilityDetails['Golpe']!['category'], 'Técnica');
      expect(c.abilityDetails['Golpe']!['cost'], 3);
      expect(c.abilityDetails['Golpe']!['damage'], '2d6');
    });
  });
}
