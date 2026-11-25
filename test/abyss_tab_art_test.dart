import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_art_size.dart';
import 'package:rpg_sheet_app/app/abyss_tab_art.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _files = ['tab_scene', 'tab_status', 'tab_abilities', 'tab_actions', 'tab_tree', 'tab_skills', 'tab_inventory', 'tab_sections'];
const _sheetTabs = ['general', 'attributesResources', 'abilities', 'skills', 'inventory', 'skillTree', 'sections'];
const _otherThemes = ['classic', 'parchment', 'vampire', 'cyberpunk', 'ice'];

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

/// O que `themedCharacterTabIcon` devolvia antes deste PR (para comparar).
Type _expectedTypeToday(String themeId, String role) {
  if (themeId == 'cyberpunk' && (role == 'general' || role == 'skills')) return ImageIcon;
  if (themeId == 'vampire' && (role == 'skillTree' || role == 'abilities')) return CustomPaint;
  return Icon;
}

Future<AppState> _pumpSheet(WidgetTester tester, String themeId, {bool compact = false}) async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setTheme(themeId);
  state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', attributes: ['Força'], resources: ['Vida', 'Energia']));
  state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys', attributes: {'Força': 2}, abilities: ['Golpe'], inventory: ['Corda']));
  final theme = buildAppTheme(themeId, compact);
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto')), home: const CharacterScreen(characterId: 'p1')),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return state;
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

String? _assetOf(Image image) => image.image is AssetImage ? (image.image as AssetImage).assetName : null;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  test('os 8 arquivos existem e a pasta está declarada no pubspec', () {
    final onDisk = Directory('assets/icons/tabs').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(onDisk, _files.map((f) => '$f.webp').toSet());
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/icons/action/\n    - assets/icons/tabs/\n'));
  });

  test('todo papel do mapa aponta para arquivo existente e nenhum arquivo fica de fora', () {
    for (final role in abyssTabArtFiles.keys) {
      final path = abyssTabArt(role)!;
      expect(File(path).existsSync(), isTrue, reason: role);
    }
    expect(abyssTabArtFiles.values.toSet(), _files.toSet());
    expect(abyssTabArt('resources'), isNull);
    expect(abyssTabArt('combat'), isNull);
  });

  group('fora do Abissal nada muda', () {
    for (final themeId in _otherThemes) {
      testWidgets('$themeId: abas e títulos com os widgets de hoje, sem Image', (tester) async {
        for (final role in [..._sheetTabs, 'actions', 'attributes', 'resources', 'combat']) {
          final widget = themedCharacterTabIcon(themeId, role, size: 22, color: Colors.red);
          expect(widget.runtimeType, _expectedTypeToday(themeId, role), reason: '$themeId/$role');
          if (widget is Icon && !(themeId == 'cyberpunk' && role == 'abilities') && !(themeId == 'vampire' && role == 'general')) {
            expect(widget.icon, themedIcon(themeId, role), reason: '$themeId/$role');
            expect(widget.size, 22);
          }
          await tester.pumpWidget(MaterialApp(home: Center(child: ThemedSectionIcon(themeId, role, size: 22))));
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.icon, themedIcon(themeId, role));
          expect(icon.size, 22);
          expect(find.byType(Image), findsNothing);
          await tester.pumpWidget(MaterialApp(home: Center(child: ThemedSectionIcon(themeId, role))));
          expect(tester.widget<Icon>(find.byType(Icon)).size, isNull, reason: 'sem size, como o Icon de hoje');
        }
        await _pumpSheet(tester, themeId);
        expect(find.byWidgetPredicate((w) => w is Image && (_assetOf(w)?.startsWith(abyssTabArtFolder) ?? false)), findsNothing);
        await _finish(tester);
      });
    }
  });

  group('no Abissal', () {
    testWidgets('as abas da ficha mostram a arte; selecionada 1.0, as outras 0.55', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpSheet(tester, 'abyss');
      for (final role in _sheetTabs) {
        final opacity = tester.widget<Opacity>(find.byKey(ValueKey('abyss-tab-art-$role')));
        expect(opacity.opacity, role == 'general' ? 1.0 : abyssTabArtUnselectedOpacity, reason: role);
        final image = tester.widget<Image>(find.descendant(of: find.byKey(ValueKey('abyss-tab-art-$role')), matching: find.byType(Image)));
        expect(_assetOf(image), abyssTabArt(role));
        expect(image.width, closeTo(22 * abyssTabArtScale, .01));
        expect(image.fit, BoxFit.contain);
        expect(image.filterQuality, FilterQuality.medium);
      }
      // Trocar de aba troca o destaque.
      await tester.tap(find.text('Status').first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.widget<Opacity>(find.byKey(const ValueKey('abyss-tab-art-attributesResources'))).opacity, 1.0);
      expect(tester.widget<Opacity>(find.byKey(const ValueKey('abyss-tab-art-general'))).opacity, abyssTabArtUnselectedOpacity);
      await _finish(tester);
    });

    testWidgets('a 8ª arte (actions) e papéis sem arte', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Column(children: [
        themedCharacterTabIcon('abyss', 'actions', size: 22, color: AbyssColors.goldLight),
        themedCharacterTabIcon('abyss', 'resources', size: 22),
        themedCharacterTabIcon('abyss', 'combat', size: 22),
        const ThemedSectionIcon('abyss', 'resources'),
        const ThemedSectionIcon('abyss', 'combat', size: 20),
      ])));
      expect(find.byType(Image), findsOneWidget);
      expect(_assetOf(tester.widget<Image>(find.byType(Image))), abyssTabArt('actions'));
      expect(find.byType(Icon), findsNWidgets(4));
    });

    testWidgets('títulos dos cards: arte 1,35× (mínimo 26) no Em Cena, Status e listas', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpSheet(tester, 'abyss');
      Iterable<Image> titleArt() => tester.widgetList<Image>(find.byType(Image)).where((i) => (_assetOf(i) ?? '').startsWith(abyssSectionArtFolder));
      final emCena = titleArt().map(_assetOf).toSet();
      expect(emCena, containsAll([abyssSectionArt('attributes'), abyssSectionArt('inventory'), abyssSectionArt('abilities')]));
      for (final image in titleArt()) {
        expect(image.width, abyssArtIconSize(false), reason: 'título: tamanho padrão do Abissal');
      }
      Future<void> openTab(String label) async {
        await tester.tap(find.text(label).first);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await openTab('Status');
      expect(tester.widgetList<Image>(find.byType(Image)).where((i) => _assetOf(i) == abyssSectionArt('attributes') && i.width == abyssArtIconSize(false)), isNotEmpty, reason: 'cabeçalho Status');
      await openTab('Inventário');
      expect(tester.widgetList<Image>(find.byType(Image)).where((i) => _assetOf(i) == abyssSectionArt('inventory') && i.width == abyssArtIconSize(false)), isNotEmpty, reason: 'cabeçalho da lista');
      await openTab('Habilidades');
      expect(tester.widgetList<Image>(find.byType(Image)).where((i) => _assetOf(i) == abyssSectionArt('abilities') && i.width == abyssArtIconSize(false)), isNotEmpty);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('se a arte falhar, volta para o Icon de hoje (errorBuilder)', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Column(children: [
        themedCharacterTabIcon('abyss', 'general', size: 22, color: AbyssColors.goldLight),
        const ThemedSectionIcon('abyss', 'inventory', size: 20),
      ])));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      final context = tester.element(find.byType(Column));
      final tabFallback = images[0].errorBuilder!(context, Exception('falhou'), null) as Icon;
      expect(tabFallback.icon, themedIcon('abyss', 'general'));
      expect(tabFallback.size, 22);
      expect(tabFallback.color, AbyssColors.goldLight);
      final titleFallback = images[1].errorBuilder!(context, Exception('falhou'), null) as Icon;
      expect(titleFallback.icon, themedIcon('abyss', 'inventory'));
      expect(titleFallback.size, 20);
    });
  });

  group('barra de abas do Abissal (altura 72)', () {
    for (final compact in [false, true]) {
      for (final scale in [1.0, 1.15, 2.0]) {
        testWidgets('compacto $compact • texto $scale', (tester) async {
          tester.view.physicalSize = const Size(411, 1600);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          Future<List<String>> overflowsOf(String themeId) async {
            final errors = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
            try {
              await _pumpSheet(tester, themeId, compact: compact);
              if (themeId == 'abyss') {
                for (final cell in find.byType(AbyssTabCell).evaluate()) {
                  final size = (cell.renderObject! as RenderBox).size;
                  if (scale <= abyssTabArtMaxTextScale) expect(size.height, lessThanOrEqualTo(72), reason: 'cabe na barra');
                }
                final art = tester.widget<Image>(find.descendant(of: find.byKey(const ValueKey('abyss-tab-art-general')), matching: find.byType(Image)));
                expect(art.width, scale <= abyssTabArtMaxTextScale ? closeTo(22 * abyssTabArtScale, .01) : 22.0);
              }
              await _finish(tester);
            } finally {
              FlutterError.onError = previous;
            }
            return errors;
          }

          final abyss = await overflowsOf('abyss');
          if (scale <= abyssTabArtMaxTextScale) {
            expect(abyss, isEmpty, reason: 'sem overflow em 1.0 e 1.15');
          } else {
            // Em 2.0 o rótulo já não cabe na barra de 72 em todos os temas
            // (estouro que já existia); a arte não pode piorar isso.
            final classic = await overflowsOf('classic');
            expect(abyss.length, lessThanOrEqualTo(classic.length));
            for (final error in abyss.where((e) => e.contains('on the bottom'))) {
              final px = double.parse(RegExp(r'by ([\d.]+) pixels').firstMatch(error)!.group(1)!);
              expect(px, lessThanOrEqualTo(5.4 + .01), reason: 'igual ao estouro de hoje no Abissal (5,4 px)');
            }
          }
        });
      }
    }
  });
}
