import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/campaign.dart';
import 'package:rpg_sheet_app/screens/campaigns/campaigns_screen.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('"Atualizar <ficha>" não mostra campo de vida (Vida/PV) do jogador', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    state.campaigns.add(Campaign(
      id: 'c1',
      name: 'Mesa',
      linkedCharacters: [
        {
          'shareCode': 'ABC123',
          'status': 'approved',
          'snapshot': {
            'id': 'r1',
            'name': 'Bia',
            'resourceValues': {'PV': 8, 'Vida': 8, 'PM': 3},
            'resourceMaxValues': {'PV': 10, 'Vida': 10, 'PM': 5},
            'conditions': ['Caído'],
          },
        },
      ],
    ));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: MasterScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Jogadores')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bia'));
    await tester.pumpAndSettle();

    expect(find.text('Atualizar Bia'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextField, 'PM')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextField, 'PV')), findsNothing);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextField, 'Vida')), findsNothing);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextField, 'Condições')), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    // Encerra a tela para cancelar o timer de sincronização automática.
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('TURNO ATUAL mostra as condições da ficha do jogador unidas às da iniciativa', (tester) async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    state.campaigns.add(Campaign(
      id: 'c1',
      name: 'Mesa',
      linkedCharacters: [
        {
          'shareCode': 'ABC123',
          'status': 'approved',
          'snapshot': {'id': 'r1', 'name': 'Bia', 'conditions': ['Caído']},
        },
      ],
      initiative: [
        {'id': 'r1', 'name': 'Bia', 'type': 'player', 'value': 15, 'done': false, 'conditions': ['caído', 'Envenenado']},
      ],
    )..combatActive = true);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: MasterScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Sessão')));
    await tester.pumpAndSettle();

    expect(find.text('TURNO ATUAL'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Caído'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'caído'), findsNothing);
    expect(find.widgetWithText(Chip, 'Envenenado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
