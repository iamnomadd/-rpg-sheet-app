// 1.3.72 — fundo ilustrado revertido: gradiente + fumaça em todos os temas.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';

void main() {
  test('assets/backgrounds/ saiu do pubspec e a arte foi apagada', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('assets/backgrounds/')));
    expect(File('assets/backgrounds/abyss_background.webp').existsSync(), isFalse);
  });

  for (final themeId in appThemes.map((t) => t.id)) {
    testWidgets('tema $themeId: fundo com fumaça e sem imagem', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(themeId, false), home: const AbyssBackground(child: Text('conteúdo'))));
      final background = find.byType(AbyssBackground);
      expect(find.descendant(of: background, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AbyssSmokePainter)), findsOneWidget);
      expect(find.descendant(of: background, matching: find.byType(Image)), findsNothing);
    });
  }

  test("'abyss' está entre os temas testados", () {
    expect(appThemes.map((t) => t.id), contains('abyss'));
  });
}
