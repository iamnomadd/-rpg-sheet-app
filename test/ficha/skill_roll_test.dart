import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/models/character.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/screens/character/skill_roll.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final system = RpgSystem(
    id: 'dnd5e',
    name: 'D&D 5e',
    attributes: ['Força', 'Destreza'],
    skills: ['Atletismo', 'Furtividade', 'Medicina', 'Arcanismo'],
    skillAttributes: {'Atletismo': 'Força', 'Furtividade': 'Destreza', 'Arcanismo': 'Inteligência'},
  );
  final character = Character(id: 'c1', name: 'Ana', attributes: {'Força': 3, 'Destreza': -1});

  group('resolveSkillRoll', () {
    test('perícia vinculada devolve o atributo', () {
      expect(resolveSkillRoll(system, character, 'Atletismo'), 'Força');
      expect(resolveSkillRoll(system, character, 'Furtividade'), 'Destreza');
    });

    test('perícia sem vínculo devolve null', () {
      expect(resolveSkillRoll(system, character, 'Medicina'), isNull);
    });

    test('vínculo para atributo que não existe no sistema devolve null', () {
      expect(resolveSkillRoll(system, character, 'Arcanismo'), isNull);
    });
  });

  group('skillRollDetail', () {
    test('com atributo', () {
      expect(
        skillRollDetail(attribute: 'Destreza', attributeValue: 3, rolls: [14], mode: 'normal', total: 17),
        'd20 (14) + Destreza (3) = 17',
      );
    });

    test('sem atributo', () {
      expect(skillRollDetail(attribute: null, attributeValue: 0, rolls: [9], mode: 'normal', total: 9), 'd20 (9) = 9');
    });

    test('vantagem e desvantagem mostram os dois dados', () {
      expect(
        skillRollDetail(attribute: 'Força', attributeValue: 2, rolls: [14, 9], mode: 'advantage', total: 16),
        'd20 (14, 9 · vantagem) + Força (2) = 16',
      );
      expect(
        skillRollDetail(attribute: null, attributeValue: 0, rolls: [14, 9], mode: 'disadvantage', total: 9),
        'd20 (14, 9 · desvantagem) = 9',
      );
    });

    test('atributo negativo', () {
      expect(
        skillRollDetail(attribute: 'Destreza', attributeValue: -1, rolls: [10], mode: 'normal', total: 9),
        'd20 (10) + Destreza (-1) = 9',
      );
    });
  });

  group('rollSkill e folha', () {
    late AppState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({'auto_sync': false});
      state = AppState();
    });

    Future<BuildContext> pump(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }))),
      ));
      return captured;
    }

    testWidgets('rollSkill rola d20 + atributo e grava com o nome da perícia', (tester) async {
      final context = await pump(tester);
      final entry = rollSkill(context, character: character, skillName: 'Atletismo', attribute: 'Força');
      await tester.pump();
      expect(entry['label'], 'Atletismo');
      expect(entry['modifier'], 3);
      expect(entry['sides'], 20);
      final die = (entry['rolls'] as List).first as int;
      expect(entry['result'], die + 3);
      expect(find.textContaining('Atletismo: d20 ($die) + Força (3) = ${die + 3}'), findsOneWidget);
    });

    testWidgets('folha começa no atributo vinculado e devolve atributo e modo', (tester) async {
      final context = await pump(tester);
      SkillRollChoice? choice;
      showSkillRollSheet(context, system: system, character: character, skillName: 'Atletismo').then((c) => choice = c);
      await tester.pumpAndSettle();
      expect(find.text('Rolar Atletismo'), findsOneWidget);
      expect(find.text('Sem atributo'), findsOneWidget);

      await tester.tap(find.text('Vantagem'));
      await tester.tap(find.text('Destreza'));
      await tester.pump();
      await tester.tap(find.text('Rolar'));
      await tester.pumpAndSettle();
      expect(choice?.attribute, 'Destreza');
      expect(choice?.mode, 'advantage');
    });

    testWidgets('escolher Sem atributo devolve attribute null', (tester) async {
      final context = await pump(tester);
      SkillRollChoice? choice;
      showSkillRollSheet(context, system: system, character: character, skillName: 'Atletismo').then((c) => choice = c);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sem atributo'));
      await tester.pump();
      await tester.tap(find.text('Rolar'));
      await tester.pumpAndSettle();
      expect(choice, isNotNull);
      expect(choice!.attribute, isNull);
      expect(choice!.mode, 'normal');
    });
  });
}
