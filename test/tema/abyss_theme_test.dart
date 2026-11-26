import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_sprites.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _iconRoles = ['general', 'attributes', 'attributesResources', 'actions', 'combat', 'skills', 'resources', 'sections', 'extras', 'inventory', 'abilities', 'skillTree'];
const _mainRoles = ['characters', 'systems', 'tree', 'dice', 'campaigns', 'settings'];

void main() {
  test("(a) 'abyss' aparece uma vez em appThemes, no fim, e os ids são únicos", () {
    final ids = appThemes.map((t) => t.id).toList();
    expect(ids.where((id) => id == 'abyss').length, 1);
    expect(ids.last, 'abyss');
    expect(ids.toSet().length, ids.length);
    expect(themePreset('abyss').name, 'Abissal');
    expect(themePreset('abyss').brightness, Brightness.dark);
  });

  test("(b) themePreset('abyss') e id desconhecido cai no Clássico", () {
    expect(themePreset('abyss').id, 'abyss');
    expect(themePreset('tema-que-nao-existe').id, 'classic');
  });

  test('(c) buildTheme(abyss) devolve ThemeData escuro com as molduras', () {
    final theme = buildTheme('abyss');
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AbyssColors.gold);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(theme.cardTheme.margin, EdgeInsets.zero);
    expect(theme.cardTheme.shape, isA<AbyssFrameBorder>());
    expect(theme.dialogTheme.shape, isA<AbyssFrameBorder>());
    expect(theme.chipTheme.shape, isA<AbyssFrameBorder>());
    expect(theme.filledButtonTheme.style!.shape!.resolve({}), isA<AbyssFrameBorder>());
    expect(theme.inputDecorationTheme.border, isA<AbyssInputBorder>());
    expect(buildAppTheme('abyss', true).visualDensity, const VisualDensity(horizontal: -4, vertical: -4));
  });

  test('(d) ícones do Abissal nunca caem no fallback', () {
    for (final role in _iconRoles) {
      final icon = themedIcon('abyss', role);
      expect(icon, isNot(Icons.circle), reason: role);
    }
    expect(themedIcon('abyss', 'general'), Icons.explore);
    expect(themedIcon('abyss', 'attributesResources'), Icons.anchor);
    expect(themedIcon('abyss', 'skillTree'), Icons.alt_route);
    expect(themedIcon('abyss', 'abilities'), Icons.flash_on);
    expect(themedIcon('abyss', 'skills'), Icons.menu_book_outlined);
    for (final role in _mainRoles) {
      expect(themedMainIcon('abyss', role), isNot(Icons.circle), reason: role);
    }
    expect(themedNavigationIndicatorShape('abyss'), isA<AbyssFrameBorder>());
  });

  test('(e) os demais temas montam sem exceção com as molduras do Abissal (padrão desde a 1.3.62)', () {
    for (final preset in appThemes.where((t) => t.id != 'abyss')) {
      final theme = buildTheme(preset.id);
      expect(theme.cardTheme.shape, isA<AbyssFrameBorder>(), reason: preset.id);
      expect(themedNavigationIndicatorShape(preset.id), isA<AbyssFrameBorder>());
    }
  });

  test('(f) AbyssFrameBorder: paths, dimensions, scale e lerp', () {
    const border = AbyssFrameBorder();
    const rect = Rect.fromLTWH(0, 0, 200, 120);
    final outer = border.getOuterPath(rect);
    final inner = border.getInnerPath(rect);
    expect(outer.getBounds(), rect);
    expect(rect.contains(inner.getBounds().topLeft), isTrue);
    // Canto chanfrado: o ponto do canto fica fora da forma.
    expect(outer.contains(const Offset(1, 1)), isFalse);
    expect(outer.contains(const Offset(100, 60)), isTrue);
    expect(border.dimensions, EdgeInsets.all(border.side.strokeInset));
    expect(border.dimensions.horizontal, lessThanOrEqualTo(border.chamfer));
    // Retângulos pequenos ou vazios não quebram.
    for (final r in [Rect.zero, const Rect.fromLTWH(0, 0, 4, 4), const Rect.fromLTWH(0, 0, 30, 10)]) {
      border.getOuterPath(r);
      border.getInnerPath(r);
    }
    expect((border.scale(.5) as AbyssFrameBorder).chamfer, border.chamfer / 2);
    final mid = border.lerpTo(const AbyssFrameBorder(chamfer: 21), .5) as AbyssFrameBorder;
    expect(mid.chamfer, 16);
    expect(border.copyWith(side: BorderSide.none).side, BorderSide.none);
    // paint não lança, com ornamentos e sombra.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const AbyssFrameBorder(shadowOffset: 2).paint(canvas, rect);
    const AbyssInputBorder().paint(canvas, rect, gapStart: 12, gapExtent: 40, gapPercentage: 1);
    recorder.endRecording().dispose();
  });

  test('personagem 2D do Abissal usa os sprites genéricos', () {
    expect(characterUsesSpecialSprite('abyss'), isFalse);
    expect(characterSpritePath(themeId: 'abyss', pose: 'normal'), 'assets/character2d/normal.png');
  });

  testWidgets('a ficha monta no tema Abissal (abas, cards, barras, personagem 220)', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    await state.setTheme('abyss');
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
    state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys', resourceValues: {'Vida': 7, 'Energia': 3}, resourceMaxValues: {'Vida': 10, 'Energia': 5}));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('abyss', false), home: const CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byType(AbyssTabCell), findsWidgets);
    expect(find.byType(AbyssResourceBar), findsWidgets);
    final cardHeights = tester.widgetList<SizedBox>(find.byWidgetPredicate((w) => w is SizedBox && w.height == 220));
    expect(cardHeights, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('outro tema na mesma ficha usa o design do Abissal (padrão desde a 1.3.62)', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    await state.setTheme('parchment');
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
    state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys', resourceValues: {'Vida': 7, 'Energia': 3}, resourceMaxValues: {'Vida': 10, 'Energia': 5}));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('parchment', false), home: const CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AbyssTabCell), findsWidgets);
    expect(find.byType(AbyssResourceBar), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('fundo do Abissal: fumaça estática e sem capturar toques', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: AbyssBackground(child: Center(child: TextButton(onPressed: () => taps++, child: const Text('ok')))),
    ));
    final paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(AbyssBackground), matching: find.byType(CustomPaint)).first);
    expect(paint.painter, isA<AbyssSmokePainter>());
    expect(paint.painter!.shouldRepaint(const AbyssSmokePainter()), isFalse);
    expect(find.ancestor(of: find.byWidget(paint), matching: find.byType(IgnorePointer)), findsWidgets);
    await tester.tap(find.text('ok'));
    expect(taps, 1);
  });
}
