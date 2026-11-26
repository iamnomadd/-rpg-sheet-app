import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/custom_sprite.dart';
import 'package:rpg_sheet_app/screens/character/custom_sprite_sheet.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Uint8List> _png(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Map<String, String> images;
  late Uint8List row4Sheet;

  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.runAsync(() async {
      images = {
        for (final (i, pose) in customSpritePoses.indexed) pose: await processCustomSpriteSingle(await _png(200, 300, Color(0xFF102030 + i * 0x101010)), pose),
      };
      row4Sheet = await _png(800, 300, const Color(0xFF334455));
    });
  });

  Future<void> settleAsync(WidgetTester tester) async {
    // O trabalho de imagem (dart:ui) só anda em tempo real: alterna runAsync e pump.
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('folha Personagem 2D', () {
    late AppState state;
    late Character character;

    Future<void> openSheet(WidgetTester tester, {bool readOnly = false, CustomSpritePicker? pick}) async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
      state.characters.add(character);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCustomSpriteSheet(context, character, readOnly: readOnly, pick: pick),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('imagem única: prévia rotulada, troca de layout e Salvar', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      character = Character(id: 'c', name: 'C');
      await openSheet(tester, pick: () async => row4Sheet);
      expect(find.text('Personagem 2D'), findsOneWidget);
      await tester.tap(find.text('Adicionar imagem própria'));
      await tester.pump();
      await settleAsync(tester);
      await settleAsync(tester);
      // 800×300 (proporção 2,67) sugere fileira de 4.
      for (final label in ['Normal', 'Ferido', 'Crítico', 'Incapacitado']) {
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(label)), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('Fileira de 3'));
      await tester.pump();
      await settleAsync(tester);
      await settleAsync(tester);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Crítico')), findsNothing);
      expect(find.text('O Crítico usa a imagem de Ferido.'), findsOneWidget);
      await tester.tap(find.text('Fileira de 4'));
      await tester.pump();
      await settleAsync(tester);
      await settleAsync(tester);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(character.customSpriteImages.keys, ['normal', 'agony', 'critical', 'incapacitated']);
      expect(character.customSpriteEnabled, isTrue);
      expect(state.characters.single.customSpriteImages.length, 4);
    });

    testWidgets('falha ao decodificar: mensagem e nada salvo', (tester) async {
      character = Character(id: 'c', name: 'C');
      await openSheet(tester, pick: () async => Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]));
      await tester.tap(find.text('Adicionar imagem própria'));
      await tester.pump();
      await settleAsync(tester);
      expect(find.textContaining('Não foi possível ler a imagem'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar')).onPressed, isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(character.customSpriteImages, isEmpty);
      expect(character.customSpriteEnabled, isFalse);
    });

    testWidgets('desligar não apaga; remover pede confirmação e apaga', (tester) async {
      character = Character(id: 'c', name: 'C', customSpriteImages: Map.of(images), customSpriteEnabled: true);
      await openSheet(tester);
      await tester.tap(find.text('Usar o personagem do tema'));
      await tester.pumpAndSettle();
      expect(character.customSpriteEnabled, isFalse);
      expect(character.customSpriteImages.length, 4);
      await tester.tap(find.text('Usar minhas imagens'));
      await tester.pumpAndSettle();
      expect(character.customSpriteEnabled, isTrue);

      await tester.ensureVisible(find.text('Remover imagens próprias'));
      await tester.tap(find.text('Remover imagens próprias'));
      await tester.pumpAndSettle();
      expect(find.text('Remover imagens próprias?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(character.customSpriteImages.length, 4);
      await tester.tap(find.text('Remover imagens próprias'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();
      expect(character.customSpriteImages, isEmpty);
      expect(character.customSpriteEnabled, isFalse);
    });

    testWidgets('só leitura: vê as imagens, não troca', (tester) async {
      character = Character(id: 'c', name: 'C', customSpriteImages: Map.of(images), customSpriteEnabled: true);
      await openSheet(tester, readOnly: true);
      expect(find.byType(Image), findsNWidgets(4));
      expect(find.text('Adicionar imagem própria'), findsNothing);
      expect(find.text('Trocar por imagem única'), findsNothing);
      expect(find.text('Imagens separadas'), findsNothing);
      expect(find.text('Remover imagens próprias'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      await tester.tap(find.text('Usar o personagem do tema'));
      await tester.pumpAndSettle();
      expect(character.customSpriteEnabled, isTrue);
    });
  });

  group('personagem 2D na ficha', () {
    Future<AppState> pumpSheet(WidgetTester tester, Character character) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
      state.characters.add(character);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: CharacterScreen(characterId: 'p1')),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await settleAsync(tester);
      return state;
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Character withLife(int life, {bool enabled = true, Map<String, String>? custom}) => Character(
          id: 'p1',
          name: 'Ana',
          systemId: 'sys',
          resourceValues: {'Vida': life, 'Energia': 0},
          resourceMaxValues: {'Vida': 10, 'Energia': 0},
          customSpriteImages: custom ?? Map.of(images),
          customSpriteEnabled: enabled,
        );

    testWidgets('mostra a imagem do estado certo nos 4 estados, card com 220', (tester) async {
      for (final (life, pose) in [(10, 'normal'), (4, 'agony'), (2, 'critical'), (0, 'incapacitated')]) {
        await pumpSheet(tester, withLife(life));
        final view = tester.widget<CustomSpriteView>(find.byType(CustomSpriteView));
        expect(view.pose, pose);
        expect(view.dataUri, images[pose], reason: pose);
        expect(tester.getSize(find.ancestor(of: find.byType(CustomSpriteView), matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 220)).first).height, 220);
        expect(tester.widget<Image>(find.descendant(of: find.byType(CustomSpriteView), matching: find.byType(Image))).fit, BoxFit.contain);
        await finish(tester);
      }
    });

    testWidgets('3 imagens: o crítico usa a de ferido', (tester) async {
      final three = Map.of(images)..remove('critical');
      await pumpSheet(tester, withLife(2, custom: three));
      expect(tester.widget<CustomSpriteView>(find.byType(CustomSpriteView)).dataUri, images['agony']);
      await finish(tester);
    });

    testWidgets('desligado: sprite do tema como antes; tocar abre a folha', (tester) async {
      await pumpSheet(tester, withLife(10, enabled: false));
      expect(find.byType(CustomSpriteView), findsNothing);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.startsWith('assets/character2d/')), findsOneWidget);
      await tester.tap(find.byTooltip('Personagem 2D'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Usar o personagem do tema'), findsOneWidget);
      expect(find.text('Usar minhas imagens'), findsOneWidget);
      await finish(tester);
    });

    for (final enabled in [true, false]) {
      testWidgets('toque discreto abre a folha (imagens próprias ${enabled ? 'ligadas' : 'desligadas'})', (tester) async {
        await pumpSheet(tester, withLife(10, enabled: enabled));
        final ink = tester.widget<InkWell>(find.descendant(of: find.byTooltip('Personagem 2D'), matching: find.byType(InkWell)).first);
        expect(ink.splashFactory, NoSplash.splashFactory);
        expect(ink.highlightColor, Colors.transparent);
        expect(ink.onTap, isNotNull);
        expect(ink.canRequestFocus, isTrue);
        expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label == 'Personagem 2D'), findsOneWidget);
        await tester.tap(find.byTooltip('Personagem 2D'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Usar minhas imagens'), findsOneWidget);
        await finish(tester);
      });
    }
  });
}
