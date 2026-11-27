// 1.3.80 — títulos das abas da ficha em Cinzel, sem ícone e com ornamento;
// e o recurso de custo dos modelos de árvore.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_tab_art.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/skill_tree_templates.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Títulos do topo de cada aba da ficha (aba → título).
const _tabTitles = {
  'Status': 'Atributos',
  'Habilidades': 'Habilidades',
  'Perícias': 'Perícias do sistema',
  'Inventário': 'Inventário',
  'Árvore': 'Árvore de Habilidades',
  'Seções': 'Seções da ficha',
};

void main() {
  test('a família "Cinzel" está registrada (peso 700) e a licença vai junto no build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('  fonts:\n    - family: Cinzel\n      fonts:\n        - asset: assets/fonts/Cinzel-Bold.ttf\n          weight: 700'));
    expect(pubspec, contains('    - assets/fonts/OFL-Cinzel.txt\n'));
    expect(File('assets/fonts/Cinzel-Bold.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-Cinzel.txt').readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    expect(pubspec, isNot(contains('google_fonts')));
  });

  for (final themeId in ['abyss', 'vampire']) {
    testWidgets('AbyssTabTitle em $themeId: Cinzel 700 no tamanho e na cor do titleLarge, com filete e losango da paleta', (tester) async {
      final theme = buildAppTheme(themeId, false);
      await tester.pumpWidget(MaterialApp(theme: theme, home: const Scaffold(body: AbyssTabTitle('Atributos'))));
      final text = tester.widget<Text>(find.text('Atributos'));
      expect(text.style!.fontFamily, abyssTitleFontFamily);
      expect(abyssTitleFontFamily, 'Cinzel');
      expect(text.style!.fontWeight, FontWeight.w700);
      // O titleLarge do tema já resolvido (com a tipografia do app).
      final resolved = Theme.of(tester.element(find.text('Atributos'))).textTheme.titleLarge!;
      expect(text.style!.fontSize, resolved.fontSize);
      expect(text.style!.color, resolved.color);
      expect(text.style!.color, isNotNull);
      final ornament = find.byKey(const ValueKey('abyss-tab-title-ornament'));
      expect(ornament, findsOneWidget);
      final painter = tester.widget<CustomPaint>(find.descendant(of: ornament, matching: find.byType(CustomPaint))).painter! as AbyssTitleOrnamentPainter;
      expect(painter.color, abyssPaletteFor(themeId).gold);
      // O filete tem a largura do texto.
      expect(tester.getSize(ornament).width, tester.getSize(find.text('Atributos')).width);
    });
  }

  test('as duas paletas testadas têm cores de ornamento diferentes', () {
    expect(abyssPaletteFor('abyss').gold, isNot(abyssPaletteFor('vampire').gold));
  });

  testWidgets('texto longo: o título quebra linha e o filete fica na largura disponível', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme('abyss', false),
      home: const Scaffold(body: SizedBox(width: 160, child: AbyssTabTitle('Um título realmente comprido demais para a linha'))),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('abyss-tab-title-ornament'))).width, lessThanOrEqualTo(160));
    expect(tester.getSize(find.byType(Text)).height, greaterThan(40), reason: 'quebrou em mais de uma linha');
  });

  Future<void> pumpSheet(WidgetTester tester, {Size size = const Size(800, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false, 'theme_id': 'abyss'});
    final state = AppState();
    await state.load();
    state.characters.add(Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'dnd5e',
      abilities: ['Golpe'],
      inventory: ['Espada'],
      skillTree: [
        {'id': 'a', 'name': 'Nó a', 'parentId': '', 'level': 1, 'unlocked': false},
      ],
    ));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('abyss', false), home: const CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    // A barra de abas rola na horizontal: traz a aba para a tela antes de tocar.
    await tester.ensureVisible(find.text(label).first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text(label).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('os títulos do topo das abas usam o AbyssTabTitle e não têm ícone', (tester) async {
    await pumpSheet(tester);
    // Em Cena: os títulos dos cards continuam com a arte sem moldura.
    expect(find.byType(ThemedSectionIcon), findsWidgets);
    for (final entry in _tabTitles.entries) {
      await openTab(tester, entry.key);
      final title = find.widgetWithText(AbyssTabTitle, entry.value);
      expect(title, findsOneWidget, reason: entry.key);
      // Na linha do título não há ícone de seção nem ícone do tema.
      final row = find.ancestor(of: title, matching: find.byType(Row));
      if (row.evaluate().isNotEmpty) {
        expect(find.descendant(of: row.first, matching: find.byType(ThemedSectionIcon)), findsNothing, reason: entry.key);
      }
      // Ícones das abas (em cima) continuam com a arte.
      expect(find.byKey(const ValueKey('abyss-tab-art-general')), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('texto grande: os títulos das abas não estouram (320 px, texto 2.0)', (tester) async {
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
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSheet(tester, size: const Size(320, 3000));
    for (final entry in _tabTitles.entries) {
      await openTab(tester, entry.key);
      final title = find.widgetWithText(AbyssTabTitle, entry.value);
      expect(title, findsOneWidget, reason: entry.key);
      expect(tester.getRect(title).right, lessThanOrEqualTo(320), reason: entry.key);
      expect(tester.getSize(find.descendant(of: title, matching: find.byKey(const ValueKey('abyss-tab-title-ornament')))).width, lessThanOrEqualTo(320));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = previous;
    // Nenhum estouro vem do título novo (os já existentes da main ficam fora).
    expect(overflows.where((o) => o.contains('AbyssTabTitle') || o.contains('IntrinsicWidth')), isEmpty);
  });

  group('costResource (1.3.80)', () {
    test('sistemas padrão: Tormenta20 → PM; D&D 5e → sem custo; Sistema Padrão → Energia', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.load();
      List<String> resources(String id) => state.systems.firstWhere((s) => s.id == id).resources;
      expect(SkillTreeTemplates.costResource(resources('tormenta20')), 'PM');
      expect(SkillTreeTemplates.costResource(resources('dnd5e')), isNull, reason: 'Vida, PV Temporários e Inspiração');
      expect(SkillTreeTemplates.costResource(resources('generic')), 'Energia');
      expect(SkillTreeTemplates.costResource(resources('ordem_paranormal')), 'PE');
      expect(SkillTreeTemplates.costResource(resources('shadowdark')), isNull);
    });

    test('energia/magia primeiro; depois o primeiro que não é vida nem excluído; senão sem custo', () {
      expect(SkillTreeTemplates.costResource(['Vida']), isNull);
      expect(SkillTreeTemplates.costResource(['Sorte', 'Mana']), 'Mana');
      expect(SkillTreeTemplates.costResource(['Vida', 'Pontos de Mana']), 'Pontos de Mana');
      expect(SkillTreeTemplates.costResource(['Vida', 'Pontos de Esforço']), 'Pontos de Esforço');
      for (final energy in ['Estamina', 'Vigor', 'Ki', 'Fôlego', 'FOLEGO', 'pm']) {
        expect(SkillTreeTemplates.costResource(['Vida', 'Inspiração', energy]), energy);
      }
      expect(SkillTreeTemplates.costResource(['Vida', 'Defesa', 'XP', 'Experiência', 'Ouro']), 'Ouro');
      expect(SkillTreeTemplates.costResource(['PV', 'Sorte', 'Sanidade', 'Defesa', 'Inspiração']), isNull);
    });

    test('árvores já geradas não mudam (vale só para novas gerações)', () {
      final old = SkillTreeTemplates.forClass('Mago', resources: const ['Vida', 'Energia']);
      final cost = old.firstWhere((n) => n['name'] == 'Bola de Fogo')['ability'] as Map;
      expect(cost['resource'], 'Energia');
      // Gerar de novo com outros recursos não toca na árvore já gravada.
      SkillTreeTemplates.forClass('Mago', resources: const ['Vida', 'Mana']);
      expect(cost['resource'], 'Energia');
    });
  });
}
