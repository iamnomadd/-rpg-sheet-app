import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/systems/system_editor_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    state = AppState();
    await state.load();
  });

  Future<void> openEditor(WidgetTester tester, RpgSystem system) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SystemEditorScreen(system: system))),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder rowOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(ListTile)).first;

  // Renomear pela interface não entra neste teste: o diálogo de texto do editor
  // (_askText) descarta o controller antes da animação de fechar terminar, o
  // que gera um assert em modo debug (bug anterior a este PR). A renomeação dos
  // vínculos está coberta pelos testes de renameAttributeInLinks/renameSkillInLinks.
  testWidgets('escolher e excluir o atributo de uma perícia', (tester) async {
    final system = RpgSystem(id: 'custom', name: 'Meu sistema', attributes: ['Força', 'Destreza'], skills: ['Furtividade']);
    await state.addSystem(system);
    await openEditor(tester, system);

    expect(find.text('Sem atributo'), findsOneWidget);

    // Escolher Destreza para Furtividade.
    await tester.tap(find.text('Furtividade'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Destreza')));
    await tester.pumpAndSettle();
    expect(find.text('Atributo: Destreza'), findsOneWidget);

    // Excluir o atributo volta para "Sem atributo".
    await tester.tap(find.descendant(of: rowOf('Destreza'), matching: find.byTooltip('Excluir')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Sem atributo'), findsOneWidget);
  });

  testWidgets('escolher Sem atributo remove o vínculo e salvar grava no sistema', (tester) async {
    final system = RpgSystem(
      id: 'custom',
      name: 'Meu sistema',
      attributes: ['Força', 'Destreza'],
      skills: ['Furtividade', 'Atletismo'],
      skillAttributes: {'Furtividade': 'Destreza', 'Atletismo': 'Força'},
    );
    await state.addSystem(system);
    await openEditor(tester, system);
    expect(find.text('Atributo: Destreza'), findsOneWidget);

    await tester.tap(find.text('Furtividade'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Sem atributo')));
    await tester.pumpAndSettle();
    expect(find.text('Atributo: Destreza'), findsNothing);

    await tester.tap(find.text('Salvar sistema'));
    await tester.pumpAndSettle();
    final saved = state.systems.firstWhere((s) => s.id == 'custom');
    expect(saved.skillAttributes, {'Atletismo': 'Força'});
  });

  testWidgets('sistema sem atributos não mostra subtítulo e avisa ao tocar', (tester) async {
    final system = RpgSystem(id: 'custom', name: 'Meu sistema', attributes: [], skills: ['Furtividade']);
    await state.addSystem(system);
    await openEditor(tester, system);

    expect(find.text('Sem atributo'), findsNothing);
    await tester.tap(find.text('Furtividade'));
    await tester.pump();
    expect(find.text('Adicione atributos ao sistema para vincular perícias.'), findsOneWidget);
    expect(find.byType(SimpleDialog), findsNothing);
  });

  testWidgets('outras seções continuam sem subtítulo', (tester) async {
    final system = RpgSystem(id: 'custom', name: 'Meu sistema', attributes: ['Força'], skills: [], resources: ['Vida'], sections: ['Notas']);
    await state.addSystem(system);
    await openEditor(tester, system);
    for (final text in ['Força', 'Vida', 'Notas']) {
      final tile = tester.widget<ListTile>(rowOf(text));
      expect(tile.subtitle, isNull, reason: text);
      expect(tile.onTap, isNull, reason: text);
    }
  });
}
