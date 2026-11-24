import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/custom_sprite.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG de teste. [noise] gera ruído (comprime mal, bom para testar limites).
Future<Uint8List> makePng(int width, int height, {bool noise = false, int seed = 1}) async {
  final ui.Image image;
  if (noise) {
    final random = math.Random(seed);
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = i % 4 == 3 ? 255 : random.nextInt(256);
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, completer.complete);
    image = await completer.future;
  } else {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF203040));
    image = await recorder.endRecording().toImage(width, height);
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<({int width, int height})> pngSize(String dataUri) async {
  final codec = await ui.instantiateImageCodec(customSpriteDataUriBytesOf(dataUri)!);
  final frame = await codec.getNextFrame();
  final size = (width: frame.image.width, height: frame.image.height);
  frame.image.dispose();
  return size;
}

void main() {
  group('stripPanelRects', () {
    void expectCovers(List<PanelRect> rects, int width, int height, int columns, int rows) {
      expect(rects.length, columns * rows);
      for (var r = 0; r < rows; r++) {
        final row = rects.sublist(r * columns, (r + 1) * columns);
        expect(row.first.left, 0);
        for (var i = 1; i < row.length; i++) {
          expect(row[i].left, row[i - 1].left + row[i - 1].width, reason: 'sem sobra nem sobreposição');
          expect(row[i].top, row.first.top);
        }
        expect(row.last.left + row.last.width, width);
      }
      expect(rects.first.top, 0);
      expect(rects.last.top + rects.last.height, height);
      expect(rects.map((r) => r.width * r.height).reduce((a, b) => a + b), width * height);
    }

    test('fileira de 4 com medidas que não dividem exato', () {
      final rects = stripPanelRects(1001, 999, CustomSpriteLayout.row4);
      expectCovers(rects, 1001, 999, 4, 1);
      expect(rects.map((r) => r.left), [0, 250, 500, 750]);
      expect(rects.map((r) => r.width), [250, 250, 250, 251]);
      expect(customSpriteLayoutPoses(CustomSpriteLayout.row4), ['normal', 'agony', 'critical', 'incapacitated']);
    });

    test('fileira de 3: Normal | Ferido | Incapacitado', () {
      final rects = stripPanelRects(1001, 999, CustomSpriteLayout.row3);
      expectCovers(rects, 1001, 999, 3, 1);
      expect(rects.map((r) => r.width), [333, 334, 334]);
      expect(customSpriteLayoutPoses(CustomSpriteLayout.row3), ['normal', 'agony', 'incapacitated']);
    });

    test('grade 2×2: Normal | Ferido / Crítico | Incapacitado', () {
      final rects = stripPanelRects(1001, 999, CustomSpriteLayout.grid2x2);
      expectCovers(rects, 1001, 999, 2, 2);
      expect(rects[0], (left: 0, top: 0, width: 500, height: 499));
      expect(rects[1], (left: 500, top: 0, width: 501, height: 499));
      expect(rects[2], (left: 0, top: 499, width: 500, height: 500));
      expect(rects[3], (left: 500, top: 499, width: 501, height: 500));
      expect(customSpriteLayoutPoses(CustomSpriteLayout.grid2x2), ['normal', 'agony', 'critical', 'incapacitated']);
    });

    test('layout sugerido pela proporção', () {
      expect(suggestCustomSpriteLayout(4096, 1536), CustomSpriteLayout.row4);
      expect(suggestCustomSpriteLayout(3072, 1536), CustomSpriteLayout.row3);
      expect(suggestCustomSpriteLayout(1024, 1024), CustomSpriteLayout.grid2x2);
      expect(suggestCustomSpriteLayout(1024, 1536), CustomSpriteLayout.grid2x2);
      expect(suggestCustomSpriteLayout(0, 0), CustomSpriteLayout.grid2x2);
    });
  });

  group('Character: imagens próprias', () {
    const uri = 'data:image/png;base64,AAAA';

    test('toJson/fromJson com os novos campos', () {
      final original = Character(id: 'c', name: 'C', customSpriteImages: {'normal': uri, 'agony': uri}, customSpriteEnabled: true);
      final restored = Character.fromJson(original.toJson());
      expect(restored.customSpriteImages, {'normal': uri, 'agony': uri});
      expect(restored.customSpriteEnabled, isTrue);
      expect(restored.fullBodyPath, isEmpty);
    });

    test('ficha antiga (sem os campos) abre sem imagens próprias', () {
      final restored = Character.fromJson({'id': 'old', 'name': 'Antiga', 'fullBodyPath': uri});
      expect(restored.customSpriteImages, isEmpty);
      expect(restored.customSpriteEnabled, isFalse);
      expect(restored.fullBodyPath, uri);
    });

    test('JSON corrompido é ignorado', () {
      for (final raw in <Object?>['x', 3, [uri], {'normal': 5}, {'agony': uri}, {'normal': 'http://x/y.png'}]) {
        final restored = Character.fromJson({'id': 'x', 'name': 'X', 'customSpriteImages': raw, 'customSpriteEnabled': 'sim'});
        expect(restored.customSpriteImages, isEmpty, reason: '$raw');
        expect(restored.customSpriteEnabled, isFalse);
      }
      final partial = Character.fromJson({
        'id': 'x',
        'name': 'X',
        'customSpriteImages': {'normal': uri, 'quinto': uri, 'critical': 7},
      });
      expect(partial.customSpriteImages, {'normal': uri});
    });

    test('cópia (via JSON) mantém as imagens', () {
      final original = Character(id: 'c', name: 'C', customSpriteImages: {'normal': uri}, customSpriteEnabled: true);
      final copy = Character.fromJson(original.toJson());
      copy.customSpriteImages['agony'] = uri;
      expect(original.customSpriteImages.keys, ['normal']);
      expect(copy.customSpriteEnabled, isTrue);
    });

    test('backup e restauração mantêm as imagens', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      final character = Character(id: 'c', name: 'C', customSpriteImages: {'normal': uri, 'critical': uri}, customSpriteEnabled: true);
      state.characters.add(character);
      final payload = state.cloudPayload();

      final restoredState = AppState();
      await restoredState.replaceFromBackup(Map<String, dynamic>.from(payload));
      final restored = restoredState.characters.single;
      expect(restored.customSpriteImages, {'normal': uri, 'critical': uri});
      expect(restored.customSpriteEnabled, isTrue);
    });
  });

  group('imagem por estado', () {
    const n = 'data:image/png;base64,Tg==', a = 'data:image/png;base64,QQ==', c = 'data:image/png;base64,Qw==', i = 'data:image/png;base64,SQ==';

    test('4 imagens', () {
      final images = {'normal': n, 'agony': a, 'critical': c, 'incapacitated': i};
      expect(resolveCustomSpriteImage(images, 'normal'), n);
      expect(resolveCustomSpriteImage(images, 'agony'), a);
      expect(resolveCustomSpriteImage(images, 'critical'), c);
      expect(resolveCustomSpriteImage(images, 'incapacitated'), i);
    });

    test('3 imagens: crítico usa ferido', () {
      final images = {'normal': n, 'agony': a, 'incapacitated': i};
      expect(resolveCustomSpriteImage(images, 'critical'), a);
      expect(resolveCustomSpriteImage(images, 'incapacitated'), i);
    });

    test('só normal: todos usam normal', () {
      for (final pose in customSpritePoses) {
        expect(resolveCustomSpriteImage({'normal': n}, pose), n);
      }
    });

    test('desligado ou sem imagens: personagem do tema', () {
      expect(customSpriteActive(Character(id: 'x', name: 'X', customSpriteImages: {'normal': n})), isFalse);
      expect(customSpriteActive(Character(id: 'x', name: 'X', customSpriteEnabled: true)), isFalse);
      expect(customSpriteActive(Character(id: 'x', name: 'X', customSpriteImages: {'normal': n}, customSpriteEnabled: true)), isTrue);
    });
  });

  group('movimento', () {
    final phases = [for (var k = 0; k <= 20; k++) k / 20];

    test('amplitudes dentro dos limites em cada estado', () {
      for (final pose in ['normal', 'agony', 'critical']) {
        final strength = customSpriteMotionStrength(pose);
        for (final b in phases) {
          for (final w in phases) {
            final m = customSpriteMotion(pose: pose, breathPhase: b, windPhase: w, reduceMotion: false);
            expect(m.scale, inInclusiveRange(1.0, 1 + .016 * strength.breath + 1e-9));
            expect(m.dy.abs(), lessThanOrEqualTo(1.5 * strength.breath + 1e-9));
            expect(m.dx.abs(), lessThanOrEqualTo(1.5 * strength.wind + 1e-9));
            expect(m.angle.abs(), lessThanOrEqualTo(.006 * strength.wind + 1e-9));
          }
        }
      }
    });

    test('há movimento em normal, ferido e crítico; vento zero no crítico', () {
      for (final pose in ['normal', 'agony', 'critical']) {
        final a = customSpriteMotion(pose: pose, breathPhase: .1, windPhase: .1, reduceMotion: false);
        final b = customSpriteMotion(pose: pose, breathPhase: .9, windPhase: .6, reduceMotion: false);
        expect(a == b, isFalse, reason: pose);
      }
      for (final w in phases) {
        final m = customSpriteMotion(pose: 'critical', breathPhase: .3, windPhase: w, reduceMotion: false);
        expect(m.dx, 0);
        expect(m.angle, 0);
      }
    });

    test('incapacitado e reduzir movimento: parado', () {
      for (final b in phases) {
        expect(customSpriteMotion(pose: 'incapacitated', breathPhase: b, windPhase: b, reduceMotion: false), (scale: 1.0, dx: 0.0, dy: 0.0, angle: 0.0));
        expect(customSpriteMotion(pose: 'normal', breathPhase: b, windPhase: b, reduceMotion: true), (scale: 1.0, dx: 0.0, dy: 0.0, angle: 0.0));
      }
    });
  });

  group('processamento', () {
    testWidgets('fileira de 4: 4 estados, maior lado ≤ 512, nunca amplia', (tester) async {
      await tester.runAsync(() async {
        final images = await processCustomSpriteSheet(await makePng(2048, 768), CustomSpriteLayout.row4);
        expect(images.keys, ['normal', 'agony', 'critical', 'incapacitated']);
        expect(await pngSize(images['normal']!), (width: 341, height: 512));
        final small = await processCustomSpriteSheet(await makePng(400, 150), CustomSpriteLayout.row4);
        expect(await pngSize(small['agony']!), (width: 100, height: 150));
      });
    });

    testWidgets('acima do limite por estado: reduz o lado; se não couber, recusa', (tester) async {
      await tester.runAsync(() async {
        final noise = await makePng(1024, 1024, noise: true);
        const unlimited = CustomSpriteLimits(perStateMaxBytes: 1 << 30, totalMaxBytes: 1 << 30, maxSides: [512]);
        final full = await processCustomSpriteSheet(noise, CustomSpriteLayout.grid2x2, limits: unlimited);
        final size512 = customSpriteDataUriBytes(full['normal']!);
        // Limite abaixo do tamanho em 512: precisa reduzir.
        final reduced = await processCustomSpriteSheet(noise, CustomSpriteLayout.grid2x2,
            limits: CustomSpriteLimits(perStateMaxBytes: size512 - 1, totalMaxBytes: 1 << 30));
        final side = (await pngSize(reduced['normal']!)).width;
        expect(side, lessThan(512));
        expect(customSpriteDataUriBytes(reduced['normal']!), lessThan(size512));
        await expectLater(
          processCustomSpriteSheet(noise, CustomSpriteLayout.grid2x2, limits: const CustomSpriteLimits(perStateMaxBytes: 100)),
          throwsA(isA<CustomSpriteException>().having((e) => e.message, 'message', contains('grandes demais'))),
        );
        await expectLater(
          processCustomSpriteSheet(noise, CustomSpriteLayout.grid2x2, limits: CustomSpriteLimits(perStateMaxBytes: 1 << 30, totalMaxBytes: size512 ~/ 2)),
          throwsA(isA<CustomSpriteException>()),
        );
      });
    });

    testWidgets('formato inválido, arquivo grande demais e falha de decodificação', (tester) async {
      await tester.runAsync(() async {
        await expectLater(processCustomSpriteSheet(Uint8List.fromList('GIF89a....'.codeUnits), CustomSpriteLayout.row4),
            throwsA(isA<CustomSpriteException>().having((e) => e.message, 'message', contains('Formato'))));
        await expectLater(
            processCustomSpriteSheet(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 1, 2, 3, 4, 5]), CustomSpriteLayout.row4),
            throwsA(isA<CustomSpriteException>().having((e) => e.message, 'message', contains('ler a imagem'))));
        await expectLater(processCustomSpriteSheet(await makePng(64, 64), CustomSpriteLayout.row4, limits: const CustomSpriteLimits(sourceMaxBytes: 10)),
            throwsA(isA<CustomSpriteException>().having((e) => e.message, 'message', contains('muito grande'))));
      });
    });

    testWidgets('estado avulso respeita o total com as imagens mantidas', (tester) async {
      await tester.runAsync(() async {
        final png = await makePng(300, 450, noise: true);
        const roomy = CustomSpriteLimits(perStateMaxBytes: 1 << 30, totalMaxBytes: 1 << 30);
        final uri = await processCustomSpriteSingle(png, 'agony', limits: roomy);
        final size = customSpriteDataUriBytes(uri);
        await expectLater(
          processCustomSpriteSingle(png, 'agony', keep: {'normal': uri}, limits: CustomSpriteLimits(perStateMaxBytes: 1 << 30, totalMaxBytes: size + 10, maxSides: const [512])),
          throwsA(isA<CustomSpriteException>()),
        );
        // A imagem do próprio estado trocado não conta duas vezes.
        final again = await processCustomSpriteSingle(png, 'agony', keep: {'agony': uri}, limits: CustomSpriteLimits(perStateMaxBytes: 1 << 30, totalMaxBytes: size + 10, maxSides: const [512]));
        expect(again, startsWith('data:image/png;base64,'));
      });
    });
  });

  group('CustomSpriteView', () {
    late String dataUri;

    Future<AnimationController> pumpView(WidgetTester tester, {required String pose, bool reduceMotion = false}) async {
      final breath = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: CustomSpriteView(dataUri: dataUri, pose: pose, breath: breath, reduceMotion: reduceMotion),
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      return breath;
    }

    Matrix4 motion(WidgetTester tester) => tester.widget<Transform>(find.byKey(const ValueKey('custom-sprite-motion'))).transform.clone();
    Matrix4 rotation(WidgetTester tester) =>
        tester.widget<Transform>(find.descendant(of: find.byKey(const ValueKey('custom-sprite-motion')), matching: find.byType(Transform)).first).transform.clone();

    setUpAll(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await binding.runAsync(() async {
        final png = await makePng(200, 300);
        dataUri = await processCustomSpriteSingle(png, 'normal');
      });
    });

    Future<void> finish(WidgetTester tester, AnimationController breath) async {
      await tester.pumpWidget(const SizedBox());
      breath.dispose();
    }

    testWidgets('mostra a ilustração inteira (contain), filtro suave e escala-base 1,04 no recorte', (tester) async {
      final breath = await pumpView(tester, pose: 'normal');
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(image.filterQuality, FilterQuality.medium);
      expect(find.byType(ClipRRect), findsOneWidget);
      final base = tester.widget<Transform>(find.byKey(const ValueKey('custom-sprite-base'))).transform;
      expect(base.getMaxScaleOnAxis(), closeTo(1.04, 1e-9));
      final clip = tester.getSize(find.byType(ClipRRect));
      expect(clip.height, closeTo(198, .01));
      expect(clip.width, closeTo(132, .01));
      expect(tester.getSize(find.byType(CustomSpriteView)).height, 198);
      await finish(tester, breath);
    });

    testWidgets('normal, ferido e crítico se movem; crítico sem vento', (tester) async {
      for (final pose in ['normal', 'agony', 'critical']) {
        final breath = await pumpView(tester, pose: pose);
        await tester.pump(const Duration(milliseconds: 300));
        final a = motion(tester);
        final ra = rotation(tester);
        await tester.pump(const Duration(milliseconds: 1700));
        final b = motion(tester);
        final rb = rotation(tester);
        expect(a == b, isFalse, reason: pose);
        final dx = b.getTranslation().x;
        expect(dx.abs(), lessThanOrEqualTo(1.5 * customSpriteMotionStrength(pose).wind + 1e-6), reason: pose);
        if (pose == 'critical') {
          expect(dx, 0);
          expect(ra, rb);
        }
        await finish(tester, breath);
      }
    });

    testWidgets('incapacitado e reduzir movimento: nada muda', (tester) async {
      for (final setup in [('incapacitated', false), ('normal', true)]) {
        final breath = await pumpView(tester, pose: setup.$1, reduceMotion: setup.$2);
        await tester.pump(const Duration(milliseconds: 300));
        final a = motion(tester);
        await tester.pump(const Duration(milliseconds: 1700));
        expect(motion(tester), a, reason: '$setup');
        expect(a.getTranslation().x, 0);
        expect(a.getTranslation().y, 0);
        await finish(tester, breath);
      }
    });
  });
}
