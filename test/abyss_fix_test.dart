import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/screens/settings/settings_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _luminance(Color c) {
  double channel(double v) => v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * channel(c.r) + .7152 * channel(c.g) + .0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  group('tema do app (buildAppTheme) no Abissal', () {
    for (final compact in [false, true]) {
      test('ListTile com respiro e botões chanfrados (compacto $compact)', () {
        final theme = buildAppTheme('abyss', compact);
        final list = theme.listTileTheme;
        expect(list.dense, isTrue);
        expect(list.minVerticalPadding, greaterThanOrEqualTo(compact ? 8 : 10));
        final padding = list.contentPadding!.resolve(TextDirection.ltr);
        expect(padding.left, greaterThanOrEqualTo(compact ? 14 : 16));
        expect(padding.right, greaterThanOrEqualTo(compact ? 14 : 16));
        expect(list.minLeadingWidth, compact ? 30 : 34);
        for (final style in [theme.filledButtonTheme.style!, theme.outlinedButtonTheme.style!]) {
          expect(style.shape!.resolve({}), isA<AbyssFrameBorder>());
          expect(style.side!.resolve({})!.color, AbyssColors.outline);
          expect(style.padding!.resolve({}), EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 8 : 10));
          expect(style.minimumSize!.resolve({}), Size(44, compact ? 40 : 44));
          expect(style.textStyle!.resolve({})!.fontSize, isNotNull, reason: 'herda o labelLarge');
        }
        expect(theme.visualDensity, compact ? const VisualDensity(horizontal: -4, vertical: -4) : const VisualDensity(horizontal: -3, vertical: -3));
      });
    }

    test('os outros temas continuam com o tema de app de antes', () {
      for (final preset in appThemes.where((t) => t.id != 'abyss')) {
        final theme = buildAppTheme(preset.id, true);
        expect(theme.listTileTheme.minVerticalPadding, 0, reason: preset.id);
        expect(theme.listTileTheme.contentPadding, const EdgeInsets.symmetric(horizontal: 8), reason: preset.id);
        expect(theme.filledButtonTheme.style!.shape!.resolve({}), RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), reason: preset.id);
      }
    });
  });

  test('moldura: filete a ~3 px e entalhes até ~6 px da borda', () {
    const border = AbyssFrameBorder();
    expect(border.side.width + abyssFrameGap + border.innerWidth / 2, closeTo(3, .1));
    // filete (3) + afastamento do entalhe (2,5) + metade do traço
    expect(border.side.width + abyssFrameGap + border.innerWidth / 2 + 2.5 + (border.innerWidth + .4) / 2, lessThanOrEqualTo(abyssFrameReach + .5));
    // Caminhos coerentes: o interno cabe no externo.
    const rect = Rect.fromLTWH(0, 0, 200, 100);
    expect(border.getOuterPath(rect).getBounds(), rect);
    final inner = border.getInnerPath(rect).getBounds();
    expect(rect.left <= inner.left && inner.right <= rect.right && rect.top <= inner.top && inner.bottom <= rect.bottom, isTrue);
  });

  test('sombra chapada sem operação booleana: paint não lança e pinta abaixo da forma', () async {
    const rect = Rect.fromLTWH(10, 10, 120, 40);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 160, 80));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 160, 80), Paint()..color = const Color(0xFFFFFFFF));
    const AbyssFrameBorder(chamfer: 7, ornaments: false, shadowOffset: 2).paint(canvas, rect);
    final image = await recorder.endRecording().toImage(160, 80);
    final bytes = (await image.toByteData())!;
    Color at(int x, int y) {
      final i = (y * 160 + x) * 4;
      return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    }

    expect(at(70, 51).r, lessThan(.6), reason: 'faixa de sombra logo abaixo');
    expect(at(70, 30), const Color(0xFFFFFFFF), reason: 'o miolo não é pintado pela sombra');
    image.dispose();
  });

  test('card com recorte; folha inferior só com os cantos de cima', () {
    final theme = buildTheme('abyss');
    expect(theme.cardTheme.clipBehavior, Clip.antiAlias);
    expect(theme.cardTheme.shape, isA<AbyssFrameBorder>());
    final sheet = theme.bottomSheetTheme.shape;
    expect(sheet, isA<AbyssSheetBorder>());
    const rect = Rect.fromLTWH(0, 0, 300, 200);
    final path = sheet!.getOuterPath(rect);
    expect(path.contains(const Offset(1, 1)), isFalse, reason: 'canto de cima chanfrado');
    expect(path.contains(const Offset(1, 199)), isTrue, reason: 'canto de baixo reto, colado na tela');
    expect(path.contains(const Offset(299, 199)), isTrue);
  });

  test('contraste: borda do campo e divisores >= 3:1', () {
    final theme = buildTheme('abyss');
    final field = theme.inputDecorationTheme.fillColor!;
    final border = (theme.inputDecorationTheme.enabledBorder! as AbyssInputBorder).borderSide.color;
    expect(_contrast(Color.alphaBlend(border, field), field), greaterThanOrEqualTo(3));
    final divider = theme.dividerTheme.color!;
    for (final background in [AbyssColors.card, AbyssColors.raised, AbyssColors.backgroundBottom]) {
      expect(_contrast(Color.alphaBlend(divider, background), background), greaterThanOrEqualTo(3));
    }
    expect(_contrast(Color.alphaBlend(AbyssColors.goldDim, field), field), lessThan(3), reason: 'antes não passava');
  });

  test('barra inferior pinta o fundo #080D12', () async {
    final painter = const AbyssNavBarDecoration().createBoxPainter();
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), Offset.zero, const ImageConfiguration(size: Size(100, 40)));
    final image = await recorder.endRecording().toImage(100, 40);
    final bytes = (await image.toByteData())!;
    final i = (30 * 100 + 50) * 4;
    expect(Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2)), AbyssColors.bar);
    image.dispose();
  });

  testWidgets('Config. mostra a contagem real de temas', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SettingsScreen())));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Escolha entre ${appThemes.length} estilos visuais para o RPG Sheet.'), findsOneWidget);
    expect(appThemes.length, 11);
  });
}
