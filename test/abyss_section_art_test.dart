import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_art_size.dart';
import 'package:rpg_sheet_app/app/abyss_tab_art.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _files = ['section_scene', 'section_status', 'section_abilities', 'section_actions', 'section_tree', 'section_skills', 'section_inventory', 'section_sections'];

Future<AppState> _pump(WidgetTester tester, String themeId, {bool compact = false}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setTheme(themeId);
  await state.setCompactMode(compact);
  state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', attributes: ['Força'], resources: ['Vida', 'Energia']));
  state.characters.add(Character(
    id: 'p1',
    name: 'Ana',
    systemId: 'sys',
    attributes: {'Força': 2},
    resourceValues: {'Vida': 5, 'Energia': 3},
    resourceMaxValues: {'Vida': 10, 'Energia': 5},
    abilities: ['Bola de Fogo'],
    abilityDetails: {'Bola de Fogo': {'category': 'Magia', 'damage': '20'}},
    inventory: ['Pistola'],
    inventoryDetails: {'Pistola': {'category': 'Arma', 'damage': '10'}},
  ));
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme(themeId, compact), home: const CharacterScreen(characterId: 'p1'))));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return state;
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

String? _asset(Image image) => image.image is AssetImage ? (image.image as AssetImage).assetName : image.image is ResizeImage && (image.image as ResizeImage).imageProvider is AssetImage ? ((image.image as ResizeImage).imageProvider as AssetImage).assetName : null;

Iterable<Image> _images(WidgetTester tester, String folder) => tester.widgetList<Image>(find.byType(Image)).where((i) => (_asset(i) ?? '').startsWith(folder));

/// Imagem de arte que está na mesma linha (Row) de um texto.
Image? _artBeside(WidgetTester tester, String text) {
  final row = find.ancestor(of: find.text(text).first, matching: find.byType(Row)).first;
  final images = find.descendant(of: row, matching: find.byType(Image));
  return images.evaluate().isEmpty ? null : tester.widget<Image>(images.first);
}

void main() {
  test('os 8 arquivos existem, a pasta está no pubspec e todos são usados', () {
    final onDisk = Directory('assets/icons/sections').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(onDisk, _files.map((f) => '$f.webp').toSet());
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/icons/resources/\n    - assets/icons/sections/\n'));
    expect(abyssSectionArtFiles.values.toSet(), _files.toSet());
    for (final role in abyssSectionArtFiles.keys) {
      expect(File(abyssSectionArt(role)!).existsSync(), isTrue, reason: role);
    }
    expect(abyssSectionArt('session'), '${abyssSectionArtFolder}section_actions.webp');
  });

  group('no Abissal', () {
    testWidgets('títulos e card Sessão com a arte SEM moldura; abas de cima com a de tabs/', (tester) async {
      await _pump(tester, 'abyss');
      expect(_asset(_artBeside(tester, 'Sessão')!), abyssSectionArt('session'));
      expect(_asset(_artBeside(tester, 'Atributos')!), abyssSectionArt('attributes'));
      final sections = _images(tester, abyssSectionArtFolder).map(_asset).toSet();
      expect(sections, containsAll([abyssSectionArt('session'), abyssSectionArt('attributes'), abyssSectionArt('inventory'), abyssSectionArt('abilities')]));
      // As abas de cima continuam com a arte com moldura.
      for (final role in ['general', 'attributesResources', 'abilities', 'skills', 'inventory', 'skillTree', 'sections']) {
        final art = find.descendant(of: find.byKey(ValueKey('abyss-tab-art-$role')), matching: find.byType(Image));
        expect(_asset(tester.widget<Image>(art)), abyssTabArt(role), reason: role);
      }
      await _openTab(tester, 'Status');
      expect(_images(tester, abyssSectionArtFolder).map(_asset), contains(abyssSectionArt('attributes')));
      await _openTab(tester, 'Habilidades');
      expect(_images(tester, abyssSectionArtFolder).map(_asset), contains(abyssSectionArt('abilities')));
      await _openTab(tester, 'Inventário');
      expect(_images(tester, abyssSectionArtFolder).map(_asset), contains(abyssSectionArt('inventory')));
      await _finish(tester);
    });

    for (final compact in [false, true]) {
      testWidgets('todas as artes fora da barra de abas medem ${abyssArtIconSize(compact)} (compacto $compact)', (tester) async {
        await _pump(tester, 'abyss', compact: compact);
        Future<void> check(String where) async {
          final art = [
            ..._images(tester, 'assets/icons/action/'),
            ..._images(tester, abyssSectionArtFolder),
            ..._images(tester, 'assets/icons/resources/'),
          ];
          expect(art, isNotEmpty, reason: where);
          for (final image in art) {
            expect(image.width, abyssArtIconSize(compact), reason: '$where: ${_asset(image)}');
            expect(image.height, abyssArtIconSize(compact), reason: '$where: ${_asset(image)}');
          }
          // A barra de abas segue com o tamanho de antes (22 × 1,35).
          for (final image in _images(tester, abyssTabArtFolder)) {
            expect(image.width, closeTo(22 * abyssTabArtScale, .01));
          }
        }

        await check('Em Cena');
        expect(_images(tester, 'assets/icons/action/'), isNotEmpty, reason: 'artes de ação no Em Cena');
        expect(_images(tester, 'assets/icons/resources/'), isNotEmpty, reason: 'artes de recurso no Em Cena');
        await _openTab(tester, 'Status');
        await check('Status');
        await _openTab(tester, 'Habilidades');
        await check('Habilidades');
        await _openTab(tester, 'Inventário');
        await check('Inventário');
        expect(tester.takeException(), isNull);
        await _finish(tester);
      });
    }
  });
}
