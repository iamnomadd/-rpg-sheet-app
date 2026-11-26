// 1.3.68 — proteção dos dados: salvamento seguro e espaço do aparelho (A),
// sincronização que junta por item (B), registro de sessão com limite (C) e
// mensagens do cloud_service (D). A nuvem é simulada com um MockClient do
// pacote http (http.runWithClient): nenhuma chamada sai para o Supabase real.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/custom_sprite_sheet.dart';
import 'package:rpg_sheet_app/screens/settings/sync_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/backup_merge.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:rpg_sheet_app/utils/error_message.dart';
import 'package:rpg_sheet_app/widgets/save_failed_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- nuvem falsa

class _FakeCloud {
  Map<String, dynamic>? payload;
  DateTime? updatedAt;
  int uploads = 0;
  int gets = 0;

  /// Chamado antes de responder cada GET (número do GET, começando em 1).
  void Function(int get)? beforeGet;

  _FakeCloud({this.payload, this.updatedAt});

  MockClient client() => MockClient((request) async {
        const json = {'content-type': 'application/json; charset=utf-8'};
        if (request.url.path.endsWith('/rest/v1/rpg_cloud_backups')) {
          if (request.method == 'GET') {
            gets++;
            beforeGet?.call(gets);
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
        if (request.url.path.endsWith('/rpc/set_rpg_master_patch')) return http.Response('false', 200, headers: json);
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

String _iso(DateTime t) => t.toUtc().toIso8601String();
final _t0 = DateTime.utc(2026, 11, 1, 12);

Map<String, dynamic> _ch(String id, String name, {DateTime? at}) => {
      ...Character(id: id, name: name, systemId: 'generic').toJson(),
      if (at != null) 'updatedAt': _iso(at),
    };

Map<String, dynamic> _pkg({List<Map<String, dynamic>> characters = const [], List<Map<String, dynamic>> campaigns = const [], List<Map<String, dynamic>> systems = const [], List<Map<String, dynamic>> deleted = const [], DateTime? changedAt, Map<String, dynamic>? preferences}) => {
      'backupSchema': 5,
      'characters': characters,
      'systems': systems,
      'campaigns': campaigns,
      'savedRolls': <Object>[],
      'diceHistory': <Object>[],
      'preferences': preferences ?? {'themeId': 'classic'},
      'deletedItems': deleted,
      if (changedAt != null) 'localChangedAt': _iso(changedAt),
    };

List<String> _names(Map<String, dynamic> pkg, [String key = 'characters']) => [for (final item in pkg[key] as List) (item as Map)['name'] as String];

Future<AppState> _device({List<Character> characters = const []}) async {
  final state = AppState();
  state.autoSync = false;
  state.characters.addAll(characters);
  state.systems.add(RpgSystem(id: 'generic', name: 'Sistema Padrão'));
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------ A
  group('A: salvamento seguro e espaço do aparelho', () {
    testWidgets('gravação falhando liga lastSaveFailed e mostra o aviso; "Tentar de novo" com sucesso apaga', (tester) async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      state.characters.add(Character(id: 'p1', name: 'Ana'));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          builder: (context, child) => SaveFailedBanner(child: child!),
          home: const Scaffold(body: Text('conteúdo')),
        ),
      ));
      expect(find.byKey(const ValueKey('save-failed-banner')), findsNothing);

      state.writeStringOverride = (key, value) async => throw Exception('QuotaExceededError: o armazenamento está cheio');
      await tester.runAsync(() => state.updateCharacter(state.characters.single));
      await tester.pump();
      expect(state.lastSaveFailed, isTrue);
      expect(state.lastSaveError, contains('QuotaExceededError'));
      expect(find.text(saveFailedMessage), findsOneWidget);
      expect(find.text('conteúdo'), findsOneWidget, reason: 'o conteúdo continua abaixo do aviso');
      expect(state.characters.single.name, 'Ana', reason: 'os dados continuam na memória');

      // Ainda falhando: "Tentar de novo" mantém o aviso.
      await tester.tap(find.text('Tentar de novo'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(find.text(saveFailedMessage), findsOneWidget);

      state.writeStringOverride = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(state.lastSaveFailed, isFalse);
      expect(find.text(saveFailedMessage), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('characters'), contains('Ana'));
    });

    test('gravação que devolve false também conta como falha', () async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      state.writeStringOverride = (key, value) async => false;
      await state.save();
      expect(state.lastSaveFailed, isTrue);
    });

    test('o aviso está no builder do app', () {
      expect(File('lib/app/app.dart').readAsStringSync(), contains('SaveFailedBanner(child: content)'));
    });

    test('cálculo do espaço usado: chaves "flutter.<chave>" + valores salvos', () async {
      SharedPreferences.setMockInitialValues({'auto_sync': false, 'outra': 'x' * 1000});
      final state = AppState();
      await state.load();
      state.characters.add(Character(id: 'p1', name: 'Ana'));
      await state.save();
      final prefs = await SharedPreferences.getInstance();
      var expected = 0;
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        expected += 'flutter.$key'.length + (value is String ? value.length + 2 : '$value'.length);
      }
      expect(state.storageUsage, expected);
      expect(state.storageUsage, greaterThan(1000));
      expect(await state.projectedStorageUsage(), state.storageUsage, reason: 'sem mudanças na memória, a projeção é igual ao salvo');
      state.characters.add(Character(id: 'p2', name: 'Bia'));
      expect(await state.projectedStorageUsage(), greaterThan(state.storageUsage));
    });

    for (final (label, bytes, alert) in [('abaixo de 80%', 1024 * 1024, false), ('acima de 80%', (4.2 * 1024 * 1024).round(), true)]) {
      testWidgets('Dados e sincronização mostra o espaço usado ($label)', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cloud = _FakeCloud();
        await http.runWithClient(() async {
          SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
          final state = AppState();
          await state.load();
          state.storageUsage = bytes;
          await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(value: state, child: const MaterialApp(home: SyncScreen())));
          await tester.pumpAndSettle();
          final megabytes = (bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
          final text = tester.widget<Text>(find.byKey(const ValueKey('storage-usage')));
          expect(text.data, 'Espaço usado neste aparelho: $megabytes MB de cerca de 5 MB');
          final error = Theme.of(tester.element(find.byKey(const ValueKey('storage-usage')))).colorScheme.error;
          expect(text.style?.color == error, alert);
        }, cloud.client);
      });
    }

    testWidgets('personagem 2D recusado acima de 4,5 MB, sem alterar a ficha', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late Uint8List sheetPng;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 800, 300), Paint()..color = const Color(0xFF334455));
        final image = await recorder.endRecording().toImage(800, 300);
        sheetPng = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        image.dispose();
      });
      // O aparelho já está quase cheio (outros dados guardados).
      SharedPreferences.setMockInitialValues({'auto_sync': false, 'outros_dados': 'x' * (customSpriteStorageLimitBytes.round() - 500)});
      final state = AppState();
      final character = Character(id: 'c', name: 'C');
      state.characters.add(character);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCustomSpriteSheet(context, character, pick: () async => sheetPng),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar imagem própria'));
      await tester.pump();
      for (var round = 0; round < 2; round++) {
        for (var i = 0; i < 25; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
        }
      }
      await tester.tap(find.text('Salvar'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.text('Sem espaço para este personagem 2D. Remova outro personagem personalizado ou use imagens menores.'), findsOneWidget);
      expect(character.customSpriteImages, isEmpty);
      expect(character.customSpriteEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('characters'), isNull, reason: 'nada foi gravado');
    });

    test('a cópia para NPC não leva o personagem 2D personalizado', () {
      final source = File('lib/screens/campaigns/campaigns_screen.dart').readAsStringSync();
      final line = source.split('\n').firstWhere((l) => l.contains("data['player']='Mestre'"));
      final index = source.indexOf(line);
      final block = source.substring(index, index + 600);
      expect(block, contains("data['customSpriteImages']=<String,String>{}"));
      expect(block, contains("data['customSpriteEnabled']=false"));
      // O import de .rpg continua levando as imagens (não é a cópia para NPC).
      expect(File('lib/services/rpg_file_service.dart').readAsStringSync(), contains('customSpriteImages: Map<String, String>.from(original.customSpriteImages),'));
    });
  });

  // ------------------------------------------------------------------ B
  group('B: mergeBackups (tabela)', () {
    final now = DateTime.utc(2026, 11, 26);
    Map<String, dynamic> merge(Map<String, dynamic> local, Map<String, dynamic> cloud, {DateTime? localTime, DateTime? cloudTime}) =>
        mergeBackups(local, cloud, localTime: localTime, cloudTime: cloudTime, now: now);

    test('item só local e item só na nuvem entram; ordem local e depois a da nuvem', () {
      final merged = merge(
        _pkg(characters: [_ch('b', 'Bia', at: _t0), _ch('a', 'Ana', at: _t0)]),
        _pkg(characters: [_ch('z', 'Zeca', at: _t0), _ch('a', 'Ana', at: _t0), _ch('y', 'Yara', at: _t0)]),
      );
      expect(_names(merged), ['Bia', 'Ana', 'Zeca', 'Yara']);
    });

    test('mesmo item editado nos dois: vence o updatedAt mais novo (dos dois lados)', () {
      final local = _pkg(characters: [_ch('a', 'Ana local', at: _t0.add(const Duration(hours: 2))), _ch('b', 'Bia local', at: _t0)]);
      final cloud = _pkg(characters: [_ch('a', 'Ana nuvem', at: _t0.add(const Duration(hours: 1))), _ch('b', 'Bia nuvem', at: _t0.add(const Duration(hours: 3)))]);
      expect(_names(merge(local, cloud)), ['Ana local', 'Bia nuvem']);
    });

    test('itens antigos sem updatedAt: vence o pacote mais novo', () {
      final local = _pkg(characters: [_ch('a', 'Ana local')]);
      final cloud = _pkg(characters: [_ch('a', 'Ana nuvem')]);
      expect(_names(merge(local, cloud, localTime: _t0, cloudTime: _t0.add(const Duration(minutes: 5)))), ['Ana nuvem']);
      expect(_names(merge(local, cloud, localTime: _t0.add(const Duration(minutes: 5)), cloudTime: _t0)), ['Ana local']);
      // Só um lado datado: vence o datado.
      expect(_names(merge(_pkg(characters: [_ch('a', 'Ana local')]), _pkg(characters: [_ch('a', 'Ana nuvem', at: _t0)]), localTime: now, cloudTime: _t0)), ['Ana nuvem']);
    });

    test('exclusão mais nova que a edição: some (de qualquer lado)', () {
      final del = [{'kind': 'character', 'id': 'a', 'deletedAt': _iso(_t0.add(const Duration(hours: 2)))}];
      expect(_names(merge(_pkg(deleted: del), _pkg(characters: [_ch('a', 'Ana', at: _t0.add(const Duration(hours: 1)))]))), isEmpty);
      expect(_names(merge(_pkg(characters: [_ch('a', 'Ana', at: _t0.add(const Duration(hours: 1)))]), _pkg(deleted: del))), isEmpty);
      // Item sem updatedAt e uma exclusão: some.
      expect(_names(merge(_pkg(characters: [_ch('a', 'Ana')]), _pkg(deleted: del))), isEmpty);
      // Campanhas e sistemas seguem a mesma regra.
      final merged = merge(
        _pkg(campaigns: [Campaign(id: 'm', name: 'Mesa', updatedAt: _iso(_t0)).toJson()], systems: [RpgSystem(id: 's', name: 'Sis', updatedAt: _iso(_t0)).toJson()]),
        _pkg(deleted: [
          {'kind': 'campaign', 'id': 'm', 'deletedAt': _iso(_t0.add(const Duration(hours: 1)))},
          {'kind': 'system', 'id': 's', 'deletedAt': _iso(_t0.add(const Duration(hours: 1)))},
        ]),
      );
      expect(merged['campaigns'], isEmpty);
      expect(merged['systems'], isEmpty);
    });

    test('edição mais nova que a exclusão: fica', () {
      final del = [{'kind': 'character', 'id': 'a', 'deletedAt': _iso(_t0)}];
      expect(_names(merge(_pkg(characters: [_ch('a', 'Ana', at: _t0.add(const Duration(hours: 1)))]), _pkg(deleted: del))), ['Ana']);
    });

    test('exclusões unidas por kind+id (fica o deletedAt mais novo); mais de 90 dias, descartadas', () {
      final old = now.subtract(const Duration(days: 91));
      final merged = merge(
        _pkg(characters: [_ch('x', 'Xavier')], deleted: [
          {'kind': 'character', 'id': 'a', 'deletedAt': _iso(_t0)},
          {'kind': 'character', 'id': 'x', 'deletedAt': _iso(old)},
        ]),
        _pkg(deleted: [{'kind': 'character', 'id': 'a', 'deletedAt': _iso(_t0.add(const Duration(hours: 1)))}]),
      );
      expect(merged['deletedItems'], [
        {'kind': 'character', 'id': 'a', 'deletedAt': _iso(_t0.add(const Duration(hours: 1)))},
      ]);
      expect(_names(merged), ['Xavier'], reason: 'a exclusão de 91 dias não vale mais');
    });

    test('savedRolls, diceHistory e preferences ficam os do aparelho', () {
      final local = {..._pkg(preferences: {'themeId': 'vampire'}), 'savedRolls': [{'id': 'r', 'name': 'Ataque'}], 'diceHistory': [{'result': 20}]};
      final cloud = {..._pkg(preferences: {'themeId': 'ice'}), 'savedRolls': <Object>[], 'diceHistory': <Object>[]};
      final merged = merge(local, cloud);
      expect(merged['preferences'], {'themeId': 'vampire'});
      expect(merged['savedRolls'], [{'id': 'r', 'name': 'Ataque'}]);
      expect(merged['diceHistory'], [{'result': 20}]);
    });

    test('backup schema 4 (sem updatedAt e sem deletedItems) é lido sem erro', () async {
      final schema4 = {
        'backupSchema': 4,
        'characters': [Character(id: 'a', name: 'Antiga').toJson()..remove('updatedAt')],
        'systems': [RpgSystem(id: 'generic', name: 'Sistema Padrão').toJson()],
        'campaigns': [Campaign(id: 'm', name: 'Mesa').toJson()],
        'savedRolls': <Object>[],
        'diceHistory': <Object>[],
      };
      expect(_names(mergeBackups(_pkg(), schema4, now: now)), ['Antiga']);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      await state.replaceFromBackup(schema4);
      expect(state.characters.single.name, 'Antiga');
      expect(state.characters.single.updatedAt, isNull);
      expect(state.deletedItems, isEmpty);
      expect(state.cloudPayload()['backupSchema'], 5);
      expect(state.cloudPayload()['deletedItems'], isEmpty);
    });

    test('updatedAt e o registro de exclusões nos métodos do AppState', () async {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      await state.load();
      final ana = await state.addCharacter(name: 'Ana');
      expect(DateTime.tryParse(ana.updatedAt ?? ''), isNotNull);
      ana.updatedAt = null;
      await state.updateCharacter(ana);
      expect(ana.updatedAt, isNotNull);
      final camp = Campaign(id: 'm', name: 'Mesa');
      await state.addCampaign(camp);
      expect(camp.updatedAt, isNotNull);
      final sys = RpgSystem(id: 's', name: 'Sis');
      await state.addSystem(sys);
      expect(sys.updatedAt, isNotNull);
      await state.deleteCharacter(ana.id);
      await state.deleteCampaign('m');
      await state.deleteSystem('s');
      expect(state.deletedItems.map((e) => '${e['kind']}:${e['id']}'), ['character:${ana.id}', 'campaign:m', 'system:s']);
      // Persistidas e lidas de volta.
      final reloaded = AppState();
      await reloaded.load();
      expect(reloaded.deletedItems, hasLength(3));
    });

    test('o load descarta exclusões com mais de 90 dias', () async {
      SharedPreferences.setMockInitialValues({
        'auto_sync': false,
        'deleted_items': jsonEncode([
          {'kind': 'character', 'id': 'velha', 'deletedAt': _iso(DateTime.now().toUtc().subtract(const Duration(days: 100)))},
          {'kind': 'character', 'id': 'nova', 'deletedAt': _iso(DateTime.now().toUtc().subtract(const Duration(days: 3)))},
        ]),
      });
      final state = AppState();
      await state.load();
      expect(state.deletedItems.map((e) => e['id']), ['nova']);
    });
  });

  group('B: syncNow com a junção', () {
    test('aparelhos A e B editam fichas diferentes: as duas edições existem nos dois', () async {
      final cloud = _FakeCloud(
        payload: _pkg(characters: [_ch('a', 'Ana', at: _t0), _ch('b', 'Bia', at: _t0)], changedAt: _t0),
        updatedAt: _t0,
      );
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final deviceA = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0)), Character.fromJson(_ch('b', 'Bia', at: _t0))]);
        final deviceB = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0)), Character.fromJson(_ch('b', 'Bia', at: _t0))]);
        // A edita Ana; B edita Bia.
        deviceA.characters.first.level = 5;
        await deviceA.updateCharacter(deviceA.characters.first);
        deviceB.characters.last.level = 9;
        await deviceB.updateCharacter(deviceB.characters.last);

        expect(await deviceA.syncNow(silent: true), 'Alterações enviadas');
        expect(await deviceB.syncNow(silent: true), 'Alterações enviadas');
        expect(await deviceA.syncNow(silent: true), 'Atualizado pela nuvem');
        for (final device in [deviceA, deviceB]) {
          expect(device.characters.firstWhere((c) => c.id == 'a').level, 5);
          expect(device.characters.firstWhere((c) => c.id == 'b').level, 9);
        }
        final inCloud = {for (final c in cloud.payload!['characters'] as List) (c as Map)['id']: c['level']};
        expect(inCloud, {'a': 5, 'b': 9});
        expect(await deviceB.syncNow(silent: true), 'Tudo sincronizado');
      }, cloud.client);
    });

    test('a mesma ficha editada nos dois: vence a edição mais nova', () async {
      final cloud = _FakeCloud(payload: _pkg(characters: [_ch('a', 'Ana', at: _t0)], changedAt: _t0), updatedAt: _t0);
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final deviceA = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0))]);
        final deviceB = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0))]);
        deviceA.characters.single.level = 3;
        await deviceA.updateCharacter(deviceA.characters.single);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        deviceB.characters.single.level = 7;
        await deviceB.updateCharacter(deviceB.characters.single);
        await deviceA.syncNow(silent: true);
        await deviceB.syncNow(silent: true);
        await deviceA.syncNow(silent: true);
        expect(deviceA.characters.single.level, 7);
        expect(deviceB.characters.single.level, 7);
      }, cloud.client);
    });

    test('exclusão em um aparelho some no outro', () async {
      final cloud = _FakeCloud(payload: _pkg(characters: [_ch('a', 'Ana', at: _t0), _ch('b', 'Bia', at: _t0)], changedAt: _t0), updatedAt: _t0);
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final deviceA = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0)), Character.fromJson(_ch('b', 'Bia', at: _t0))]);
        final deviceB = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0)), Character.fromJson(_ch('b', 'Bia', at: _t0))]);
        await deviceA.deleteCharacter('b');
        await deviceA.syncNow(silent: true);
        await deviceB.syncNow(silent: true);
        expect(deviceB.characters.map((c) => c.id), ['a']);
        expect(deviceB.deletedItems.single['id'], 'b');
      }, cloud.client);
    });

    test('conflito no envio: refaz o ciclo uma vez e junta o que chegou no meio', () async {
      final cloud = _FakeCloud(payload: _pkg(characters: [_ch('a', 'Ana', at: _t0)], changedAt: _t0), updatedAt: _t0);
      // No 2º GET (a conferência antes do envio), outro aparelho já enviou.
      cloud.beforeGet = (get) {
        if (get == 2) {
          cloud.payload = _pkg(characters: [_ch('a', 'Ana', at: _t0), _ch('o', 'Outro', at: _t0.add(const Duration(hours: 1)))], changedAt: _t0);
          cloud.updatedAt = _t0.add(const Duration(hours: 1));
        }
      };
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final device = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0))]);
        await device.addCharacter(name: 'Nova');
        expect(await device.syncNow(silent: true), 'Alterações enviadas');
        expect(cloud.uploads, 1);
        expect(device.characters.map((c) => c.name), containsAll(['Ana', 'Nova', 'Outro']));
        expect(_names(cloud.payload!), containsAll(['Ana', 'Nova', 'Outro']));
      }, cloud.client);
    });

    test('conflito duas vezes seguidas: para (sem enviar) e avisa a falha', () async {
      final cloud = _FakeCloud(payload: _pkg(characters: [_ch('a', 'Ana', at: _t0)], changedAt: _t0), updatedAt: _t0);
      cloud.beforeGet = (get) {
        if (get.isEven) cloud.updatedAt = cloud.updatedAt!.add(const Duration(hours: 1));
      };
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final device = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0))]);
        await device.addCharacter(name: 'Nova');
        expect(await device.syncNow(silent: true), 'Falha na sincronização');
        expect(cloud.uploads, 0);
        expect(cloud.gets, 4, reason: 'duas tentativas (download + conferência cada)');
      }, cloud.client);
    });

    test('clearAll não cria exclusões; criar uma ficha depois e sincronizar traz a nuvem E mantém a nova', () async {
      final cloud = _FakeCloud(payload: _pkg(characters: [_ch('a', 'Ana', at: _t0), _ch('b', 'Bia', at: _t0)], changedAt: _t0), updatedAt: _t0);
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0), _ch('b', 'Bia', at: _t0)])});
        final state = AppState();
        await state.load();
        await state.clearAll();
        expect(state.deletedItems, isEmpty);
        expect(state.cloudRestorePending, isTrue);
        await state.addCharacter(name: 'Nova');
        await state.syncNow(silent: true);
        expect(state.characters.map((c) => c.name), ['Nova', 'Ana', 'Bia']);
        expect(_names(cloud.payload!), ['Nova', 'Ana', 'Bia']);
        expect(state.cloudRestorePending, isFalse);
      }, cloud.client);
    });

    test('restaurar .rpg marca updatedAt e cria as exclusões dos ids removidos (e vale contra a nuvem)', () async {
      final cloud = _FakeCloud(payload: _pkg(characters: [_ch('a', 'Ana nuvem', at: DateTime.now().toUtc()), _ch('b', 'Bia', at: _t0)], changedAt: _t0), updatedAt: DateTime.now().toUtc());
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0), _ch('b', 'Bia', at: _t0)])});
        final state = AppState();
        await state.load();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final before = DateTime.now().toUtc();
        await state.restoreFromFileBackup({
          'characters': [_ch('a', 'Ana do arquivo', at: _t0)],
          'systems': [RpgSystem(id: 'generic', name: 'Sistema Padrão').toJson()],
          'campaigns': <Object>[],
        });
        expect(state.characters.single.name, 'Ana do arquivo');
        expect(DateTime.parse(state.characters.single.updatedAt!).isBefore(before), isFalse);
        expect(state.deletedItems.any((e) => e['kind'] == 'character' && e['id'] == 'b'), isTrue);
        // A próxima sincronização respeita a restauração.
        await state.syncNow(silent: true);
        expect(state.characters.map((c) => c.name), ['Ana do arquivo']);
        expect(_names(cloud.payload!), ['Ana do arquivo']);
      }, cloud.client);
      // O import de arquivo usa a restauração nova.
      expect(File('lib/services/rpg_file_service.dart').readAsStringSync(), contains('await state.restoreFromFileBackup(data);'));
    });

    test('restauração por partes (só os dados do jogo) também marca updatedAt e as exclusões', () async {
      SharedPreferences.setMockInitialValues({'auto_sync': false, 'characters': jsonEncode([_ch('a', 'Ana', at: _t0), _ch('b', 'Bia', at: _t0)])});
      final state = AppState();
      await state.load();
      await state.restoreBackupSections({'characters': [_ch('a', 'Ana', at: _t0)], 'systems': <Object>[], 'campaigns': <Object>[]}, restoreGameData: true, restoreRollData: false, restorePreferences: false);
      expect(state.characters.single.updatedAt, isNot(_iso(_t0)));
      expect(state.deletedItems.map((e) => e['id']), contains('b'));
    });

    test('sem backup na nuvem: envia o aparelho', () async {
      final cloud = _FakeCloud();
      await http.runWithClient(() async {
        SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false});
        final device = await _device(characters: [Character.fromJson(_ch('a', 'Ana', at: _t0))]);
        expect(await device.syncNow(silent: true), 'Enviado para a nuvem');
        expect(cloud.uploads, 1);
      }, cloud.client);
    });
  });

  // ------------------------------------------------------------------ C
  group('C: registro de sessão com limite', () {
    test('o 301º registro remove o mais antigo', () {
      final campaign = Campaign(id: 'm', name: 'Mesa');
      for (var i = 1; i <= 300; i++) {
        campaign.addSessionLog('evento $i');
      }
      expect(campaign.sessionLog, hasLength(300));
      campaign.addSessionLog('evento 301');
      expect(campaign.sessionLog, hasLength(300));
      expect(campaign.sessionLog.first, 'evento 2');
      expect(campaign.sessionLog.last, 'evento 301');
    });

    test('o load não corta registros', () async {
      SharedPreferences.setMockInitialValues({
        'auto_sync': false,
        'campaigns': jsonEncode([Campaign(id: 'm', name: 'Mesa', sessionLog: [for (var i = 0; i < 450; i++) 'e$i']).toJson()]),
      });
      final state = AppState();
      await state.load();
      expect(state.campaigns.single.sessionLog, hasLength(450));
    });

    test('a tela de campanhas usa o helper em todo lugar', () {
      final source = File('lib/screens/campaigns/campaigns_screen.dart').readAsStringSync();
      expect(source, isNot(contains('sessionLog.add(')));
      expect('addSessionLog('.allMatches(source).length, 13);
    });
  });

  // ------------------------------------------------------------------ D
  group('D: mensagens do cloud_service', () {
    test('"Sem permissão para alterar esta ficha." chega ao usuário por appErrorMessage', () async {
      final cloud = _FakeCloud();
      await http.runWithClient(() async {
        const session = CloudSession(accessToken: 't', refreshToken: '', userId: 'u1', email: '', isAnonymous: true);
        Object? error;
        try {
          await CloudService.updateSharedCharacterPatch(session, 'ABCD-1234', {'conditions': <String>[]});
        } catch (e) {
          error = e;
        }
        expect(error, isA<AppMessageException>());
        expect(appErrorMessage(error!), 'Sem permissão para alterar esta ficha.');
      }, cloud.client);
    });

    test('"Supabase ainda não configurado neste site." do signUp é AppMessageException', () {
      final source = File('lib/services/cloud_service.dart').readAsStringSync();
      final signUp = source.substring(source.indexOf('static Future<CloudSession?> signUp('), source.indexOf('static Future<CloudSession?> signUp(') + 200);
      expect(signUp, contains("throw AppMessageException('Supabase ainda não configurado neste site.')"));
      expect(appErrorMessage(const AppMessageException('Supabase ainda não configurado neste site.')), 'Supabase ainda não configurado neste site.');
      expect(source, isNot(contains("throw Exception('Sem permissão para alterar esta ficha.')")));
    });
  });
}
