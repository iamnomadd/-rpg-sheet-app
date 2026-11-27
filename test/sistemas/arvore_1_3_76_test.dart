// 1.3.76 — Árvore de Habilidades, parte 1: ramos, tipos, níveis, escolhas
// exclusivas, requisito de atributo opcional e ligação com as Habilidades.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/skill_tree_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _node(String id, {String parent = '', bool unlocked = false, int? level, Map<String, dynamic> extra = const {}}) => {
      'id': id,
      'name': 'Nó $id',
      'description': 'Descrição de $id',
      'parentId': parent,
      if (level != null) 'level': level,
      'unlocked': unlocked,
      ...extra,
    };

// 1.3.77: as funções da árvore são ligadas no sistema; os testes da 1.3.76
// usam um sistema com todas ligadas (o requisito continua opcional).
RpgSystem _system({bool requirement = false}) => RpgSystem(
      id: 'sys',
      name: 'Sistema',
      attributes: ['Força', 'Destreza'],
      resources: ['PV', 'PM'],
      treeAttributeRequirement: requirement,
      treeBranches: true,
      treeTiers: true,
      treeRanks: true,
      treeExclusive: true,
      treeAbilityLink: true,
    );

Character _character(List<Map<String, dynamic>> tree, {List<Map<String, dynamic>> branches = const []}) => Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      attributes: {'Força': 12, 'Destreza': 10},
      resourceValues: {'PV': 10, 'PM': 5},
      resourceMaxValues: {'PV': 10, 'PM': 5},
      skillTree: tree,
      skillTreeBranches: [...branches],
    );

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  late AppState state;

  Future<Character> pump(WidgetTester tester, Character character, {RpgSystem? system, bool reduceAnimations = false, Size size = const Size(800, 2200)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false, 'reduce_animations': reduceAnimations});
    state = AppState();
    await state.load();
    state.systems.insert(0, system ?? _system());
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

  Future<void> openDetail(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await settle(tester);
  }

  group('compatibilidade', () {
    test('árvore no formato antigo abre igual e salva sem perder dados', () {
      final old = {
        'id': 'p1',
        'name': 'Ana',
        'systemId': 'sys',
        'skillTree': [
          {'id': 'a', 'name': 'Golpe', 'description': 'd', 'parentId': '', 'level': 1, 'unlocked': true, 'template': 'guerreiro'},
          {'id': 'b', 'name': 'Bloqueio', 'description': '', 'parentId': 'a', 'level': 2, 'unlocked': false},
        ],
      };
      final c = Character.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      expect(c.skillTree.map((n) => n['id']), ['a', 'b']);
      expect(c.skillTree.where((n) => n['unlocked'] == true).map((n) => n['id']), ['a']);
      // Padrões: Talento, 1 nível, sem ramo, sem escolha, sem requisito, sem Habilidades.
      final a = c.skillTree.first;
      expect([nodeTier(a), nodeMaxRank(a), nodeRank(a), nodeBranchId(a), nodeGroup(a), a['addToAbilities']], ['talento', 1, 1, '', '', null]);
      expect(nodeRank(c.skillTree.last), 0);
      final json = c.toJson();
      expect(json.containsKey('skillTreeBranches'), isFalse, reason: 'sem ramos, o JSON fica como antes');
      expect(jsonEncode(json['skillTree']), jsonEncode(old['skillTree']));
      expect(c.skillTreeBranches, isEmpty);
    });

    test('fromJson/toJson preservam os campos novos (ficha e sistema)', () {
      final c = _character([
        _node('a', unlocked: true, extra: {'tier': 'lenda', 'maxRank': 3, 'rank': 2, 'rankTexts': ['n1', 'n2', 'n3'], 'branchId': 'r1', 'exclusiveGroup': 'g', 'reqAttribute': 'Força', 'reqValue': 14, 'addToAbilities': true, 'ability': {'category': 'Magia', 'cost': 2, 'resource': 'PM'}}),
      ], branches: [{'id': 'r1', 'name': 'Fúria', 'color': 0xFFFF6B6B}]);
      final back = Character.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.skillTreeBranches, [{'id': 'r1', 'name': 'Fúria', 'color': 0xFFFF6B6B}]);
      expect(jsonEncode(back.skillTree), jsonEncode(c.skillTree));
      final system = _system(requirement: true);
      expect(RpgSystem.fromJson(jsonDecode(jsonEncode(system.toJson())) as Map<String, dynamic>).treeAttributeRequirement, isTrue);
      expect(system.copyWith(name: 'X').treeAttributeRequirement, isTrue);
      expect(_system().toJson().containsKey('treeAttributeRequirement'), isFalse);
      expect(RpgSystem.fromJson({'id': 'x', 'name': 'Antigo'}).treeAttributeRequirement, isFalse);
    });

    test('todos os sistemas padrão começam com o requisito desligado', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.systems.every((sys) => !sys.treeAttributeRequirement), isTrue);
    });

    testWidgets('árvore simples (sem ramos, tipos e níveis) fica igual à de hoje', (tester) async {
      await pump(tester, _character([_node('a', unlocked: true, level: 1), _node('b', parent: 'a', level: 2)]));
      expect(find.text('Nível 1 • Desbloqueada'), findsOneWidget);
      expect(find.text('Nível 2 • Disponível'), findsOneWidget);
      expect(find.textContaining('Tipos:'), findsNothing);
      expect(find.text('Geral'), findsNothing);
      expect(find.textContaining('/1'), findsNothing);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('skill-node-tier-')), findsNothing);
    });

    testWidgets('editor: por padrão só Nome, Descrição e Pré-requisito; o resto em "Mais opções"', (tester) async {
      await pump(tester, _character([_node('a')]));
      await tester.tap(find.byTooltip('Nova habilidade'));
      await settle(tester);
      expect(find.widgetWithText(TextField, 'Nome'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Descrição'), findsOneWidget);
      expect(find.text('Pré-requisito / ramo anterior'), findsOneWidget);
      expect(find.text('Mais opções'), findsOneWidget);
      expect(find.byKey(const ValueKey('node-tier')), findsNothing);
      expect(find.byKey(const ValueKey('node-branch')), findsNothing, reason: 'sem ramos, sem o campo Ramo');
      await tester.tap(find.text('Mais opções'));
      await settle(tester);
      expect(find.byKey(const ValueKey('node-tier')), findsOneWidget);
      expect(find.byKey(const ValueKey('node-req-attribute')), findsNothing, reason: 'interruptor do sistema desligado');
    });
  });

  group('ramos', () {
    test('criar, renomear e apagar (os nós vão para "Geral")', () {
      final c = _character([_node('a'), _node('b')]);
      final branch = addSkillTreeBranch(c, name: 'Fúria');
      c.skillTree.first['branchId'] = branch['id'];
      expect(skillTreeSections(c).map((s) => s.branch?['name'] ?? 'Geral'), ['Geral', 'Fúria']);
      branch['name'] = 'Fúria Ancestral';
      expect(nodeBranch(c, c.skillTree.first)!['name'], 'Fúria Ancestral');
      removeSkillTreeBranch(c, branch['id'] as String);
      expect(c.skillTreeBranches, isEmpty);
      expect(c.skillTree.length, 2);
      expect(c.skillTree.every((n) => nodeBranchId(n).isEmpty), isTrue);
    });

    test('cores dos ramos com contraste ≥ 3:1 sobre o card de todos os temas', () {
      expect(skillTreeBranchColors.length, greaterThanOrEqualTo(8));
      for (final entry in abyssPalettes.entries) {
        for (final color in skillTreeBranchColors) {
          expect(_contrast(color, entry.value.card), greaterThanOrEqualTo(3), reason: '${entry.key} $color');
        }
      }
    });

    testWidgets('tela de ramos: criar, renomear e apagar sem diálogos; árvore em seções com a cor do ramo', (tester) async {
      final c = await pump(tester, _character([_node('a', level: 1), _node('b', level: 1)]));
      await tester.tap(find.byTooltip('Ramos'));
      await settle(tester);
      await tester.tap(find.text('Novo ramo'));
      await settle(tester);
      expect(c.skillTreeBranches, hasLength(1));
      await tester.enterText(find.byKey(ValueKey('branch-name-${c.skillTreeBranches.single['id']}')), 'Fúria');
      await tester.pump();
      expect(c.skillTreeBranches.single['name'], 'Fúria');
      expect(find.byType(AlertDialog), findsNothing);
      // Um nó no ramo: a árvore ganha as seções "Geral" e "Fúria".
      c.skillTree.first['branchId'] = c.skillTreeBranches.single['id'];
      await state.updateCharacter(c);
      await tester.pageBack();
      await settle(tester);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Fúria'), findsOneWidget);
      final title = tester.widget<Text>(find.text('Fúria'));
      expect(title.style?.color, branchColor(c.skillTreeBranches.single));
      // Apagar o ramo: o nó volta para "Geral" e a árvore fica como antes.
      await tester.tap(find.byTooltip('Ramos'));
      await settle(tester);
      await tester.tap(find.byTooltip('Apagar ramo'));
      await settle(tester);
      expect(c.skillTreeBranches, isEmpty);
      expect(c.skillTree, hasLength(2));
      expect(nodeBranchId(c.skillTree.first), '');
    });
  });

  group('tipos', () {
    testWidgets('Talento, Façanha e Lenda têm tamanhos diferentes; Lenda sem animação com "reduzir movimento"', (tester) async {
      await pump(
        tester,
        _character([
          _node('t', level: 1),
          _node('f', level: 1, extra: {'tier': 'facanha'}),
          _node('l', level: 1, unlocked: true, extra: {'tier': 'lenda'}),
        ]),
        reduceAnimations: true,
      );
      double height(String name) => tester.getSize(find.ancestor(of: find.text(name), matching: find.byType(Material)).first).height;
      expect(height('Nó t'), lessThan(height('Nó f')));
      expect(height('Nó f'), lessThan(height('Nó l')));
      expect(find.text('Façanha'), findsOneWidget);
      expect(find.text('Lenda'), findsOneWidget);
      expect(find.byKey(const ValueKey('skill-node-lenda-l')), findsOneWidget);
      expect(find.byKey(const ValueKey('skill-tree-tier-legend')), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0, reason: 'sem animação contínua');
      // Legenda recolhível com uma frase por tipo.
      expect(find.text(skillTreeTierHint('lenda')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('skill-tree-tier-legend')));
      await tester.pump();
      for (final tier in skillTreeTiers) {
        expect(find.text(skillTreeTierHint(tier)), findsOneWidget);
      }
      // O tipo não muda a regra: a Lenda bloqueada com pai livre é Disponível.
      expect(nodeRaiseBlock(_system(), _character([_node('x', extra: {'tier': 'lenda'})]), _node('x', extra: {'tier': 'lenda'})), isNull);
    });
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (411.0, 1.15), (800.0, 2.0)]) {
    testWidgets('tipos e níveis sem estouro: $width px, texto $scale', (tester) async {
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
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        _character([
          for (final (i, tier) in ['talento', 'facanha', 'lenda', 'facanha'].indexed)
            _node('n$i', level: 1, unlocked: i.isEven, extra: {'tier': tier, 'maxRank': 3, 'rank': i.isEven ? 2 : 0, 'exclusiveGroup': i > 1 ? 'g' : ''}..removeWhere((k, v) => v == '')),
          _node('c', parent: 'n0', level: 2, extra: {'tier': 'lenda'}),
        ]),
        size: Size(width, 2400),
      );
      FlutterError.onError = previous;
      expect(overflows, isEmpty);
    });
  }

  group('níveis', () {
    test('aprimorar até o máximo, reduzir até 0, filho exige pai ≥ 1 e não reduz a 0 com filho', () {
      final parent = _node('a', extra: {'maxRank': 3});
      final child = _node('b', parent: 'a');
      final c = _character([parent, child]);
      expect(nodeRaiseBlock(_system(), c, child), 'Desbloqueie primeiro a habilidade anterior deste ramo.');
      for (var i = 1; i <= 3; i++) {
        expect(nodeRaiseBlock(_system(), c, parent), isNull);
        setNodeRank(parent, nodeRank(parent) + 1);
        expect(parent['unlocked'], isTrue);
      }
      expect(nodeRank(parent), 3);
      expect(nodeRaiseBlock(_system(), c, parent), 'Já está no nível máximo.');
      expect(nodeRaiseBlock(_system(), c, child), isNull);
      setNodeRank(child, 1);
      setNodeRank(parent, 1);
      expect(nodeLowerBlock(c, parent, system: _system()), 'Bloqueie primeiro as habilidades que dependem desta.');
      setNodeRank(child, 0);
      expect(nodeLowerBlock(c, parent, system: _system()), isNull);
      setNodeRank(parent, 0);
      expect(parent['unlocked'], isFalse);
      expect(nodeLowerBlock(c, parent, system: _system()), isNotNull);
    });

    testWidgets('o cartão mostra "1/3" e o detalhe tem Aprimorar e Reduzir', (tester) async {
      final c = await pump(tester, _character([_node('a', level: 1, unlocked: true, extra: {'maxRank': 3, 'rank': 1, 'rankTexts': ['', 'Dano 2d6', '']})]));
      expect(find.text('Nível 1 • Desbloqueada • 1/3'), findsOneWidget);
      await openDetail(tester, 'Nó a');
      expect(find.text('Talento • Aprimoramento 1 de 3'), findsOneWidget);
      expect(find.text('Próximo nível: Dano 2d6'), findsOneWidget);
      await tester.tap(find.text('Aprimorar'));
      await settle(tester);
      expect(nodeRank(c.skillTree.single), 2);
      expect(find.text('Nível 1 • Desbloqueada • 2/3'), findsOneWidget);
      await openDetail(tester, 'Nó a');
      await tester.tap(find.text('Reduzir'));
      await settle(tester);
      expect(nodeRank(c.skillTree.single), 1);
    });

    testWidgets('bloquear um pai com filho desbloqueado mostra a mensagem e não bloqueia', (tester) async {
      final c = await pump(tester, _character([_node('a', level: 1, unlocked: true), _node('b', parent: 'a', level: 2, unlocked: true)]));
      await tester.tap(find.byTooltip('Bloquear').first);
      await settle(tester);
      expect(find.text('Bloqueie primeiro as habilidades que dependem desta.'), findsOneWidget);
      expect(c.skillTree.first['unlocked'], isTrue);
    });
  });

  group('escolhas exclusivas', () {
    testWidgets('desbloquear A fecha B (com o texto certo); reduzir A a 0 reabre B', (tester) async {
      final c = await pump(tester, _character([
        _node('a', level: 1, extra: {'exclusiveGroup': 'caminho'}),
        _node('b', level: 1, extra: {'exclusiveGroup': 'caminho'}),
      ]));
      final a = c.skillTree.first, b = c.skillTree.last;
      await tester.tap(find.byTooltip('Desbloquear').first);
      await settle(tester);
      expect(nodeRank(a), 1);
      expect(nodeClosedBy(c, b), same(a));
      expect(nodeRaiseBlock(_system(), c, b), 'Fechado pela escolha: Nó a');
      expect(find.text('Nível 1 • Fechada'), findsOneWidget);
      await openDetail(tester, 'Nó b');
      expect(find.text('Fechado porque você escolheu: Nó a'), findsOneWidget);
      final unlock = tester.widget<FilledButton>(find.ancestor(of: find.text('Desbloquear'), matching: find.byWidgetPredicate((w) => w is FilledButton)).first);
      expect(unlock.onPressed, isNull, reason: 'tocar num fechado explica em vez de desbloquear');
      Navigator.of(tester.element(find.text('Fechado porque você escolheu: Nó a'))).pop();
      await settle(tester);
      setNodeRank(a, 0);
      expect(nodeClosedBy(c, b), isNull);
      expect(nodeRaiseBlock(_system(), c, b), isNull);
    });
  });

  group('requisito de atributo', () {
    final node = _node('a', extra: {'reqAttribute': 'Força', 'reqValue': 14});

    test('desligado no sistema: o requisito é ignorado', () {
      expect(nodeRequirement(_system(), _character([node]), node), isNull);
      expect(nodeRaiseBlock(_system(), _character([node]), node), isNull);
    });

    test('ligado: bloqueia com a mensagem certa e libera ao atingir o valor', () {
      final c = _character([node]);
      expect(nodeRaiseBlock(_system(requirement: true), c, node), 'Precisa de Força 14 (você tem 12)');
      c.attributes['Força'] = 14;
      expect(nodeRaiseBlock(_system(requirement: true), c, node), isNull);
      // Reduzir sempre é permitido.
      setNodeRank(node, 1);
      c.attributes['Força'] = 1;
      expect(nodeLowerBlock(c, node), isNull);
    });

    testWidgets('ligado: o campo aparece no editor e o detalhe mostra o requisito', (tester) async {
      await pump(tester, _character([_node('a', level: 1, extra: {'reqAttribute': 'Força', 'reqValue': 14})]), system: _system(requirement: true));
      await openDetail(tester, 'Nó a');
      expect(find.text('Precisa de Força 14 (você tem 12)'), findsWidgets);
      await tester.tap(find.byTooltip('Editar'));
      await settle(tester);
      await tester.tap(find.text('Mais opções'));
      await settle(tester);
      expect(find.byKey(const ValueKey('node-req-attribute')), findsOneWidget);
    });
  });

  group('habilidades', () {
    Map<String, dynamic> linked(String id, {int maxRank = 2}) => _node(id, level: 1, extra: {
          'tier': 'facanha',
          'maxRank': maxRank,
          'rankTexts': ['Dano 1d6', 'Dano 2d6'],
          'addToAbilities': true,
          'ability': {'category': 'Magia', 'cost': 2, 'resource': 'PM', 'damage': '1d6'},
        });

    testWidgets('desbloquear cria com fromTree; aprimorar atualiza; voltar a 0 pergunta e remove', (tester) async {
      final c = await pump(tester, _character([linked('a')]));
      await tester.tap(find.byTooltip('Desbloquear'));
      await settle(tester);
      expect(c.abilities, ['Nó a']);
      expect(c.abilityDetails['Nó a']!['fromTree'], 'a');
      expect(c.abilityDetails['Nó a']!['category'], 'Magia');
      expect(c.abilityDetails['Nó a']!['cost'], 2);
      expect(c.abilityDescriptions['Nó a'], 'Descrição de a\n\nDano 1d6');
      await openDetail(tester, 'Nó a');
      await tester.tap(find.text('Aprimorar'));
      await settle(tester);
      expect(c.abilityDescriptions['Nó a'], 'Descrição de a\n\nDano 2d6');
      // 2 → 1 (sem pergunta), 1 → 0 (pergunta).
      await openDetail(tester, 'Nó a');
      await tester.tap(find.text('Reduzir'));
      await settle(tester);
      expect(c.abilityDescriptions['Nó a'], 'Descrição de a\n\nDano 1d6');
      await openDetail(tester, 'Nó a');
      await tester.tap(find.text('Reduzir'));
      await settle(tester);
      expect(find.text('Remover também a habilidade Nó a das Habilidades?'), findsOneWidget);
      await tester.tap(find.text('Remover'));
      await settle(tester);
      expect(nodeRank(c.skillTree.single), 0);
      expect(c.abilities, isEmpty);
      expect(c.abilityDetails, isEmpty);
    });

    testWidgets('conflito de nome: não sobrescreve e segue com o desbloqueio', (tester) async {
      final character = _character([linked('a', maxRank: 1)]);
      character.abilities.add('Nó a');
      character.abilityDescriptions['Nó a'] = 'Minha habilidade';
      character.abilityDetails['Nó a'] = {'category': 'Técnica'};
      final c = await pump(tester, character);
      await tester.tap(find.byTooltip('Desbloquear'));
      await settle(tester);
      expect(find.text('Já existe uma habilidade com esse nome; ela não foi alterada.'), findsOneWidget);
      expect(nodeRank(c.skillTree.single), 1);
      expect(c.abilityDescriptions['Nó a'], 'Minha habilidade');
      expect(c.abilityDetails['Nó a'], {'category': 'Técnica'});
      // Voltar a 0 não remove a habilidade que não veio da árvore (e nem pergunta).
      await tester.tap(find.byTooltip('Bloquear'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(c.abilities, ['Nó a']);
    });

    test('renomear o nó renomeia a habilidade (mantendo o vínculo); "Manter" mantém', () {
      final node = linked('a', maxRank: 1);
      final c = _character([node]);
      setNodeRank(node, 1);
      expect(syncNodeAbility(c, node), isTrue);
      node['name'] = 'Seta arcana';
      expect(renameNodeAbility(c, node), isTrue);
      expect(c.abilities, ['Seta arcana']);
      expect(c.abilityDetails['Seta arcana']!['fromTree'], 'a');
      expect(linkedAbilityName(c, node), 'Seta arcana');
      // Nome novo já usado por outra habilidade: nada muda.
      c.abilities.add('Outra');
      node['name'] = 'Outra';
      expect(renameNodeAbility(c, node), isFalse);
      expect(c.abilities, ['Seta arcana', 'Outra']);
    });

    testWidgets('renomear pelo editor renomeia a habilidade; nós novos Façanha/Lenda vão para as Habilidades por padrão', (tester) async {
      final node = linked('a', maxRank: 1);
      setNodeRank(node, 1);
      final character = _character([node]);
      syncNodeAbility(character, node);
      final c = await pump(tester, character);
      await openDetail(tester, 'Nó a');
      await tester.tap(find.byTooltip('Editar'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Fúria Ancestral');
      await tester.tap(find.text('Salvar'));
      await settle(tester);
      expect(c.abilities, ['Fúria Ancestral']);
      expect(c.abilityDetails['Fúria Ancestral']!['fromTree'], 'a');

      await tester.tap(find.byTooltip('Nova habilidade'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Golpe lendário');
      await tester.tap(find.text('Mais opções'));
      await settle(tester);
      await tester.tap(find.text('Lenda'));
      await settle(tester);
      final toggle = tester.widget<SwitchListTile>(find.byKey(const ValueKey('node-add-ability')));
      expect(toggle.value, isTrue);
      await tester.tap(find.text('Salvar'));
      await settle(tester);
      final created = c.skillTree.last;
      expect(nodeTier(created), 'lenda');
      expect(created['addToAbilities'], isTrue);
    });
  });

  test('o editor de sistemas tem o interruptor do requisito (padrão desligado)', () {
    expect(RpgSystem(id: 'x', name: 'Novo').treeAttributeRequirement, isFalse);
  });
}
