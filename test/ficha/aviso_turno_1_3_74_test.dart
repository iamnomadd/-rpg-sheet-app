// 1.3.74 — aviso de turno do jogador no padrão do app (+ 3 correções).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/screens/character/player_turn_banner.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

const _session = <String, Object>{
  'cloud_access_token': 'token-de-teste',
  'cloud_refresh_token': '',
  'cloud_user_id': 'u1',
  'cloud_email': 'ana@exemplo.test',
  'cloud_is_anonymous': false,
};

Map<String, dynamic> _sessionState({required bool myTurn, int round = 3}) => {
      'round': round,
      'active': true,
      'current_index': 0,
      'initiative': [
        {'id': myTurn ? 'p1' : 'outro', 'name': myTurn ? 'Ana' : 'Goblin'},
        {'id': myTurn ? 'outro' : 'p1', 'name': myTurn ? 'Goblin' : 'Ana'},
      ],
    };

class _FakeCloud {
  final calls = <String>[];
  List<String> campaigns = [];
  Map<String, Map<String, dynamic>> states = {};

  MockClient client() => MockClient((request) async {
        final path = request.url.path;
        calls.add(path);
        if (path.endsWith('/rest/v1/rpg_character_link_requests')) {
          return http.Response(jsonEncode([for (final c in campaigns) {'campaign_id': c, 'share_code': 'ABCD-EFGH'}]), 200, headers: _json);
        }
        if (path.endsWith('/rest/v1/rpg_campaign_session_state')) {
          final id = (request.url.queryParameters['campaign_id'] ?? '').replaceFirst('eq.', '');
          final state = states[id];
          return http.Response(jsonEncode(state == null ? [] : [state]), 200, headers: _json);
        }
        return http.Response(jsonEncode({'message': 'inesperado $path'}), 500, headers: _json);
      });
}

void main() {
  setUp(() => PlayerTurnBanner.debugDisableRealtime = true);
  tearDown(() => PlayerTurnBanner.debugDisableRealtime = false);

  group('regras puras', () {
    test('sem shareCode e sem campanhas: 60 s; com campanhas: 15 s / reconexão rápida; falhas: backoff de sempre', () {
      expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: false, hasShareCode: false, hasCampaigns: false), const Duration(seconds: 60));
      expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: true, hasShareCode: false, hasCampaigns: true), const Duration(seconds: 15));
      expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: false, hasShareCode: false, hasCampaigns: true), const Duration(milliseconds: 1200));
      expect(playerTurnRefreshDelay(failures: 0, realtimeConnected: false, hasShareCode: true, hasCampaigns: false), const Duration(seconds: 10));
      expect(playerTurnRefreshDelay(failures: 1, realtimeConnected: false, hasShareCode: false, hasCampaigns: false), const Duration(seconds: 4));
      expect(playerTurnRefreshDelay(failures: 2, realtimeConnected: true, hasShareCode: true, hasCampaigns: true), const Duration(seconds: 8));
      expect(playerTurnRefreshDelay(failures: 5, realtimeConnected: true, hasShareCode: true, hasCampaigns: true), const Duration(seconds: 12));
    });

    test('duas campanhas: "não é a vez" na A não apaga a vez na B', () {
      final tracker = PlayerTurnTracker()
        ..set('B', isTurn: true, round: 4)
        ..set('A', isTurn: false, round: 2);
      expect(tracker.isTurn, isTrue);
      expect(tracker.round, 4);
      tracker.set('A', isTurn: false, round: 3);
      expect(tracker.isTurn, isTrue);
      tracker.set('B', isTurn: false, round: 5);
      expect(tracker.isTurn, isFalse);
      tracker
        ..set('A', isTurn: true, round: 6)
        ..retain({'B'});
      expect(tracker.isTurn, isFalse, reason: 'campanha desvinculada sai do mapa');
    });
  });

  group('widget', () {
    late _FakeCloud cloud;
    late AppState state;

    Future<void> pumpBanner(WidgetTester tester, {String shareCode = '', bool reduceAnimations = false}) async {
      SharedPreferences.setMockInitialValues({..._session, 'auto_sync': false, 'reduce_animations': reduceAnimations});
      state = AppState();
      await state.load();
      final character = Character(id: 'p1', name: 'Ana', systemId: 'generic', shareCode: shareCode);
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildAppTheme('abyss', false),
          home: Scaffold(body: const SizedBox.expand(), bottomNavigationBar: PlayerTurnBanner(character: character)),
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('vez na campanha B (não na A): card da paleta com a arte, sem raio, e brilho rodando', (tester) async {
      cloud = _FakeCloud()
        ..campaigns = ['A', 'B']
        ..states = {'A': _sessionState(myTurn: false, round: 2), 'B': _sessionState(myTurn: true, round: 3)};
      await http.runWithClient(() async {
        await pumpBanner(tester);
        final card = find.byKey(const ValueKey('turn-card'));
        expect(card, findsOneWidget);
        expect(find.text('SEU TURNO'), findsOneWidget);
        expect(find.textContaining('Rodada 3'), findsOneWidget);
        expect(find.byIcon(Icons.flash_on_rounded), findsNothing);
        final p = AbyssPalette.of(tester.element(card));
        final widget = tester.widget<Card>(card);
        expect(widget.color, p.card);
        final shape = widget.shape! as AbyssFrameBorder;
        expect(shape.side.width, 2);
        expect(shape.side.color.a, greaterThan(0));
        final art = tester.widget<Image>(find.descendant(of: card, matching: find.byType(Image)));
        expect((art.image as AssetImage).assetName, 'assets/icons/sections/section_actions.webp');
        expect(find.byTooltip('Atualizar agora'), findsOneWidget);
        // Sem sombra pulsando no card inteiro.
        expect(find.descendant(of: find.byType(PlayerTurnBanner), matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).boxShadow != null)), findsNothing);
        // Brilho da borda rodando durante o turno.
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        final before = (tester.widget<Card>(card).shape! as AbyssFrameBorder).side.color;
        await tester.pump(const Duration(milliseconds: 1200));
        final after = (tester.widget<Card>(card).shape! as AbyssFrameBorder).side.color;
        expect(after, isNot(before), reason: 'só a borda muda');
        await finish(tester);
      }, cloud.client);
    });

    testWidgets('com "reduzir movimento": borda fixa e sem animação', (tester) async {
      cloud = _FakeCloud()
        ..campaigns = ['B']
        ..states = {'B': _sessionState(myTurn: true)};
      await http.runWithClient(() async {
        await pumpBanner(tester, reduceAnimations: true);
        final card = find.byKey(const ValueKey('turn-card'));
        expect(card, findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        final before = (tester.widget<Card>(card).shape! as AbyssFrameBorder).side.color;
        await tester.pump(const Duration(milliseconds: 1200));
        expect((tester.widget<Card>(card).shape! as AbyssFrameBorder).side.color, before);
        await finish(tester);
      }, cloud.client);
    });

    testWidgets('sem turno, a animação não roda', (tester) async {
      cloud = _FakeCloud()
        ..campaigns = ['A']
        ..states = {'A': _sessionState(myTurn: false)};
      await http.runWithClient(() async {
        await pumpBanner(tester);
        expect(find.byKey(const ValueKey('turn-card')), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        await finish(tester);
      }, cloud.client);
    });

    testWidgets('sem shareCode e sem campanhas: a próxima consulta é em 60 s', (tester) async {
      cloud = _FakeCloud();
      await http.runWithClient(() async {
        await pumpBanner(tester);
        int linkCalls() => cloud.calls.where((c) => c.endsWith('/rpg_character_link_requests')).length;
        expect(linkCalls(), 1);
        await tester.pump(const Duration(seconds: 58));
        expect(linkCalls(), 1, reason: 'antes: uma consulta a cada 1,2 s');
        await tester.pump(const Duration(seconds: 3));
        expect(linkCalls(), 2);
        await finish(tester);
      }, cloud.client);
    });

    testWidgets('alteração do Mestre e status de conexão usam a paleta', (tester) async {
      cloud = _FakeCloud();
      await http.runWithClient(() async {
        await pumpBanner(tester, shareCode: 'ABCD-EFGH');
        final p = AbyssPalette.of(tester.element(find.byType(PlayerTurnBanner)));
        final status = find.descendant(of: find.byType(PlayerTurnBanner), matching: find.byType(Text)).first;
        expect(tester.widget<Text>(status).style?.color, p.creamMuted);
        await finish(tester);
      }, cloud.client);
    });
  });
}
