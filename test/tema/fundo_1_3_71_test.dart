// 1.3.71 — fundo ilustrado do Abissal.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';

void main() {
  Finder smoke() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AbyssSmokePainter);
  Finder art() => find.descendant(of: find.byType(AbyssBackground), matching: find.byType(Image));

  Future<void> pump(WidgetTester tester, String? themeId, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AbyssBackground(themeId: themeId, child: const Text('conteúdo'))));
    await tester.pump();
  }

  test('a arte do Abissal está registrada e existe', () {
    expect(themeBackgroundArt, {'abyss': 'assets/backgrounds/abyss_background.webp'});
    expect(File(themeBackgroundArt['abyss']!).existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/backgrounds/\n'));
  });

  testWidgets("'abyss' mostra a arte, sem fumaça, atrás do conteúdo e sem capturar toques", (tester) async {
    await pump(tester, 'abyss');
    expect(art(), findsOneWidget);
    final image = tester.widget<Image>(art());
    expect((image.image as AssetImage).assetName, 'assets/backgrounds/abyss_background.webp');
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
    expect(image.filterQuality, FilterQuality.medium);
    expect(smoke(), findsNothing);
    expect(find.ancestor(of: art(), matching: find.byType(IgnorePointer)), findsWidgets);
    expect(find.text('conteúdo'), findsOneWidget);
    // A arte vem antes do conteúdo no Stack (fica atrás).
    final stack = tester.widget<Stack>(find.descendant(of: find.byType(AbyssBackground), matching: find.byType(Stack)).first);
    expect(stack.children.last, isA<Text>());
  });

  testWidgets('tela larga: arte na altura inteira, centralizada', (tester) async {
    await pump(tester, 'abyss', size: const Size(1400, 800));
    final image = tester.widget<Image>(art());
    expect(image.fit, BoxFit.fitHeight);
    expect(image.alignment, Alignment.center);
  });

  for (final themeId in ['vampire', 'classic', null]) {
    testWidgets('tema $themeId: sem arte, com a fumaça de sempre', (tester) async {
      await pump(tester, themeId);
      expect(art(), findsNothing);
      expect(smoke(), findsOneWidget);
    });
  }

  testWidgets('falha ao carregar a arte: volta para gradiente + fumaça, sem exceção', (tester) async {
    await pump(tester, 'abyss');
    final image = tester.widget<Image>(art());
    final fallback = image.errorBuilder!(tester.element(art()), Exception('falhou'), null);
    await tester.pumpWidget(MaterialApp(home: Stack(children: [fallback])));
    expect(smoke(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
