// 1.3.81 — a barra de abas da ficha acompanha a página atual.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ordem padrão das abas de uma ficha nova.
const _labels = ['Em Cena', 'Status', 'Árvore', 'Habilidades', 'Perícias', 'Inventário', 'Seções'];

void main() {
  const width = 360.0;

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false, double textScale = 1.0, double viewWidth = width}) async {
    tester.view.physicalSize = Size(viewWidth, 1600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({'auto_sync': false, 'reduce_animations': reduceMotion});
    final state = AppState();
    await state.load();
    state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'generic'));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('abyss', false), home: const CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder tabCell(String label) => find.ancestor(of: find.descendant(of: find.byType(AbyssTabCell), matching: find.text(label)), matching: find.byType(AbyssTabCell)).first;

  ScrollPosition barPosition(WidgetTester tester) {
    final scrollable = find.ancestor(of: tabCell('Em Cena'), matching: find.byType(Scrollable)).first;
    return tester.state<ScrollableState>(scrollable).position;
  }

  PageController pages(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!;

  testWidgets('ir para a última aba: a aba fica visível e a barra rola; voltar à primeira: offset 0', (tester) async {
    await pump(tester);
    final position = barPosition(tester);
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(0), reason: 'a barra precisa rolar nesta largura');
    expect(tester.getRect(tabCell('Seções')).right, greaterThan(width), reason: 'a última aba começa fora da tela');

    pages(tester).jumpToPage(_labels.length - 1);
    await settle(tester);
    expect(position.pixels, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent, reason: 'na ponta, só até o limite');
    final last = tester.getRect(tabCell('Seções'));
    expect(last.left, greaterThanOrEqualTo(0));
    expect(last.right, lessThanOrEqualTo(width));

    pages(tester).jumpToPage(0);
    await settle(tester);
    expect(position.pixels, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('deslizar para uma aba do meio: ela fica centralizada', (tester) async {
    await pump(tester);
    pages(tester).jumpToPage(3);
    await settle(tester);
    final rect = tester.getRect(tabCell(_labels[3]));
    final position = barPosition(tester);
    if (position.pixels > 0 && position.pixels < position.maxScrollExtent) {
      expect((rect.center.dx - width / 2).abs(), lessThan(1.5), reason: 'centralizada');
    }
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(width));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tocar numa aba parcialmente visível: ela fica visível e centralizada', (tester) async {
    await pump(tester);
    // A primeira aba que passa da borda direita.
    final partial = _labels.firstWhere((label) {
      final rect = tester.getRect(tabCell(label));
      return rect.left < width && rect.right > width;
    });
    final before = tester.getRect(tabCell(partial));
    await tester.tapAt(Offset((before.left + width) / 2, before.center.dy));
    await settle(tester);
    final after = tester.getRect(tabCell(partial));
    expect(after.left, greaterThanOrEqualTo(0), reason: partial);
    expect(after.right, lessThanOrEqualTo(width), reason: partial);
    final position = barPosition(tester);
    if (position.pixels < position.maxScrollExtent) {
      expect((after.center.dx - width / 2).abs(), lessThan(1.5), reason: 'centralizada');
    }
    expect(tester.widget<AbyssTabCell>(tabCell(partial)).selected, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('com "reduzir movimento", a barra pula direto (sem animação pendente)', (tester) async {
    await pump(tester, reduceMotion: true);
    final position = barPosition(tester);
    pages(tester).jumpToPage(_labels.length - 1);
    await tester.pump();
    await tester.pump();
    final jumped = position.pixels;
    expect(jumped, position.maxScrollExtent);
    expect(position.isScrollingNotifier.value, isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(position.pixels, jumped, reason: 'nenhuma animação depois do pulo');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('arrastar as páginas não rola a barra a cada pixel; só quando a página muda', (tester) async {
    await pump(tester);
    final position = barPosition(tester);
    final gesture = await tester.startGesture(const Offset(300, 900));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(position.pixels, 0, reason: 'página ainda não mudou');
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('texto grande (2.0) em 320 px: a barra acompanha sem estourar', (tester) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('overflowed')) {
        overflows.add(text);
      } else {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);
    await pump(tester, textScale: 2.0, viewWidth: 320);
    for (var i = 0; i < _labels.length; i++) {
      pages(tester).jumpToPage(i);
      await settle(tester);
      final rect = tester.getRect(tabCell(_labels[i]));
      expect(rect.left, greaterThanOrEqualTo(-0.5), reason: _labels[i]);
      expect(rect.right, lessThanOrEqualTo(320.5), reason: _labels[i]);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = previous;
    // Nenhum estouro na barra de abas (os já existentes da main ficam fora).
    expect(overflows.where((o) => o.contains('AbyssTabCell') || o.contains('_CharacterTabsHeader')), isEmpty);
  });
}
