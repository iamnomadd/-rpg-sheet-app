import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/widgets/card_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  Campaign campaign() => Campaign(
        id: 'c1',
        name: 'Mesa',
        masterObjectives: ['[ ] Achar o mapa'],
        locations: ['Porto'],
        sessionLog: ['Começou'],
        npcSheets: [
          for (final name in ['Goblin', 'Orc', 'Lobo'])
            {'id': name, 'kind': 'NPC', 'name': name, 'sheet': {'id': name, 'name': name}},
        ],
        initiative: [
          {'id': 'a', 'name': 'Ana', 'type': 'npc', 'value': 12, 'done': false},
        ],
      );

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    state = AppState();
    state.campaigns.add(campaign());
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('classic', false), home: home),
    ));
    await tester.pumpAndSettle();
  }

  /// Distâncias verticais entre itens consecutivos.
  List<double> gaps(WidgetTester tester, List<Finder> items) {
    final rects = [for (final f in items) tester.getRect(f)];
    return [for (var i = 1; i < rects.length; i++) rects[i].top - rects[i - 1].bottom];
  }

  Finder cardWith(String text) => find.ancestor(of: find.text(text), matching: find.byType(Card)).first;

  test('a separação vem do Em Cena: 10', () {
    expect(cardSpacing, 10);
    expect(cardSpacingMargin, const EdgeInsets.only(bottom: 10));
  });

  testWidgets('Painel do Mestre: cards separados por cardSpacing', (tester) async {
    await pump(tester, const MasterToolsScreen(campaignId: 'c1'));
    final cards = find.byType(Card);
    expect(cards, findsNWidgets(6));
    expect(gaps(tester, [for (var i = 0; i < 6; i++) cards.at(i)]), List.filled(5, cardSpacing));
  });

  testWidgets('Mestre › NPCs: lista separada por cardSpacing', (tester) async {
    await pump(tester, const MasterScreen());
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('NPCs')));
    await tester.pumpAndSettle();
    expect(gaps(tester, [cardWith('Goblin'), cardWith('Orc'), cardWith('Lobo')]), [cardSpacing, cardSpacing]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Mestre › Sessão: cards e o botão Preparar sessão separados por cardSpacing', (tester) async {
    await pump(tester, const MasterScreen());
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Sessão')));
    await tester.pumpAndSettle();
    final button = find.ancestor(of: find.text('Preparar sessão'), matching: find.byType(FilledButton)).first;
    expect(gaps(tester, [cardWith('Sem combate ativo'), cardWith('Ordem de iniciativa'), button]), [cardSpacing, cardSpacing]);
    await tester.pumpWidget(const SizedBox());
  });

  test('aba Config. não muda: o cardTheme global continua sem margem', () {
    for (final themeId in appThemes.map((t) => t.id)) {
      expect(buildAppTheme(themeId, false).cardTheme.margin, EdgeInsets.zero, reason: themeId);
    }
  });
}
