// 1.3.72 — "Criar conta" sem código (tela de entrada).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_sheet_app/screens/auth/access_gate.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

class _FakeAuth {
  final calls = <String>[];
  bool emailTaken = false;
  bool offline = false;

  MockClient client() => MockClient((request) async {
        if (offline) throw http.ClientException('sem rede');
        final path = request.url.path;
        calls.add('${request.method} $path');
        if (path.endsWith('/auth/v1/signup')) {
          return http.Response(jsonEncode({
            'access_token': 'token-anonimo',
            'refresh_token': '',
            'user': {'id': 'u1', 'is_anonymous': true},
          }), 200, headers: _json);
        }
        if (path.endsWith('/rest/v1/rpc/claim_rpg_open_access')) return http.Response('true', 200, headers: _json);
        if (path.endsWith('/auth/v1/user') && request.method == 'PUT') {
          if (emailTaken) {
            return http.Response(jsonEncode({'code': 422, 'error_code': 'email_exists', 'msg': 'A user with this email address has already been registered'}), 422, headers: _json);
          }
          final body = jsonDecode(request.body) as Map;
          return http.Response(jsonEncode({'id': 'u1', 'email': body['email'], 'is_anonymous': false}), 200, headers: _json);
        }
        if (path.endsWith('/rest/v1/rpc/has_rpg_app_access')) return http.Response('true', 200, headers: _json);
        return http.Response(jsonEncode({'message': 'inesperado $path'}), 500, headers: _json);
      });
}

void main() {
  late _FakeAuth cloud;

  setUp(() {
    cloud = _FakeAuth();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpFor(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AccessGate(child: Text('APP LIBERADO'))));
    await pumpFor(tester);
  }

  Future<void> openCreate(WidgetTester tester) async {
    await tester.tap(find.text('Criar conta').first);
    await tester.pump();
  }

  Finder createButton() => find.widgetWithText(FilledButton, 'Criar conta');

  testWidgets('"Entrar" continua igual e é a aba inicial', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      expect(find.text('Entre para acessar suas fichas.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
      expect(find.text('Tenho convite'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
    }, cloud.client);
  });

  testWidgets('a aba "Criar conta" só tem e-mail e senha, sem código', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      await openCreate(tester);
      expect(find.text('Crie sua conta para guardar suas fichas.'), findsOneWidget);
      expect(find.text('Código do convite'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Senha'), findsOneWidget);
    }, cloud.client);
  });

  testWidgets('valida e-mail e senha antes de chamar a nuvem', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      await openCreate(tester);
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'sem-arroba');
      await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123456');
      await tester.tap(createButton());
      await tester.pump();
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'ana@exemplo.test');
      await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123');
      await tester.tap(createButton());
      await tester.pump();
      expect(find.text('Use uma senha com pelo menos 6 caracteres.'), findsOneWidget);
      expect(cloud.calls, isEmpty);
    }, cloud.client);
  });

  testWidgets('cria a conta: sessão → claim_rpg_open_access → e-mail/senha → acesso → libera', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      await openCreate(tester);
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'ana@exemplo.test');
      await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123456');
      await tester.tap(createButton());
      await pumpFor(tester);
      expect(cloud.calls.where((c) => !c.contains('/token')).toList(), [
        'POST /auth/v1/signup',
        'POST /rest/v1/rpc/claim_rpg_open_access',
        'PUT /auth/v1/user',
        'POST /rest/v1/rpc/has_rpg_app_access',
      ]);
      expect(cloud.calls, isNot(contains('POST /rest/v1/rpc/redeem_rpg_invite')));
      expect(find.text('APP LIBERADO'), findsOneWidget);
      final session = await CloudService.loadSession();
      expect(session?.isAnonymous, isFalse);
      expect(session?.email, 'ana@exemplo.test');
    }, cloud.client);
  });

  testWidgets('e-mail já usado e sem conexão mostram mensagens claras', (tester) async {
    cloud.emailTaken = true;
    await http.runWithClient(() async {
      await pumpGate(tester);
      await openCreate(tester);
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'ana@exemplo.test');
      await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123456');
      await tester.tap(createButton());
      await pumpFor(tester);
      expect(find.text('Este e-mail já está em uso. Use a aba Entrar.'), findsOneWidget);
      expect(find.text('APP LIBERADO'), findsNothing);
      cloud.offline = true;
      await tester.tap(createButton());
      await pumpFor(tester);
      expect(find.text('Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.'), findsOneWidget);
    }, cloud.client);
  });

  test('createAccountErrorMessage: função ainda não aplicada (404)', () {
    expect(createAccountErrorMessage(const CloudRequestException('Could not find the function', statusCode: 404)),
        'A criação de conta ainda não está disponível. Tente novamente mais tarde.');
  });

  test('a migração nova cria só claim_rpg_open_access, com as permissões pedidas', () {
    final files = Directory('supabase/migrations').listSync().whereType<File>().where((f) => f.path.endsWith('_open_access_v172.sql')).toList();
    expect(files, hasLength(1));
    final sql = files.single.readAsStringSync();
    expect(sql, contains('create or replace function public.claim_rpg_open_access() returns boolean'));
    expect(sql, contains('security definer set search_path=public,pg_temp'));
    expect(sql, contains("if auth.uid() is null then raise exception"));
    expect(sql, contains("values(auth.uid(),'open') on conflict(user_id) do nothing"));
    expect(sql, contains('revoke all on function public.claim_rpg_open_access() from public,anon;'));
    expect(sql, contains('grant execute on function public.claim_rpg_open_access() to authenticated;'));
    final code = sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n').toLowerCase();
    for (final other in ['rpg_invites', 'redeem_rpg_invite', 'has_rpg_app_access', 'drop ', 'alter ']) {
      expect(code, isNot(contains(other)), reason: other);
    }
  });
}
