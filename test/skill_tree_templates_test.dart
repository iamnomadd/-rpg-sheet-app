import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/services/skill_tree_templates.dart';

void main() {
  test('Paladino gera árvore interna até nível 10', () {
    final tree = SkillTreeTemplates.forClass('Paladino');
    expect(tree, hasLength(10));
    expect(tree.first['level'], 1);
    expect(tree.last['level'], 10);
    final ids = tree.map((node) => node['id']).toSet();
    for (final node in tree) {
      final parent = node['parentId']?.toString() ?? '';
      if (parent.isNotEmpty) expect(ids, contains(parent));
    }
  });

  test('classes conhecidas são reconhecidas sem depender de maiúsculas ou acentos', () {
    expect(SkillTreeTemplates.hasTemplate('INVESTIGADOR'), isTrue);
    expect(SkillTreeTemplates.hasTemplate('Clérigo'), isTrue);
    expect(SkillTreeTemplates.hasTemplate('classe inventada'), isFalse);
  });
}
