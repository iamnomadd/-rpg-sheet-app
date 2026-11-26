// 1.3.65: ícone do app (A), tela de abertura (B), cor de fundo (C), editor de
// recursos com Dano/Cura no topo (D), lixeira em "Minhas Fichas" (E) e os
// achados do PR #49 (F1: editores da ficha de NPC; F2: renomear com nomes
// repetidos na ficha do jogador).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/character/resource_quick_adjust.dart';
import 'package:rpg_sheet_app/screens/home/home_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FNV-1a de 64 bits (só para conferir que o arquivo é o esperado).
String _fnv(Uint8List bytes) {
  var h = 0xcbf29ce484222325;
  for (final b in bytes) {
    h = (h ^ b) * 0x100000001b3;
  }
  return BigInt.from(h).toUnsigned(64).toRadixString(16);
}

/// Largura e altura do PNG (cabeçalho IHDR).
(int, int) _pngSize(Uint8List b) {
  int u32(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (u32(16), u32(20));
}

// arquivo: (largura/altura, tamanho em bytes, hash novo, hash do ícone antigo)
const _icons = <String, (int, int, String, String)>{
  'Icon-192.png': (192, 50938, '8add95959a686dca', '3014dc34c6d00d2a'),
  'Icon-512.png': (512, 325960, '23cbdf815cc23164', 'e1536b962f3b0ca0'),
  'Icon-maskable-192.png': (192, 41184, 'b3e4870ba48affea', '3014dc34c6d00d2a'),
  'Icon-maskable-512.png': (512, 278630, 'b6fe53b28d117190', 'e1536b962f3b0ca0'),
  'apple-touch-icon.png': (180, 45132, '4406fcf57c49801', '99246660f1a4c69d'),
  'apple-touch-icon-167.png': (167, 39149, '1489db7912202414', 'f6788b2abdd9f615'),
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('A: ícone do app', () {
    test('os 6 PNGs de web/icons/ são os novos, nos tamanhos de sempre', () {
      for (final e in _icons.entries) {
        final bytes = File('web/icons/${e.key}').readAsBytesSync();
        final (side, length, hash, oldHash) = e.value;
        expect(_pngSize(bytes), (side, side), reason: e.key);
        expect(bytes.length, length, reason: e.key);
        expect(_fnv(bytes), hash, reason: e.key);
        expect(_fnv(bytes), isNot(oldHash), reason: '${e.key} não é mais o ícone antigo');
      }
      // Em design/app-icon/ sobra só o original.
      final left = Directory('design/app-icon').listSync().map((f) => f.uri.pathSegments.last).toList();
      expect(left, ['app-icon-source.png']);
    });

    test('manifest com as mesmas 4 entradas de ícone', () {
      final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons.map((i) => '${i['src']}|${i['sizes']}|${i['type']}|${i['purpose']}').toList(), [
        'icons/Icon-192.png|192x192|image/png|any',
        'icons/Icon-512.png|512x512|image/png|any',
        'icons/Icon-maskable-192.png|192x192|image/png|maskable',
        'icons/Icon-maskable-512.png|512x512|image/png|maskable',
      ]);
    });
  });

  group('B/C: abertura e cor de fundo', () {
    test('index.html: <img> no splash, sem "✦", sem #101114 e com #070C14', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<div class="rpg-splash-icon"><img src="icons/Icon-192.png" alt="" width="68" height="68"></div>'));
      expect(html, isNot(contains('✦')));
      expect(html.toLowerCase(), isNot(contains('#101114')));
      expect(html, contains('<meta name="theme-color" content="#070C14">'));
      expect(html, contains('html,body{margin:0;width:100%;height:100%;background:#070C14}'));
      expect(RegExp(r'#rpg-splash\{[^}]*background:#070C14').hasMatch(html), isTrue);
      final icon = RegExp(r'\.rpg-splash-icon\{([^}]*)\}').firstMatch(html)!.group(1)!;
      expect(icon, contains('width:68px;height:68px'));
      expect(icon, contains('border-radius:20px'));
      expect(icon, contains('overflow:hidden'));
      expect(icon, contains('box-shadow'));
      expect(icon, isNot(contains('background')));
      expect(icon, isNot(contains('font-size')));
      expect(icon, isNot(contains('place-items')));
      // Título e texto de carregamento continuam.
      expect(html, contains('<div class="rpg-splash-title">Grimório</div>'));
      expect(html, contains('Carregando suas aventuras…'));
    });

    test('manifest com #070C14 nas duas cores', () {
      final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['background_color'], '#070C14');
      expect(manifest['theme_color'], '#070C14');
    });
  });

  group('D: editor de recursos com Dano/Cura no topo', () {
    /// Monta a tela, abre a folha e devolve como ler o resultado depois.
    Future<Future<ResourceValues?> Function()> open(WidgetTester tester, {int current = 7, int max = 10}) async {
      ResourceValues? result;
      var done = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showResourceQuickAdjust(context, name: 'Vida', current: current, max: max);
                  done = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      return () async {
        expect(done, isTrue, reason: 'a folha fechou');
        return result;
      };
    }

    Finder field(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextField));

    testWidgets('ordem: Quantidade e botões antes de Valor atual/máximo; foco em Quantidade', (tester) async {
      await open(tester);
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(find.text('Vida').last), lessThan(y(field('Quantidade'))));
      expect(y(field('Quantidade')), lessThan(y(find.text('Receber dano'))));
      expect(y(find.text('Receber dano')), lessThan(y(find.byType(Divider))));
      expect(y(find.byType(Divider)), lessThan(y(field('Valor atual'))));
      expect(y(field('Valor atual')), lessThan(y(find.text('Salvar valores'))));
      Finder button(String label) => find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton));
      expect(y(button('Curar')), y(button('Receber dano')), reason: 'os dois botões na mesma linha');
      final quantity = tester.widget<TextField>(field('Quantidade'));
      expect(quantity.autofocus, isTrue);
      final editable = tester.widget<EditableText>(find.descendant(of: field('Quantidade'), matching: find.byType(EditableText)));
      expect(editable.focusNode.hasFocus, isTrue);
      await _finish(tester);
    });

    testWidgets('dano, cura e salvar valores funcionam como antes', (tester) async {
      var read = await open(tester);
      await tester.enterText(field('Quantidade'), '3');
      await tester.tap(find.text('Receber dano'));
      await _settle(tester);
      expect(await read(), const ResourceValues(current: 4, max: 10));

      read = await open(tester);
      await tester.enterText(field('Quantidade'), '50');
      await tester.tap(find.text('Curar'));
      await _settle(tester);
      expect(await read(), const ResourceValues(current: 10, max: 10), reason: 'limite no máximo');

      read = await open(tester);
      await tester.tap(find.text('Receber dano'));
      await tester.pump();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      await tester.enterText(field('Valor atual'), '2');
      await tester.enterText(field('Valor máximo'), '12');
      await tester.tap(find.text('Salvar valores'));
      await _settle(tester);
      expect(await read(), const ResourceValues(current: 2, max: 12));
      await _finish(tester);
    });
  });

  group('E: lixeira em "Minhas Fichas"', () {
    Future<AppState> pumpHome(WidgetTester tester) async {
      _bigView(tester);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida']));
      state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'sys'));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('classic', false), home: const HomeScreen()),
      ));
      await _settle(tester);
      return state;
    }

    Finder card() => find.ancestor(of: find.text('Ana'), matching: find.byType(Card)).first;

    testWidgets('sem chevron; lixeira com "Excluir ficha"; cancelar não exclui; confirmar exclui', (tester) async {
      final state = await pumpHome(tester);
      expect(find.descendant(of: card(), matching: find.byIcon(Icons.chevron_right)), findsNothing);
      final trash = find.descendant(of: card(), matching: find.widgetWithIcon(IconButton, Icons.delete_outline));
      expect(tester.widget<IconButton>(trash).tooltip, 'Excluir ficha');
      final tile = tester.widget<ListTile>(find.descendant(of: card(), matching: find.byType(ListTile)));
      expect(tile.onLongPress, isNull);

      await tester.tap(trash);
      await _settle(tester);
      expect(find.text('Excluir ficha?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await _settle(tester);
      expect(state.characters, hasLength(1));

      await tester.tap(trash);
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Excluir')));
      await _settle(tester);
      expect(state.characters, isEmpty);
      await _finish(tester);
    });

    testWidgets('tocar no card abre a ficha', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Ana'));
      await _settle(tester);
      expect(find.byType(CharacterScreen), findsOneWidget);
      await _finish(tester);
    });
  });

  group('F1: editores da ficha de NPC', () {
    Future<Character> pumpNpc(WidgetTester tester, String tab) async {
      _bigView(tester);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida']));
      final sheet = Character(
        id: 'n1',
        name: 'Orc',
        systemId: 'sys',
        inventory: ['Espada', 'Corda'],
        inventoryDetails: {'Espada': {'category': 'Arma', 'damage': '1d8'}, 'Corda': {'category': 'Ferramenta'}},
        inventoryDescriptions: {'Espada': 'Afiada', 'Corda': '10 m'},
      );
      state.campaigns.add(Campaign(id: 'c1', name: 'Mesa', npcSheets: [
        {'id': 'n1', 'name': 'Orc', 'kind': 'NPC', 'sheet': sheet.toJson()},
      ]));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('classic', false), home: const NpcSheetScreen(campaignId: 'c1', npcId: 'n1')),
      ));
      await _settle(tester);
      await tester.tap(find.text(tab).first);
      await _settle(tester);
      return sheet;
    }

    Map<String, dynamic> saved(WidgetTester tester) {
      final state = Provider.of<AppState>(tester.element(find.byType(NpcSheetScreen)), listen: false);
      return Map<String, dynamic>.from(state.campaigns.single.npcSheets.single['sheet'] as Map);
    }

    Finder dialog() => find.byType(AlertDialog);
    Finder nameField() => find.descendant(of: dialog(), matching: find.byType(TextField)).first;

    Future<void> tapAdd(WidgetTester tester, String title) async {
      // A linha do título da lista (não o rótulo da aba) tem o botão +.
      final add = find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(Row)), matching: find.byIcon(Icons.add));
      await tester.tap(add.first);
      await _settle(tester);
    }

    testWidgets('ação (Ataques): vazio, repetido e manter o próprio nome', (tester) async {
      await pumpNpc(tester, 'Ações');
      await tapAdd(tester, 'Ataques');
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Salvar')));
      await _settle(tester);
      expect(find.text('Dê um nome.'), findsOneWidget);
      expect(dialog(), findsOneWidget);
      await tester.enterText(nameField(), ' espada ');
      await tester.pump();
      expect(find.text('Dê um nome.'), findsNothing, reason: 'some ao digitar');
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Salvar')));
      await _settle(tester);
      expect(find.text('Já existe um item com esse nome. Use outro nome.'), findsOneWidget);
      expect(dialog(), findsOneWidget);
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Cancelar')));
      await _settle(tester);
      var sheet = saved(tester);
      expect(sheet['inventory'], ['Espada', 'Corda']);
      expect((sheet['inventoryDetails'] as Map)['Espada']['damage'], '1d8');
      expect((sheet['inventoryDescriptions'] as Map)['Espada'], 'Afiada');

      // Editar mantendo o próprio nome funciona.
      await tester.tap(find.text('Espada').last);
      await _settle(tester);
      expect(find.text('Editar ação'), findsOneWidget);
      await tester.enterText(find.descendant(of: dialog(), matching: find.byType(TextField)).at(1), '2d6');
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Salvar')));
      await _settle(tester);
      expect(dialog(), findsNothing);
      sheet = saved(tester);
      expect((sheet['inventoryDetails'] as Map)['Espada']['damage'], '2d6');
      await _finish(tester);
    });

    testWidgets('item simples (Inventário): vazio, repetido e manter o próprio nome', (tester) async {
      await pumpNpc(tester, 'Inventário');
      await tapAdd(tester, 'Inventário');
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Salvar')));
      await _settle(tester);
      expect(find.text('Dê um nome.'), findsOneWidget);
      await tester.enterText(nameField(), 'CORDA');
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Salvar')));
      await _settle(tester);
      expect(find.text('Já existe um item com esse nome. Use outro nome.'), findsOneWidget);
      expect(dialog(), findsOneWidget);
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Cancelar')));
      await _settle(tester);
      var sheet = saved(tester);
      expect(sheet['inventory'], ['Espada', 'Corda']);
      expect((sheet['inventoryDescriptions'] as Map)['Corda'], '10 m');

      // Editar "Corda" mantendo o nome.
      final row = find.ancestor(of: find.text('Corda').last, matching: find.byType(ListTile)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)));
      await _settle(tester);
      await tester.tap(find.text('Editar').last);
      await _settle(tester);
      await tester.enterText(find.descendant(of: dialog(), matching: find.byType(TextField)).at(1), '15 m');
      await tester.tap(find.descendant(of: dialog(), matching: find.text('Salvar')));
      await _settle(tester);
      expect(dialog(), findsNothing);
      sheet = saved(tester);
      expect((sheet['inventoryDescriptions'] as Map)['Corda'], '15 m');
      await _finish(tester);
    });
  });

  testWidgets('F2: com dois itens de mesmo nome, renomear um mantém os dados do outro', (tester) async {
    _bigView(tester);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida']));
    state.characters.add(Character(
      id: 'p1',
      name: 'Ana',
      systemId: 'sys',
      inventory: ['Poção', 'Poção'],
      inventoryDetails: {'Poção': {'category': 'Consumível', 'quantity': 3}},
      inventoryDescriptions: {'Poção': 'Cura 10'},
    ));
    await state.setReduceAnimations(true);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: buildAppTheme('classic', false), home: const CharacterScreen(characterId: 'p1')),
    ));
    await _settle(tester);
    await tester.tap(find.text('Inventário').first);
    await _settle(tester);
    await tester.tap(find.ancestor(of: find.text('Poção').last, matching: find.byType(Card)).first);
    await _settle(tester);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'Elixir');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Salvar')));
    await _settle(tester);
    final c = state.characters.single;
    expect(c.inventory, unorderedEquals(['Elixir', 'Poção']));
    expect(c.inventoryDetails['Poção']!['quantity'], 3);
    expect(c.inventoryDescriptions['Poção'], 'Cura 10');
    expect(c.inventoryDetails['Elixir']!['quantity'], 3, reason: 'o renomeado leva uma cópia');
    expect(c.inventoryDescriptions['Elixir'], 'Cura 10');
    await _finish(tester);
  });
}
