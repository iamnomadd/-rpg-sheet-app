import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_resource_art.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _table = <String, List<int>>{
  'Vida': [0xFF8F1B1B, 0xFFD93A3A],
  'PV Temporários': [0xFFA0581A, 0xFFF0A040],
  'Sangue': [0xFF5E0B14, 0xFFA3192B],
  'Energia': [0xFF2D5F96, 0xFF5A9BDA],
  'Mana': [0xFF2B3A8F, 0xFF5B6FE0],
  'Sanidade': [0xFF5B4A8F, 0xFFA899E0],
  'Vontade': [0xFF8C7A4A, 0xFFF2E3B0],
  'Exaustão': [0xFF4A3F36, 0xFF8C7A68],
  'Fôlego': [0xFF2A7F8F, 0xFF6FD0DE],
  'Estamina': [0xFF2F6B2A, 0xFF6DBA4F],
  'Escudo': [0xFF4A5560, 0xFF9AA6B2],
  'Fé': [0xFF8A6A1E, 0xFFE6C25A],
  'Fúria': [0xFF8A2A0E, 0xFFE5532A],
  'Êxtase': [0xFF7A1F6B, 0xFFE04FB8],
  'Ki': [0xFF3E6E9E, 0xFFB8DDF5],
  'Humanidade': [0xFF7A6A58, 0xFFD6C6A8],
  'Fome': [0xFF7A4A1E, 0xFFC9863E],
  'Sede': [0xFF1E5A8A, 0xFF4FA8E0],
  'Sorte': [0xFF1E7A4A, 0xFF4FD68A],
  'XP': [0xFF9A7A1A, 0xFFF5D55A],
  'Corrupção': [0xFF2A3A1A, 0xFF7FA83A],
  'Temperatura': [0xFFE0642A, 0xFF6FC8F0],
  'Moral': [0xFF8A1F2A, 0xFFD6A030],
};

const _sheetResources = ['Vida', 'PV Temporários', 'Energia', 'Êxtase'];

Future<AppState> _state(String themeId) async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setTheme(themeId);
  state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: _sheetResources));
  state.characters.add(Character(
    id: 'p1',
    name: 'Ana',
    systemId: 'sys',
    resourceValues: {for (final r in _sheetResources) r: 5},
    resourceMaxValues: {for (final r in _sheetResources) r: 10},
  ));
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Cor do pixel do meio de uma barra cheia (meio do gradiente).
Future<Color> _middleColor(WidgetTester tester, Widget bar) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: 200, child: bar))),
  ));
  final bytes = await tester.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  });
  final i = (7 * 200 + 100) * 4;
  return Color.fromARGB(bytes!.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
}

void _expectNear(Color actual, Color expected) {
  expect((actual.r - expected.r).abs(), lessThan(.03), reason: '$actual ≈ $expected');
  expect((actual.g - expected.g).abs(), lessThan(.03), reason: '$actual ≈ $expected');
  expect((actual.b - expected.b).abs(), lessThan(.03), reason: '$actual ≈ $expected');
}

void main() {
  group('tabela de cores das barras (23 tipos)', () {
    for (final e in _table.entries) {
      test('${e.key} → ${e.value.map((c) => c.toRadixString(16)).join(' / ')}', () {
        expect(abyssResourceBarColors(e.key), [Color(e.value[0]), Color(e.value[1])]);
      });
    }
    test('cobre os 23 tipos (todos menos o genérico)', () {
      final kinds = _table.keys.map(abyssResourceKind).toSet();
      expect(kinds.length, 23);
      expect(abyssResourceBarColorTable.keys.toSet(), kinds);
    });
    test('nome vazio e genérico → null (barra de sempre)', () {
      expect(abyssResourceBarColors(''), isNull);
      expect(abyssResourceBarColors('XYZ'), isNull);
    });
  });

  group('AbyssResourceBar', () {
    testWidgets('sem colors: vida/energia como antes', (tester) async {
      _expectNear(await _middleColor(tester, const AbyssResourceBar(value: 1)), Color.lerp(AbyssColors.life[0], AbyssColors.life[1], .5)!);
      _expectNear(await _middleColor(tester, const AbyssResourceBar(value: 1, secondary: true)), Color.lerp(AbyssColors.energy[0], AbyssColors.energy[1], .5)!);
    });
    testWidgets('com colors: usa as cores passadas', (tester) async {
      const colors = [Color(0xFF7A1F6B), Color(0xFFE04FB8)];
      _expectNear(await _middleColor(tester, const AbyssResourceBar(value: 1, colors: colors)), Color.lerp(colors[0], colors[1], .5)!);
      _expectNear(await _middleColor(tester, const AbyssResourceBar(value: 1, secondary: true, colors: colors)), Color.lerp(colors[0], colors[1], .5)!);
    });
  });

  testWidgets('Abissal: Vida, PV Temporários, Energia e Êxtase em vermelho, laranja, azul e magenta', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = await _state('abyss');
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme('abyss', false), home: const CharacterScreen(characterId: 'p1'))));
    await _settle(tester);
    // Em Cena e depois a aba Status.
    for (final pass in ['Em Cena', 'Status']) {
      if (pass == 'Status') {
        await tester.tap(find.text('Status').first);
        await _settle(tester);
      }
      for (final name in _sheetResources) {
        final card = find.ancestor(of: find.text(name).last, matching: find.byType(Card)).first;
        final bar = tester.widget<AbyssResourceBar>(find.descendant(of: card, matching: find.byType(AbyssResourceBar)));
        expect(bar.colors, [Color(_table[name]![0]), Color(_table[name]![1])], reason: '$pass/$name');
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final themeId in ['classic', 'parchment', 'vampire', 'cyberpunk', 'ice']) {
    testWidgets('$themeId: barras de sempre (themedResourceBarColors), sem AbyssResourceBar', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = await _state(themeId);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme(themeId, false), home: const CharacterScreen(characterId: 'p1'))));
      await _settle(tester);
      await tester.tap(find.text('Status').first);
      await _settle(tester);
      expect(find.byType(AbyssResourceBar), findsNothing);
      final gradients = tester.widgetList<Container>(find.byType(Container)).map((c) => c.decoration).whereType<BoxDecoration>().map((d) => d.gradient).whereType<LinearGradient>().map((g) => g.colors).toList();
      for (final secondary in [false, true]) {
        expect(gradients.any((c) => listEquals(c, themedResourceBarColors(themeId, secondary: secondary))), isTrue, reason: 'secondary=$secondary');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
