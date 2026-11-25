import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/combat_tab.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/utils/action_art.dart';
import 'package:rpg_sheet_app/utils/spell_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? art(ActionArtKind kind, String name, {String description = '', String category = ''}) {
  final path = ActionArtResolver.resolve(kind: kind, name: name, description: description, category: category);
  return path?.replaceFirst(ActionArtResolver.folder, '').replaceFirst('.webp', '');
}

/// Ícones do SpellIconResolver na ordem das 21 categorias.
const _oldIcons = [
  Icons.local_fire_department_outlined, Icons.bolt, Icons.ac_unit, Icons.science_outlined, Icons.healing,
  Icons.shield_outlined, Icons.bloodtype_outlined, Icons.dangerous_outlined, Icons.nights_stay_outlined,
  Icons.wb_sunny_outlined, Icons.water_drop_outlined, Icons.air, Icons.landscape_outlined, Icons.eco_outlined,
  Icons.blur_circular, Icons.bedtime_outlined, Icons.warning_amber_rounded, Icons.psychology_outlined,
  Icons.graphic_eq, Icons.schedule_outlined, Icons.public,
];

void main() {
  group('(a) exemplos nome → arte', () {
    final cases = <(ActionArtKind, String, String, String)>[
      (ActionArtKind.spell, 'Bola de Fogo', 'Magia', 'spell_fire'),
      (ActionArtKind.spell, 'Cone de Gelo', 'Magia', 'spell_ice'),
      (ActionArtKind.ability, 'Cone de Gelo', 'Habilidade', 'spell_ice'),
      (ActionArtKind.spell, 'Sangue', 'Magia', 'spell_blood'),
      (ActionArtKind.ability, 'Sangue', 'Habilidade', 'spell_blood'),
      (ActionArtKind.spell, 'Raio', 'Magia', 'spell_lightning'),
      (ActionArtKind.spell, 'Curar Feridas', 'Magia', 'spell_heal'),
      (ActionArtKind.weapon, 'Pistola', '', 'item_pistol'),
      (ActionArtKind.weapon, 'Escopeta', '', 'item_shotgun'),
      (ActionArtKind.weapon, 'Cutelo', '', 'item_sword'),
      (ActionArtKind.weapon, 'Arco Longo', '', 'item_bow'),
      (ActionArtKind.weapon, 'Machado', '', 'item_axe'),
      (ActionArtKind.weapon, 'Cajado Arcano', '', 'item_staff'),
      (ActionArtKind.item, 'Pistola', 'Arma', 'item_pistol'),
      (ActionArtKind.item, 'Poção', 'Consumível', 'item_potion'),
      (ActionArtKind.item, 'Balas', 'Munição', 'item_ammo'),
      (ActionArtKind.item, 'Amuleto', 'Acessório', 'item_accessory'),
      (ActionArtKind.item, 'Martelo', 'Ferramenta', 'item_tool'),
      (ActionArtKind.item, 'Broquel de Ferro', 'Armadura', 'spell_shield'),
      (ActionArtKind.item, 'Couraça', 'Armadura', 'item_armor'),
      (ActionArtKind.item, 'Elixir Vermelho', 'Outro', 'item_potion'),
      (ActionArtKind.item, 'ARCOS', 'Outro', 'item_bow'),
      (ActionArtKind.spell, 'BOLA DE FOGO', 'Magia', 'spell_fire'),
      (ActionArtKind.spell, 'Água Benta', 'Magia', 'spell_water'),
    ];
    for (final (kind, name, category, expected) in cases) {
      test('$name ($category) → $expected', () => expect(art(kind, name, category: category), expected));
    }
  });

  group('(b) falsos positivos', () {
    test('"Barco" não vira arco', () {
      expect(art(ActionArtKind.item, 'Barco'), isNull);
      expect(art(ActionArtKind.weapon, 'Barco'), 'item_sword', reason: 'fallback de arma, não item_bow');
    });
    test('"Ataca rapidamente" não vira mente', () {
      expect(art(ActionArtKind.spell, 'Golpe', description: 'Ataca rapidamente', category: 'Magia'), 'spell_magic_generic');
    });
    test('"Braço de ferro" não vira fogo', () {
      expect(art(ActionArtKind.ability, 'Braço de ferro', category: 'Habilidade'), 'spell_magic_generic');
    });
  });

  group('(c) ordem nome → descrição → categoria', () {
    test('descrição decide quando o nome não casa', () {
      expect(art(ActionArtKind.spell, 'Toque Etéreo', description: 'Um toque de gelo puro.', category: 'Magia'), 'spell_ice');
    });
    test('o nome vence a descrição', () {
      expect(art(ActionArtKind.spell, 'Bola de Fogo', description: 'Congela o alvo', category: 'Magia'), 'spell_fire');
    });
    test('sem nada: fallback da categoria', () {
      expect(art(ActionArtKind.spell, 'Truque', category: 'Magia'), 'spell_magic_generic');
      expect(art(ActionArtKind.ability, 'Truque', category: 'Habilidade'), 'spell_magic_generic');
      expect(art(ActionArtKind.ability, 'Truque', category: 'Outro'), 'spell_magic_generic');
      expect(art(ActionArtKind.ability, 'Golpe giratório', category: 'Técnica'), 'ability_technique');
      expect(art(ActionArtKind.ability, 'Rajada de Fogo', category: 'Técnica'), 'spell_fire', reason: 'Técnica ainda detecta por palavra');
    });
    test('Passiva sempre ability_passive', () {
      expect(art(ActionArtKind.ability, 'Pele de Fogo', description: 'gelo', category: 'Passiva'), 'ability_passive');
    });
    test('item Outro sem palavra-chave → null (mantém o ícone Material)', () {
      expect(art(ActionArtKind.item, 'Estatueta velha', category: 'Outro'), isNull);
      expect(art(ActionArtKind.item, 'Estatueta velha'), isNull);
    });
  });

  test('(d) todo caminho existe em disco e fica sob a pasta declarada no pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('    - assets/icons/action/\n'));
    expect(ActionArtResolver.files.toSet().length, 60);
    final onDisk = Directory('assets/icons/action').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(onDisk, ActionArtResolver.files.map((f) => '$f.webp').toSet());
    final reachable = <String>{
      for (final (file, _) in ActionArtResolver.spellTerms) file,
      for (final (file, _) in ActionArtResolver.weaponTerms) file,
      for (final (file, _) in ActionArtResolver.itemTerms) file,
      'spell_magic_generic', 'ability_technique', 'ability_passive', 'item_sword', 'item_armor', 'spell_shield',
      'item_potion', 'item_ammo', 'item_accessory', 'item_tool',
    };
    for (final file in reachable) {
      final path = ActionArtResolver.path(file);
      expect(path.startsWith('assets/icons/action/'), isTrue);
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    // Amostra ampla de entradas: nada fora da lista dos 36.
    for (final kind in ActionArtKind.values) {
      for (final category in ['', 'Magia', 'Habilidade', 'Técnica', 'Passiva', 'Outro', 'Arma', 'Armadura', 'Consumível', 'Munição', 'Acessório', 'Ferramenta']) {
        for (final name in ['', 'Bola de fogo', 'Pistola', 'Elmo', 'Anel', 'xyz', 'Escudo']) {
          final path = ActionArtResolver.resolve(kind: kind, name: name, category: category);
          if (path != null) expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    }
  });

  test('(e) paridade de categoria com o SpellIconResolver', () {
    const names = ['fogo', 'raio', 'gelo', 'veneno', 'cura', 'escudo', 'sangue', 'morte', 'sombra', 'luz', 'água', 'vento', 'terra', 'natureza', 'portal', 'sono', 'medo', 'mente', 'som', 'tempo', 'gravidade'];
    for (var i = 0; i < names.length; i++) {
      final oldIndex = _oldIcons.indexOf(SpellIconResolver.resolve(names[i]));
      final newFile = art(ActionArtKind.spell, names[i], category: 'Magia');
      expect(oldIndex, i, reason: names[i]);
      expect(newFile, ActionArtResolver.spellTerms[oldIndex].$1, reason: names[i]);
    }
  });

  group('(f) ActionIconSlot', () {
    const fallback = Icon(Icons.gps_fixed, key: ValueKey('fallback'));
    Widget host(String themeId, String? path) => MaterialApp(home: Scaffold(body: Center(child: ActionIconSlot(themeId: themeId, artPath: path, fallback: fallback))));

    testWidgets('Abissal com arte mostra a imagem decorativa no tamanho pedido', (tester) async {
      await tester.pumpWidget(host('abyss', ActionArtResolver.path('spell_fire')));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).imageProvider, isA<AssetImage>());
      expect(image.width, 40);
      expect(image.fit, BoxFit.contain);
      expect(image.excludeFromSemantics, isTrue);
      expect(find.byKey(const ValueKey('fallback')), findsNothing);
    });

    for (final theme in ['parchment', 'vampire', 'classic', 'cyberpunk']) {
      testWidgets('$theme devolve exatamente o fallback', (tester) async {
        await tester.pumpWidget(host(theme, ActionArtResolver.path('spell_fire')));
        expect(find.byType(Image), findsNothing);
        expect(tester.widget(find.byKey(const ValueKey('fallback'))), same(fallback));
      });
    }

    testWidgets('Abissal sem arte usa o fallback', (tester) async {
      await tester.pumpWidget(host('abyss', null));
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const ValueKey('fallback')), findsOneWidget);
    });

    testWidgets('arte inexistente cai no fallback pelo errorBuilder', (tester) async {
      await tester.pumpWidget(host('abyss', 'assets/icons/action/nao_existe.webp'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.byKey(const ValueKey('fallback')), findsOneWidget);
    });

    test('tamanho: 40 normal, 36 compacto', () {
      expect(actionArtSize(false), 40);
      expect(actionArtSize(true), 36);
    });
  });

  group('(g) smoke', () {
    Character character() => Character(
          id: 'p1',
          name: 'Ana',
          systemId: 'sys',
          resourceValues: {'Vida': 10, 'Energia': 5},
          resourceMaxValues: {'Vida': 10, 'Energia': 5},
          abilities: ['Bola de Fogo', 'Pele de Pedra'],
          abilityDetails: {'Bola de Fogo': {'category': 'Magia', 'damage': '20', 'cost': 2}, 'Pele de Pedra': {'category': 'Passiva'}},
          inventory: ['Pistola', 'Poção de cura'],
          inventoryDetails: {'Pistola': {'category': 'Arma', 'damage': '10'}, 'Poção de cura': {'category': 'Consumível', 'quantity': 2}},
        );

    Future<AppState> pump(WidgetTester tester, String themeId, Widget home, {bool compact = false}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.setTheme(themeId);
      await state.setCompactMode(compact);
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
      state.characters.add(character());
      state.campaigns.add(Campaign(id: 'c1', name: 'Mesa', npcSheets: [
        {'id': 'n1', 'kind': 'NPC', 'name': 'Goblin', 'sheet': character().toJson()..['id'] = 'n1'..['name'] = 'Goblin'},
      ]));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme(themeId, compact), home: home),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return state;
    }

    Set<String> artShown(WidgetTester tester) => {
          for (final image in tester.widgetList<Image>(find.byType(Image)))
            if (image.image is ResizeImage && (image.image as ResizeImage).imageProvider is AssetImage)
              ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
        }.where((p) => p.startsWith(ActionArtResolver.folder)).map((p) => p.replaceFirst(ActionArtResolver.folder, '').replaceFirst('.webp', '')).toSet();

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    for (final compact in [false, true]) {
      testWidgets('ficha no Abissal mostra as artes (compacto $compact)', (tester) async {
        await pump(tester, 'abyss', const CharacterScreen(characterId: 'p1'), compact: compact);
        expect(tester.takeException(), isNull);
        expect(artShown(tester), containsAll(['spell_fire', 'item_pistol', 'item_potion']));
        final sizes = tester.widgetList<Image>(find.byType(Image)).where((i) => i.image is ResizeImage).map((i) => i.width).toSet();
        expect(sizes, {actionArtSize(compact)});
        await tester.tap(find.text('Habilidades').first);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(artShown(tester), containsAll(['spell_fire', 'ability_passive']));
        expect(tester.takeException(), isNull);
        await finish(tester);
      });
    }

    for (final theme in ['parchment', 'vampire', 'classic']) {
      testWidgets('ficha no tema $theme não mostra nenhuma arte', (tester) async {
        await pump(tester, theme, const CharacterScreen(characterId: 'p1'));
        expect(tester.takeException(), isNull);
        expect(artShown(tester), isEmpty);
        expect(find.byIcon(Icons.local_fire_department_outlined), findsWidgets, reason: 'ícone Material de antes');
        await finish(tester);
      });
    }

    testWidgets('aba de combate e ficha de NPC no Abissal', (tester) async {
      final state = await pump(tester, 'abyss', const SizedBox());
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('abyss', false), home: Scaffold(body: CombatTab(character: state.characters.single, system: state.systems.first))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(artShown(tester), containsAll(['spell_fire', 'item_pistol', 'item_potion']));
      await finish(tester);

      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('abyss', false), home: const NpcSheetScreen(campaignId: 'c1', npcId: 'n1')),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Ações'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(artShown(tester), containsAll(['spell_fire', 'item_pistol']));
      await finish(tester);
    });

    testWidgets('aba de combate no Pirata segue sem arte', (tester) async {
      final state = await pump(tester, 'parchment', const SizedBox());
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('parchment', false), home: Scaffold(body: CombatTab(character: state.characters.single, system: state.systems.first))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(artShown(tester), isEmpty);
      expect(find.byIcon(Icons.gps_fixed), findsWidgets);
      await finish(tester);
    });
  });
}
