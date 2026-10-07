import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/widgets/confirm_delete_dialog.dart';

void main() {
  Future<List<bool>> pumpOpener(WidgetTester tester) async {
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await confirmDelete(context, title: 'Excluir item?', message: '"Espada" será removido desta ficha.')),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('mostra título e mensagem', (tester) async {
    await pumpOpener(tester);
    expect(find.text('Excluir item?'), findsOneWidget);
    expect(find.text('"Espada" será removido desta ficha.'), findsOneWidget);
  });

  testWidgets('Cancelar retorna false', (tester) async {
    final results = await pumpOpener(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('Excluir retorna true', (tester) async {
    final results = await pumpOpener(tester);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('tocar fora retorna false', (tester) async {
    final results = await pumpOpener(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
