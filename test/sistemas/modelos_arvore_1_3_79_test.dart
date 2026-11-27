// 1.3.79 — os 12 modelos de classe refeitos: ramos, textos de Talento/Façanha/
// Lenda, uma escolha exclusiva e ligação com Habilidades.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/skill_tree_rules.dart';
import 'package:rpg_sheet_app/services/skill_tree_templates.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _classes = ['Paladino', 'Guerreiro', 'Lutador', 'Mago', 'Ladino', 'Arqueiro', 'Clérigo', 'Bárbaro', 'Investigador', 'Pistoleiro', 'Ocultista', 'Médico'];

void main() {
  group('formato dos 12 modelos', () {
    for (final className in _classes) {
      test(className, () {
        final generated = SkillTreeTemplates.generate(className, resources: const ['PV', 'PM']);
        final key = SkillTreeTemplates.templateKeyForClass(className)!;
        final nodes = generated.nodes;
        final branches = generated.branches;
        // 2–3 ramos com cores diferentes e ids estáveis.
        expect(branches.length, inInclusiveRange(2, 3));
        expect(branches.map((b) => b['color']).toSet(), hasLength(branches.length));
        for (var b = 0; b < branches.length; b++) {
          expect(branches[b]['id'], 'template_${key}_ramo_${b + 1}');
          expect((branches[b]['name'] as String).trim(), isNotEmpty);
          expect(skillTreeBranchColors.map((c) => c.toARGB32()), contains(branches[b]['color']));
        }
        // 8–12 nós com ids únicos e estáveis.
        expect(nodes.length, inInclusiveRange(8, 12));
        final ids = [for (final n in nodes) n['id']];
        expect(ids.toSet(), hasLength(nodes.length));
        expect(ids, [for (var i = 1; i <= nodes.length; i++) 'template_${key}_$i']);
        final byId = {for (final n in nodes) n['id']: n};
        final branchIds = {for (final b in branches) b['id']};
        for (final b in branchIds) {
          final roots = nodes.where((n) => n['branchId'] == b && n['parentId'] == '');
          expect(roots, hasLength(1), reason: 'ramo $b com 1 inicial');
        }
        for (final n in nodes) {
          final name = n['name'];
          expect(branchIds, contains(n['branchId']), reason: '$name');
          final parent = n['parentId'] as String;
          if (parent.isNotEmpty) {
            expect(byId, contains(parent), reason: '$name');
            expect(byId[parent]!['branchId'], n['branchId'], reason: '$name: pai do mesmo ramo');
          }
          expect((n['description'] as String).trim(), isNotEmpty, reason: '$name');
          final texts = n['rankTexts'] as List;
          expect(texts, hasLength(3), reason: '$name');
          expect(texts.every((t) => (t as String).trim().isNotEmpty), isTrue, reason: '$name');
          expect(nodeRank(n), 0, reason: '$name bloqueado');
          expect(n['unlocked'], isFalse);
          for (final absent in ['tier', 'maxRank', 'reqAttribute', 'reqValue', 'rank']) {
            expect(n.containsKey(absent), isFalse, reason: '$name sem $absent');
          }
          expect(n['addToAbilities'], isTrue);
          final ability = n['ability'] as Map;
          expect(['Habilidade', 'Magia', 'Técnica', 'Passiva'], contains(ability['category']), reason: '$name');
          expect(ability['cost'] as int, inInclusiveRange(0, 3), reason: '$name');
          if (ability['category'] == 'Passiva') {
            expect(ability['cost'], 0, reason: '$name: passiva sem custo');
            expect(ability['damage'], '', reason: '$name: passiva sem dano');
          }
          final damage = ability['damage'] as String;
          if (damage.isNotEmpty) expect(RegExp(r'^\d+d\d+$').hasMatch(damage), isTrue, reason: '$name: $damage');
        }
        // Exatamente 1 escolha exclusiva com 2 nós de mesmo pré-requisito.
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final n in nodes) {
          final g = n['exclusiveGroup'];
          if (g != null) groups.putIfAbsent(g as String, () => []).add(n);
        }
        expect(groups, hasLength(1));
        final pair = groups.values.single;
        expect(pair, hasLength(2));
        expect(pair[0]['parentId'], pair[1]['parentId']);
        expect(pair[0]['parentId'], isNotEmpty);
      });
    }
  });

  test('custo usa o primeiro recurso que não é de vida; sem recurso, sem custo', () {
    expect(SkillTreeTemplates.costResource(['Vida', 'Energia']), 'Energia');
    expect(SkillTreeTemplates.costResource(['PV', 'PM']), 'PM');
    expect(SkillTreeTemplates.costResource(['PV', 'PE', 'Sanidade']), 'PE');
    expect(SkillTreeTemplates.costResource(['Vida', 'PV Temporários', 'Inspiração']), 'Inspiração');
    expect(SkillTreeTemplates.costResource(['Pontos de Vida', 'Sanidade']), isNull);
    expect(SkillTreeTemplates.costResource(['PV']), isNull);
    Map ability(List<String> resources, String name) =>
        SkillTreeTemplates.forClass('Mago', resources: resources).firstWhere((n) => n['name'] == name)['ability'] as Map;
    expect(ability(['Vida', 'Mana'], 'Bola de Fogo'), containsPair('resource', 'Mana'));
    expect(ability(['Vida', 'Mana'], 'Bola de Fogo')['cost'], 3);
    expect(ability(['PV'], 'Bola de Fogo')['cost'], 0);
    expect(ability(['PV'], 'Bola de Fogo')['resource'], '');
  });

  group('gerar pela tela da árvore', () {
    late AppState state;

    Future<Character> pump(WidgetTester tester, RpgSystem system, {List<Map<String, dynamic>> tree = const []}) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false, 'reduce_animations': true});
      state = AppState();
      await state.load();
      state.systems.insert(0, system);
      final c = Character(id: 'p1', name: 'Ana', systemId: system.id, className: 'Ladino', resourceValues: {'PV': 10, 'PM': 5}, resourceMaxValues: {'PV': 10, 'PM': 5}, skillTree: [...tree]);
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

    RpgSystem plain() => RpgSystem(id: 'sys', name: 'Sistema', resources: ['PV', 'PM']);

    testWidgets('tudo desligado: gera nós e ramos e a árvore aparece simples', (tester) async {
      final c = await pump(tester, plain());
      await tester.tap(find.text('Gerar árvore de Ladino'));
      await settle(tester);
      expect(c.skillTree, hasLength(9));
      expect(c.skillTreeBranches.map((b) => b['name']), ['Sombra', 'Truques', 'Esperteza']);
      // Uma coluna, sem títulos de ramo, selos, legenda, "Fechada" nem "Mais opções".
      expect(find.text('Sombra'), findsNothing);
      expect(find.text('Geral'), findsNothing);
      expect(find.text('Façanha'), findsNothing);
      expect(find.byKey(const ValueKey('skill-tree-tier-legend')), findsNothing);
      expect(find.textContaining('Fechada'), findsNothing);
      // Detalhe: só a descrição (sem textos de nível).
      await tester.tap(find.text('Passo Silencioso'));
      await settle(tester);
      expect(find.text('Move-se sem fazer barulho.'), findsOneWidget);
      expect(find.textContaining('Agora:'), findsNothing);
      // Desbloquear não cria habilidade (Adicionar às Habilidades desligado).
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);
      expect(nodeRank(c.skillTree.first), 1);
      expect(c.abilities, isEmpty);
      await tester.tap(find.byTooltip('Nova habilidade'));
      await settle(tester);
      expect(find.text('Mais opções'), findsNothing);
    });

    testWidgets('com a árvore não vazia, gerar não muda nada', (tester) async {
      final c = await pump(tester, plain(), tree: [
        {'id': 'x', 'name': 'Minha', 'parentId': '', 'level': 1, 'unlocked': true},
      ]);
      expect(find.text('Gerar árvore de Ladino'), findsNothing);
      await tester.runAsync(() async {});
      expect(c.skillTree.single['id'], 'x');
      expect(c.skillTreeBranches, isEmpty);
    });

    testWidgets('com Aprimoramento e Adicionar às Habilidades: textos de Façanha e Lenda e a habilidade criada', (tester) async {
      final system = RpgSystem(id: 'sys', name: 'Sistema', resources: ['PV', 'PM'], treeRanks: true, treeAbilityLink: true, treeBranches: true, treeExclusive: true);
      final c = await pump(tester, system);
      await tester.tap(find.text('Gerar árvore de Ladino'));
      await settle(tester);
      expect(find.text('Sombra'), findsOneWidget, reason: 'com Ramos ligado, as seções aparecem');
      await tester.tap(find.text('Passo Silencioso'));
      await settle(tester);
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);
      expect(c.abilities, ['Passo Silencioso']);
      expect(c.abilityDetails['Passo Silencioso']!['category'], 'Passiva');
      await tester.tap(find.text('Passo Silencioso'));
      await settle(tester);
      expect(find.text('Agora: Passos sem som.'), findsOneWidget);
      await tester.tap(find.text('Aprimorar para Façanha'));
      await settle(tester);
      await tester.tap(find.text('Passo Silencioso'));
      await settle(tester);
      expect(find.text('Agora: Também não deixa rastros.'), findsOneWidget);
      await tester.tap(find.text('Aprimorar para Lenda'));
      await settle(tester);
      await tester.tap(find.text('Passo Silencioso'));
      await settle(tester);
      expect(find.text('Agora: Nem animais percebem sua presença.'), findsOneWidget);
      expect(c.abilityDescriptions['Passo Silencioso'], 'Move-se sem fazer barulho.\n\nNem animais percebem sua presença.');
    });
  });
}
