// 1.3.66 — Parte C (alterações não salvas no editor de sistema), Parte D
// (avisos no campo: Nova ficha e editor de sistema), Parte E (animação de
// carregamento) e F1 (campos dos editores do NPC liberados depois de fechar).
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
import 'package:rpg_sheet_app/screens/home/home_screen.dart';
import 'package:rpg_sheet_app/screens/systems/system_editor_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({'auto_sync': false});
  final state = AppState();
  await state.load();
  return state;
}

RpgSystem _system() => RpgSystem(
      id: 'meu',
      name: 'Meu sistema',
      description: 'Teste',
      attributes: ['Força', 'Destreza'],
      skills: ['Furtividade'],
      resources: ['Vida'],
      sections: ['Notas'],
    );

/// Abre o editor a partir de uma tela "início" (para ver a saída).
Future<AppState> _openEditor(WidgetTester tester) async {
  _bigView(tester);
  final state = await _state();
  state.systems.add(_system());
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: buildAppTheme('classic', false),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SystemEditorScreen(system: state.systems.firstWhere((s) => s.id == 'meu')))),
            child: const Text('início'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('início'));
  await _settle(tester);
  expect(find.byType(SystemEditorScreen), findsOneWidget);
  return state;
}

Finder get _dialog => find.byType(AlertDialog);
Finder get _nameField => find.ancestor(of: find.text('Nome do sistema'), matching: find.byType(TextField));

void main() {
  group('C: editor de sistema — alterações não salvas', () {
    testWidgets('sem alterações, a seta sai direto', (tester) async {
      await _openEditor(tester);
      await tester.pageBack();
      await _settle(tester);
      expect(find.byType(SystemEditorScreen), findsNothing);
      expect(find.text('Descartar alterações?'), findsNothing);
    });

    testWidgets('com alterações pergunta; "Continuar editando" fica; "Sair sem salvar" sai sem salvar', (tester) async {
      final state = await _openEditor(tester);
      await tester.enterText(_nameField, 'Outro nome');
      await tester.pump();
      await tester.pageBack();
      await _settle(tester);
      expect(find.text('Descartar alterações?'), findsOneWidget);
      expect(find.text('As mudanças neste sistema ainda não foram salvas.'), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await _settle(tester);
      expect(find.byType(SystemEditorScreen), findsOneWidget);
      expect(find.text('Outro nome'), findsOneWidget);

      // O botão/gesto voltar do sistema também pergunta.
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Sair sem salvar'));
      await _settle(tester);
      expect(find.byType(SystemEditorScreen), findsNothing);
      expect(state.systems.firstWhere((s) => s.id == 'meu').name, 'Meu sistema');
    });

    testWidgets('mudança na lista também conta; desfazer volta a sair direto', (tester) async {
      await _openEditor(tester);
      await tester.tap(find.text('Adicionar').first);
      await _settle(tester);
      await tester.enterText(find.descendant(of: _dialog, matching: find.byType(TextField)), 'Carisma');
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Adicionar')));
      await _settle(tester);
      await tester.pageBack();
      await _settle(tester);
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Sair sem salvar'));
      await _settle(tester);
      expect(find.byType(SystemEditorScreen), findsNothing);
    });

    testWidgets('"Salvar sistema" grava e sai; abrir de novo e voltar sai direto', (tester) async {
      final state = await _openEditor(tester);
      await tester.enterText(_nameField, 'Sistema salvo');
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar sistema'));
      await tester.tap(find.text('Salvar sistema'));
      await _settle(tester);
      expect(find.byType(SystemEditorScreen), findsNothing);
      expect(find.text('Descartar alterações?'), findsNothing);
      expect(state.systems.firstWhere((s) => s.id == 'meu').name, 'Sistema salvo');
      await tester.tap(find.text('início'));
      await _settle(tester);
      await tester.pageBack();
      await _settle(tester);
      expect(find.byType(SystemEditorScreen), findsNothing);
      expect(find.text('Descartar alterações?'), findsNothing);
    });
  });

  group('D: avisos no campo', () {
    testWidgets('Nova ficha sem nome: "Dê um nome." e o diálogo fica; some ao digitar', (tester) async {
      _bigView(tester);
      final state = await _state();
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme('classic', false), home: const HomeScreen()),
      ));
      await _settle(tester);
      await tester.tap(find.byTooltip('Nova ficha'));
      await _settle(tester);
      await tester.tap(find.text('Criar'));
      await tester.pump();
      expect(find.text('Dê um nome.'), findsOneWidget);
      expect(_dialog, findsOneWidget);
      expect(state.characters, isEmpty);
      await tester.enterText(find.ancestor(of: find.text('Nome do personagem'), matching: find.byType(TextField)), 'A');
      await tester.pump();
      expect(find.text('Dê um nome.'), findsNothing);
    });

    for (final viaEnter in [false, true]) {
      final how = viaEnter ? 'Enter' : 'botão';
      testWidgets('item do editor ($how): vazio e repetido mostram o erro no campo; sem SnackBar', (tester) async {
        await _openEditor(tester);
        Future<void> submit() async {
          if (viaEnter) {
            await tester.testTextInput.receiveAction(TextInputAction.done);
          } else {
            await tester.tap(find.descendant(of: _dialog, matching: find.text('Adicionar')));
          }
          await tester.pump();
        }

        final field = find.descendant(of: _dialog, matching: find.byType(TextField));
        // Atributos (o primeiro "Adicionar").
        await tester.tap(find.text('Adicionar').first);
        await _settle(tester);
        await tester.enterText(field, '   ');
        await submit();
        expect(find.text('Dê um nome.'), findsOneWidget);
        expect(_dialog, findsOneWidget);
        await tester.enterText(field, ' força ');
        await tester.pump();
        expect(find.text('Dê um nome.'), findsNothing, reason: 'some ao digitar');
        await submit();
        expect(find.text('"força" já existe nesta categoria.'), findsOneWidget);
        expect(_dialog, findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        await tester.enterText(field, 'Carisma');
        await tester.pump();
        expect(find.textContaining('já existe'), findsNothing);
        await submit();
        await _settle(tester);
        expect(_dialog, findsNothing);
        expect(find.text('Carisma'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'nenhum controlador usado depois de liberado');
      });
    }

    testWidgets('renomear item: repetido mostra o erro; o próprio nome é aceito', (tester) async {
      await _openEditor(tester);
      final row = find.ancestor(of: find.text('Destreza'), matching: find.byType(ListTile)).first;
      await tester.tap(find.descendant(of: row, matching: find.byTooltip('Renomear')));
      await _settle(tester);
      final field = find.descendant(of: _dialog, matching: find.byType(TextField));
      await tester.enterText(field, 'FORÇA');
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Salvar')));
      await tester.pump();
      expect(find.text('"FORÇA" já existe nesta categoria.'), findsOneWidget);
      await tester.enterText(field, 'Destreza');
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Salvar')));
      await _settle(tester);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nome do sistema vazio: erro no próprio campo, sem SnackBar', (tester) async {
      final state = await _openEditor(tester);
      await tester.enterText(_nameField, '  ');
      await tester.ensureVisible(find.text('Salvar sistema'));
      await tester.tap(find.text('Salvar sistema'));
      await _settle(tester);
      expect(find.text('Informe um nome para o sistema.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SystemEditorScreen), findsOneWidget);
      expect(tester.getTopLeft(find.text('Informe um nome para o sistema.')).dy, greaterThanOrEqualTo(0));
      await tester.enterText(_nameField, 'Novo');
      await tester.pump();
      expect(find.text('Informe um nome para o sistema.'), findsNothing);
      expect(state.systems.firstWhere((s) => s.id == 'meu').name, 'Meu sistema');
    });
  });

  group('E: animação de carregamento', () {
    test('index.html com a <img class="rpg-loader">, sem o anel antigo, com prefers-reduced-motion', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<img class="rpg-loader" src="icons/loader.png" alt="" width="56" height="56">'));
      expect(html, isNot(contains('<div class="rpg-loader"></div>')));
      expect(html, isNot(contains('border-top-color')));
      final css = RegExp(r'\.rpg-loader\{([^}]*)\}').firstMatch(html)!.group(1)!;
      expect(css, contains('width:56px;height:56px'));
      expect(css, contains('margin:22px auto 0'));
      expect(css, contains('display:block'));
      expect(css, contains('border:0'));
      expect(css, contains('border-radius:0'));
      expect(css, contains('rpg-spin 2.5s linear infinite'));
      expect(css, contains('rpg-glow 1.6s ease-in-out infinite'));
      expect(html, contains('@keyframes rpg-spin{to{transform:rotate(360deg)}}'));
      expect(RegExp(r'@keyframes rpg-glow\{[^@]*drop-shadow[^@]*#9B4FE0').hasMatch(html), isTrue);
      final reduced = RegExp(r'@media \(prefers-reduced-motion: reduce\)\{\.rpg-loader\{animation:([^}]*)\}\}').firstMatch(html);
      expect(reduced, isNotNull);
      expect(reduced!.group(1), isNot(contains('rpg-spin')));
      expect(reduced.group(1), contains('rpg-glow'));
    });

    test('web/icons/loader.png existe com 192×192; em design/loader/ sobra só o original', () {
      final bytes = File('web/icons/loader.png').readAsBytesSync();
      int u32(Uint8List b, int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
      expect((u32(bytes, 16), u32(bytes, 20)), (192, 192));
      expect(Directory('design/loader').listSync().map((f) => f.uri.pathSegments.last).toList(), ['loader-source.png']);
    });

    test('CORE do service worker contém /icons/loader.png', () {
      final sw = File('web/rpg_service_worker.js').readAsStringSync();
      final core = RegExp(r'const CORE=\[([^\]]*)\]').firstMatch(sw)!.group(1)!;
      expect(core, contains("'/icons/loader.png'"));
      expect(core, contains("'/icons/Icon-192.png'"));
    });
  });

  group('F1: editores do NPC abrem e salvam sem erro', () {
    Future<void> pumpNpc(WidgetTester tester, String tab) async {
      _bigView(tester);
      final state = await _state();
      final sheet = Character(id: 'n1', name: 'Orc', systemId: 'generic', inventory: ['Espada'], inventoryDetails: {'Espada': {'category': 'Arma', 'damage': '1d8'}});
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
    }

    Future<void> addAndSave(WidgetTester tester, String title, String name, {String? damage}) async {
      final add = find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(Row)), matching: find.byIcon(Icons.add));
      await tester.tap(add.first);
      await _settle(tester);
      // A lista de Ataques só mostra ações com dano.
      if (damage != null) await tester.enterText(find.descendant(of: _dialog, matching: find.byType(TextField)).at(1), damage);
      // Salva com o campo de nome em foco (o caso que usava controlador liberado).
      await tester.enterText(find.descendant(of: _dialog, matching: find.byType(TextField)).first, name);
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Salvar')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    }

    testWidgets('ação (Ataques)', (tester) async {
      await pumpNpc(tester, 'Ações');
      await addAndSave(tester, 'Ataques', 'Machado', damage: '1d10');
      expect(find.text('Machado'), findsOneWidget);
      // Editar e salvar.
      await tester.tap(find.text('Machado'));
      await _settle(tester);
      await tester.tap(find.descendant(of: _dialog, matching: find.text('Salvar')));
      await _settle(tester);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('item simples (Inventário)', (tester) async {
      await pumpNpc(tester, 'Inventário');
      await addAndSave(tester, 'Inventário', 'Corda');
      expect(find.text('Corda'), findsOneWidget);
    });
  });
}
