import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/screens/character/resource_quick_adjust.dart';

void main() {
  group('resourceActionLabels', () {
    test('Vida e PV usam Receber dano / Curar', () {
      for (final name in ['Vida', 'vida', ' VIDA ', 'PV']) {
        final labels = resourceActionLabels(name);
        expect(labels.decrease, 'Receber dano', reason: name);
        expect(labels.increase, 'Curar', reason: name);
        expect(labels.decreaseIcon, Icons.heart_broken_outlined, reason: name);
        expect(labels.increaseIcon, Icons.favorite_outline, reason: name);
      }
    });

    test('Energia usa Gastar energia / Recuperar energia', () {
      final labels = resourceActionLabels('Energia');
      expect(labels.decrease, 'Gastar energia');
      expect(labels.increase, 'Recuperar energia');
      expect(labels.decreaseIcon, Icons.bolt_outlined);
      expect(labels.increaseIcon, Icons.bolt);
    });

    test('Mana usa Gastar mana / Recuperar mana', () {
      final labels = resourceActionLabels('Mana');
      expect(labels.decrease, 'Gastar mana');
      expect(labels.increase, 'Recuperar mana');
      expect(labels.decreaseIcon, Icons.remove_circle_outline);
      expect(labels.increaseIcon, Icons.add_circle_outline);
    });

    test('outros recursos usam o nome em minúsculas', () {
      final labels = resourceActionLabels('Pontos de Fé');
      expect(labels.decrease, 'Gastar pontos de fé');
      expect(labels.increase, 'Recuperar pontos de fé');
    });

    test('nome vazio não quebra', () {
      final labels = resourceActionLabels('');
      expect(labels.decrease, 'Gastar');
      expect(labels.increase, 'Recuperar');
    });
  });

  group('showResourceQuickAdjust', () {
    Future<List<int?>> pumpOpener(WidgetTester tester, String name) async {
      final results = <int?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await showResourceQuickAdjust(context, name: name, current: 10, max: 20)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      return results;
    }

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra nome e valores e aplica dano e cura com sinal', (tester) async {
      final results = await pumpOpener(tester, 'Vida');

      await open(tester);
      expect(find.text('Vida'), findsOneWidget);
      expect(find.text('10 / 20'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Receber dano'));
      await tester.pumpAndSettle();
      expect(results.last, -5);
      expect(find.byType(TextField), findsNothing);

      await open(tester);
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Curar'));
      await tester.pumpAndSettle();
      expect(results.last, 5);
    });

    testWidgets('campo vazio ou 0 mostra aviso e não fecha', (tester) async {
      final results = await pumpOpener(tester, 'Vida');
      await open(tester);

      await tester.tap(find.text('Curar'));
      await tester.pump();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Receber dano'));
      await tester.pump();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('fechar sem aplicar retorna null', (tester) async {
      final results = await pumpOpener(tester, 'Vida');
      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('Energia mostra Gastar energia / Recuperar energia', (tester) async {
      final results = await pumpOpener(tester, 'Energia');
      await open(tester);
      expect(find.text('Gastar energia'), findsOneWidget);
      expect(find.text('Recuperar energia'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('Gastar energia'));
      await tester.pumpAndSettle();
      expect(results.last, -3);
    });
  });
}
