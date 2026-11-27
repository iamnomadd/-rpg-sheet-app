// 1.3.69 — limpeza: sem a tela de combate antiga, a tela de Dados e o
// detector de ícones antigo (A); dependências (B); conta anônima só quando há
// o que guardar (C1); migrações (C2/C3); achados do PR #55 (D). A nuvem é
// simulada com um MockClient do pacote http: nada sai para o Supabase real.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/campaigns/npc_sheet_screen.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:rpg_sheet_app/utils/action_art.dart';
import 'package:rpg_sheet_app/utils/error_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nuvem simulada: conta TODAS as requisições.
class _FakeCloud {
  Map<String, dynamic>? payload;
  DateTime? updatedAt;
  int requests = 0;
  int gets = 0;
  int uploads = 0;
  Object? failWith;

  _FakeCloud({this.payload, this.updatedAt});

  MockClient client() => MockClient((request) async {
        requests++;
        const json = {'content-type': 'application/json; charset=utf-8'};
        final failure = failWith;
        if (failure is http.ClientException) throw failure;
        if (request.url.path.endsWith('/rest/v1/rpg_cloud_backups')) {
          if (request.method == 'GET') {
            gets++;
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
        // Qualquer outra (por exemplo, criar sessão anônima): falha.
        return http.Response(jsonEncode({'message': 'indisponível no teste'}), 500, headers: json);
      });
}

const _session = <String, Object>{
  'cloud_access_token': 'token-de-teste',
  'cloud_refresh_token': '',
  'cloud_user_id': 'u1',
  'cloud_email': '',
  'cloud_is_anonymous': true,
};

final _t0 = DateTime.utc(2026, 11, 1, 12);

Map<String, dynamic> _ch(String id, String name, {DateTime? at}) => {
      ...Character(id: id, name: name, systemId: 'generic').toJson(),
      if (at != null) 'updatedAt': at.toIso8601String(),
    };

Map<String, dynamic> _pkg(List<Map<String, dynamic>> characters) => {
      'backupSchema': 5,
      'characters': characters,
      'systems': <Object>[],
      'campaigns': <Object>[],
      'savedRolls': <Object>[],
      'diceHistory': <Object>[],
      'preferences': {'themeId': 'classic'},
      'deletedItems': <Object>[],
      'localChangedAt': _t0.toIso8601String(),
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------ A
  group('A: código sem uso removido', () {
    test('arquivos removidos', () {
      expect(File('lib/screens/character/combat_tab.dart').existsSync(), isFalse);
      expect(Directory('lib/screens/dice').existsSync(), isFalse);
      expect(File('lib/core/feature_flags.dart').existsSync(), isFalse);
      expect(File('lib/utils/spell_icon.dart').existsSync(), isFalse);
      final app = File('lib/app/app.dart').readAsStringSync();
      expect(app, isNot(contains('DiceScreen')));
      expect(app, isNot(contains("'dice'")));
      expect(app, isNot(contains('diceTabEnabled')));
    });

    for (final master in [false, true]) {
      testWidgets('o app abre sem a aba Dados e sem erro (Mestre ${master ? 'ligado' : 'desligado'})', (tester) async {
        SharedPreferences.setMockInitialValues({'auto_sync': false});
        final state = AppState();
        await state.setMasterToolsEnabled(master);
        final controller = PageController();
        final index = ValueNotifier<int>(0);
        addTearDown(controller.dispose);
        addTearDown(index.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: buildAppTheme('classic', false),
            home: MainTabsShell(controller: controller, index: index, pageBuilder: (role) => Center(child: Text('Página $role'))),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Dados'), findsNothing);
        // 1.3.78: a aba "Árvore" saiu da barra principal.
        expect(mainTabs(masterToolsEnabled: master).map((t) => t.role), ['characters', 'systems', if (master) 'campaigns', 'settings']);
        for (final label in ['Fichas', 'Sistemas', if (master) 'Mestre', 'Config.']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(mainTabIndex('dice', masterToolsEnabled: master), 0, reason: 'papel que não existe cai na primeira aba');
      });
    }

    test('diceHistory e savedRolls continuam no pacote da nuvem e no backup .rpg', () async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      state.rollAdvanced(sides: 20);
      await state.saveRollPreset(name: 'Ataque', sides: 20, count: 1, modifier: 2, mode: 'normal');
      final payload = state.cloudPayload();
      expect((payload['diceHistory'] as List), hasLength(1));
      expect((payload['savedRolls'] as List).single['name'], 'Ataque');
      final files = File('lib/services/rpg_file_service.dart').readAsStringSync();
      final backup = files.substring(files.indexOf('static Future<void> exportBackup('), files.indexOf('static Future<Map<String, dynamic>?> pickBackupForRestore('));
      expect(backup, contains("'savedRolls'"));
      expect(backup, contains("'diceHistory'"));
      // E voltam ao restaurar.
      final restored = AppState();
      await restored.replaceFromBackup(payload);
      expect(restored.diceHistory, hasLength(1));
      expect(restored.savedRolls.single['name'], 'Ataque');
    });

    testWidgets('magia sem arte usa Icons.auto_awesome (ficha); botão Lançar idem; chip Magia igual', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.setReduceAnimations(true);
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida', 'Energia']));
      state.characters.add(Character(
        id: 'p1',
        name: 'Ana',
        systemId: 'sys',
        resourceValues: {'Vida': 10, 'Energia': 5},
        resourceMaxValues: {'Vida': 10, 'Energia': 5},
        abilities: ['Bola de Fogo'],
        abilityDetails: {'Bola de Fogo': {'category': 'Magia'}},
      ));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme('classic', false), home: const CharacterScreen(characterId: 'p1'))));
      await _settle(tester);
      // Card Ações do Em Cena: reserva e botão.
      final row = find.ancestor(of: find.text('Bola de Fogo').first, matching: find.byType(Card)).first;
      final slot = tester.widget<ActionIconSlot>(find.descendant(of: row, matching: find.byType(ActionIconSlot)));
      expect((slot.fallback as Icon).icon, Icons.auto_awesome);
      expect(find.descendant(of: find.widgetWithText(FilledButton, 'Lançar'), matching: find.byIcon(Icons.auto_awesome)), findsOneWidget);
      // Habilidades: reserva da linha e o chip de filtro de sempre.
      await tester.tap(find.text('Habilidades').first);
      await _settle(tester);
      final itemRow = find.ancestor(of: find.text('Bola de Fogo').last, matching: find.byType(Card)).first;
      final itemSlot = tester.widget<ActionIconSlot>(find.descendant(of: itemRow, matching: find.byType(ActionIconSlot)));
      expect(_iconsIn(itemSlot.fallback), [Icons.auto_awesome]);
      final chip = find.ancestor(of: find.text('Magia (1)'), matching: find.byType(FilterChip));
      expect(tester.widget<FilterChip>(chip).avatar, isA<Icon>().having((i) => i.icon, 'icon', Icons.auto_awesome_outlined));
    });

    testWidgets('NPC: magia sem arte usa Icons.auto_awesome', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      final sheet = Character(id: 'n1', name: 'Orc', abilities: ['Raio'], abilityDetails: {'Raio': {'category': 'Magia'}});
      state.campaigns.add(Campaign(id: 'c1', name: 'Mesa', npcSheets: [
        {'id': 'n1', 'name': 'Orc', 'kind': 'NPC', 'sheet': sheet.toJson()},
      ]));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: MaterialApp(theme: buildAppTheme('classic', false), home: const NpcSheetScreen(campaignId: 'c1', npcId: 'n1'))));
      await _settle(tester);
      await tester.tap(find.text('Ações').first);
      await _settle(tester);
      final row = find.ancestor(of: find.text('Raio').last, matching: find.byType(ListTile)).first;
      final slot = tester.widget<ActionIconSlot>(find.descendant(of: row, matching: find.byType(ActionIconSlot)));
      expect((slot.fallback as Icon).icon, Icons.auto_awesome);
    });
  });

  // ------------------------------------------------------------------ B
  test('B: pubspec sem path_provider e cupertino_icons; supabase sem "^"', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('path_provider')));
    expect(pubspec, isNot(contains('cupertino_icons')));
    final line = pubspec.split('\n').firstWhere((l) => l.trim().startsWith('supabase:'));
    expect(line.trim(), 'supabase: 2.14.0');
    expect(line, isNot(contains('^')));
  });

  // ------------------------------------------------------------------ C1
  group('C1: conta anônima só quando há o que guardar', () {
    test('aparelho vazio sem sessão salva: a automática não chama a nuvem', () async {
      final cloud = _FakeCloud();
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({'auto_sync': false});
        final state = AppState();
        await state.load();
        expect(state.hasDataToKeep, isFalse);
        expect(await state.syncNow(silent: true, automatic: true), 'Nada para sincronizar ainda');
        expect(cloud.requests, 0);
        expect(await CloudService.loadSession(), isNull, reason: 'nenhuma sessão anônima criada');
      }, cloud.client);
    });

    test('ao abrir o app (sync de inicialização) e ao salvar sem dados: nenhuma requisição', () async {
      final cloud = _FakeCloud();
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({'auto_sync': true});
        final state = AppState();
        await state.load();
        // Salvamento sem ficha (por exemplo, uma rolagem guardada) agenda a automática.
        await state.saveRollPreset(name: 'Ataque', sides: 20, count: 1, modifier: 0, mode: 'normal');
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        expect(cloud.requests, 0);
        expect(state.syncStatus, 'Nada para sincronizar ainda');
      }, cloud.client);
    });

    test('com uma ficha (ou um sistema personalizado), a automática segue e chama a nuvem', () async {
      for (final addData in <Future<void> Function(AppState)>[
        (s) => s.addCharacter(name: 'Ana'),
        (s) => s.addSystem(RpgSystem(id: 'meu', name: 'Meu')),
      ]) {
        final cloud = _FakeCloud();
        await http.runWithClient(() async {
          SharedPreferences.setMockInitialValues({'auto_sync': false});
          final state = AppState();
          await state.load();
          await addData(state);
          expect(state.hasDataToKeep, isTrue);
          await state.syncNow(silent: true, automatic: true);
          expect(cloud.requests, greaterThan(0));
        }, cloud.client);
      }
    });

    test('com sessão salva, a automática segue mesmo com o aparelho vazio', () async {
      final cloud = _FakeCloud(payload: _pkg([_ch('a', 'Ana', at: _t0)]), updatedAt: _t0);
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final state = AppState();
        await state.load();
        expect(await state.syncNow(silent: true, automatic: true), 'Atualizado pela nuvem');
        expect(state.characters.single.name, 'Ana');
      }, cloud.client);
    });

    test('ações explícitas (Sincronizar agora) continuam chamando a nuvem', () async {
      final cloud = _FakeCloud();
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({'auto_sync': false});
        final state = AppState();
        await state.load();
        await state.syncNow(silent: true);
        expect(cloud.requests, greaterThan(0), reason: 'cria a sessão como hoje');
      }, cloud.client);
    });

    test('só a inicialização e o salvamento usam o modo automático', () {
      final source = File('lib/services/app_state.dart').readAsStringSync();
      expect('syncNow(silent:true, automatic:true)'.allMatches(source).length, 2);
      final sync = File('lib/screens/settings/sync_screen.dart').readAsStringSync();
      expect(sync, isNot(contains('automatic')));
    });
  });

  // ------------------------------------------------------------------ C2/C3
  group('C2/C3: migrações', () {
    File? find(String suffix) {
      final files = Directory('supabase/migrations').listSync().whereType<File>().where((f) => f.path.endsWith(suffix)).toList();
      return files.length == 1 ? files.single : null;
    }

    test('limpeza de contas anônimas vazias', () {
      final file = find('_cleanup_empty_anonymous_users_v169.sql');
      expect(file, isNotNull);
      final sql = file!.readAsStringSync();
      expect(sql, contains("create or replace function public.cleanup_empty_anonymous_users(p_min_age interval default interval '30 days')"));
      expect(sql, contains('returns integer'));
      expect(sql, contains('security definer'));
      expect(sql, contains('set search_path = public, pg_temp'));
      expect(sql, contains('u.is_anonymous = true'));
      expect(sql, contains('coalesce(u.last_sign_in_at, u.created_at) < now() - p_min_age'));
      for (final table in ['rpg_shared_characters', 'rpg_character_link_requests', 'rpg_campaign_sessions', 'rpg_campaign_session_state', 'rpg_character_live_state', 'rpg_app_access', 'rpg_app_admins']) {
        expect(sql, contains('public.$table'), reason: table);
      }
      expect(sql, contains('r.character_owner_id = u.id or r.requester_id = u.id'));
      expect(sql, contains("jsonb_array_length(b.payload -> 'characters')"));
      expect(sql, contains("jsonb_array_length(b.payload -> 'campaigns')"));
      expect(sql.indexOf('delete from public.rpg_cloud_backups'), lessThan(sql.indexOf('delete from auth.users')));
      expect(sql, contains('revoke execute on function public.cleanup_empty_anonymous_users(interval) from public, anon, authenticated;'));
      expect(sql.toLowerCase(), isNot(contains('cron.schedule')));
    });

    test('remoção da tabela antiga user_backups (sem uso em lib/)', () {
      final file = find('_drop_user_backups_v169.sql');
      expect(file, isNotNull);
      expect(file!.readAsStringSync(), contains('drop table if exists public.user_backups;'));
      for (final dart in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(dart.readAsStringSync(), isNot(contains('user_backups')), reason: dart.path);
      }
    });
  });

  // ------------------------------------------------------------------ D
  group('D: achados do PR #55', () {
    test('D1: excluir a última ficha (com exclusão registrada) envia a junção', () async {
      final cloud = _FakeCloud(payload: _pkg([_ch('a', 'Ana', at: _t0)]), updatedAt: _t0);
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0)])});
        final state = AppState();
        await state.load();
        await state.deleteCharacter('a');
        expect(state.isLocalEmpty, isTrue);
        expect(await state.syncNow(silent: true), 'Alterações enviadas');
        expect(cloud.uploads, 1);
        expect(cloud.payload!['characters'], isEmpty);
        expect((cloud.payload!['deletedItems'] as List).single['id'], 'a');
      }, cloud.client);
    });

    test('D1: aparelho vazio sem exclusões (apagar) continua sem enviar', () async {
      final cloud = _FakeCloud(payload: _pkg([_ch('a', 'Ana', at: _t0)]), updatedAt: _t0);
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0)])});
        final state = AppState();
        await state.load();
        await state.clearAll();
        expect(state.deletedItems, isEmpty);
        await state.syncNow(silent: true);
        expect(cloud.uploads, 0);
        expect(state.characters.single.name, 'Ana', reason: 'a nuvem volta');
      }, cloud.client);
    });

    test('D2: CloudConflictException é AppMessageException, com a mesma mensagem e lançada no cloud_service', () {
      const e = CloudConflictException('Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      expect(e, isA<AppMessageException>());
      expect(appErrorMessage(e), 'Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      final source = File('lib/services/cloud_service.dart').readAsStringSync();
      expect(source, contains("throw const CloudConflictException('Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');"));
      expect(File('lib/services/app_state.dart').readAsStringSync(), contains('e is CloudConflictException'));
    });

    test('D2: conflito repete uma vez (e um segundo conflito para)', () async {
      final cloud = _FakeCloud(payload: _pkg([_ch('a', 'Ana', at: _t0)]), updatedAt: _t0);
      final client = MockClient((request) async {
        // A conferência antes de cada envio (GET par) sempre vê uma nuvem mais nova.
        if (request.method == 'GET') {
          cloud.gets++;
          if (cloud.gets.isEven) cloud.updatedAt = cloud.updatedAt!.add(const Duration(hours: 1));
          return http.Response(jsonEncode([{'payload': cloud.payload, 'updated_at': cloud.updatedAt!.toIso8601String()}]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        cloud.uploads++;
        return http.Response('', 201);
      });
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0)])});
        final state = AppState();
        await state.load();
        await state.addCharacter(name: 'Nova');
        expect(await state.syncNow(silent: true), 'Falha na sincronização');
        expect(cloud.gets, 4, reason: 'duas tentativas');
        expect(cloud.uploads, 0);
      }, () => client);
    });

    test('D2: outro AppMessageException não repete', () async {
      final cloud = _FakeCloud()..failWith = http.ClientException('socket closed');
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0)])});
        final state = AppState();
        await state.load();
        Object? error;
        try {
          await state.syncNow();
        } catch (e) {
          error = e;
        }
        expect(error, isA<AppMessageException>());
        expect(error, isNot(isA<CloudConflictException>()));
        expect(cloud.requests, 1, reason: 'uma tentativa só');
      }, cloud.client);
    });
  });
}

List<IconData?> _iconsIn(Widget widget) => [
      if (widget is Icon) widget.icon,
      if (widget is Container && widget.child != null) ..._iconsIn(widget.child!),
    ];
