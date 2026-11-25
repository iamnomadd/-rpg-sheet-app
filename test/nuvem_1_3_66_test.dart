// 1.3.66 — Parte A ("Apagar todos os dados" vale só para o aparelho) e Parte B
// (mensagens de erro claras). A nuvem é simulada com um MockClient do pacote
// http (http.runWithClient): nenhuma chamada sai para o Supabase real.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/settings/settings_screen.dart';
import 'package:rpg_sheet_app/screens/settings/sync_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:rpg_sheet_app/utils/error_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backup da nuvem simulado (tabela rpg_cloud_backups de um usuário).
class _FakeCloud {
  Map<String, dynamic>? payload;
  DateTime? updatedAt;
  int uploads = 0;
  int downloads = 0;

  /// Se definido, toda chamada falha assim.
  Object? failWith;

  _FakeCloud({this.payload, this.updatedAt});

  MockClient client() => MockClient((request) async {
        final failure = failWith;
        if (failure is http.ClientException) throw failure;
        if (failure != null) {
          return http.Response(jsonEncode({'message': '$failure'}), 500, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path.endsWith('/rest/v1/rpg_cloud_backups')) {
          if (request.method == 'GET') {
            downloads++;
            final body = payload == null ? <Object>[] : [{'payload': payload, 'updated_at': updatedAt?.toIso8601String()}];
            return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (request.method == 'POST') {
            uploads++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            payload = Map<String, dynamic>.from(body['payload'] as Map);
            updatedAt = DateTime.parse(body['updated_at'] as String);
            return http.Response('', 201);
          }
        }
        return http.Response(jsonEncode({'message': 'chamada inesperada ${request.method} ${request.url}'}), 500, headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

/// Sessão anônima já salva (sem rede para entrar).
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

/// Estado carregado com autoSync ligado e uma ficha local.
Future<AppState> _loadedState({bool autoSync = true, bool withCharacter = true, String? lastLocalChange}) async {
  SharedPreferences.setMockInitialValues({
    ..._session,
    'auto_sync': autoSync,
    if (withCharacter) 'characters': jsonEncode([Character(id: 'p1', name: 'Ana', systemId: 'generic').toJson()]),
    if (lastLocalChange != null) 'last_local_change_utc': lastLocalChange,
  });
  final state = AppState();
  await state.load();
  return state;
}

/// Avança o tempo em passos (a tela mostra um indicador animado enquanto
/// espera, então pumpAndSettle não serve).
Future<void> _pumpFor(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A: apagar vale só para o aparelho', () {
    test('com autoSync ligado, clearAll não envia (nem depois do debounce), desliga o autoSync e zera lastLocalChangeUtc', () async {
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)));
      await http.runWithClient(() async {
        final state = await _loadedState();
        expect(state.autoSync, isTrue);
        // Uma alteração local agenda a sincronização automática (700 ms)…
        await state.save();
        // …e o apagar vem antes de ela disparar.
        await state.clearAll();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(cloud.uploads, 0, reason: 'nada foi enviado');
        expect(state.autoSync, isFalse);
        expect(state.lastLocalChangeUtc, isNull);
        expect(state.characters, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('auto_sync'), isFalse);
        expect(prefs.getString('last_local_change_utc'), isNull);
        // O backup da nuvem continua com os dados.
        expect(AppState.backupCounts(cloud.payload), (characters: 2, campaigns: 1));
      }, cloud.client);
    });

    test('depois do clearAll, syncNow com a nuvem cheia traz os dados de volta e não envia nada', () async {
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)));
      await http.runWithClient(() async {
        final state = await _loadedState();
        await state.clearAll();
        final status = await state.syncNow(silent: true);
        expect(status, 'Atualizado pela nuvem');
        expect(cloud.uploads, 0);
        expect(state.characters.map((c) => c.name), ['Nuvem 0', 'Nuvem 1']);
        expect(state.campaigns.map((c) => c.name), ['Mesa 0']);
      }, cloud.client);
    });

    test('syncNow com o aparelho vazio e a nuvem com dados nunca envia', () async {
      // Aparelho vazio com uma "alteração local" mais nova que a nuvem (por
      // exemplo, apagou tudo à mão).
      final cloud = _FakeCloud(payload: _cloudPayload(characters: 1, campaigns: 0), updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)));
      await http.runWithClient(() async {
        final state = await _loadedState(autoSync: false, withCharacter: false, lastLocalChange: DateTime.now().toUtc().toIso8601String());
        expect(state.isLocalEmpty, isTrue);
        final status = await state.syncNow(silent: true);
        expect(status, 'Nada enviado: este aparelho está vazio');
        expect(cloud.uploads, 0);
        expect(AppState.backupCounts(cloud.payload), (characters: 1, campaigns: 0));
      }, cloud.client);
    });

    test('aparelho com dados e alteração mais nova continua enviando como antes', () async {
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)));
      await http.runWithClient(() async {
        final state = await _loadedState(autoSync: false, lastLocalChange: DateTime.now().toUtc().toIso8601String());
        final status = await state.syncNow(silent: true);
        expect(status, 'Alterações enviadas');
        expect(cloud.uploads, 1);
      }, cloud.client);
    });

    group('envio manual ("Forçar envio deste aparelho")', () {
      Future<AppState> pumpSync(WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = await _loadedState(autoSync: false, withCharacter: false);
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SyncScreen())));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Opções manuais'));
        await tester.pumpAndSettle();
        return state;
      }

      for (final (button, uploads) in [('Cancelar', 0), ('Substituir', 1)]) {
        testWidgets('aparelho vazio e nuvem com dados pede confirmação; "$button"', (tester) async {
          final cloud = _FakeCloud(payload: _cloudPayload(characters: 3, campaigns: 2), updatedAt: DateTime.now().toUtc());
          await http.runWithClient(() async {
            await pumpSync(tester);
            await tester.tap(find.text('Forçar envio deste aparelho'));
            await _pumpFor(tester);
            expect(find.text('Este aparelho está vazio. Enviar agora vai substituir o backup da nuvem, que tem 3 ficha(s) e 2 campanha(s). Continuar?'), findsOneWidget);
            await tester.tap(find.text(button));
            await _pumpFor(tester);
            expect(cloud.uploads, uploads);
            if (uploads == 1) expect(find.text('Dados enviados para a nuvem.'), findsOneWidget);
          }, cloud.client);
        });
      }

      testWidgets('aparelho com dados envia sem perguntar', (tester) async {
        final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc());
        await http.runWithClient(() async {
          final state = await pumpSync(tester);
          state.characters.add(Character(id: 'p1', name: 'Ana', systemId: 'generic'));
          await tester.tap(find.text('Forçar envio deste aparelho'));
          await _pumpFor(tester);
          expect(find.byType(AlertDialog), findsNothing);
          expect(cloud.uploads, 1);
        }, cloud.client);
      });
    });

    testWidgets('diálogo: "Apagar" só com APAGAR (aceita "apagar "); mensagem final', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc());
      await http.runWithClient(() async {
        final state = await _loadedState();
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SettingsScreen())));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Apagar todos os dados locais'));
        await tester.tap(find.text('Apagar todos os dados locais'));
        await tester.pumpAndSettle();
        expect(find.text('Apagar todos os dados deste aparelho?'), findsOneWidget);
        expect(find.text('Fichas, sistemas personalizados e campanhas serão apagados SÓ deste aparelho. A sincronização automática será desligada para não apagar o seu backup na nuvem. Para trazer os dados de volta, use Restaurar da nuvem em Dados e sincronização.'), findsOneWidget);
        FilledButton apagar() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apagar'));
        expect(apagar().onPressed, isNull);
        final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
        expect(find.text('Digite APAGAR para confirmar'), findsOneWidget);
        await tester.enterText(field, 'APAGA');
        await tester.pump();
        expect(apagar().onPressed, isNull);
        await tester.enterText(field, 'apagar ');
        await tester.pump();
        expect(apagar().onPressed, isNotNull);
        await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        expect(find.text('Dados apagados deste aparelho. Sincronização automática desligada.'), findsOneWidget);
        expect(state.characters, isEmpty);
        expect(state.autoSync, isFalse);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 900)));
        expect(cloud.uploads, 0);
      }, cloud.client);
    });
  });

  group('B: mensagens de erro claras', () {
    test('appErrorMessage: só mensagens do próprio app', () {
      expect(appErrorMessage(const AppMessageException('Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.')), 'Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      expect(appErrorMessage(const CloudRequestException('duplicate key value violates unique constraint', statusCode: 409)), isNull);
      expect(appErrorMessage(const FormatException('Unexpected character')), isNull);
      expect(appErrorMessage(StateError('Bad state')), isNull);
      expect(appErrorMessage(TypeError()), isNull);
      expect(genericErrorMessage, 'Não foi possível concluir. Verifique a conexão e tente de novo.');
    });

    test('cada ponto tem a frase nova, registra o erro com debugPrint e não mostra o erro técnico', () {
      const points = <String, List<String>>{
        'lib/screens/systems/systems_screen.dart': [
          'Não foi possível importar o sistema. Confira se o arquivo .rpg é válido.',
          'Não foi possível exportar o sistema. Tente de novo.',
        ],
        'lib/screens/settings/import_export_screen.dart': [
          'Não foi possível concluir. Tente de novo.',
          'Arquivo inválido. Escolha um arquivo .rpg exportado pelo Grimório.',
          'Não foi possível restaurar. Confira se o arquivo é um backup .rpg válido.',
        ],
        'lib/screens/character/character_screen.dart': [
          'Não foi possível consultar as solicitações. Verifique a conexão.',
          'Não foi possível compartilhar a ficha. Verifique a conexão.',
        ],
        'lib/screens/campaigns/campaigns_screen.dart': [
          'Não foi possível vincular a ficha. Confira o código e a conexão.',
          'Não foi possível desvincular. Verifique a conexão.',
          'Não foi possível sincronizar. Verifique a conexão.',
          'Não foi possível atualizar os vínculos. Verifique a conexão.',
          'Não foi possível compartilhar. Tente de novo.',
        ],
      };
      final technical = RegExp(r"""Text\(\s*'[^']*(\$e\b|\$\{e\}|e\.toString\(\))""");
      for (final entry in points.entries) {
        final source = File(entry.key).readAsStringSync();
        for (final phrase in entry.value) {
          expect(source, contains("Text('$phrase')"), reason: '${entry.key}: $phrase');
        }
        expect(technical.hasMatch(source), isFalse, reason: '${entry.key} ainda mostra o erro técnico');
        expect('debugPrint('.allMatches(source).length, greaterThanOrEqualTo(entry.value.length), reason: entry.key);
      }
      for (final file in ['lib/screens/settings/sync_screen.dart', 'lib/screens/settings/invite_manager_screen.dart']) {
        final source = File(file).readAsStringSync();
        expect(source, contains('appErrorMessage(e)'), reason: file);
        expect(source, contains('genericErrorMessage'), reason: file);
        expect(source, contains('debugPrint('), reason: file);
      }
    });

    for (final (name, failure, expected, hidden) in [
      ('erro do servidor → frase genérica', 'violates row-level security policy', genericErrorMessage, 'row-level'),
      ('mensagem do próprio app → a mensagem', http.ClientException('socket closed'), 'Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.', 'socket'),
    ]) {
      testWidgets('sync_screen: $name', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cloud = _FakeCloud(payload: _cloudPayload(), updatedAt: DateTime.now().toUtc());
        await http.runWithClient(() async {
          final state = await _loadedState(autoSync: false);
          await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SyncScreen())));
          await tester.pumpAndSettle();
          cloud.failWith = failure;
          await tester.tap(find.text('Sincronizar agora'));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pumpAndSettle();
          final snack = find.descendant(of: find.byType(SnackBar), matching: find.byType(Text));
          expect(tester.widget<Text>(snack).data, expected);
          expect(find.textContaining('Exception'), findsNothing);
          expect(find.textContaining(hidden), findsNothing);
        }, cloud.client);
      });
    }
  });
}
