// 1.3.72 — compartilhar a ficha como imagem.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_share_image.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  Future<void> pumpPreview(WidgetTester tester, Character character, RpgSystem system, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    state = AppState();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: buildAppTheme('abyss', false),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
        home: CharacterShareImageScreen(character: character, system: system),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  final system = RpgSystem(id: 'sys', name: 'Sistema da Mesa', resources: ['Vida', 'Mana'], attributes: ['FOR', 'DES']);
  Character ana() => Character(
        id: 'p1',
        name: 'Ana',
        systemId: 'sys',
        resourceValues: {'Vida': 7, 'Mana': 3},
        resourceMaxValues: {'Vida': 10, 'Mana': 5},
        attributes: {'FOR': 12, 'DES': 14},
        conditions: ['Envenenado', 'Minha condição'],
      );

  testWidgets('a prévia mostra nome, sistema, recursos, atributos, condições e o rodapé', (tester) async {
    await pumpPreview(tester, ana(), system);
    final card = find.byKey(const ValueKey('share-card'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card), shareCardSize);
    expect(shareCardSize.width / shareCardSize.height, 4 / 5);
    for (final text in ['Ana', 'Sistema da Mesa', 'Vida', '7 / 10', 'Mana', '3 / 5', 'FOR', '12', 'Envenenado', 'Minha condição', 'Grimório']) {
      expect(find.descendant(of: card, matching: find.text(text)), findsOneWidget, reason: text);
    }
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('condition-art-Envenenado'))), findsOneWidget);
    // Personagem 2D na pose atual (7/10 de vida + condição negativa → agony).
    final sprite = tester.widget<Image>(find.byKey(const ValueKey('share-sprite-agony')));
    expect(sprite.fit, BoxFit.contain);
    expect(sprite.filterQuality, FilterQuality.none);
    expect(sprite.isAntiAlias, isFalse);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Salvar imagem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gera um PNG não vazio com 1080 px de largura', (tester) async {
    await pumpPreview(tester, ana(), system);
    final boundary = find.ancestor(of: find.byKey(const ValueKey('share-card')), matching: find.byType(RepaintBoundary)).first;
    final key = tester.widget<RepaintBoundary>(boundary).key! as GlobalKey;
    final bytes = await tester.runAsync(() => renderShareImage(key));
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(100));
    expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final header = ByteData.sublistView(bytes, 16, 24);
    expect(header.getUint32(0), 1080);
    expect(header.getUint32(4), 1350);
  });

  testWidgets('ficha com muitos itens cabe no cartão (+N) sem estouro, até com texto grande', (tester) async {
    final big = RpgSystem(
      id: 'big',
      name: 'Sistema com um nome muito muito comprido para caber',
      resources: [for (var i = 0; i < 12; i++) 'Recurso com nome longo $i'],
      attributes: [for (var i = 0; i < 15; i++) 'Atributo comprido $i'],
    );
    final character = Character(
      id: 'p2',
      name: 'Personagem com um nome realmente enorme que não cabe numa linha',
      systemId: 'big',
      resourceValues: {for (final r in big.resources) r: 999999},
      resourceMaxValues: {for (final r in big.resources) r: 999999},
      attributes: {for (final a in big.attributes) a: 99},
      conditions: ['Envenenado', 'Queimando', 'Congelado', 'Sangrando', 'Atordoado', 'Caído', 'Cego', 'Outra condição longa demais'],
    );
    await pumpPreview(tester, character, big, textScale: 2.0);
    expect(tester.takeException(), isNull);
    final card = find.byKey(const ValueKey('share-card'));
    expect(tester.getSize(card), shareCardSize);
    expect(find.descendant(of: card, matching: find.text('+9 recursos')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('+10')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('+5')), findsOneWidget);
  });

  test('nome do arquivo e limites', () {
    expect(shareImageFileName('Ana'), 'Ana.png');
    expect(shareImageFileName('A/B: C?'), 'A_B_ C_.png');
    expect(shareImageFileName('  '), 'personagem.png');
    final small = shareCardLimit([1, 2, 3], 4);
    expect(small.shown, [1, 2, 3]);
    expect(small.hidden, 0);
    final large = shareCardLimit([1, 2, 3, 4, 5], 4);
    expect(large.shown, [1, 2, 3]);
    expect(large.hidden, 2);
  });

  testWidgets('o menu da ficha tem "Compartilhar como imagem" e abre a prévia', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    state = AppState();
    state.systems.insert(0, system);
    state.characters.add(ana());
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Compartilhar'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.text('Compartilhar como imagem'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Compartilhar como imagem'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CharacterShareImageScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('share-card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
