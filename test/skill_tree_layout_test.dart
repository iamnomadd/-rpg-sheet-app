import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> node(String id, {String parent = '', int? level, bool unlocked = false}) => {
      'id': id,
      'name': 'Nó $id',
      'parentId': parent,
      if (level != null) 'level': level,
      'unlocked': unlocked,
    };

List<Map<String, dynamic>> chain(int n) => [for (var i = 0; i < n; i++) node('$i', parent: i == 0 ? '' : '${i - 1}', level: i + 1)];

// Para os testes de widget: sem nível (a fonte de teste é bem mais larga que a real).
List<Map<String, dynamic>> plainChain(int n) => [for (var i = 0; i < n; i++) node('$i', parent: i == 0 ? '' : '${i - 1}')];

List<Map<String, dynamic>> siblings(int n) => [node('root'), for (var i = 0; i < n; i++) node('s$i', parent: 'root')];

void expectInside(SkillTreeLayout layout, double width) {
  expect(layout.width, width);
  expect(layout.columns, inInclusiveRange(1, 4));
  for (final p in layout.positions.values) {
    expect(p.dx, greaterThanOrEqualTo(0));
    expect(p.dx + layout.nodeWidth, lessThanOrEqualTo(width + 1e-9));
    expect(p.dy + layout.nodeHeight, lessThanOrEqualTo(layout.height));
  }
}

void main() {
  group('computeSkillTreeLayout', () {
    test('cadeia (um por nível) = 1 coluna, cartão largo', () {
      final layout = computeSkillTreeLayout(chain(5), 360);
      expect(layout.columns, 1);
      expect(layout.nodeWidth, skillTreeCardMaxWidth);
      expect(layout.compact, isFalse);
      final xs = layout.positions.values.map((p) => p.dx).toSet();
      expect(xs.length, 1);
      final ys = [for (var i = 0; i < 5; i++) layout.positions['$i']!.dy];
      for (var i = 1; i < 5; i++) {
        expect(ys[i], greaterThan(ys[i - 1]));
      }
      expectInside(layout, 360);
    });

    test('4 irmãos = 4 colunas numa linha', () {
      final layout = computeSkillTreeLayout(siblings(4), 411);
      expect(layout.columns, 4);
      expect(layout.compact, isTrue);
      final ys = {for (var i = 0; i < 4; i++) layout.positions['s$i']!.dy};
      expect(ys.length, 1);
      expectInside(layout, 411);
    });

    test('5 irmãos = 4 + 1 na linha seguinte, centralizada', () {
      final layout = computeSkillTreeLayout(siblings(5), 411);
      expect(layout.columns, 4);
      final first = layout.positions['s0']!.dy;
      for (var i = 1; i < 4; i++) {
        expect(layout.positions['s$i']!.dy, first);
      }
      final last = layout.positions['s4']!;
      expect(last.dy, greaterThan(first + layout.nodeHeight));
      expect(last.dx + layout.nodeWidth / 2, closeTo(411 / 2, 1e-6));
      expectInside(layout, 411);
    });

    test('9 nós no mesmo nível = 4 + 4 + 1, ordem estável', () {
      final nodes = [for (var i = 0; i < 9; i++) node('n$i')];
      final layout = computeSkillTreeLayout(nodes, 411);
      final rows = <double, List<String>>{};
      for (final n in nodes) {
        rows.putIfAbsent(layout.positions[n['id']]!.dy, () => []).add(n['id'] as String);
      }
      expect(rows.values.map((r) => r.length).toList(), [4, 4, 1]);
      expect(rows.values.expand((r) => r).toList(), [for (var i = 0; i < 9; i++) 'n$i']);
      for (final row in rows.values) {
        final xs = row.map((id) => layout.positions[id]!.dx).toList();
        for (var i = 1; i < xs.length; i++) {
          expect(xs[i], greaterThan(xs[i - 1]));
        }
      }
    });

    for (final width in [320.0, 360.0, 411.0, 1024.0]) {
      test('largura $width: nada sai da tela e o cartão fica entre o mínimo e 154', () {
        for (final nodes in [chain(6), siblings(3), siblings(4), siblings(9), [for (var i = 0; i < 12; i++) node('x$i')]]) {
          final layout = computeSkillTreeLayout(nodes, width);
          expectInside(layout, width);
          expect(layout.nodeWidth, inInclusiveRange(skillTreeCardMinWidth, skillTreeCardMaxWidth));
        }
      });
    }

    test('320 px cabem só 3 colunas; 360 e 411 cabem 4; 1024 limita o cartão a 154 e centraliza', () {
      final many = [for (var i = 0; i < 8; i++) node('x$i')];
      expect(computeSkillTreeLayout(many, 320).columns, 3);
      expect(computeSkillTreeLayout(many, 360).columns, 4);
      expect(computeSkillTreeLayout(many, 411).columns, 4);
      final wide = computeSkillTreeLayout(many, 1024);
      expect(wide.columns, 4);
      expect(wide.nodeWidth, skillTreeCardMaxWidth);
      expect(wide.compact, isFalse);
      final left = wide.positions['x0']!.dx;
      final right = wide.positions['x3']!.dx + wide.nodeWidth;
      expect(left, closeTo(1024 - right, 1e-6));
    });

    test('árvore vazia, ciclo, pai inexistente e nó sem id não dão erro', () {
      final empty = computeSkillTreeLayout(const [], 360);
      expect(empty.positions, isEmpty);
      expect(empty.width, 360);
      final cycle = computeSkillTreeLayout([node('a', parent: 'b'), node('b', parent: 'a'), node('c', parent: 'nao-existe'), {'name': 'sem id'}], 360);
      expect(cycle.positions.keys, containsAll(['a', 'b', 'c']));
      expectInside(cycle, 360);
      // Pai inexistente conta como raiz.
      expect(cycle.positions['c']!.dy, cycle.positions.values.map((p) => p.dy).reduce((a, b) => a < b ? a : b));
    });
  });

  group('tela da árvore', () {
    late AppState state;

    Character withTree(List<Map<String, dynamic>> tree) => Character(id: 'p1', name: 'Ana', systemId: 'sys', skillTree: tree);

    Future<void> pumpTree(WidgetTester tester, List<Map<String, dynamic>> tree, {double width = 360, Widget Function(Widget tree)? wrap}) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      state.characters.add(withTree(tree));
      const screen = SkillTreeScreen(characterId: 'p1', embedded: true);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: wrap == null ? screen : wrap(screen))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('sem InteractiveViewer, rola na vertical até o último nó', (tester) async {
      await pumpTree(tester, plainChain(12));
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.textContaining('role para ver toda a árvore'), findsOneWidget);
      final scroll = find.descendant(of: find.byKey(const ValueKey('skill-tree-scroll')), matching: find.byType(Scrollable)).first;
      expect(tester.widget<Scrollable>(scroll).axisDirection, AxisDirection.down);
      expect(find.text('Nó 11').hitTestable(), findsNothing);
      await tester.scrollUntilVisible(find.text('Nó 11').hitTestable(), 200, scrollable: scroll);
      expect(find.text('Nó 11').hitTestable(), findsOneWidget);
      // Nada passa da largura da tela.
      final card = tester.getRect(find.ancestor(of: find.text('Nó 11'), matching: find.byType(Material)).first);
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(360));
    });

    testWidgets('cartão compacto (4 colunas) sem cadeado; largo (1 coluna) com cadeado', (tester) async {
      await pumpTree(tester, [node('a'), node('b'), node('c'), node('d')]);
      expect(find.text('Nó a'), findsOneWidget);
      expect(find.byTooltip('Desbloquear'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Nó a, Disponível')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await pumpTree(tester, plainChain(2));
      expect(find.byTooltip('Desbloquear'), findsOneWidget);
      expect(find.byTooltip('Requer pré-requisito'), findsOneWidget);
    });

    testWidgets('tocar num nó compacto abre a folha com Desbloquear', (tester) async {
      await pumpTree(tester, [node('a'), node('b'), node('c'), node('d')]);
      await tester.tap(find.text('Nó c'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Desbloquear'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
      await tester.pumpAndSettle();
      expect(state.characters.single.skillTree[2]['unlocked'], isTrue);
    });

    testWidgets('dentro de um PageView, o deslize horizontal sobre a árvore troca de página', (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      // Árvore larga (6 irmãos): antes, o arrastar da árvore ficava com o gesto.
      await pumpTree(tester, siblings(6), wrap: (tree) => PageView(controller: controller, children: [tree, const Center(child: Text('Outra aba'))]));
      await tester.timedDrag(find.text('Nó root'), const Offset(-250, 0), const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      expect(find.text('Outra aba'), findsOneWidget);
    });
  });

  testWidgets('na ficha: deslize horizontal sobre a árvore troca de aba', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
    state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys', skillTree: siblings(6)));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Árvore').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final before = tester.getTopLeft(find.text('Nó root')).dx;
    expect(before, greaterThanOrEqualTo(0));
    await tester.timedDrag(find.text('Nó root'), const Offset(-500, 0), const Duration(milliseconds: 800));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // A árvore saiu de cena para a esquerda: o PageView das abas trocou de aba.
    final after = find.text('Nó root', skipOffstage: false);
    expect(after.evaluate().isEmpty || tester.getTopLeft(after).dx < 0, isTrue);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
