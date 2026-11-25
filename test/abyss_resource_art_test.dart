import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_art_size.dart';
import 'package:rpg_sheet_app/app/abyss_resource_art.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/combat_tab.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _files = [
  'res_life', 'res_temp_hp', 'res_energy', 'res_mana', 'res_sanity', 'res_stamina', 'res_defense', 'res_faith',
  'res_fury', 'res_ecstasy', 'res_ki', 'res_generic', 'res_blood', 'res_humanity', 'res_willpower', 'res_hunger',
  'res_thirst', 'res_luck', 'res_xp', 'res_corruption', 'res_exhaustion', 'res_breath', 'res_temperature', 'res_morale',
];
const _resources = ['Vida', 'PV Temporários', 'Energia', 'Êxtase'];

String? file(String name) => abyssResourceArt(name)?.replaceFirst(abyssResourceArtFolder, '').replaceFirst('.webp', '');

Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) fail('Fontes do SDK não encontradas em ${dir.path}.');
  for (final (family, files) in [
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']),
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('${dir.path}/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

Future<AppState> _state(String themeId, {bool compact = false}) async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setTheme(themeId);
  await state.setCompactMode(compact);
  state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: _resources));
  state.characters.add(Character(
    id: 'p1',
    name: 'Ana',
    systemId: 'sys',
    resourceValues: {for (final r in _resources) r: 5},
    resourceMaxValues: {for (final r in _resources) r: 10},
  ));
  return state;
}

Widget _app(AppState state, String themeId, Widget home, {bool compact = false}) {
  final theme = buildAppTheme(themeId, compact);
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto')), home: home),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await _settle(tester);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

String? _asset(Widget w) => w is Image && w.image is AssetImage ? (w.image as AssetImage).assetName : null;

Set<String> _resourceArtShown(WidgetTester tester) => {
      for (final w in tester.widgetList(find.byType(Image)))
        if ((_asset(w) ?? '').startsWith(abyssResourceArtFolder)) _asset(w)!.replaceFirst(abyssResourceArtFolder, '').replaceFirst('.webp', ''),
    };

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  test('os 24 arquivos existem, a pasta está no pubspec e todos são alcançáveis', () {
    final onDisk = Directory('assets/icons/resources').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(onDisk, _files.map((f) => '$f.webp').toSet());
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/icons/tabs/\n    - assets/icons/resources/\n'));
    final reachable = {for (final (f, _) in abyssResourceRules) f, abyssResourceGeneric};
    expect(reachable, _files.toSet());
    for (final f in reachable) {
      expect(File('$abyssResourceArtFolder$f.webp').existsSync(), isTrue, reason: f);
    }
    expect(abyssResourceArt(''), isNull);
    expect(abyssResourceArt('   '), isNull);
  });

  group('nome → arquivo', () {
    const cases = <String, String>{
      'Vida': 'res_life', 'PV': 'res_life', 'Pontos de Vida': 'res_life', 'HP': 'res_life',
      'PV Temporários': 'res_temp_hp', 'Vida Temporária': 'res_temp_hp', 'HP Temp': 'res_temp_hp',
      'Sangue': 'res_blood', 'Pontos de Sangue': 'res_blood', 'Vitae': 'res_blood',
      'Energia': 'res_energy', 'PE': 'res_energy',
      'Mana': 'res_mana', 'PM': 'res_mana',
      'Sanidade': 'res_sanity', 'SAN': 'res_sanity',
      'Força de Vontade': 'res_willpower', 'Vontade': 'res_willpower',
      'Exaustão': 'res_exhaustion', 'Cansaço': 'res_exhaustion',
      'Fôlego': 'res_breath', 'Oxigênio': 'res_breath', 'Ar': 'res_breath',
      'Estamina': 'res_stamina', 'Vigor': 'res_stamina',
      'Escudo': 'res_defense', 'Defesa': 'res_defense', 'Armadura': 'res_defense', 'CA': 'res_defense',
      'Fé': 'res_faith', 'Graça Divina': 'res_faith',
      'Fúria': 'res_fury', 'Ira': 'res_fury',
      'Êxtase': 'res_ecstasy', 'Extase': 'res_ecstasy',
      'Ki': 'res_ki', 'Espírito': 'res_ki',
      'Humanidade': 'res_humanity',
      'Fome': 'res_hunger',
      'Sede': 'res_thirst', 'Hidratação': 'res_thirst',
      'Sorte': 'res_luck',
      'Experiência': 'res_xp', 'XP': 'res_xp', 'Nível': 'res_xp',
      'Corrupção': 'res_corruption',
      'Temperatura': 'res_temperature', 'Calor': 'res_temperature',
      'Moral': 'res_morale', 'Coragem': 'res_morale',
      'Ouro': 'res_generic', 'Munição': 'res_generic', 'XYZ': 'res_generic',
    };
    for (final e in cases.entries) {
      test('${e.key} → ${e.value}', () => expect(file(e.key), e.value));
    }
  });

  group('palavras curtas só casam inteiras (onde cada uma cai)', () {
    test('"Pedra" e "Pequeno" não são energia (pe) → genérico', () {
      expect(file('Pedra'), 'res_generic');
      expect(file('Pequeno'), 'res_generic');
    });
    test('"Carga" não é defesa (ca) → genérico', () => expect(file('Carga'), 'res_generic'));
    test('"Ferro" não é fé (fe) → genérico', () => expect(file('Ferro'), 'res_generic'));
    test('"Arma" não é fôlego (ar) → genérico', () => expect(file('Arma'), 'res_generic'));
    test('"Irado" não é fúria por \'ira\' → genérico', () => expect(file('Irado'), 'res_generic'));
  });

  group('no Abissal', () {
    for (final compact in [false, true]) {
      for (final scale in [1.0, 1.15, 2.0]) {
        testWidgets('4 artes certas, sem overflow (compacto $compact, texto $scale)', (tester) async {
          tester.view.physicalSize = const Size(411, 2400);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          // Overflows que já existem na ficha no mesmo tamanho (Clássico).
          Future<List<String>> run(String themeId) async {
            final errors = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
            try {
              final state = await _state(themeId, compact: compact);
              await tester.pumpWidget(_app(state, themeId, const CharacterScreen(characterId: 'p1'), compact: compact));
              await _settle(tester);
              if (themeId == 'abyss') {
                expect(_resourceArtShown(tester), {'res_life', 'res_temp_hp', 'res_energy', 'res_ecstasy'}, reason: 'Em Cena');
              }
              await _openTab(tester, 'Status');
              if (themeId == 'abyss') {
                expect(_resourceArtShown(tester), {'res_life', 'res_temp_hp', 'res_energy', 'res_ecstasy'}, reason: 'Status');
                for (final image in tester.widgetList<Image>(find.byType(Image)).where((i) => (_asset(i) ?? '').startsWith(abyssResourceArtFolder))) {
                  expect(image.width, abyssArtIconSize(compact), reason: 'Status: tamanho padrão do Abissal');
                }
              }
              await _finish(tester);
              final combat = await _state(themeId, compact: compact);
              await tester.pumpWidget(_app(combat, themeId, Scaffold(body: CombatTab(character: combat.characters.single, system: combat.systems.first)), compact: compact));
              await _settle(tester);
              if (themeId == 'abyss') {
                final art = tester.widgetList<Image>(find.byType(Image)).where((i) => (_asset(i) ?? '').startsWith(abyssResourceArtFolder)).toList();
                expect(art, isNotEmpty);
                for (final image in art) {
                  expect(image.width, abyssArtIconSize(compact), reason: 'combate: tamanho padrão do Abissal');
                }
              }
              await _finish(tester);
            } finally {
              FlutterError.onError = previous;
            }
            return errors;
          }

          final abyss = await run('abyss');
          if (scale < 2.0) {
            expect(abyss, isEmpty);
          } else {
            // Com texto 2.0 a ficha já tem estouros em todos os temas (cabeçalho
            // de abas, card do personagem 2D...). A arte não pode criar outros.
            final classic = await run('classic');
            expect(abyss.length, lessThanOrEqualTo(classic.length), reason: '$abyss');
          }
        });
      }
    }

    testWidgets('ponto 3 (size 22) usa 29,7 px e o errorBuilder volta ao Icon de hoje', (tester) async {
      await tester.pumpWidget(MaterialApp(home: ThemedResourceIcon('abyss', 'Vida', fallbackIcon: themedIcon('abyss', 'resources'), size: 22)));
      final image = tester.widget<Image>(find.byType(Image));
      expect(_asset(image), '${abyssResourceArtFolder}res_life.webp');
      expect(image.width, abyssArtIconSize(false));
      expect(image.fit, BoxFit.contain);
      expect(image.filterQuality, FilterQuality.medium);
      expect(image.excludeFromSemantics, isTrue);
      final fallback = image.errorBuilder!(tester.element(find.byType(Image)), Exception('x'), null) as Icon;
      expect(fallback.icon, themedIcon('abyss', 'resources'));
      expect(fallback.size, 22);
    });

    testWidgets('sem size: mínimo 26, com 24 × 1,35 = 32,4', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ThemedResourceIcon('abyss', 'Energia', fallbackIcon: Icons.bolt)));
      expect(tester.widget<Image>(find.byType(Image)).width, abyssArtIconSize(false));
      await tester.pumpWidget(const MaterialApp(home: ThemedResourceIcon('abyss', 'Energia', fallbackIcon: Icons.bolt, size: 12)));
      expect(tester.widget<Image>(find.byType(Image)).width, abyssArtIconSize(false));
    });
  });
}
