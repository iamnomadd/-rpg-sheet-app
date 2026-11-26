// 1.3.62: o design do Abissal é o padrão de todos os temas. Em cada um dos 11
// temas, a ficha (Em Cena e Status) usa os cards com AbyssFrameBorder na
// paleta do tema, a AbyssResourceBar, as artes e a barra de abas do Abissal;
// o card do personagem 2D continua com 220 de altura e o sprite do tema.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_resource_art.dart';
import 'package:rpg_sheet_app/app/abyss_tab_art.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ownSprite = <String, String>{
  'vampire': 'assets/character2d/vampiric_normal.png',
  'cyberpunk': 'assets/character2d/cyberpunk_normal.png',
  'parchment': 'assets/character2d/pirate_normal.webp',
};

String? _assetOf(Widget w) {
  if (w is! Image) return null;
  final provider = w.image is ResizeImage ? (w.image as ResizeImage).imageProvider : w.image;
  return provider is AssetImage ? provider.assetName : null;
}

Set<String> _assets(WidgetTester tester, String folder) => {
      for (final w in tester.widgetList(find.byType(Image)))
        if ((_assetOf(w) ?? '').startsWith(folder)) _assetOf(w)!,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Cada Card visível usa a moldura do Abissal com o filete na cor do tema.
void _expectFramedCards(WidgetTester tester, String themeId, String where) {
  final palette = abyssPaletteFor(themeId);
  final cards = find.byType(Card);
  expect(cards, findsWidgets, reason: '$themeId/$where');
  for (final card in cards.evaluate()) {
    final material = tester.widget<Material>(find.descendant(of: find.byWidget(card.widget), matching: find.byType(Material)).first);
    expect(material.shape, isA<AbyssFrameBorder>(), reason: '$themeId/$where');
    final frame = material.shape! as AbyssFrameBorder;
    expect(frame.innerColor, palette.goldLine, reason: '$themeId/$where');
    expect(material.color, palette.card, reason: '$themeId/$where');
  }
}

void main() {
  test("o tema 'abyss' se chama Abissal, sem 'experimental', e ids/ordem/padrão não mudam", () {
    final preset = themePreset('abyss');
    expect(preset.name, 'Abissal');
    expect(preset.description, isNot(contains('xperimental')));
    expect(appThemes.map((t) => t.id).toList(), ['classic', 'parchment', 'medieval', 'arcane', 'vampire', 'forest', 'ocean', 'cyberpunk', 'infernal', 'ice', 'abyss']);
    expect(buildTheme().extension<AbyssPalette>(), abyssPaletteFor('classic'));
  });

  for (final preset in appThemes) {
    final themeId = preset.id;
    testWidgets('$themeId: ficha com o design do Abissal na paleta do tema', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.setTheme(themeId);
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', attributes: ['Força'], resources: ['Vida', 'Energia']));
      state.characters.add(Character(
        id: 'p1',
        name: 'Ana',
        systemId: 'sys',
        attributes: {'Força': 2},
        resourceValues: {'Vida': 10, 'Energia': 5},
        resourceMaxValues: {'Vida': 10, 'Energia': 5},
        abilities: ['Bola de Fogo'],
        abilityDetails: {'Bola de Fogo': {'category': 'Magia', 'damage': '20'}},
        inventory: ['Pistola'],
        inventoryDetails: {'Pistola': {'category': 'Arma', 'damage': '10'}},
      ));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme(themeId, false), home: const CharacterScreen(characterId: 'p1')),
      ));
      await _settle(tester);
      final palette = abyssPaletteFor(themeId);
      expect(AbyssPalette.of(tester.element(find.byType(CharacterScreen))), palette);

      // Barra de abas do Abissal, com as artes das abas.
      expect(find.byType(AbyssTabCell), findsWidgets);
      expect(_assets(tester, abyssTabArtFolder), isNotEmpty, reason: 'artes das abas');

      // Em Cena: cards com moldura, barras do Abissal, artes de ação, recurso e título.
      _expectFramedCards(tester, themeId, 'Em Cena');
      expect(find.byType(AbyssResourceBar), findsWidgets);
      expect(_assets(tester, 'assets/icons/action/'), isNotEmpty, reason: 'artes de ação');
      expect(_assets(tester, abyssResourceArtFolder), isNotEmpty, reason: 'artes de recurso');
      expect(_assets(tester, abyssSectionArtFolder), isNotEmpty, reason: 'artes dos títulos');

      // Personagem 2D: card de 220 e o sprite do próprio tema (ou o genérico).
      expect(find.byWidgetPredicate((w) => w is SizedBox && w.height == 220), findsWidgets);
      expect(_assets(tester, 'assets/character2d/'), {_ownSprite[themeId] ?? 'assets/character2d/normal.png'});

      // Status: as mesmas peças.
      await tester.tap(find.text('Status').first);
      await _settle(tester);
      _expectFramedCards(tester, themeId, 'Status');
      expect(find.byType(AbyssResourceBar), findsWidgets);
      expect(_assets(tester, abyssResourceArtFolder), isNotEmpty, reason: 'Status: artes de recurso');
      expect(_assets(tester, abyssSectionArtFolder), isNotEmpty, reason: 'Status: artes dos títulos');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
