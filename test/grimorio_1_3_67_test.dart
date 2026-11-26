// 1.3.67 — Parte A (nome visível "Grimório", identificadores técnicos
// intactos), Parte B (depois de apagar, a nuvem só volta; nunca é substituída
// sem confirmação), C1 (DisposeOnRemoved único) e C2 (AppMessageException).
// A nuvem é simulada com um MockClient do pacote http (http.runWithClient):
// nenhuma chamada sai para o Supabase real.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/core/app_version.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/settings/sync_screen.dart';
import 'package:rpg_sheet_app/screens/systems/system_editor_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:rpg_sheet_app/services/rpg_file_service.dart';
import 'package:rpg_sheet_app/utils/error_message.dart';
import 'package:rpg_sheet_app/widgets/dispose_on_removed.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- nuvem falsa

class _FakeCloud {
  Map<String, dynamic>? payload;
  DateTime? updatedAt;
  int uploads = 0;

  _FakeCloud({this.payload, this.updatedAt});

  MockClient client() => MockClient((request) async {
        const json = {'content-type': 'application/json; charset=utf-8'};
        if (request.url.path.endsWith('/rest/v1/rpg_cloud_backups')) {
          if (request.method == 'GET') {
            final body = payload == null ? <Object>[] : [{'payload': payload, 'updated_at': updatedAt?.toIso8601String()}];
            return http.Response(jsonEncode(body), 200, headers: json);
          }
          if (request.method == 'POST') {
            uploads++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            payload = Map<String, dynamic>.from(body['payload'] as Map);
            updatedAt = DateTime.parse(body['updated_at'] as String);
            return http.Response('', 201);
          }
        }
        return http.Response(jsonEncode({'message': 'chamada inesperada ${request.method} ${request.url}'}), 500, headers: json);
      });
}

const _session = <String, Object>{
  'cloud_access_token': 'token-de-teste',
  'cloud_refresh_token': '',
  'cloud_user_id': 'u1',
  'cloud_email': '',
  'cloud_is_anonymous': true,
};

Map<String, dynamic> _cloudPayload({int characters = 2, int campaigns = 1}) => {
      'backupSchema': 4,
      'characters': [for (var i = 0; i < characters; i++) Character(id: 'n$i', name: 'Nuvem $i', systemId: 'generic').toJson()],
      'systems': <Object>[],
      'campaigns': [for (var i = 0; i < campaigns; i++) Campaign(id: 'c$i', name: 'Mesa $i').toJson()],
      'savedRolls': <Object>[],
      'diceHistory': <Object>[],
    };

Future<AppState> _loadedState() async {
  SharedPreferences.setMockInitialValues({
    ..._session,
    'auto_sync': true,
    'characters': jsonEncode([Character(id: 'p1', name: 'Ana', systemId: 'generic').toJson()]),
  });
  final state = AppState();
  await state.load();
  return state;
}

Future<void> _pumpFor(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// ------------------------------------------------------------ arquivo .rpg

class _FakePicker extends FilePicker {
  final List<int> bytes;
  _FakePicker(this.bytes);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult([PlatformFile(name: 'rpg-sheet-backup.rpg', size: bytes.length, bytes: Uint8List.fromList(bytes))]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A: nome visível "Grimório"', () {
    test('manifest com name e short_name "Grimório"; id/start_url/scope iguais', () {
      final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['name'], 'Grimório');
      expect(manifest['short_name'], 'Grimório');
      expect(manifest['id'], '/');
      expect(manifest['start_url'], '/');
      expect(manifest['scope'], '/');
    });

    test('index.html: <title>, apple-mobile-web-app-title, description e splash com "Grimório"', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<title>Grimório</title>'));
      expect(html, contains('<meta name="apple-mobile-web-app-title" content="Grimório">'));
      expect(html, contains('<meta name="description" content="Grimório — fichas, campanhas e sessões de RPG.">'));
      expect(html, contains('<div class="rpg-splash-title">Grimório</div>'));
      expect(html, isNot(contains('RPG Sheet')));
    });

    test('nenhum "RPG Sheet" visível em lib/; textos novos no lugar', () {
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(file.readAsStringSync(), isNot(contains('RPG Sheet')), reason: file.path);
      }
      expect(appVersionDisplay, 'Grimório • V$appVersion');
      expect(File('lib/app/app.dart').readAsStringSync(), contains("title: 'Grimório',"));
      expect(File('lib/screens/auth/access_gate.dart').readAsStringSync(), contains("'Esta conta ainda não possui acesso ao Grimório.'"));
      expect(File('lib/screens/settings/account_screen.dart').readAsStringSync(), contains("'Conta Grimório'"));
      final files = File('lib/services/rpg_file_service.dart').readAsStringSync();
      expect(files, contains("'Arquivo do Grimório: \$fileName'"));
      expect(files, contains("'Escolha um arquivo de backup do Grimório.'"));
      expect(files, contains("'Este arquivo não pertence ao Grimório.'"));
    });

    test('identificadores técnicos intactos: format, nomes de arquivo, esquema, cache', () {
      expect(RpgFileService.format, 'rpg_sheet');
      final files = File('lib/services/rpg_file_service.dart').readAsStringSync();
      expect(files, contains("'rpg-sheet-backup.rpg'"));
      expect(files, contains("'rpg-sheet.rpg'"));
      expect(files, contains("allowedExtensions: ['rpg', 'json']"));
      expect(File('lib/services/cloud_service.dart').readAsStringSync(), contains("'rpgsheet://auth-callback'"));
      expect(File('lib/app/app.dart').readAsStringSync(), contains("uri.scheme != 'rpgsheet'"));
      expect(File('web/rpg_service_worker.js').readAsStringSync(), contains("const CACHE='rpg-sheet-'+VERSION;"));
    });

    test('um backup .rpg antigo (format rpg_sheet) continua sendo aceito', () async {
      final old = {
        'format': 'rpg_sheet',
        'formatVersion': 1,
        'type': 'backup',
        'exportedAt': '2025-01-01T00:00:00Z',
        'data': {
          'characters': [Character(id: 'a', name: 'Antiga', systemId: 'generic').toJson()],
          'systems': <Object>[],
          'campaigns': <Object>[],
        },
      };
      FilePicker.platform = _FakePicker(utf8.encode(jsonEncode(old)));
      final data = await RpgFileService.pickBackupForRestore();
      expect(data, isNotNull);
      expect((data!['characters'] as List).single['name'], 'Antiga');
      expect(RpgFileService.backupSummary(data)['characters'], 1);
      // Arquivo de outro app continua recusado (com o nome novo na mensagem).
      FilePicker.platform = _FakePicker(utf8.encode(jsonEncode({...old, 'format': 'outro'})));
      await expectLater(RpgFileService.pickBackupForRestore(), throwsA(isA<FormatException>().having((e) => e.message, 'message', 'Este arquivo não pertence ao Grimório.')));
    });
  });

  group('B: depois de apagar, a nuvem só volta', () {
    test('clearAll liga a marca (e grava)', () async {
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc());
      await http.runWithClient(() async {
        final state = await _loadedState();
        expect(state.cloudRestorePending, isFalse);
        await state.clearAll();
        expect(state.cloudRestorePending, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('cloud_restore_pending'), isTrue);
        // Recarregar mantém a marca.
        final reloaded = AppState();
        await reloaded.load();
        expect(reloaded.cloudRestorePending, isTrue);
      }, cloud.client);
    });

    test('syncNow com o aparelho vazio traz a nuvem e desliga a marca', () async {
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)));
      await http.runWithClient(() async {
        final state = await _loadedState();
        await state.clearAll();
        expect(await state.syncNow(silent: true), 'Atualizado pela nuvem');
        expect(cloud.uploads, 0);
        expect(state.characters.map((c) => c.name), ['Nuvem 0', 'Nuvem 1']);
        expect(state.cloudRestorePending, isFalse);
        expect((await SharedPreferences.getInstance()).getBool('cloud_restore_pending'), isFalse);
      }, cloud.client);
    });

    test('ficha criada depois de apagar: syncNow não envia nem substitui e mostra a mensagem', () async {
      // Nuvem antiga: pela regra de datas, o aparelho "venceria" e enviaria.
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)));
      await http.runWithClient(() async {
        final state = await _loadedState();
        await state.clearAll();
        await state.addCharacter(name: 'Nova');
        await state.setAutoSync(true);
        // 1.3.68 (junção): recebe a nuvem, mantém a ficha nova e envia o resultado.
        expect(state.syncStatus, 'Alterações enviadas');
        expect(cloud.uploads, 1);
        expect(state.characters.map((c) => c.name), ['Nova', 'Nuvem 0', 'Nuvem 1']);
        expect(state.cloudRestorePending, isFalse);
        expect(AppState.backupCounts(cloud.payload), (characters: 3, campaigns: 1));
      }, cloud.client);
    });

    for (final (label, payload) in [('sem backup', null), ('backup sem fichas e sem campanhas', <String, dynamic>{'characters': <Object>[], 'campaigns': <Object>[]})]) {
      test('nuvem $label desliga a marca e segue a lógica normal', () async {
        final cloud = _FakeCloud(payload: payload, updatedAt: payload == null ? null : DateTime.now().toUtc().subtract(const Duration(days: 2)));
        await http.runWithClient(() async {
          final state = await _loadedState();
          await state.clearAll();
          await state.addCharacter(name: 'Nova');
          await state.syncNow(silent: true);
          expect(state.cloudRestorePending, isFalse);
          expect(cloud.uploads, 1, reason: 'lógica normal: o aparelho é mais novo e envia');
          expect(AppState.backupCounts(cloud.payload).characters, 1);
        }, cloud.client);
      });
    }

    group('na tela de sincronização', () {
      Future<AppState> pumpSync(WidgetTester tester, {bool createAfterClear = true}) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = await _loadedState();
        await state.clearAll();
        if (createAfterClear) await state.addCharacter(name: 'Nova');
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SyncScreen())));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Opções manuais'));
        await tester.pumpAndSettle();
        return state;
      }

      for (final (button, uploads) in [('Cancelar', 0), ('Substituir', 1)]) {
        testWidgets('envio manual depois de apagar e alterar pede a confirmação nova; "$button"', (tester) async {
          final cloud = _FakeCloud(payload: _cloudPayload(characters: 3, campaigns: 2), updatedAt: DateTime.now().toUtc());
          await http.runWithClient(() async {
            final state = await pumpSync(tester);
            await tester.tap(find.text('Forçar envio deste aparelho'));
            await _pumpFor(tester);
            expect(find.text('Substituir o backup da nuvem?'), findsOneWidget);
            expect(find.text('Este aparelho foi apagado e depois alterado. Enviar agora vai substituir o backup da nuvem, que tem 3 ficha(s) e 2 campanha(s). Continuar?'), findsOneWidget);
            await tester.tap(find.text(button));
            await _pumpFor(tester);
            expect(cloud.uploads, uploads);
            expect(state.cloudRestorePending, uploads == 0, reason: 'a marca só sai depois de enviar');
            if (uploads == 1) {
              expect(AppState.backupCounts(cloud.payload), (characters: 1, campaigns: 0));
              expect((await SharedPreferences.getInstance()).getBool('cloud_restore_pending'), isFalse);
            }
          }, cloud.client);
        });
      }

      testWidgets('aparelho vazio depois de apagar: a confirmação da 1.3.66 continua igual', (tester) async {
        final cloud = _FakeCloud(payload: _cloudPayload(characters: 3, campaigns: 2), updatedAt: DateTime.now().toUtc());
        await http.runWithClient(() async {
          await pumpSync(tester, createAfterClear: false);
          await tester.tap(find.text('Forçar envio deste aparelho'));
          await _pumpFor(tester);
          expect(find.text('Este aparelho está vazio. Enviar agora vai substituir o backup da nuvem, que tem 3 ficha(s) e 2 campanha(s). Continuar?'), findsOneWidget);
          await tester.tap(find.text('Cancelar'));
          await _pumpFor(tester);
          expect(cloud.uploads, 0);
        }, cloud.client);
      });

      testWidgets('"Restaurar cópia da nuvem" desliga a marca', (tester) async {
        final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc());
        await http.runWithClient(() async {
          final state = await pumpSync(tester);
          expect(state.cloudRestorePending, isTrue);
          await tester.tap(find.text('Restaurar cópia da nuvem'));
          await _pumpFor(tester);
          await tester.tap(find.text('Restaurar'));
          await _pumpFor(tester);
          expect(find.text('Dados restaurados da nuvem.'), findsOneWidget);
          expect(state.cloudRestorePending, isFalse);
          expect(state.characters.map((c) => c.name), ['Nuvem 0', 'Nuvem 1']);
          expect(cloud.uploads, 0);
        }, cloud.client);
      });
    });
  });

  group('C1: DisposeOnRemoved único', () {
    test('as cópias privadas saíram; os três editores usam o widget público', () {
      for (final file in ['lib/screens/character/character_screen.dart', 'lib/screens/systems/system_editor_screen.dart', 'lib/screens/campaigns/npc_sheet_screen.dart']) {
        final source = File(file).readAsStringSync();
        expect(source, isNot(contains('class _OnRemoved')), reason: file);
        expect(source, isNot(contains('class _DisposeOnRemoved')), reason: file);
        expect(source, contains('DisposeOnRemoved('), reason: file);
        expect(source, contains("import '../../widgets/dispose_on_removed.dart';"), reason: file);
      }
    });

    testWidgets('chama onRemoved só quando sai da árvore', (tester) async {
      var removed = 0;
      await tester.pumpWidget(DisposeOnRemoved(onRemoved: () => removed++, child: const SizedBox()));
      await tester.pumpWidget(DisposeOnRemoved(onRemoved: () => removed++, child: const SizedBox(width: 1)));
      expect(removed, 0);
      await tester.pumpWidget(const SizedBox());
      expect(removed, 1);
    });

    Future<void> saveFocused(WidgetTester tester, String name) async {
      final dialog = find.byType(AlertDialog);
      await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)).first, name);
      await tester.tap(find.descendant(of: dialog, matching: find.byWidgetPredicate((w) => w is FilledButton)).last);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(dialog, findsNothing);
      expect(tester.takeException(), isNull, reason: 'nenhum controlador usado depois de liberado');
    }

    Future<AppState> baseState() async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      return state;
    }

    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('editor de item da ficha', (tester) async {
      bigView(tester);
      final state = await baseState();
      await state.setReduceAnimations(true);
      state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'generic'));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme('classic', false), home: const CharacterScreen(characterId: 'p1'))));
      await _pumpFor(tester);
      await tester.tap(find.text('Inventário').first);
      await _pumpFor(tester);
      await tester.tap(find.byTooltip('Adicionar'));
      await _pumpFor(tester);
      await saveFocused(tester, 'Corda');
      expect(state.characters.single.inventory, ['Corda']);
    });

    testWidgets('editor de sistema (_askText)', (tester) async {
      bigView(tester);
      final state = await baseState();
      final system = RpgSystem(id: 'meu', name: 'Meu', attributes: ['Força']);
      state.systems.add(system);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(home: SystemEditorScreen(system: system))));
      await _pumpFor(tester);
      await tester.tap(find.text('Adicionar').first);
      await _pumpFor(tester);
      await saveFocused(tester, 'Destreza');
      expect(find.text('Destreza'), findsOneWidget);
    });

    testWidgets('editores da ficha de NPC', (tester) async {
      bigView(tester);
      final state = await baseState();
      final sheet = Character(id: 'n1', name: 'Orc', systemId: 'generic');
      state.campaigns.add(Campaign(id: 'c1', name: 'Mesa', npcSheets: [
        {'id': 'n1', 'name': 'Orc', 'kind': 'NPC', 'sheet': sheet.toJson()},
      ]));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme('classic', false), home: const NpcSheetScreen(campaignId: 'c1', npcId: 'n1'))));
      await _pumpFor(tester);
      Future<void> add(String title) async {
        await tester.tap(find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(Row)), matching: find.byIcon(Icons.add)).first);
        await _pumpFor(tester);
      }

      await tester.tap(find.text('Inventário').first);
      await _pumpFor(tester);
      await add('Inventário');
      await saveFocused(tester, 'Corda');
      await tester.tap(find.text('Ações').first);
      await _pumpFor(tester);
      await add('Ataques');
      await saveFocused(tester, 'Machado');
    });
  });

  group('C2: AppMessageException', () {
    test('AppMessageException mostra a mensagem; Exception genérica mostra a frase genérica', () {
      const message = AppMessageException('Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      expect(message.toString(), 'Exception: Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      expect(appErrorMessage(message), 'Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      expect(appErrorMessage(Exception('mensagem interna de uma biblioteca')), isNull);
      expect(appErrorMessage(const CloudRequestException('erro do servidor', statusCode: 500)), isNull);
      expect(appErrorMessage(const FormatException('x')), isNull);
      expect(genericErrorMessage, 'Não foi possível concluir. Verifique a conexão e tente de novo.');
    });

    test('as mensagens do cloud_service que chegam à sincronização e aos convites usam AppMessageException', () {
      final source = File('lib/services/cloud_service.dart').readAsStringSync();
      for (final text in [
        'A nuvem demorou para responder. Verifique a conexão e tente novamente.',
        'Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.',
        'Não foi possível iniciar a sessão da nuvem.',
        'Sua sessão expirou. Entre novamente.',
        'Informe um e-mail válido.',
        'A senha precisa ter pelo menos 6 caracteres.',
        'Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.',
      ]) {
        expect(source, contains("throw AppMessageException('$text')"), reason: text);
        expect(source, isNot(contains("throw Exception('$text')")), reason: text);
      }
    });

    testWidgets('sync_screen: mensagem do app aparece; Exception genérica vira a frase genérica', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // A nuvem demora: o CloudService lança AppMessageException.
      final client = MockClient((request) async => throw http.ClientException('socket closed'));
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final state = AppState();
        await state.load();
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SyncScreen())));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sincronizar agora'));
        await _pumpFor(tester);
        expect(find.text('Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.'), findsOneWidget);
        expect(find.textContaining('socket'), findsNothing);
      }, () => client);
    });
  });
}
