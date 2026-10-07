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
    final currentField = find.widgetWithText(TextField, 'Valor atual');
    final maxField = find.widgetWithText(TextField, 'Valor máximo');
    final amountField = find.widgetWithText(TextField, 'Quantidade');

    Future<List<ResourceValues?>> open(WidgetTester tester, {String name = 'Vida', int current = 10, int max = 20}) async {
      final results = <ResourceValues?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await showResourceQuickAdjust(context, name: name, current: current, max: max)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return results;
    }

    String fieldText(WidgetTester tester, Finder field) => tester.widget<TextField>(field).controller!.text;

    testWidgets('abre com nome, atual e máximo preenchidos', (tester) async {
      await open(tester);
      expect(find.text('Vida'), findsOneWidget);
      expect(fieldText(tester, currentField), '10');
      expect(fieldText(tester, maxField), '20');
      expect(find.text('Salvar valores'), findsOneWidget);
      expect(find.text('Receber dano'), findsOneWidget);
      expect(find.text('Curar'), findsOneWidget);
    });

    testWidgets('Salvar valores devolve atual e máximo editados', (tester) async {
      final results = await open(tester);
      await tester.enterText(currentField, '7');
      await tester.enterText(maxField, '30');
      await tester.tap(find.text('Salvar valores'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 7, max: 30)]);
    });

    testWidgets('máximo menor que o atual limita o atual', (tester) async {
      final results = await open(tester);
      await tester.enterText(maxField, '5');
      await tester.tap(find.text('Salvar valores'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 5, max: 5)]);
    });

    testWidgets('valor vazio mostra erro e não fecha', (tester) async {
      final results = await open(tester);
      await tester.enterText(currentField, '');
      await tester.tap(find.text('Salvar valores'));
      await tester.pump();
      expect(find.text('Informe um número válido.'), findsOneWidget);
      expect(find.text('Salvar valores'), findsOneWidget);

      await tester.enterText(currentField, '4');
      await tester.enterText(maxField, '');
      await tester.tap(find.text('Receber dano'));
      await tester.pump();
      expect(find.text('Informe um número válido.'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('dano aplica sobre o atual digitado, com clamp em 0', (tester) async {
      var results = await open(tester);
      await tester.enterText(amountField, '4');
      await tester.tap(find.text('Receber dano'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 6, max: 20)]);

      results = await open(tester);
      await tester.enterText(currentField, '3');
      await tester.enterText(amountField, '5');
      await tester.tap(find.text('Receber dano'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 0, max: 20)]);
    });

    testWidgets('cura aplica sobre os valores digitados, com clamp no máximo', (tester) async {
      var results = await open(tester, current: 18);
      await tester.enterText(amountField, '5');
      await tester.tap(find.text('Curar'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 20, max: 20)]);

      results = await open(tester, current: 18);
      await tester.enterText(maxField, '25');
      await tester.enterText(amountField, '5');
      await tester.tap(find.text('Curar'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 23, max: 25)]);
    });

    testWidgets('quantidade vazia ou 0 mostra erro e não fecha', (tester) async {
      final results = await open(tester);
      await tester.tap(find.text('Curar'));
      await tester.pump();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);

      await tester.enterText(amountField, '0');
      await tester.tap(find.text('Receber dano'));
      await tester.pump();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('máximo 0 abre normalmente e permite definir o máximo', (tester) async {
      final results = await open(tester, name: 'Mana', current: 0, max: 0);
      expect(fieldText(tester, maxField), '0');
      await tester.enterText(maxField, '12');
      await tester.enterText(currentField, '12');
      await tester.tap(find.text('Salvar valores'));
      await tester.pumpAndSettle();
      expect(results, [const ResourceValues(current: 12, max: 12)]);
    });

    testWidgets('fechar sem salvar devolve null', (tester) async {
      final results = await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('rótulos da folha seguem o recurso', (tester) async {
      await open(tester, name: 'Energia');
      expect(find.text('Gastar energia'), findsOneWidget);
      expect(find.text('Recuperar energia'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await open(tester, name: 'Mana');
      expect(find.text('Gastar mana'), findsOneWidget);
      expect(find.text('Recuperar mana'), findsOneWidget);
    });
  });

  testWidgets('tocar na barra (ResourceBarTapTarget) abre a folha preenchida', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ResourceBarTapTarget(
            label: 'Vida',
            onTap: () => showResourceQuickAdjust(context, name: 'Vida', current: 8, max: 15),
            child: const SizedBox(height: 14, width: 200),
          ),
        ),
      ),
    ));
    expect(find.bySemanticsLabel('Ajustar Vida'), findsOneWidget);
    await tester.tap(find.byType(ResourceBarTapTarget));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Valor atual')).controller!.text, '8');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Valor máximo')).controller!.text, '15');
  });
}
