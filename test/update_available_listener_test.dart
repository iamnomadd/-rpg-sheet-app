import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/widgets/update_available_listener.dart';

void main() {
  const local = '1.3.43+143';

  Future<void> pumpListener(
    WidgetTester tester, {
    required Future<String?> Function() fetch,
    Future<void> Function()? apply,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: UpdateAvailableListener(
        enabled: true,
        localVersion: local,
        fetchRemoteVersion: fetch,
        applyUpdate: apply ?? () async {},
        child: const Scaffold(body: Text('app')),
      ),
    ));
  }

  // Desmonta o widget para cancelar o timer periódico.
  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('versão remota mais nova mostra o aviso e Atualizar chama applyUpdate uma vez', (tester) async {
    var applied = 0;
    await pumpListener(tester, fetch: () async => '1.3.44+144', apply: () async => applied++);
    expect(find.text('Nova versão disponível'), findsNothing);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão disponível'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);

    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();
    expect(applied, 1);
    await unmount(tester);
  });

  testWidgets('mesma versão não mostra aviso', (tester) async {
    await pumpListener(tester, fetch: () async => local);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão disponível'), findsNothing);
    await unmount(tester);
  });

  testWidgets('versão mais antiga, null ou erro não mostram aviso', (tester) async {
    for (final fetch in <Future<String?> Function()>[
      () async => '1.3.42+142',
      () async => null,
      () async => throw Exception('offline'),
    ]) {
      await pumpListener(tester, fetch: fetch);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.text('Nova versão disponível'), findsNothing);
      await unmount(tester);
    }
  });

  testWidgets('a mesma versão remota não é avisada duas vezes na sessão', (tester) async {
    var fetches = 0;
    await pumpListener(tester, fetch: () async {
      fetches++;
      return '1.3.44+144';
    });
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão disponível'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão disponível'), findsNothing);

    await tester.pump(const Duration(minutes: 30));
    await tester.pumpAndSettle();
    expect(fetches, 2);
    expect(find.text('Nova versão disponível'), findsNothing);
    await unmount(tester);
  });

  testWidgets('uma versão ainda mais nova volta a avisar', (tester) async {
    final versions = ['1.3.44+144', '1.3.45+145'];
    var call = 0;
    await pumpListener(tester, fetch: () async => versions[call++ < 1 ? 0 : 1]);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(minutes: 30));
    await tester.pumpAndSettle();
    expect(find.text('Nova versão disponível'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('desativado não checa', (tester) async {
    var fetches = 0;
    await tester.pumpWidget(MaterialApp(
      home: UpdateAvailableListener(
        enabled: false,
        localVersion: local,
        fetchRemoteVersion: () async {
          fetches++;
          return '9.9.9+999';
        },
        child: const Scaffold(body: Text('app')),
      ),
    ));
    await tester.pump(const Duration(minutes: 31));
    expect(fetches, 0);
    expect(find.text('Nova versão disponível'), findsNothing);
  });
}
