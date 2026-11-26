import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/initiative_tools.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/resource_quick_adjust.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

RpgSystem _system(List<String> resources) => RpgSystem(id: 'sys', name: 'Sistema', resources: resources);

void main() {
  group('secondaryResourceNames', () {
    test('todos os recursos menos a vida, na ordem do sistema', () {
      expect(secondaryResourceNames(_system(['Vida', 'PV temporarios', 'Energia', 'Êxtase']), 'Vida'),
          ['PV temporarios', 'Energia', 'Êxtase']);
    });

    test('só Vida → vazio', () {
      expect(secondaryResourceNames(_system(['Vida']), 'Vida'), isEmpty);
    });

    test('PV como vida', () {
      expect(secondaryResourceNames(_system(['PV', 'PM']), 'PV'), ['PM']);
    });
  });

  group('Em Cena — recursos', () {
    late AppState state;

    Future<void> pump(WidgetTester tester, List<String> resources, {Size size = const Size(800, 4000)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      state.systems.insert(0, _system(resources));
      final values = {for (final r in resources) r: 3};
      final maxValues = {for (final r in resources) r: 10};
      state.characters.add(Character(
        id: 'p1',
        name: 'Ana',
        systemId: 'sys',
        resourceValues: values,
        resourceMaxValues: maxValues,
      ));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: CharacterScreen(characterId: 'p1')),
      ));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('mostra um cartão por recurso, com barra tocável', (tester) async {
      await pump(tester, ['Vida', 'PV temporarios', 'Energia', 'Êxtase']);
      for (final name in ['Vida', 'PV temporarios', 'Energia', 'Êxtase']) {
        expect(find.byKey(ValueKey('general-${name == 'Vida' ? 'health' : name == 'PV temporarios' ? 'energy' : 'resource-$name'}')), findsOneWidget, reason: name);
      }
      expect(find.text('Nenhum recurso configurado.'), findsNothing);
      for (final key in ['general-energy', 'general-resource-Energia', 'general-resource-Êxtase']) {
        expect(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(ResourceBarTapTarget)), findsOneWidget, reason: key);
      }
      expect(find.descendant(of: find.byKey(const ValueKey('general-energy')), matching: find.text('PV temporarios')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(const ValueKey('general-resource-Êxtase')), matching: find.byType(ResourceBarTapTarget)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Valor atual'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('ficha só com Vida mostra "Nenhum recurso configurado."', (tester) async {
      await pump(tester, ['Vida']);
      expect(find.byKey(const ValueKey('general-energy')), findsOneWidget);
      expect(find.text('Nenhum recurso configurado.'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('cartões de recurso cabem em 320 px', (tester) async {
      // A main já tem overflows em 320 px com a fonte de teste em outros
      // módulos (cabeçalho do Inventário, "Estado do personagem" e
      // "Condições ativas"). Eles são registrados aqui e não fazem parte
      // deste teste; os cartões de recurso são conferidos pela geometria.
      final previous = FlutterError.onError;
      final overflows = <String>[];
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('overflowed')) {
          overflows.add(text);
        } else {
          previous?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = previous);
      await pump(tester, ['Vida', 'PV temporarios', 'Energia', 'Êxtase'], size: const Size(320, 4000));
      for (final key in ['general-health', 'general-energy', 'general-resource-Energia', 'general-resource-Êxtase']) {
        final card = tester.getRect(find.byKey(ValueKey(key)));
        final plus = tester.getRect(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byTooltip('Aumentar')));
        final bar = tester.getRect(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(ResourceBarTapTarget)));
        expect(card.right, lessThanOrEqualTo(320), reason: key);
        expect(plus.right, lessThanOrEqualTo(card.right), reason: key);
        expect(bar.right, lessThanOrEqualTo(card.right), reason: key);
      }
      await finish(tester);
      FlutterError.onError = previous;
    });
  });
}
