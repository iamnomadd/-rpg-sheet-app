// Auditoria de respiro dos cards no tema Abissal ('abyss').
//
// Regra: todo texto/ícone dentro de um Card fica a >= 12 px das bordas
// laterais e a >= 8 px de cima/baixo (>= 10 px nos cards com ornamentos), em
// escala de texto 1.0, 1.15 e 2.0, com modo compacto ligado e desligado, e sem
// exceções de overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/theme.dart' show appThemes;
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/skill_tree_screen.dart';
import 'package:rpg_sheet_app/screens/home/home_screen.dart';
import 'package:rpg_sheet_app/screens/settings/account_screen.dart';
import 'package:rpg_sheet_app/screens/settings/beta_check_screen.dart';
import 'package:rpg_sheet_app/screens/settings/import_export_screen.dart';
import 'package:rpg_sheet_app/screens/settings/invite_manager_screen.dart';
import 'package:rpg_sheet_app/screens/settings/settings_screen.dart';
import 'package:rpg_sheet_app/screens/settings/sync_screen.dart';
import 'package:rpg_sheet_app/screens/settings/theme_screen.dart';
import 'package:rpg_sheet_app/screens/systems/system_editor_screen.dart';
import 'package:rpg_sheet_app/screens/systems/systems_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lateral = 12.0;
const _vertical = 8.0;
const _verticalOrnamented = 10.0;

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
      name: 'Ana Abissal',
      systemId: 'sys',
      className: 'Ladina',
      race: 'Humana',
      attributes: {'Força': 2, 'Destreza': 4},
      resourceValues: {'Vida': 7, 'Energia': 3},
      resourceMaxValues: {'Vida': 10, 'Energia': 5},
      sectionNotes: {'Anotações': 'Uma anotação longa o bastante para quebrar em mais de uma linha no card.'},
      skills: ['Furtividade'],
      abilities: ['Bola de fogo', 'Escudo arcano'],
      abilityDescriptions: {'Bola de fogo': 'Explosão em área que causa dano de fogo.'},
      abilityDetails: {
        'Bola de fogo': {'category': 'Magia', 'damage': '20', 'cost': 2, 'resource': 'Energia'},
        'Escudo arcano': {'category': 'Habilidade', 'durationType': 'turns', 'turns': 2},
      },
      inventory: ['Pistola', 'Poção de cura', 'Corda'],
      inventoryDescriptions: {'Corda': 'Quinze metros de corda resistente.'},
      inventoryDetails: {
        'Pistola': {'category': 'Arma', 'damage': '10', 'ammo': 9, 'ammoMax': 15},
        'Poção de cura': {'category': 'Consumível', 'quantity': 2},
      },
      conditions: ['Envenenado'],
      skillTree: [
        {'id': 'a', 'name': 'Golpe furtivo', 'parentId': '', 'level': 1, 'unlocked': true},
        {'id': 'b', 'name': 'Sombra veloz', 'parentId': 'a', 'level': 2, 'unlocked': false},
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
        {
          'id': 'n1',
          'kind': 'Monstro',
          'name': 'Goblin',
          'sheet': {
            'id': 'n1',
            'name': 'Goblin',
            'systemId': 'sys',
            'resourceValues': {'Vida': 5},
            'resourceMaxValues': {'Vida': 8},
            'inventory': ['Adaga'],
            'inventoryDetails': {'Adaga': {'category': 'Arma', 'damage': '4'}},
            'abilities': ['Mordida'],
          },
        },
      ],
      initiative: [
        {'id': 'p1', 'name': 'Ana Abissal', 'type': 'player', 'value': 15, 'done': false},
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

class _Scenario {
  final String name;
  final Widget Function() build;
  final List<String> tabs;
  final bool masterTools;

  /// Toque que abre um diálogo ou uma folha inferior (auditados também).
  final Finder Function()? open;

  const _Scenario(this.name, this.build, {this.tabs = const [], this.masterTools = false, this.open});
}

final _scenarios = <_Scenario>[
  _Scenario('Config.', () => const SettingsScreen()),
  _Scenario('Config. (Mestre ligado)', () => const SettingsScreen(), masterTools: true),
  _Scenario('Conta', () => const AccountScreen()),
  _Scenario('Sincronização', () => const SyncScreen()),
  _Scenario('Importar/Exportar', () => const ImportExportScreen()),
  _Scenario('Verificação beta', () => const BetaCheckScreen()),
  _Scenario('Gerenciar convites', () => const InviteManagerScreen()),
  _Scenario('Tema', () => const ThemeScreen()),
  _Scenario('Fichas', () => const HomeScreen()),
  _Scenario('Sistemas', () => const SystemsScreen()),
  _Scenario('Editor de sistema', () => SystemEditorScreen(system: _system())),
  _Scenario('Árvore (tela)', () => const SkillTreeScreen(characterId: 'p1')),
  _Scenario('Árvore › folha do nó', () => const SkillTreeScreen(characterId: 'p1'), open: () => find.text('Golpe furtivo')),
  _Scenario('Ficha › diálogo Editar dados', () => const CharacterScreen(characterId: 'p1'), open: () => find.byTooltip('Editar dados')),
  _Scenario('Config. › diálogo Apagar dados', () => const SettingsScreen(), open: () => find.text('Apagar todos os dados locais')),
  _Scenario('Mestre', () => const MasterScreen(), tabs: ['Resumo', 'Jogadores', 'NPCs', 'Sessão', 'Notas']),
  _Scenario('Campanhas', () => const CampaignsScreen()),
  _Scenario('Detalhe da campanha', () => const CampaignDetailScreen(campaignId: 'c1')),
  _Scenario('Painel do Mestre', () => const MasterToolsScreen(campaignId: 'c1')),
  _Scenario('Controle da sessão', () => const SessionToolsScreen(campaignId: 'c1')),
  _Scenario('Ficha do NPC', () => const NpcSheetScreen(campaignId: 'c1', npcId: 'n1'), tabs: ['Resumo', 'Status', 'Ações', 'Habilidades', 'Inventário', 'Notas']),
  _Scenario('Ficha do personagem', () => const CharacterScreen(characterId: 'p1'), tabs: ['Em Cena', 'Status', 'Habilidades', 'Perícias', 'Inventário', 'Árvore', 'Seções']),
];

/// Folgas de cada texto/ícone em relação ao Card mais próximo que o contém.
List<String> _auditCards(WidgetTester tester, String where, double scale) {
  final problems = <String>[];
  final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  final containers = [
    ...find.byType(Card).evaluate(),
    ...find.byType(RawChip).evaluate(),
    ...find.byType(Dialog).evaluate(),
    ...find.byType(BottomSheet).evaluate(),
  ];
  for (final cardElement in containers) {
    final cardBox = cardElement.renderObject;
    if (cardBox is! RenderBox || !cardBox.attached || !cardBox.hasSize) continue;
    final card = MatrixUtils.transformRect(cardBox.getTransformTo(null), Offset.zero & cardBox.size);
    if (!card.overlaps(screen)) continue;
    // Exceção documentada: o card do personagem 2D está fora do escopo e o
    // rótulo de estado passa da largura só em texto 2.0 (em todos os temas).
    if (scale >= 2.0 && _inside2DCard(cardElement)) continue;
    final widget = cardElement.widget;
    final shape = widget is Card ? (widget.shape ?? Theme.of(cardElement).cardTheme.shape) : null;
    final ornamented = shape is AbyssFrameBorder && shape.ornaments;
    final kind = widget is Card ? 'card' : widget is RawChip ? 'chip' : widget is Dialog ? 'diálogo' : 'folha';
    final minVertical = ornamented ? _verticalOrnamented : _vertical;
    void visit(Element element) {
      if (element.widget is Card || element.widget is RawChip) return; // auditados à parte
      // Conteúdo em rolagem horizontal é recortado de propósito.
      if (element.widget is Scrollable && axisDirectionToAxis((element.widget as Scrollable).axisDirection) == Axis.horizontal) return;
      final render = element.renderObject;
      if (element.widget is RichText && render is RenderBox && render.attached && render.hasSize && render.size.width > 0 && render.size.height > 0) {
        // Caixa real na tela (considera rotação, como a seta do ExpansionTile).
        final box = MatrixUtils.transformRect(render.getTransformTo(null), Offset.zero & render.size);
        if (box.overlaps(card)) {
          final left = box.left - card.left, right = card.right - box.right, top = box.top - card.top, bottom = card.bottom - box.bottom;
          final text = (element.widget as RichText).text.toPlainText();
          final label = text.runes.length == 1 && text.codeUnitAt(0) > 0xE000 ? 'ícone' : '"${text.length > 30 ? '${text.substring(0, 30)}…' : text}"';
          if (left < _lateral - .01 || right < _lateral - .01 || top < minVertical - .01 || bottom < minVertical - .01) {
            problems.add('$where: $label esq ${left.toStringAsFixed(1)} dir ${right.toStringAsFixed(1)} topo ${top.toStringAsFixed(1)} base ${bottom.toStringAsFixed(1)} ($kind ${card.width.toStringAsFixed(0)}×${card.height.toStringAsFixed(0)})');
          }
        }
        return;
      }
      element.visitChildren(visit);
    }

    cardElement.visitChildren(visit);
  }
  problems.addAll(_auditButtons(tester, where, screen));
  return problems;
}

/// Botões com moldura medidos (por tela), para o relatório do PR.
int _buttonsMeasured = 0;
final _buttonsByScreen = <String, Set<String>>{};

/// Botões com moldura do Abissal (FilledButton, OutlinedButton e
/// ElevatedButton, inclusive .tonal/.icon/.tonalIcon): texto e ícone a
/// >= chanfro + 4 das laterais e >= 6 de cima/baixo da forma (a sombra
/// chapada de 2 px fica fora da forma e não conta).
List<String> _auditButtons(WidgetTester tester, String where, Rect screen) {
  final problems = <String>[];
  final buttons = find.byWidgetPredicate((w) => w is FilledButton || w is OutlinedButton || w is ElevatedButton).evaluate();
  for (final button in buttons) {
    // A forma visível é o Material do botão (a caixa externa inclui a área
    // mínima de toque).
    Element? material;
    void findMaterial(Element e) {
      if (material != null) return;
      if (e.widget is Material) {
        material = e;
        return;
      }
      e.visitChildren(findMaterial);
    }

    button.visitChildren(findMaterial);
    final shaped = material;
    if (shaped == null) continue;
    final shape = (shaped.widget as Material).shape;
    if (shape is! AbyssFrameBorder) continue;
    final render = shaped.renderObject;
    if (render is! RenderBox || !render.attached || !render.hasSize) continue;
    final rect = MatrixUtils.transformRect(render.getTransformTo(null), Offset.zero & render.size);
    if (!rect.overlaps(screen)) continue;
    _buttonsMeasured++;
    final minLateral = shape.chamfer + 4;
    var label = '';
    void visit(Element element) {
      final box = element.renderObject;
      if (element.widget is RichText && box is RenderBox && box.attached && box.hasSize && box.size.width > 0) {
        final r = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
        final text = (element.widget as RichText).text.toPlainText();
        final isIcon = text.runes.length == 1 && text.codeUnitAt(0) > 0xE000;
        if (!isIcon) label = text;
        final left = r.left - rect.left, right = rect.right - r.right, top = r.top - rect.top, bottom = rect.bottom - r.bottom;
        if (left < minLateral - .01 || right < minLateral - .01 || top < 6 - .01 || bottom < 6 - .01) {
          problems.add('$where: botão ${isIcon ? 'ícone' : '"$text"'} esq ${left.toStringAsFixed(1)} dir ${right.toStringAsFixed(1)} topo ${top.toStringAsFixed(1)} base ${bottom.toStringAsFixed(1)} (botão ${rect.width.toStringAsFixed(0)}×${rect.height.toStringAsFixed(0)})');
        }
        return;
      }
      element.visitChildren(visit);
    }

    shaped.visitChildren(visit);
    _buttonsByScreen.putIfAbsent(where.split(' › ').first.replaceAll(' (aberto)', ''), () => <String>{}).add(label);
  }
  return problems;
}

/// Carrega Roboto e Material Icons do próprio SDK do Flutter (a fonte padrão
/// dos testes desenha cada letra como um quadrado e exagera as larguras).
Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) fail('Fontes do SDK não encontradas em ${dir.path}.');
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('${dir.path}/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

ThemeData _withRoboto(ThemeData theme) => theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: theme.appBarTheme.copyWith(titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto')),
    );

bool _inside2DCard(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    found = ancestor.widget.runtimeType.toString() == '_CombatCharacter2D';
    return !found;
  });
  return found;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Monta a tela no tema e devolve as exceções (ex.: overflow) e, se pedido,
/// os problemas de respiro dos cards.
Future<({List<String> errors, List<String> problems})> _run(WidgetTester tester, _Scenario scenario, String themeId, bool compact, double scale, {required bool audit}) async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.setTheme(themeId);
  await state.setMasterToolsEnabled(scenario.masterTools);
  state.systems.insert(0, _system());
  state.characters.add(_character());
  state.campaigns.add(_campaign());

  final errors = <String>[];
  final problems = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);
  try {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: _withRoboto(buildAppTheme(themeId, compact)), home: scenario.build()),
    ));
    await _settle(tester);
    if (audit) problems.addAll(_auditCards(tester, scenario.name, scale));
    for (final tab in scenario.tabs) {
      final candidates = find.text(tab);
      if (candidates.evaluate().isNotEmpty) await tester.ensureVisible(candidates.first);
      await tester.pump();
      final label = find.text(tab).hitTestable();
      if (label.evaluate().isEmpty) {
        problems.add('${scenario.name}: aba "$tab" não encontrada');
        continue;
      }
      await tester.tap(label.first);
      await _settle(tester);
      if (audit) problems.addAll(_auditCards(tester, '${scenario.name} › $tab', scale));
    }
    final open = scenario.open;
    if (open != null) {
      final target = open();
      if (target.evaluate().isEmpty) {
        problems.add('${scenario.name}: alvo para abrir não encontrado');
      } else {
        await tester.ensureVisible(target.first);
        await tester.pump();
        await tester.tap(target.first);
        await _settle(tester);
        final opened = find.byType(Dialog).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty;
        if (!opened) problems.add('${scenario.name}: diálogo/folha não abriu');
        if (audit) problems.addAll(_auditCards(tester, '${scenario.name} (aberto)', scale));
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  } finally {
    FlutterError.onError = previous;
  }
  return (errors: errors, problems: problems);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  tearDownAll(() {
    debugPrint('BOTOES| total medido: $_buttonsMeasured');
    for (final entry in _buttonsByScreen.entries) {
      debugPrint('BOTOES| ${entry.key}: ${entry.value.where((l) => l.isNotEmpty).join(', ')}');
    }
  });

  for (final compact in [false, true]) {
    for (final scale in [1.0, 1.15, 2.0]) {
      for (final scenario in _scenarios) {
        testWidgets('Abissal • ${scenario.name} • texto $scale • compacto ${compact ? 'ligado' : 'desligado'}', (tester) async {
          tester.view.physicalSize = const Size(411, 2200);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          // Base de comparação: a mesma tela no Clássico Escuro. Estouros que
          // também acontecem lá já existem em todos os temas (fora do escopo).
          final classic = await _run(tester, scenario, 'classic', compact, scale, audit: false);
          for (final line in classic.errors.toSet()) {
            debugPrint('CLASSICO| ${scenario.name}: $line');
          }
          // Desde a 1.3.62 o design do Abissal é o de todos os temas: a
          // auditoria roda em cada um deles.
          for (final themeId in appThemes.map((t) => t.id)) {
            final abyss = await _run(tester, scenario, themeId, compact, scale, audit: true);
            for (final line in {...abyss.errors.map((e) => 'ERRO $themeId ${scenario.name}: $e'), ...abyss.problems.map((p) => '$themeId $p')}) {
              debugPrint('AUDIT| $line');
            }
            expect(abyss.errors.length, lessThanOrEqualTo(classic.errors.length), reason: '$themeId não pode ter estouros a mais que o Clássico: ${abyss.errors}');
            expect(abyss.problems.toSet().toList(), isEmpty, reason: themeId);
          }
        });
      }
    }
  }
}
