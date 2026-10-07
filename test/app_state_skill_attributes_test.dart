import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _storedDnd5e({Map<String, dynamic>? skillAttributes}) {
  final json = <String, dynamic>{
    'id': 'dnd5e',
    'name': 'D&D 5e',
    'description': '',
    'attributes': ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'],
    'skills': dnd5eSkillAttributes.keys.toList(),
    'resources': ['Vida'],
    'sections': ['Anotações'],
    'dice': [20],
  };
  if (skillAttributes != null) json['skillAttributes'] = skillAttributes;
  return json;
}

Future<AppState> _load(Map<String, Object> prefs) async {
  // auto_sync desligado: os testes não tentam sincronizar com a nuvem.
  SharedPreferences.setMockInitialValues({'auto_sync': false, ...prefs});
  final state = AppState();
  await state.load();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('instalação nova: o D&D 5e padrão já vem com os vínculos', () async {
    final state = await _load({});
    final dnd = state.systems.firstWhere((s) => s.id == 'dnd5e');
    expect(dnd.skillAttributes, dnd5eSkillAttributes);
    final others = state.systems.where((s) => s.id != 'dnd5e');
    expect(others.every((s) => s.skillAttributes.isEmpty), isTrue);
  });

  test('D&D 5e salvo antes do campo existir recebe os vínculos ao carregar', () async {
    final state = await _load({'systems': jsonEncode([_storedDnd5e()])});
    final dnd = state.systems.firstWhere((s) => s.id == 'dnd5e');
    expect(dnd.skillAttributes, hasLength(18));
    expect(dnd.skillAttributes['Furtividade'], 'Destreza');
  });

  test('D&D 5e salvo com skillAttributes {} continua vazio', () async {
    final state = await _load({'systems': jsonEncode([_storedDnd5e(skillAttributes: {})])});
    final dnd = state.systems.firstWhere((s) => s.id == 'dnd5e');
    expect(dnd.skillAttributes, isEmpty);
  });

  test('duplicar sistema mantém os vínculos em uma cópia independente', () async {
    final state = await _load({});
    final copy = (await state.duplicateSystem('dnd5e'))!;
    expect(copy.id, isNot('dnd5e'));
    expect(copy.skillAttributes, dnd5eSkillAttributes);

    copy.skillAttributes['Furtividade'] = 'Sabedoria';
    final original = state.systems.firstWhere((s) => s.id == 'dnd5e');
    expect(original.skillAttributes['Furtividade'], 'Destreza');
  });

  test('salvar e carregar de novo mantém os vínculos escolhidos', () async {
    final state = await _load({});
    final dnd = state.systems.firstWhere((s) => s.id == 'dnd5e');
    dnd.skillAttributes
      ..clear()
      ..['Atletismo'] = 'Destreza';
    await state.save();

    final prefs = await SharedPreferences.getInstance();
    final reloaded = AppState();
    SharedPreferences.setMockInitialValues({
      'auto_sync': false,
      'systems': prefs.getString('systems')!,
    });
    await reloaded.load();
    expect(reloaded.systems.firstWhere((s) => s.id == 'dnd5e').skillAttributes, {'Atletismo': 'Destreza'});
  });

  test('restaurar backup mantém os vínculos do sistema', () async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    final state = AppState();
    await state.replaceFromBackup({
      'characters': <dynamic>[],
      'systems': [
        {
          'id': 'custom',
          'name': 'Meu sistema',
          'attributes': ['Força'],
          'skills': ['Correr'],
          'resources': <String>[],
          'sections': <String>[],
          'dice': [20],
          'skillAttributes': {'Correr': 'Força'},
        },
      ],
      'campaigns': <dynamic>[],
      'savedRolls': <dynamic>[],
      'diceHistory': <dynamic>[],
    });
    expect(state.systems.firstWhere((s) => s.id == 'custom').skillAttributes, {'Correr': 'Força'});
  });
}
