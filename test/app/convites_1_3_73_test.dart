// 1.3.73 — "Gerenciar convites" de volta (só administrador), limpeza das
// contas anônimas com acesso 'open' e arte da condição no card 2D.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/character_screen.dart';
import 'package:rpg_sheet_app/screens/settings/settings_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

const _session = <String, Object>{
  'cloud_access_token': 'token-de-teste',
  'cloud_refresh_token': '',
  'cloud_user_id': 'u1',
  'cloud_email': 'admin@exemplo.test',
  'cloud_is_anonymous': false,
};

void main() {
  group('A: "Gerenciar convites" só para o administrador', () {
    Future<List<String>> pumpSettings(WidgetTester tester, {required bool withSession, bool admin = false}) async {
      final calls = <String>[];
      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false, if (withSession) ..._session});
      final client = MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('/rest/v1/rpc/is_rpg_app_admin')) return http.Response(jsonEncode(admin), 200, headers: _json);
        return http.Response(jsonEncode({'message': 'inesperado'}), 500, headers: _json);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: AppState(),
          child: const MaterialApp(home: SettingsScreen()),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }, () => client);
      return calls;
    }

    testWidgets('aparece com isAppAdmin true, antes de "Manutenção"', (tester) async {
      final calls = await pumpSettings(tester, withSession: true, admin: true);
      expect(calls, contains('/rest/v1/rpc/is_rpg_app_admin'));
      expect(find.text('Administração'), findsOneWidget);
      final tile = find.widgetWithText(ListTile, 'Gerenciar convites');
      expect(tile, findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Crie, copie e revogue códigos de acesso ao Grimório.')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.confirmation_number_outlined)), findsOneWidget);
      expect(tester.getTopLeft(tile).dy, lessThan(tester.getTopLeft(find.text('Manutenção')).dy));
    });

    testWidgets('não aparece com isAppAdmin false', (tester) async {
      await pumpSettings(tester, withSession: true, admin: false);
      expect(find.text('Administração'), findsNothing);
      expect(find.text('Gerenciar convites'), findsNothing);
    });

    testWidgets('não aparece sem sessão (e nem consulta a nuvem)', (tester) async {
      final calls = await pumpSettings(tester, withSession: false);
      expect(calls, isEmpty);
      expect(find.text('Gerenciar convites'), findsNothing);
    });
  });

  group('B: limpeza das contas anônimas com acesso open', () {
    File find(String suffix) {
      final files = Directory('supabase/migrations').listSync().whereType<File>().where((f) => f.path.endsWith(suffix)).toList();
      expect(files, hasLength(1), reason: suffix);
      return files.single;
    }

    String body(String sql) => sql.substring(sql.indexOf('create or replace function'));

    test('mesma função, mesmas permissões; só a regra do acesso open muda', () {
      final v169 = body(find('_cleanup_empty_anonymous_users_v169.sql').readAsStringSync());
      final v173sql = find('_cleanup_open_access_v173.sql').readAsStringSync();
      final v173 = body(v173sql);
      expect(v173, contains("create or replace function public.cleanup_empty_anonymous_users(p_min_age interval default interval '30 days')"));
      expect(v173, contains('security definer'));
      expect(v173, contains('set search_path = public, pg_temp'));
      expect(v173, contains('u.is_anonymous = true'));
      expect(v173, contains('revoke execute on function public.cleanup_empty_anonymous_users(interval) from public, anon, authenticated;'));
      expect(v173, contains("and not exists (select 1 from public.rpg_app_access a where a.user_id = u.id and a.source <> 'open')"));
      expect(v173, isNot(contains('where a.user_id = u.id)\n')));
      // Sem comentários, o resto é idêntico ao da 1.3.69.
      String code(String sql) => sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');
      final expected = code(v169).replaceFirst(
        'and not exists (select 1 from public.rpg_app_access a where a.user_id = u.id)',
        "and not exists (select 1 from public.rpg_app_access a where a.user_id = u.id and a.source <> 'open')",
      );
      expect(code(v173), expected);
      expect(v173sql.toLowerCase(), isNot(contains('claim_rpg_open_access()')));
      expect(v173sql.toLowerCase(), isNot(contains('cron.schedule')));
    });
  });

  group('C: arte da condição no card do personagem 2D', () {
    testWidgets('no card 2D a arte tem 16 px e o card mantém 220; no card de condições continua 22 px', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      final state = AppState();
      state.systems.insert(0, RpgSystem(id: 'sys', name: 'Sistema', resources: ['Vida']));
      state.characters.add(Character(
        id: 'p1',
        name: 'Ana',
        systemId: 'sys',
        resourceValues: {'Vida': 10},
        resourceMaxValues: {'Vida': 10},
        conditions: ['Envenenado', 'Protegido'],
      ));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: CharacterScreen(characterId: 'p1')),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      final card2d = find.ancestor(of: find.text('Estado do personagem'), matching: find.byType(Card)).first;
      expect(find.descendant(of: card2d, matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 220)), findsOneWidget);
      for (final name in ['Envenenado', 'Protegido']) {
        final art = find.descendant(of: card2d, matching: find.byKey(ValueKey('condition-art-$name')));
        expect(art, findsOneWidget, reason: name);
        final size = tester.getSize(art);
        expect(size.width, lessThanOrEqualTo(16), reason: name);
        expect(size.height, lessThanOrEqualTo(16), reason: name);
        // A arte não passa do avatar: fica à esquerda do texto da pílula.
        final chip = find.ancestor(of: art, matching: find.byType(Chip)).first;
        final label = find.descendant(of: chip, matching: find.text(name));
        expect(tester.getRect(art).right, lessThanOrEqualTo(tester.getRect(label).left), reason: name);
      }
      final conditionsCard = find.byKey(const ValueKey('general-conditions'));
      expect(tester.getSize(find.descendant(of: conditionsCard, matching: find.byKey(const ValueKey('condition-art-Envenenado')))), const Size(22, 22));
      // 220 de altura também nos outros estados (crítico e incapacitado).
      for (final life in [2, 0]) {
        final c = state.characters.single;
        c.resourceValues['Vida'] = life;
        await state.updateCharacter(c);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.descendant(of: card2d, matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 220)), findsOneWidget, reason: 'vida $life');
        expect(tester.getSize(find.descendant(of: card2d, matching: find.byKey(const ValueKey('condition-art-Envenenado')))).height, lessThanOrEqualTo(16));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
