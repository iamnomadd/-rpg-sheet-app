// 1.3.78 — Talento/Façanha/Lenda automáticos pelo nível (1/2/3), "Tipos" unido
// ao Aprimoramento no sistema, e a aba "Árvore" fora da barra principal.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/screens/systems/system_editor_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/skill_tree_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

RpgSystem _system({bool ranks = true, bool tiers = false}) =>
    RpgSystem(id: 'sys', name: 'Sistema', attributes: ['Força'], resources: ['PV'], treeRanks: ranks, treeTiers: tiers);

Character _character(List<Map<String, dynamic>> tree) => Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      resourceValues: {'PV': 10},
      resourceMaxValues: {'PV': 10},
      skillTree: tree,
    );

void main() {
  late AppState state;

  Future<Character> pump(WidgetTester tester, RpgSystem system, List<Map<String, dynamic>> tree) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false, 'reduce_animations': true});
    state = AppState();
    await state.load();
    state.systems.insert(0, system);
    final c = _character(tree);
    state.characters.add(c);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('abyss', false), home: SkillTreeScreen(characterId: c.id)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  double cardHeight(WidgetTester tester, String name) => tester.getSize(find.ancestor(of: find.text(name), matching: find.byType(Material)).first).height;

  test('skillTreeTierLabel recebe o nível: 1 Talento, 2 Façanha, 3 Lenda', () {
    expect([skillTreeTierLabel(1), skillTreeTierLabel(2), skillTreeTierLabel(3)], ['Talento', 'Façanha', 'Lenda']);
    expect(skillTreeRanksLegend, 'Cada habilidade sobe até 3 pontos: Talento → Façanha → Lenda.');
  });

  testWidgets('aprimorar 1 → 2 → 3 muda o visual, não passa de 3 e reduzir volta o visual', (tester) async {
    final c = await pump(tester, _system(), [
      {'id': 'a', 'name': 'Nó a', 'parentId': '', 'level': 1, 'unlocked': true, 'rankTexts': ['Dano 1d6', 'Dano 2d6', 'Dano 3d6']},
    ]);
    final node = c.skillTree.single;
    final talento = cardHeight(tester, 'Nó a');
    expect(find.text('Façanha'), findsNothing, reason: 'Talento não tem selo');
    expect(find.textContaining('/3'), findsNothing);
    expect(find.byKey(const ValueKey('skill-tree-tier-legend')), findsOneWidget);

    await tester.tap(find.text('Nó a'));
    await settle(tester);
    expect(find.text('Talento • próximo: Façanha'), findsOneWidget);
    expect(find.text('Agora: Dano 1d6'), findsOneWidget);
    await tester.tap(find.text('Aprimorar para Façanha'));
    await settle(tester);
    expect(nodeRank(node), 2);
    expect(find.text('Façanha'), findsOneWidget);
    final facanha = cardHeight(tester, 'Nó a');
    expect(facanha, greaterThan(talento));

    await tester.tap(find.text('Nó a'));
    await settle(tester);
    expect(find.text('Façanha • próximo: Lenda'), findsOneWidget);
    await tester.tap(find.text('Aprimorar para Lenda'));
    await settle(tester);
    expect(nodeRank(node), 3);
    expect(find.text('Lenda'), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-node-lenda-a')), findsOneWidget);
    expect(cardHeight(tester, 'Nó a'), greaterThan(facanha));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.tap(find.text('Nó a'));
    await settle(tester);
    expect(find.text('Lenda • nível máximo'), findsOneWidget);
    expect(find.textContaining('Aprimorar para'), findsNothing);
    expect(nodeRaiseBlock(_system(), c, node), 'Já está no nível máximo.');
    // Reduzir volta para Façanha.
    await tester.tap(find.text('Reduzir'));
    await settle(tester);
    expect(nodeRank(node), 2);
    expect(find.text('Façanha'), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-node-lenda-a')), findsNothing);
  });

  testWidgets('Aprimoramento desligado: máximo 1, sem selo, sem legenda e sem textos por nível', (tester) async {
    final c = await pump(tester, _system(ranks: false), [
      {'id': 'a', 'name': 'Nó a', 'parentId': '', 'level': 1, 'unlocked': true, 'rank': 3},
    ]);
    expect(find.text('Lenda'), findsNothing);
    expect(find.byKey(const ValueKey('skill-tree-tier-legend')), findsNothing);
    expect(nodeRaiseBlock(_system(ranks: false), c, c.skillTree.single), 'Já está no nível máximo.');
    await tester.tap(find.byTooltip('Nova habilidade'));
    await settle(tester);
    expect(find.text('Mais opções'), findsNothing);
    expect(find.byKey(const ValueKey('node-rank-text-1')), findsNothing);
  });

  testWidgets('editor: sem Tipo e sem quantidade de níveis; com Aprimoramento, os 3 textos opcionais', (tester) async {
    final c = await pump(tester, _system(), [
      {'id': 'a', 'name': 'Nó a', 'parentId': '', 'level': 1, 'unlocked': false},
    ]);
    await tester.tap(find.byTooltip('Nova habilidade'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Nó b');
    await tester.tap(find.text('Mais opções'));
    await settle(tester);
    expect(find.byKey(const ValueKey('node-tier')), findsNothing);
    expect(find.byKey(const ValueKey('node-max-rank')), findsNothing);
    for (final label in ['Talento (opcional)', 'Façanha (opcional)', 'Lenda (opcional)']) {
      expect(find.widgetWithText(TextField, label), findsOneWidget, reason: label);
    }
    await tester.enterText(find.widgetWithText(TextField, 'Façanha (opcional)'), 'Dano 2d6');
    await tester.tap(find.text('Salvar'));
    await settle(tester);
    final created = c.skillTree.last;
    expect(created['rankTexts'], ['', 'Dano 2d6', '']);
    expect(created.containsKey('tier'), isFalse);
    expect(created.containsKey('maxRank'), isFalse);
  });

  group('compatibilidade', () {
    test('sistema salvo com treeTiers = true e treeRanks = false: Aprimoramento ligado', () {
      final old = RpgSystem.fromJson({'id': 'x', 'name': 'Antigo', 'treeTiers': true});
      expect(old.treeTiers, isTrue);
      expect(old.treeRanks, isFalse);
      expect(SkillTreeFeatures.of(old).ranks, isTrue);
      expect(SkillTreeFeatures.of(RpgSystem(id: 'y', name: 'Novo')).ranks, isFalse);
    });

    testWidgets('editor de sistemas: sem "Tipos"; treeTiers salvo abre com Aprimoramento ligado e salva só treeRanks', (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final s = AppState();
      await s.load();
      final system = RpgSystem.fromJson({'id': 'old', 'name': 'Antigo', 'treeTiers': true});
      s.systems.add(system);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: s, child: MaterialApp(home: SystemEditorScreen(system: system))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('tree-tiers')), findsNothing);
      expect(find.text('Tipos'), findsNothing);
      for (final key in ['tree-branches', 'tree-ranks', 'tree-exclusive', 'tree-attribute-requirement', 'tree-ability-link']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('tree-ranks'))).value, isTrue);
      await tester.ensureVisible(find.text('Salvar sistema'));
      await tester.tap(find.text('Salvar sistema'));
      await tester.pump(const Duration(milliseconds: 300));
      final saved = s.systems.firstWhere((x) => x.id == 'old').toJson();
      expect(saved['treeRanks'], isTrue);
      expect(saved.containsKey('treeTiers'), isFalse);
    });

    testWidgets('nó antigo com tier "lenda" e nível 1 aparece como Talento; nível 5 salvo aparece como Lenda', (tester) async {
      final c = await pump(tester, _system(), [
        {'id': 'a', 'name': 'Nó a', 'parentId': '', 'level': 1, 'unlocked': true, 'tier': 'lenda'},
        {'id': 'b', 'name': 'Nó b', 'parentId': '', 'level': 1, 'unlocked': true, 'tier': 'talento', 'maxRank': 5, 'rank': 5},
      ]);
      final a = c.skillTree.first, b = c.skillTree.last;
      expect(nodeTier(a), 'talento');
      expect(nodeRank(b), 3);
      expect(nodeTier(b), 'lenda');
      expect(find.byKey(const ValueKey('skill-node-lenda-a')), findsNothing);
      expect(find.byKey(const ValueKey('skill-node-lenda-b')), findsOneWidget);
      expect(find.text('Lenda'), findsOneWidget, reason: 'só o selo do nó b');
      // O 5 salvo só muda se o jogador reduzir.
      expect(b['rank'], 5);
      final before = jsonEncode(c.toJson()['skillTree']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(jsonEncode(c.toJson()['skillTree']), before);
      await tester.tap(find.text('Nó b'));
      await settle(tester);
      expect(find.text('Lenda • nível máximo'), findsOneWidget);
      await tester.tap(find.text('Reduzir'));
      await settle(tester);
      expect(b['rank'], 2);
    });
  });

  group('barra principal', () {
    for (final master in [false, true]) {
      testWidgets('Fichas, Sistemas, ${master ? 'Mestre, ' : ''}Config. (sem "Árvore")', (tester) async {
        expect(mainTabs(masterToolsEnabled: master).map((t) => t.label), ['Fichas', 'Sistemas', if (master) 'Mestre', 'Config.']);
        SharedPreferences.setMockInitialValues({'auto_sync': false});
        final s = AppState();
        await s.setMasterToolsEnabled(master);
        final controller = PageController();
        final index = ValueNotifier<int>(0);
        addTearDown(controller.dispose);
        addTearDown(index.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: s,
          child: MaterialApp(
            theme: buildAppTheme('classic', false),
            home: MainTabsShell(controller: controller, index: index, pageBuilder: (role) => Center(child: Text('Página $role'))),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Árvore'), findsNothing);
        for (final label in ['Fichas', 'Sistemas', if (master) 'Mestre', 'Config.']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(mainTabIndex('tree', masterToolsEnabled: master), 0, reason: 'quem estava na Árvore cai em Fichas');
        expect(mainTabIndex('settings', masterToolsEnabled: master), master ? 3 : 2);
      });
    }

    test('a lista de árvores saiu do app', () {
      expect(File('lib/screens/home/skill_trees_screen.dart').existsSync(), isFalse);
      expect(File('lib/app/app.dart').readAsStringSync(), isNot(contains('SkillTreesScreen')));
    });

    testWidgets('a aba "Árvore" da ficha continua existindo', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final s = AppState();
      await s.load();
      s.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'generic'));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: s, child: const MaterialApp(home: CharacterScreen(characterId: 'p1'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Árvore'), findsWidgets);
      expect(File('lib/screens/character/character_screen.dart').readAsStringSync(), contains("'skillTree' => SkillTreeScreen(characterId: c.id, embedded: true)"));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
