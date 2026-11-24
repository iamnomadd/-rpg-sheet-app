import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/character_publish_queue.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';
import 'package:rpg_sheet_app/widgets/flush_on_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;
  late List<({Map<String, dynamic> snapshot, String code})> sent;

  Character shared(String id, {int life = 10, Map<String, String>? images}) => Character(
        id: id,
        name: 'Ficha $id',
        shareCode: 'CODE-$id',
        resourceValues: {'Vida': life},
        customSpriteImages: images ?? const {},
        customSpriteEnabled: images != null,
      );

  int lifeOf(Map<String, dynamic> snapshot) => (snapshot['resourceValues'] as Map)['Vida'] as int;

  setUp(() {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    state = AppState();
    sent = [];
    state.sharedCharacterPublisherOverride = (snapshot, code) async => sent.add((snapshot: snapshot, code: code));
  });

  Future<void> change(WidgetTester tester, String id, int life) async {
    final c = state.characters.firstWhere((c) => c.id == id)..resourceValues['Vida'] = life;
    await state.updateCharacter(c);
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('toques seguidos geram UMA publicação com o estado mais recente', (tester) async {
    state.characters.add(shared('a'));
    for (final life in [9, 8, 7, 6]) {
      await change(tester, 'a', life);
    }
    expect(sent, isEmpty, reason: 'nada sai antes da pausa');
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent.length, 1);
    expect(lifeOf(sent.single.snapshot), 6);
    expect(sent.single.code, 'CODE-a');
    await tester.pump(const Duration(seconds: 5));
    expect(sent.length, 1);
  });

  testWidgets('duas fichas não se misturam', (tester) async {
    state.characters.addAll([shared('a'), shared('b')]);
    await change(tester, 'a', 5);
    await change(tester, 'b', 3);
    await change(tester, 'a', 4);
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent.length, 2);
    final byCode = {for (final s in sent) s.code: lifeOf(s.snapshot)};
    expect(byCode, {'CODE-a': 4, 'CODE-b': 3});
    expect(sent.every((s) => s.snapshot['id'] == s.code.substring(5)), isTrue);
  });

  testWidgets('com publicação em andamento, a próxima sai depois com o estado mais novo', (tester) async {
    final gate = Completer<void>();
    state.sharedCharacterPublisherOverride = (snapshot, code) async {
      sent.add((snapshot: snapshot, code: code));
      if (sent.length == 1) await gate.future;
    };
    state.characters.add(shared('a'));
    await change(tester, 'a', 9);
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent.length, 1);
    await change(tester, 'a', 2);
    await change(tester, 'a', 1);
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent.length, 1, reason: 'espera a anterior terminar');
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(sent.length, 2);
    expect(lifeOf(sent.last.snapshot), 1);
  });

  testWidgets('ficha apagada ou descompartilhada antes da pausa não é publicada', (tester) async {
    state.characters.addAll([shared('a'), shared('b')]);
    await change(tester, 'a', 5);
    await change(tester, 'b', 5);
    state.characters.removeWhere((c) => c.id == 'a');
    state.characters.firstWhere((c) => c.id == 'b').shareCode = '';
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent, isEmpty);
  });

  testWidgets('snapshot acima do limite vai sem as imagens; a ficha local fica intacta', (tester) async {
    final big = 'data:image/png;base64,${'A' * (sharedSnapshotMaxBytes + 10)}';
    state.characters.add(shared('a', images: {'normal': big}));
    await change(tester, 'a', 3);
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent.single.snapshot.containsKey('customSpriteImages'), isFalse);
    expect(sent.single.snapshot['customSpriteEnabled'], isFalse);
    expect(lifeOf(sent.single.snapshot), 3);
    final local = state.characters.single;
    expect(local.customSpriteImages['normal'], big);
    expect(local.customSpriteEnabled, isTrue);
    expect(Character.fromJson(sent.single.snapshot).customSpriteImages, isEmpty);
  });

  testWidgets('abaixo do limite o snapshot vai completo', (tester) async {
    const small = 'data:image/png;base64,AAAA';
    state.characters.add(shared('a', images: {'normal': small}));
    await change(tester, 'a', 3);
    await tester.pump(CharacterPublishQueue.defaultDelay);
    expect(sent.single.snapshot['customSpriteImages'], {'normal': small});
    expect(sent.single.snapshot['customSpriteEnabled'], isTrue);
  });

  test('sharedSnapshotFor só corta acima do limite e devolve cópia', () {
    final json = shared('a', images: {'normal': 'data:image/png;base64,${'A' * 500}'}).toJson();
    expect(identical(sharedSnapshotFor(json, maxBytes: 100000), json), isTrue);
    final cut = sharedSnapshotFor(json, maxBytes: 300);
    expect(cut.containsKey('customSpriteImages'), isFalse);
    expect(cut['customSpriteEnabled'], isFalse);
    expect(json.containsKey('customSpriteImages'), isTrue);
    expect(json['customSpriteEnabled'], isTrue);
  });

  testWidgets('erro na publicação não derruba nada e não imprime o snapshot', (tester) async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      var calls = 0;
      state.sharedCharacterPublisherOverride = (snapshot, code) async {
        calls++;
        throw const CloudRequestException('conteúdo do servidor', statusCode: 500);
      };
      state.characters.add(shared('a'));
      await change(tester, 'a', 4);
      await tester.pump(CharacterPublishQueue.defaultDelay);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      expect(logs.single, 'Falha ao publicar a ficha compartilhada (CloudRequestException, status 500).');
      expect(logs.single, isNot(contains('Ficha a')));
      expect(logs.single, isNot(contains('CODE-a')));
      expect(state.characters.single.resourceValues['Vida'], 4);
      // A próxima alteração volta a tentar.
      await change(tester, 'a', 3);
      await tester.pump(CharacterPublishQueue.defaultDelay);
      expect(calls, 2);
    } finally {
      debugPrint = original;
    }
  });

  testWidgets('ficha sem código não agenda nada', (tester) async {
    state.characters.add(Character(id: 'x', name: 'X'));
    await state.updateCharacter(state.characters.single);
    await tester.pump(const Duration(seconds: 3));
    expect(sent, isEmpty);
  });

  group('flush ao ir para segundo plano', () {
    testWidgets('com pendência, publica na hora uma única vez com o estado mais recente', (tester) async {
      state.characters.add(shared('a'));
      await change(tester, 'a', 8);
      await change(tester, 'a', 5);
      expect(sent, isEmpty);
      await state.flushSharedCharacterPublications();
      expect(sent.length, 1);
      expect(lifeOf(sent.single.snapshot), 5);
      await tester.pump(const Duration(seconds: 5));
      expect(sent.length, 1, reason: 'o timer cancelado não publica de novo');
    });

    testWidgets('sem pendência, não publica', (tester) async {
      state.characters.add(shared('a'));
      await state.flushSharedCharacterPublications();
      expect(sent, isEmpty);
      await change(tester, 'a', 3);
      await tester.pump(CharacterPublishQueue.defaultDelay);
      expect(sent.length, 1);
      await state.flushSharedCharacterPublications();
      expect(sent.length, 1);
    });

    testWidgets('duas fichas pendentes publicam as duas', (tester) async {
      state.characters.addAll([shared('a'), shared('b')]);
      await change(tester, 'a', 7);
      await change(tester, 'b', 2);
      await state.flushSharedCharacterPublications();
      expect({for (final s in sent) s.code: lifeOf(s.snapshot)}, {'CODE-a': 7, 'CODE-b': 2});
      expect(sent.length, 2);
    });

    testWidgets('durante uma publicação em andamento não duplica e espera terminar', (tester) async {
      final gate = Completer<void>();
      state.sharedCharacterPublisherOverride = (snapshot, code) async {
        sent.add((snapshot: snapshot, code: code));
        if (sent.length == 1) await gate.future;
      };
      state.characters.add(shared('a'));
      await change(tester, 'a', 9);
      await tester.pump(CharacterPublishQueue.defaultDelay);
      expect(sent.length, 1);
      await change(tester, 'a', 4);
      var done = false;
      final flushing = state.flushSharedCharacterPublications().then((_) => done = true);
      await tester.pump();
      expect(sent.length, 1, reason: 'não envia em paralelo');
      expect(done, isFalse, reason: 'espera a que está em andamento');
      gate.complete();
      await flushing;
      expect(sent.length, 2);
      expect(lifeOf(sent.last.snapshot), 4);
      await tester.pump(const Duration(seconds: 5));
      expect(sent.length, 2);
    });

    for (final lifecycle in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      testWidgets('app ${lifecycle.name}: envia o pendente na hora', (tester) async {
        state.characters.add(shared('a'));
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const FlushOnBackground(child: SizedBox()),
        ));
        await change(tester, 'a', 6);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        expect(sent, isEmpty, reason: 'inactive (perder o foco) não envia');
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        if (lifecycle == AppLifecycleState.paused) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
        await tester.pump();
        expect(sent.length, 1);
        expect(lifeOf(sent.single.snapshot), 6);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(seconds: 5));
        expect(sent.length, 1, reason: 'sem duplicar');
      });
    }

    testWidgets('o observador sai junto com o widget', (tester) async {
      state.characters.add(shared('a'));
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const FlushOnBackground(child: SizedBox()),
      ));
      await tester.pumpWidget(const SizedBox());
      await change(tester, 'a', 6);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(sent, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(CharacterPublishQueue.defaultDelay);
      expect(sent.length, 1);
    });
  });
}
