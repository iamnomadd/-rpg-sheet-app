// Achados do PR #46 tratados na 1.3.62: C2 (cache do crescimento de texto da
// árvore) e C3 (action_art.dart sem depender do app_state).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _node(String id, {String parent = '', int? level, bool unlocked = false}) => {
      'id': id,
      'name': 'Nó $id',
      'parentId': parent,
      if (level != null) 'level': level,
      'unlocked': unlocked,
    };

void main() {
  group('C2: cache do crescimento de texto dos cartões da árvore', () {
    late AppState state;

    Future<void> pumpTree(WidgetTester tester, {double textScale = 1.0}) async {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildAppTheme('classic', false),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const Scaffold(body: SkillTreeScreen(characterId: 'p1', embedded: true)),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys', skillTree: [_node('a', level: 1), _node('b'), _node('c'), _node('d', parent: 'a')]));
    });

    testWidgets('redesenho sem mudança não recalcula; nós, largura e escala do texto recalculam', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpTree(tester);
      final first = skillTreeTextGrowthComputations;
      expect(first, greaterThan(0));

      // Redesenho sem mudança (o AppState avisa por outro motivo).
      await state.setMasterToolsEnabled(!state.masterToolsEnabled);
      await tester.pump();
      await tester.pump();
      expect(skillTreeTextGrowthComputations, first, reason: 'nada mudou nos cartões, na largura nem no texto');

      // Largura do cartão (cartões compactos nas duas larguras).
      final tree = state.characters.single.skillTree;
      expect(computeSkillTreeLayout(tree, 411).nodeWidth, isNot(computeSkillTreeLayout(tree, 360).nodeWidth));
      tester.view.physicalSize = const Size(411, 800);
      await tester.pump();
      await tester.pump();
      final afterWidth = skillTreeTextGrowthComputations;
      expect(afterWidth, greaterThan(first));

      // Nome, nível ou estado de um nó.
      final character = state.characters.single;
      await state.updateCharacter(Character.fromJson(character.toJson()..['skillTree'] = [_node('a', level: 2, unlocked: true), _node('b'), _node('c'), _node('d', parent: 'a')]));
      await tester.pump();
      await tester.pump();
      final afterNodes = skillTreeTextGrowthComputations;
      expect(afterNodes, greaterThan(afterWidth));

      // Escala do texto.
      final beforeScale = skillTreeTextGrowthComputations;
      await pumpTree(tester, textScale: 1.6);
      expect(skillTreeTextGrowthComputations, greaterThan(beforeScale));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  test('C3: action_art.dart não depende do app_state nem do provider', () {
    final source = File('lib/utils/action_art.dart').readAsStringSync();
    expect(source, isNot(contains('app_state')));
    expect(source, isNot(contains('package:provider')));
    expect(source, isNot(contains('AppState')));
  });
}
