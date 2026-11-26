// 1.3.71 — número flutuante nos recursos da ficha do jogador.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/resource_delta.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  Character character(String id, {int vida = 10}) => Character(
        id: id,
        name: id == 'p1' ? 'Ana' : 'Bia',
        systemId: 'sys',
        resourceValues: {'Vida': vida, 'Energia': 5},
        resourceMaxValues: {'Vida': 20, 'Energia': 10},
      );

  Future<void> pump(WidgetTester tester, {String id = 'p1', bool disableAnimations = false}) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    state = AppState();
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
    state.characters.addAll([character('p1'), character('p2', vida: 4)]);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations), child: child!),
        home: CharacterScreen(characterId: id),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Finder health(String tooltip) => find.descendant(of: find.byKey(const ValueKey('general-health')), matching: find.byTooltip(tooltip));
  Finder delta(String resource) => find.byKey(ValueKey('resource-delta-$resource'));
  String deltaText(WidgetTester tester, String resource) => tester.widget<Text>(delta(resource)).data!;

  testWidgets('diminuir a vida mostra "−N" vermelho; aumentar mostra "+N" verde', (tester) async {
    await pump(tester);
    expect(delta('Vida'), findsNothing);
    await tester.tap(health('Diminuir'));
    await tester.pump();
    expect(deltaText(tester, 'Vida'), '−1');
    expect(tester.widget<Text>(delta('Vida')).style!.color, resourceDeltaDownColor);
    await tester.pump(const Duration(seconds: 2));
    expect(delta('Vida'), findsNothing);
    await tester.tap(health('Aumentar'));
    await tester.pump();
    expect(deltaText(tester, 'Vida'), '+1');
    expect(tester.widget<Text>(delta('Vida')).style!.color, resourceDeltaUpColor);
    await finish(tester);
  });

  testWidgets('toques rápidos somam num número só, que some depois da animação', (tester) async {
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(health('Diminuir'));
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(delta('Vida'), findsOneWidget);
    expect(deltaText(tester, 'Vida'), '−3');
    await tester.tap(health('Aumentar'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(deltaText(tester, 'Vida'), '−2');
    // A soma é só do recurso tocado.
    expect(delta('Energia'), findsNothing);
    await tester.pump(resourceDeltaDuration + const Duration(milliseconds: 100));
    expect(delta('Vida'), findsNothing);
    expect(state.characters.firstWhere((c) => c.id == 'p1').resourceValues['Vida'], 8);
    await finish(tester);
  });

  testWidgets('o número sobe e não muda a altura dos cards', (tester) async {
    await pump(tester);
    final cards = [for (final key in ['general-health', 'general-energy']) find.byKey(ValueKey(key))];
    // Inclui o card do personagem 2D (altura fixa 220).
    final card2d = find.byWidgetPredicate((w) => w is SizedBox && w.height == 220);
    expect(card2d, findsWidgets);
    final before = [for (final card in cards) tester.getSize(card), tester.getSize(card2d.first)];
    await tester.tap(health('Diminuir'));
    await tester.pump();
    final start = tester.getTopLeft(delta('Vida')).dy;
    await tester.pump(const Duration(milliseconds: 450));
    final middle = tester.getTopLeft(delta('Vida')).dy;
    expect(start - middle, greaterThan(8));
    expect(start - middle, lessThanOrEqualTo(resourceDeltaRise));
    expect([for (final card in cards) tester.getSize(card), tester.getSize(card2d.first)], before);
    await finish(tester);
  });

  testWidgets('com animações desligadas, o número aparece sem deslocamento', (tester) async {
    await pump(tester, disableAnimations: true);
    await tester.tap(health('Diminuir'));
    await tester.pump();
    final start = tester.getTopLeft(delta('Vida'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.getTopLeft(delta('Vida')), start);
    final transform = tester.widget<Transform>(find.ancestor(of: delta('Vida'), matching: find.byType(Transform)).first);
    expect(transform.transform.getTranslation().y, 0);
    await finish(tester);
  });

  testWidgets('sem número ao abrir, ao trocar de ficha ou com mudança vinda de fora', (tester) async {
    await pump(tester);
    expect(find.byType(FloatingResourceDelta), findsWidgets);
    expect(delta('Vida'), findsNothing);
    // Mudança que não vem da tela (nuvem/Mestre): sem número.
    final c = state.characters.firstWhere((c) => c.id == 'p1');
    c.resourceValues['Vida'] = 2;
    await state.updateCharacter(c);
    await tester.pump(const Duration(milliseconds: 300));
    expect(delta('Vida'), findsNothing);
    // Trocar de ficha: sem número.
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: CharacterScreen(characterId: 'p2')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(delta('Vida'), findsNothing);
    expect(delta('Energia'), findsNothing);
    await finish(tester);
  });
}
