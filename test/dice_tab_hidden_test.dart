import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/core/feature_flags.dart';
import 'package:rpg_sheet_app/screens/dice/dice_screen.dart';
import 'package:rpg_sheet_app/screens/settings/settings_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;
  late PageController controller;
  late ValueNotifier<int> index;

  Widget page(String role) => role == 'dice' ? const DiceScreen() : Center(child: Text('Página $role'));

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: MainTabsShell(controller: controller, index: index, pageBuilder: page)),
    ));
    await tester.pumpAndSettle();
  }

  List<String> barLabels() => [
        for (final label in ['Fichas', 'Sistemas', 'Árvore', 'Dados', 'Mestre', 'Config.'])
          if (find.text(label).evaluate().isNotEmpty) label,
      ];

  int pageCount(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).childrenDelegate.estimatedChildCount!;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state = AppState();
    controller = PageController();
    index = ValueNotifier<int>(0);
  });

  tearDown(() {
    diceTabEnabled = false;
    controller.dispose();
    index.dispose();
  });

  test('o interruptor vem desligado', () {
    expect(diceTabEnabled, isFalse);
  });

  testWidgets('desligada: sem botão Dados e sem DiceScreen; ligada: volta como antes', (tester) async {
    await pumpShell(tester);
    expect(find.text('Dados'), findsNothing);
    expect(find.byType(DiceScreen, skipOffstage: false), findsNothing);
    expect(barLabels(), ['Fichas', 'Sistemas', 'Árvore', 'Config.']);
    expect(pageCount(tester), 4);

    diceTabEnabled = true;
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    controller = PageController();
    await pumpShell(tester);
    expect(barLabels(), ['Fichas', 'Sistemas', 'Árvore', 'Dados', 'Config.']);
    expect(pageCount(tester), 5);
    await tester.tap(find.text('Dados'));
    await tester.pumpAndSettle();
    expect(find.byType(DiceScreen), findsOneWidget);
    expect(index.value, 3);
  });

  for (final dice in [false, true]) {
    testWidgets('Mestre liga e desliga na ordem certa (Dados ${dice ? 'ligada' : 'desligada'})', (tester) async {
      diceTabEnabled = dice;
      await pumpShell(tester);
      final base = ['Fichas', 'Sistemas', 'Árvore', if (dice) 'Dados'];
      expect(barLabels(), [...base, 'Config.']);
      expect(pageCount(tester), barLabels().length);

      await state.setMasterToolsEnabled(true);
      await tester.pumpAndSettle();
      expect(barLabels(), [...base, 'Mestre', 'Config.']);
      expect(pageCount(tester), barLabels().length);
      expect(mainTabs(masterToolsEnabled: true).map((t) => t.role), ['characters', 'systems', 'tree', if (dice) 'dice', 'campaigns', 'settings']);

      await state.setMasterToolsEnabled(false);
      await tester.pumpAndSettle();
      expect(barLabels(), [...base, 'Config.']);
      expect(pageCount(tester), barLabels().length);
    });
  }

  for (final dice in [false, true]) {
    for (final master in [false, true]) {
      testWidgets('link de confirmação leva à aba Config. (Dados $dice, Mestre $master)', (tester) async {
        diceTabEnabled = dice;
        await state.setMasterToolsEnabled(master);
        await pumpShell(tester);
        // Mesmo cálculo usado em _handleIncomingLink.
        final target = mainTabIndex('settings', masterToolsEnabled: master);
        expect(target, (dice ? 4 : 3) + (master ? 1 : 0));
        index.value = target;
        controller.jumpToPage(target);
        await tester.pumpAndSettle();
        expect(find.text('Página settings'), findsOneWidget);
        final column = find.ancestor(of: find.text('Config.'), matching: find.byType(Column)).first;
        final icon = tester.widget<Icon>(find.descendant(of: column, matching: find.byType(Icon)));
        // Design do Abissal (padrão desde a 1.3.62): a aba selecionada usa goldLight da paleta.
        expect(icon.color, AbyssPalette.of(tester.element(find.byType(MainTabsShell))).goldLight);
      });
    }
  }

  testWidgets('aba inativa ou índice fora do intervalo não dá erro', (tester) async {
    // Papel que não está na barra (Dados escondida) cai na primeira aba.
    expect(mainTabIndex('dice', masterToolsEnabled: false), 0);
    expect(mainTabIndex('campaigns', masterToolsEnabled: false), 0);
    index.value = 9;
    await pumpShell(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Fichas'), findsOneWidget);
  });

  testWidgets('histórico de rolagens e contagem em Configurações continuam com a aba escondida', (tester) async {
    final history = [
      {'expression': '1d20', 'sides': 20, 'count': 1, 'modifier': 0, 'mode': 'normal', 'rolls': [7], 'result': 7, 'timestamp': 1},
      {'expression': '2d6', 'sides': 6, 'count': 2, 'modifier': 0, 'mode': 'normal', 'rolls': [3, 4], 'result': 7, 'timestamp': 2},
    ];
    SharedPreferences.setMockInitialValues({'dice_history': jsonEncode(history), 'auto_sync': false});
    state = AppState();
    await state.load();
    expect(state.diceHistory.length, 2);
    // Rolagem de perícia não depende da DiceScreen: grava no mesmo histórico.
    state.rollAdvanced(sides: 20, modifier: 2, label: 'Furtividade');
    expect(state.diceHistory.length, 3);

    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('3 rolagens'), findsOneWidget);
    expect(find.text('Remove somente o histórico de rolagens.', skipOffstage: false), findsOneWidget);
    expect(state.diceHistory.length, 3);
  });
}
