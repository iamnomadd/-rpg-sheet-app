// 1.3.74 — "Esqueci minha senha".
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rpg_sheet_app/screens/auth/access_gate.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:rpg_sheet_app/services/password_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/source_reader.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

class _FakeAuth {
  final requests = <http.Request>[];
  int recoverStatus = 200;
  bool offline = false;
  bool userUnauthorized = false;

  MockClient client() => MockClient((request) async {
        if (offline) throw http.ClientException('sem rede');
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/auth/v1/recover')) {
          return http.Response(recoverStatus == 429 ? jsonEncode({'msg': 'email rate limit exceeded'}) : '{}', recoverStatus, headers: _json);
        }
        if (path.endsWith('/auth/v1/user') && request.method == 'GET') {
          if (userUnauthorized) return http.Response(jsonEncode({'msg': 'invalid JWT'}), 401, headers: _json);
          return http.Response(jsonEncode({'id': 'u1', 'email': 'ana@exemplo.test', 'is_anonymous': false}), 200, headers: _json);
        }
        if (path.endsWith('/auth/v1/user') && request.method == 'PUT') {
          return http.Response(jsonEncode({'id': 'u1', 'email': 'ana@exemplo.test'}), 200, headers: _json);
        }
        if (path.endsWith('/rest/v1/rpc/has_rpg_app_access')) return http.Response('true', 200, headers: _json);
        return http.Response(jsonEncode({'message': 'inesperado $path'}), 500, headers: _json);
      });

  List<String> get calls => [for (final r in requests) '${r.method} ${r.url.path}'];
}

final _recoveryLink = Uri.parse('${CloudService.authCallbackUrl}#access_token=token-recuperacao&refresh_token=r1&type=recovery&expires_in=3600');

void main() {
  late _FakeAuth cloud;

  setUp(() {
    cloud = _FakeAuth();
    SharedPreferences.setMockInitialValues({});
    PasswordRecovery.events.value = null;
  });

  Future<void> pumpFor(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AccessGate(child: Scaffold(body: Text('APP LIBERADO')))));
    await pumpFor(tester);
  }

  Future<void> askReset(WidgetTester tester, String email) async {
    await tester.tap(find.text('Esqueci minha senha'));
    await pumpFor(tester);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), email);
    await tester.tap(find.text('Enviar link'));
    await pumpFor(tester);
  }

  testWidgets('"Esqueci minha senha" fica abaixo do botão Entrar e chama /recover com redirect_to da origem', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      expect(tester.getTopLeft(find.text('Esqueci minha senha')).dy, greaterThan(tester.getTopLeft(find.widgetWithText(FilledButton, 'Entrar')).dy));
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'ana@exemplo.test');
      await tester.tap(find.text('Esqueci minha senha'));
      await pumpFor(tester);
      // Reaproveita o e-mail já preenchido.
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('ana@exemplo.test')), findsOneWidget);
      await tester.tap(find.text('Enviar link'));
      await pumpFor(tester);
      final recover = cloud.requests.single;
      expect(recover.method, 'POST');
      expect(recover.url.path, '/auth/v1/recover');
      expect(recover.url.queryParameters['redirect_to'], CloudService.authCallbackUrl);
      expect(jsonDecode(recover.body), {'email': 'ana@exemplo.test'});
      expect(find.text(passwordRecoverySentMessage), findsOneWidget);
    }, cloud.client);
  });

  test('o redirect_to usa a origem do site no Web, sem domínio fixo', () {
    final source = File('lib/services/cloud_service.dart').readAsStringSync();
    expect(source, contains("static String get authCallbackUrl => kIsWeb ? Uri.base.origin : 'rpgsheet://auth-callback';"));
    expect(source, contains('/auth/v1/recover?redirect_to=\${Uri.encodeComponent(authCallbackUrl)}'));
  });

  testWidgets('a mensagem é a mesma com conta existente ou não', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      await askReset(tester, 'existe@exemplo.test');
      expect(find.text(passwordRecoverySentMessage), findsOneWidget);
      await askReset(tester, 'nao-existe@exemplo.test');
      expect(find.text(passwordRecoverySentMessage), findsOneWidget);
      expect(cloud.calls, ['POST /auth/v1/recover', 'POST /auth/v1/recover']);
    }, cloud.client);
  });

  testWidgets('429 e sem conexão têm mensagens claras', (tester) async {
    cloud.recoverStatus = 429;
    await http.runWithClient(() async {
      await pumpGate(tester);
      await askReset(tester, 'ana@exemplo.test');
      expect(find.text('Muitos pedidos seguidos. Espere alguns minutos e tente de novo.'), findsOneWidget);
      expect(find.text(passwordRecoverySentMessage), findsNothing);
      cloud.offline = true;
      await askReset(tester, 'ana@exemplo.test');
      expect(find.text('Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.'), findsOneWidget);
    }, cloud.client);
  });

  testWidgets('o link com type=recovery abre "Criar nova senha"; recusa senhas curtas ou diferentes; salvar chama PUT /user e libera', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      expect(await PasswordRecovery.isRecoveryLink(_recoveryLink), isTrue);
      await PasswordRecovery.handleLink(_recoveryLink);
      await pumpFor(tester);
      expect(find.text('Criar nova senha'), findsOneWidget);
      // A sessão do link foi salva como os outros links.
      expect((await CloudService.loadSession())?.accessToken, 'token-recuperacao');

      await tester.enterText(find.widgetWithText(TextField, 'Senha nova'), '123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmar senha'), '123');
      await tester.tap(find.text('Salvar senha'));
      await tester.pump();
      expect(find.text('Use uma senha com pelo menos 6 caracteres.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Senha nova'), 'senha-nova-1');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmar senha'), 'senha-nova-2');
      await tester.tap(find.text('Salvar senha'));
      await tester.pump();
      expect(find.text('As senhas não são iguais.'), findsOneWidget);
      expect(cloud.calls, isNot(contains('PUT /auth/v1/user')));

      await tester.enterText(find.widgetWithText(TextField, 'Confirmar senha'), 'senha-nova-1');
      await tester.tap(find.text('Salvar senha'));
      await pumpFor(tester);
      final put = cloud.requests.firstWhere((r) => r.method == 'PUT' && r.url.path == '/auth/v1/user');
      expect(jsonDecode(put.body), {'password': 'senha-nova-1'});
      expect(put.headers['Authorization'], 'Bearer token-recuperacao');
      expect(cloud.calls.last, 'POST /rest/v1/rpc/has_rpg_app_access');
      expect(find.text('APP LIBERADO'), findsOneWidget);
      expect(find.text(passwordChangedMessage), findsOneWidget);
    }, cloud.client);
  });

  testWidgets('link com erro mostra a mensagem de expirado e volta para a entrada', (tester) async {
    await http.runWithClient(() async {
      await pumpGate(tester);
      await askReset(tester, 'ana@exemplo.test');
      final expired = Uri.parse('${CloudService.authCallbackUrl}#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired');
      expect(await PasswordRecovery.isRecoveryLink(expired), isTrue, reason: 'este aparelho pediu a recuperação');
      await PasswordRecovery.handleLink(expired);
      await pumpFor(tester);
      expect(find.text(passwordRecoveryExpiredMessage), findsOneWidget);
      expect(find.text('Criar nova senha'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    }, cloud.client);
  });

  test('confirmação de e-mail (sem type=recovery) continua no fluxo antigo', () async {
    final confirmation = Uri.parse('${CloudService.authCallbackUrl}#access_token=t&refresh_token=r&type=signup');
    expect(await PasswordRecovery.isRecoveryLink(confirmation), isFalse);
    // Erro sem pedido de recuperação neste aparelho: segue como antes.
    final error = Uri.parse('${CloudService.authCallbackUrl}#error=access_denied&error_description=expired');
    expect(await PasswordRecovery.isRecoveryLink(error), isFalse);
    // As mensagens antigas da confirmação continuam no app.dart.
    final app = readWithParts('lib/app/app.dart');
    expect(app, contains("'Confirmação recebida. Atualizando sua conta...'"));
    expect(app, contains("'E-mail confirmado. Sua nuvem está protegida.'"));
    expect(app.indexOf('PasswordRecovery.isRecoveryLink(uri)'), lessThan(app.indexOf('CloudService.handleAuthCallback(uri)')));
  });
}
