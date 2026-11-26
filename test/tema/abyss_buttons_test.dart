import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

void main() {
  final variants = <String, Widget Function()>{
    'FilledButton': () => FilledButton(onPressed: () {}, child: const Text('Atacar')),
    'FilledButton.tonal': () => FilledButton.tonal(onPressed: () {}, child: const Text('Lançar')),
    'FilledButton.icon': () => FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.gps_fixed), label: const Text('Atacar')),
    'FilledButton.tonalIcon': () => FilledButton.tonalIcon(onPressed: () {}, icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('Usar')),
    'OutlinedButton.icon': () => OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.delete_forever), label: const Text('Apagar todos os dados locais')),
    'ElevatedButton': () => ElevatedButton(onPressed: () {}, child: const Text('Salvar')),
  };

  for (final compact in [false, true]) {
    for (final scale in [1.0, 1.15, 2.0]) {
      for (final entry in variants.entries) {
        testWidgets('Abissal • ${entry.key} • compacto $compact • texto $scale', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(MaterialApp(theme: buildAppTheme('abyss', compact), home: Scaffold(body: Center(child: entry.value()))));
          final material = find.descendant(of: find.byWidgetPredicate((w) => w is ButtonStyleButton), matching: find.byType(Material)).first;
          final shape = tester.widget<Material>(material).shape;
          expect(shape, isA<AbyssFrameBorder>());
          expect((shape! as AbyssFrameBorder).chamfer, abyssButtonChamfer);
          final button = _rectOf(tester, material);
          expect(button.height, greaterThanOrEqualTo(abyssButtonMinHeight(compact) - .01), reason: 'altura mínima');
          final contents = find.descendant(of: material, matching: find.byType(RichText));
          final centers = <double>[];
          for (final element in contents.evaluate()) {
            final r = _rectOf(tester, find.byWidget(element.widget).first);
            expect(r.left - button.left, greaterThanOrEqualTo(abyssButtonChamfer + 4), reason: 'lateral esquerda');
            expect(button.right - r.right, greaterThanOrEqualTo(abyssButtonChamfer + 4), reason: 'lateral direita');
            expect(r.top - button.top, greaterThanOrEqualTo(6), reason: 'topo');
            expect(button.bottom - r.bottom, greaterThanOrEqualTo(6), reason: 'base');
            centers.add(r.center.dy);
          }
          // Ícone e texto na mesma linha e centralizados na forma (a sombra de
          // 2 px é pintada fora da forma).
          for (final c in centers) {
            expect(c, closeTo(button.center.dy, 1.0));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  test('filled, outlined e elevated têm o mesmo padding, altura e densidade no Abissal', () {
    for (final compact in [false, true]) {
      final theme = buildAppTheme('abyss', compact);
      final styles = [theme.filledButtonTheme.style!, theme.outlinedButtonTheme.style!, theme.elevatedButtonTheme.style!];
      for (final style in styles) {
        expect(style.padding!.resolve({}), EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 8 : 10));
        expect(style.minimumSize!.resolve({})!.height, compact ? 40 : 44);
        expect(style.visualDensity, VisualDensity.standard);
        expect(style.shape!.resolve({}), isA<AbyssFrameBorder>());
        expect((style.shape!.resolve({})! as AbyssFrameBorder).shadowOffset, 2);
      }
    }
  });

  test('os outros temas têm os botões do Abissal (padrão desde a 1.3.62)', () {
    for (final preset in appThemes.where((t) => t.id != 'abyss')) {
      for (final compact in [false, true]) {
        final theme = buildAppTheme(preset.id, compact);
        final abyss = buildAppTheme('abyss', compact);
        for (final (style, reference) in [
          (theme.filledButtonTheme.style!, abyss.filledButtonTheme.style!),
          (theme.outlinedButtonTheme.style!, abyss.outlinedButtonTheme.style!),
          (theme.elevatedButtonTheme.style!, abyss.elevatedButtonTheme.style!),
        ]) {
          expect(style.padding!.resolve({}), reference.padding!.resolve({}), reason: preset.id);
          expect(style.minimumSize!.resolve({}), reference.minimumSize!.resolve({}), reason: preset.id);
          expect(style.shape!.resolve({}), isA<AbyssFrameBorder>(), reason: preset.id);
          expect((style.shape!.resolve({})! as AbyssFrameBorder).chamfer, abyssButtonChamfer, reason: preset.id);
          expect(style.visualDensity, reference.visualDensity, reason: preset.id);
        }
      }
    }
  });
}
