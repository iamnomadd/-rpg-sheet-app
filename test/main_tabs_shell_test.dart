import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/core/feature_flags.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;
  late PageController controller;
  late ValueNotifier<int> index;
  late int pagesBuilds;

  // Uma página por papel de aba; conta quantas vezes a lista de páginas é montada.
  Widget page(String role) {
    if (role == 'characters') pagesBuilds++;
    const names = {
      'characters': 'Fichas',
      'systems': 'Sistemas',
      'tree': 'Árvore',
      'dice': 'Dados',
      'campaigns': 'Mestre',
      'settings': 'Config',
    };
    return Center(child: Text('Página ${names[role]}'));
  }

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, s, _) => MaterialApp(
          theme: buildAppTheme(s.themeId, s.compactMode),
          home: MainTabsShell(controller: controller, index: index, pageBuilder: page),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Color? iconColor(WidgetTester tester, String label) {
    final column = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
    final icon = tester.widget<Icon>(find.descendant(of: column, matching: find.byType(Icon)));
    return icon.color;
  }

  IconData? iconData(WidgetTester tester, String label) {
    final column = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
    return tester.widget<Icon>(find.descendant(of: column, matching: find.byType(Icon))).icon;
  }

  setUp(() {
    // Estes testes cobrem a barra com a aba Dados ligada (como antes da 1.3.52).
    diceTabEnabled = true;
    SharedPreferences.setMockInitialValues({});
    state = AppState();
    controller = PageController();
    index = ValueNotifier<int>(0);
    pagesBuilds = 0;
  });

  tearDown(() {
    diceTabEnabled = false;
    controller.dispose();
    index.dispose();
  });

  for (final masterTools in [false, true]) {
    testWidgets('tocar na barra troca destaque e página (Mestre ${masterTools ? 'ligado' : 'desligado'})', (tester) async {
      await state.setMasterToolsEnabled(masterTools);
      await pumpShell(tester);
      final scheme = Theme.of(tester.element(find.byType(MainTabsShell))).colorScheme;

      expect(find.text('Mestre'), masterTools ? findsOneWidget : findsNothing);
      expect(find.text('Página Fichas'), findsOneWidget);
      expect(iconColor(tester, 'Fichas'), scheme.primary);
      expect(iconColor(tester, 'Sistemas'), scheme.onSurfaceVariant);
      final buildsBefore = pagesBuilds;

      await tester.tap(find.text('Sistemas'));
      await tester.pumpAndSettle();
      expect(find.text('Página Sistemas'), findsOneWidget);
      expect(index.value, 1);
      expect(iconColor(tester, 'Sistemas'), scheme.primary);
      expect(iconColor(tester, 'Fichas'), scheme.onSurfaceVariant);
      // Trocar de aba não reconstrói o shell nem a lista de páginas.
      expect(pagesBuilds, buildsBefore);

      final lastLabel = masterTools ? 'Mestre' : 'Config.';
      final lastPage = masterTools ? 'Página Mestre' : 'Página Config';
      await tester.tap(find.text(lastLabel));
      await tester.pumpAndSettle();
      expect(find.text(lastPage), findsOneWidget);
      expect(iconColor(tester, lastLabel), scheme.primary);
      expect(pagesBuilds, buildsBefore);
    });
  }

  testWidgets('ligar e desligar o Mestre atualiza a barra', (tester) async {
    await pumpShell(tester);
    expect(find.text('Mestre'), findsNothing);
    await state.setMasterToolsEnabled(true);
    await tester.pumpAndSettle();
    expect(find.text('Mestre'), findsOneWidget);
    await state.setMasterToolsEnabled(false);
    await tester.pumpAndSettle();
    expect(find.text('Mestre'), findsNothing);
  });

  testWidgets('com Reduzir animações a troca de aba é imediata', (tester) async {
    await state.setReduceAnimations(true);
    await pumpShell(tester);
    await tester.tap(find.text('Dados'));
    await tester.pump();
    expect(find.text('Página Dados'), findsOneWidget);
    expect(index.value, 3);
  });

  testWidgets('trocar de tema continua atualizando a barra', (tester) async {
    await pumpShell(tester);
    expect(iconData(tester, 'Fichas'), themedMainIcon('classic', 'characters'));
    final classicPrimary = Theme.of(tester.element(find.byType(MainTabsShell))).colorScheme.primary;

    await state.setTheme('parchment');
    await tester.pumpAndSettle();
    final piratePrimary = Theme.of(tester.element(find.byType(MainTabsShell))).colorScheme.primary;
    expect(iconData(tester, 'Fichas'), themedMainIcon('parchment', 'characters'));
    expect(iconColor(tester, 'Fichas'), piratePrimary);
    expect(piratePrimary, isNot(classicPrimary));
  });

  test('cache do tema devolve a mesma instância até o tema ou o modo compacto mudar', () {
    final cache = AppThemeCache();
    final classic = cache.resolve('classic', false);
    expect(identical(cache.resolve('classic', false), classic), isTrue);

    final pirate = cache.resolve('parchment', false);
    expect(identical(pirate, classic), isFalse);
    expect(pirate.colorScheme.primary, buildTheme('parchment').colorScheme.primary);

    final compact = cache.resolve('parchment', true);
    expect(identical(compact, pirate), isFalse);
    expect(compact.visualDensity, const VisualDensity(horizontal: -4, vertical: -4));
    expect(pirate.visualDensity, const VisualDensity(horizontal: -3, vertical: -3));
  });
}
