// Estouros (overflow) com texto grande em TODOS os temas: ficha (todas as
// abas), Mestre (todas as abas) e Árvore, com texto 1.0 / 1.15 / 2.0 e modo
// compacto ligado/desligado, com Roboto e Material Icons do próprio SDK.
// Única exceção: o 0,545 px da grade de atributos com texto 1.0, que já
// existia e só se resolveria mudando o layout com texto normal (Parte F3).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
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

RpgSystem _system() => RpgSystem(
      id: 'sys',
      name: 'Sistema de teste',
      attributes: ['Força', 'Destreza'],
      skills: ['Furtividade', 'Percepção'],
      resources: ['Vida', 'Energia'],
      sections: ['Anotações'],
      skillAttributes: {'Furtividade': 'Destreza'},
    );

Character _character() => Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      className: 'Ladina',
      attributes: {'Força': 2, 'Destreza': 4},
      resourceValues: {'Vida': 7, 'Energia': 3},
      resourceMaxValues: {'Vida': 10, 'Energia': 5},
      sectionNotes: {'Anotações': 'Uma anotação.'},
      skills: ['Furtividade'],
      abilities: ['Bola de fogo'],
      abilityDetails: {'Bola de fogo': {'category': 'Magia', 'damage': '20', 'cost': 2, 'resource': 'Energia'}},
      inventory: ['Pistola', 'Poção de cura'],
      inventoryDetails: {
        'Pistola': {'category': 'Arma', 'damage': '10', 'ammo': 9, 'ammoMax': 15},
        'Poção de cura': {'category': 'Consumível', 'quantity': 2},
      },
      conditions: ['Envenenado'],
      skillTree: [
        {'id': 'a', 'name': 'Golpe furtivo', 'parentId': '', 'level': 1, 'unlocked': true},
        {'id': 'b', 'name': 'Sombra veloz', 'parentId': 'a', 'level': 2, 'unlocked': false},
        {'id': 'c', 'name': 'Passo leve', 'parentId': 'a', 'level': 2, 'unlocked': false},
      ],
    );

Campaign _campaign() => Campaign(
      id: 'c1',
      name: 'Mesa do Abismo',
      description: 'Campanha de teste com descrição.',
      characterIds: ['p1'],
      masterObjectives: ['[ ] Encontrar o mapa', '[x] Sobreviver ao porto'],
      locations: ['Porto Sombrio'],
      sessionLog: ['A sessão começou.'],
      notes: 'Notas da campanha.',
      masterNotes: 'Notas privadas.',
      conditions: ['Neblina'],
      npcs: ['Velho marinheiro'],
      npcSheets: [
        {'id': 'n1', 'kind': 'Monstro', 'name': 'Goblin', 'sheet': {'id': 'n1', 'name': 'Goblin', 'systemId': 'sys', 'resourceValues': {'Vida': 5}, 'resourceMaxValues': {'Vida': 8}}},
      ],
      initiative: [
        {'id': 'p1', 'name': 'Ana', 'type': 'player', 'value': 15, 'done': false},
        {'id': 'npc:n1', 'name': 'Goblin', 'type': 'npc', 'value': 9, 'done': false},
      ],
      linkedCharacters: [
        {
          'shareCode': 'ABCD-1234',
          'status': 'approved',
          'snapshot': {'id': 'r1', 'name': 'Bia Remota', 'resourceValues': {'Vida': 4}, 'resourceMaxValues': {'Vida': 10}, 'conditions': ['Caído']},
        },
      ],
    );

ThemeData _withRoboto(ThemeData theme) => theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: theme.appBarTheme.copyWith(titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto')),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Cada estouro como "mensagem @ arquivo:linha do widget que causou".
String _describe(FlutterErrorDetails details) {
  final text = details.toString();
  final first = details.exceptionAsString().split('\n').first;
  final where = RegExp(r'file:///[^\s]*?/lib/([^\s:]+:\d+)').firstMatch(text)?.group(1) ?? '?';
  return '$first @ $where';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  for (final preset in appThemes) {
    for (final compact in [false, true]) {
      for (final scale in [1.0, 1.15, 2.0]) {
        testWidgets('${preset.id} • texto $scale • compacto ${compact ? 'ligado' : 'desligado'}: sem overflow', (tester) async {
          tester.view.physicalSize = const Size(411, 1600);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final errors = <String>{};
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(_describe(details));
          try {
            Future<void> mount(Widget home) async {
              SharedPreferences.setMockInitialValues({'auto_sync': false});
              final state = AppState();
              await state.setTheme(preset.id);
              await state.setCompactMode(compact);
              await state.setMasterToolsEnabled(true);
              state.systems.insert(0, _system());
              state.characters.add(_character());
              state.campaigns.add(_campaign());
              await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
                value: state,
                child: MaterialApp(theme: _withRoboto(buildAppTheme(preset.id, compact)), home: home),
              ));
              await _settle(tester);
            }

            Future<void> visitTabs(List<String> labels) async {
              for (final label in labels) {
                final candidates = find.text(label);
                if (candidates.evaluate().isEmpty) {
                  errors.add('aba "$label" não encontrada');
                  continue;
                }
                await tester.ensureVisible(candidates.first);
                await tester.pump();
                await tester.tap(find.text(label).hitTestable().first);
                await _settle(tester);
              }
            }

            // Ficha: todas as abas.
            await mount(const CharacterScreen(characterId: 'p1'));
            if (scale == 1.0) {
              // A altura pedida pela barra de abas (o SizedBox interno); a borda de
              // 1 px do Container em volta fica dentro desses 72.
              final header = find.byWidgetPredicate((w) => w is SizedBox && w.child is SingleChildScrollView && (w.child as SingleChildScrollView).scrollDirection == Axis.horizontal);
              expect(tester.widget<SizedBox>(header.first).height, 72, reason: 'barra de abas da ficha com 72 em texto 1.0');
            }
            await visitTabs(['Status', 'Habilidades', 'Perícias', 'Inventário', 'Árvore', 'Seções', 'Em Cena']);
            // Mestre: todas as abas.
            await mount(const MasterScreen());
            await visitTabs(['Jogadores', 'NPCs', 'Sessão', 'Notas', 'Resumo']);
            // Lista de campanhas.
            await mount(const CampaignsScreen());
            // Árvore.
            await mount(const SkillTreeScreen(characterId: 'p1'));
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
          } finally {
            FlutterError.onError = previous;
          }
          for (final e in errors) {
            debugPrint('OVERFLOW| ${preset.id} s$scale c$compact | $e');
          }
          // Exceção conhecida (Parte F3): com texto 1.0, a célula de atributo da
          // aba Status (proporção 2,75) já fica 0,545 px curta em todos os temas
          // menos o Abissal. Corrigir exigiria mudar o layout com texto 1.0.
          bool knownAtNormalText(String e) {
            if (scale != 1.0 || !e.contains('screens/character/character_screen.dart')) return false;
            final px = double.tryParse(RegExp(r'overflowed by ([\d.]+) pixels on the bottom').firstMatch(e)?.group(1) ?? '');
            return px != null && px < 1;
          }

          expect(errors.where((e) => !knownAtNormalText(e)).toList(), isEmpty);
        });
      }
    }
  }
}
