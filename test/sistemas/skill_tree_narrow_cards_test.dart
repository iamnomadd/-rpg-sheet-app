// E3 (1.3.63): a árvore não estoura com cartões estreitos. Larguras de tela de
// 280 a 420 px (de 20 em 20), texto 1.0 / 1.15 / 2.0, com 1 a 4 cartões por
// nível (cartões normais e compactos), nomes longos, nível e os três estados.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// [roots] cartões no primeiro nível (1 = só cartões normais largos; 2 a 4 =
/// cartões normais estreitos e compactos) e um filho em cada estado.
List<Map<String, dynamic>> _tree(int roots) => [
      for (var i = 0; i < roots; i++)
        {'id': 'r$i', 'name': i.isEven ? 'Golpe furtivo aprimorado' : 'Sentidos', 'parentId': '', 'level': i + 1, 'unlocked': i == 0},
      {'id': 'c1', 'name': 'Ataque relâmpago devastador', 'parentId': 'r0', 'level': 3, 'unlocked': false},
      {'id': 'c2', 'name': 'Bloqueio', 'parentId': 'c1', 'unlocked': false},
    ];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets('sem overflow de 280 a 420 px com texto $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final theme = buildAppTheme('classic', false);
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);
      try {
        for (var width = 280.0; width <= 420; width += 20) {
          for (final roots in [1, 2, 3, 4]) {
            tester.view.physicalSize = Size(width, 900);
            SharedPreferences.setMockInitialValues({'auto_sync': false});
            final state = AppState();
            state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys', skillTree: _tree(roots)));
            await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
              value: state,
              child: MaterialApp(
                theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto')),
                home: const Scaffold(body: SkillTreeScreen(characterId: 'p1', embedded: true)),
              ),
            ));
            await tester.pump();
            for (final e in errors) {
              debugPrint('ARVORE| largura $width, $roots raízes, texto $scale: $e');
            }
            expect(errors, isEmpty, reason: 'largura $width, $roots raízes, texto $scale');
            await tester.pumpWidget(const SizedBox());
          }
        }
      } finally {
        FlutterError.onError = previous;
      }
    });
  }
}
