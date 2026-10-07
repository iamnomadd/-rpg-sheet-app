import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/models/rpg_system.dart';

const _dndAttributes = ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'];
const _dndSkills = [
  'Acrobacia', 'Arcanismo', 'Atletismo', 'Atuação', 'Enganação', 'Furtividade', 'História', 'Intimidação', 'Intuição',
  'Investigação', 'Lidar com Animais', 'Medicina', 'Natureza', 'Percepção', 'Persuasão', 'Prestidigitação', 'Religião', 'Sobrevivência',
];

Map<String, dynamic> _legacyJson(String id, {List<String> attributes = _dndAttributes, List<String> skills = _dndSkills}) => {
      'id': id,
      'name': 'Sistema',
      'attributes': attributes,
      'skills': skills,
      'resources': ['Vida'],
      'sections': ['Anotações'],
      'dice': [20],
    };

void main() {
  test('ida e volta toJson/fromJson mantém os vínculos', () {
    final system = RpgSystem(
      id: 'custom',
      name: 'Meu sistema',
      attributes: ['Força', 'Agilidade'],
      skills: ['Correr', 'Lutar'],
      skillAttributes: {'Correr': 'Agilidade', 'Lutar': 'Força'},
    );
    final json = system.toJson();
    expect(json['skillAttributes'], {'Correr': 'Agilidade', 'Lutar': 'Força'});
    final back = RpgSystem.fromJson(json);
    expect(back.skillAttributes, {'Correr': 'Agilidade', 'Lutar': 'Força'});
  });

  test('toJson sempre inclui skillAttributes, mesmo vazio', () {
    expect(RpgSystem(id: 'x', name: 'x').toJson().containsKey('skillAttributes'), isTrue);
    expect(RpgSystem(id: 'x', name: 'x').toJson()['skillAttributes'], isEmpty);
  });

  test('o mapa padrão é mutável e não é compartilhado', () {
    final a = RpgSystem(id: 'a', name: 'a');
    final b = RpgSystem(id: 'b', name: 'b');
    a.skillAttributes['Correr'] = 'Força';
    expect(b.skillAttributes, isEmpty);
  });

  test('dado antigo sem a chave em sistema que não é dnd5e fica vazio', () {
    for (final id in ['generic', 'tormenta20', 'ordem_paranormal', 'shadowdark', 'custom-123']) {
      expect(RpgSystem.fromJson(_legacyJson(id)).skillAttributes, isEmpty, reason: id);
    }
  });

  test('dnd5e antigo sem a chave recebe os 18 vínculos padrão', () {
    final system = RpgSystem.fromJson(_legacyJson('dnd5e'));
    expect(system.skillAttributes, hasLength(18));
    expect(system.skillAttributes, dnd5eSkillAttributes);
    expect(system.skillAttributes['Furtividade'], 'Destreza');
    expect(system.skillAttributes['Atletismo'], 'Força');
  });

  test('dnd5e antigo sem o atributo Destreza ignora os vínculos de Destreza', () {
    final attributes = _dndAttributes.where((a) => a != 'Destreza').toList();
    final system = RpgSystem.fromJson(_legacyJson('dnd5e', attributes: attributes));
    expect(system.skillAttributes.values, isNot(contains('Destreza')));
    expect(system.skillAttributes.containsKey('Furtividade'), isFalse);
    expect(system.skillAttributes, hasLength(15));
  });

  test('dnd5e antigo sem uma perícia ignora o vínculo dela', () {
    final skills = _dndSkills.where((s) => s != 'Medicina').toList();
    final system = RpgSystem.fromJson(_legacyJson('dnd5e', skills: skills));
    expect(system.skillAttributes.containsKey('Medicina'), isFalse);
    expect(system.skillAttributes, hasLength(17));
  });

  test('dnd5e com skillAttributes {} continua vazio', () {
    final json = _legacyJson('dnd5e')..['skillAttributes'] = <String, dynamic>{};
    expect(RpgSystem.fromJson(json).skillAttributes, isEmpty);
  });

  test('valores que não são String são ignorados sem exceção', () {
    final json = _legacyJson('custom')
      ..['skillAttributes'] = {'Acrobacia': 'Destreza', 'Atletismo': 3, 'Arcanismo': null, 'Furtividade': ['x']};
    expect(RpgSystem.fromJson(json).skillAttributes, {'Acrobacia': 'Destreza'});

    final notMap = _legacyJson('dnd5e')..['skillAttributes'] = ['Acrobacia'];
    expect(RpgSystem.fromJson(notMap).skillAttributes, isEmpty);
  });

  test('copyWith é profundo e mantém skillAttributes', () {
    final original = RpgSystem(
      id: 'a',
      name: 'Original',
      attributes: ['Força'],
      skills: ['Atletismo'],
      resources: ['Vida'],
      sections: ['Notas'],
      dice: [20],
      skillAttributes: {'Atletismo': 'Força'},
    );
    final copy = original.copyWith(id: 'b', name: 'Cópia');
    expect(copy.id, 'b');
    expect(copy.name, 'Cópia');
    expect(copy.description, original.description);
    expect(copy.skillAttributes, {'Atletismo': 'Força'});

    copy.attributes.add('Destreza');
    copy.skills.add('Furtividade');
    copy.resources.add('Mana');
    copy.sections.add('Extra');
    copy.dice.add(6);
    copy.skillAttributes['Furtividade'] = 'Destreza';

    expect(original.attributes, ['Força']);
    expect(original.skills, ['Atletismo']);
    expect(original.resources, ['Vida']);
    expect(original.sections, ['Notas']);
    expect(original.dice, [20]);
    expect(original.skillAttributes, {'Atletismo': 'Força'});
  });

  test('pruneSkillAttributes remove perícia ausente e atributo ausente', () {
    final pruned = pruneSkillAttributes(
      skills: ['Atletismo', 'Furtividade'],
      attributes: ['Força'],
      links: {'Atletismo': 'Força', 'Furtividade': 'Destreza', 'Medicina': 'Sabedoria'},
    );
    expect(pruned, {'Atletismo': 'Força'});
  });
}
