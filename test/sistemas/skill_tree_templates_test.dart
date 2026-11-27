import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/services/skill_tree_templates.dart';

void main() {
  // 1.3.79: modelos refeitos (3 ramos, 9 habilidades, profundidade 1 a 3).
  test('Paladino gera a árvore do modelo', () {
    final tree = SkillTreeTemplates.forClass('Paladino');
    expect(tree, hasLength(9));
    expect(tree.first['level'], 1);
    expect(tree.last['level'], 2);
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
