// 1.3.72 — condições ilustradas.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/condition_presets.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('os 20 presets apontam para um asset que existe', () {
    expect(conditionPresets, hasLength(20));
    for (final preset in conditionPresets) {
      final art = conditionArtFor(preset.name);
      expect(art, isNotNull, reason: preset.name);
      expect(art, startsWith('assets/icons/conditions/cond_'), reason: preset.name);
      expect(File(art!).existsSync(), isTrue, reason: art);
    }
    expect(conditionArt.length, 20);
    expect(conditionArtFor('envenenado'), 'assets/icons/conditions/cond_poisoned.webp');
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/icons/conditions/\n'));
  });

  test('o ícone de reserva de cada preset continua', () {
    expect(conditionIcon('Envenenado'), Icons.coronavirus);
    expect(conditionIcon('Minha condição'), Icons.flag_outlined);
  });

  Future<void> pumpChip(WidgetTester tester, Widget avatar) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: InputChip(key: const ValueKey('chip'), avatar: avatar, label: const Text('Envenenado'), onDeleted: () {}))),
      ));

  testWidgets('a pílula mostra a arte em 22 px, sem tint, sem mudar a altura do chip', (tester) async {
    await pumpChip(tester, const Icon(Icons.coronavirus, size: 18));
    final before = tester.getSize(find.byKey(const ValueKey('chip')));
    await pumpChip(tester, const ConditionIcon('Envenenado', color: Colors.red));
    final art = find.byKey(const ValueKey('condition-art-Envenenado'));
    expect(art, findsOneWidget);
    expect(tester.getSize(art), const Size(22, 22));
    final image = tester.widget<Image>(art);
    expect(image.fit, BoxFit.contain);
    expect(image.filterQuality, FilterQuality.medium);
    expect(image.color, isNull);
    expect(tester.getSize(find.byKey(const ValueKey('chip'))).height, before.height);
  });

  testWidgets('na lista do diálogo (ícone de 24 px) a arte aparece com 22 px, centralizada', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [ConditionIcon('Protegido', size: 24), SizedBox(width: 10), Text('Protegido')])))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ConditionIcon)), const Size(24, 24));
    expect(tester.getSize(find.byKey(const ValueKey('condition-art-Protegido'))), const Size(22, 22));
  });

  testWidgets('condição personalizada mostra o ícone reserva', (tester) async {
    await pumpChip(tester, const ConditionIcon('Minha condição'));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
  });

  testWidgets('falha ao carregar a imagem cai no ícone do preset', (tester) async {
    await pumpChip(tester, const ConditionIcon('Envenenado'));
    final image = tester.widget<Image>(find.byKey(const ValueKey('condition-art-Envenenado')));
    final fallback = image.errorBuilder!(tester.element(find.byType(Image)), Exception('falhou'), null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: fallback))));
    expect(find.byIcon(Icons.coronavirus), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('na ficha, as condições ativas mostram a arte; a personalizada, o ícone', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida']));
    state.characters.add(Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      resourceValues: {'Vida': 10},
      resourceMaxValues: {'Vida': 10},
      conditions: ['Envenenado', 'Protegido', 'Minha condição'],
    ));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: CharacterScreen(characterId: 'p1')),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final card = find.byKey(const ValueKey('general-conditions'));
    expect(card, findsOneWidget);
    for (final name in ['Envenenado', 'Protegido']) {
      expect(find.descendant(of: card, matching: find.byKey(ValueKey('condition-art-$name'))), findsOneWidget, reason: name);
    }
    expect(find.descendant(of: card, matching: find.byIcon(Icons.flag_outlined)), findsWidgets);
    final chips = find.descendant(of: card, matching: find.byType(InputChip));
    final heights = chips.evaluate().map((e) => tester.getSize(find.byWidget(e.widget)).height).toSet();
    expect(heights, hasLength(1), reason: 'chips com arte e sem arte têm a mesma altura');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
