/// Atributo base padrão de cada perícia do D&D 5e.
const dnd5eSkillAttributes = <String, String>{
  'Acrobacia': 'Destreza',
  'Arcanismo': 'Inteligência',
  'Atletismo': 'Força',
  'Atuação': 'Carisma',
  'Enganação': 'Carisma',
  'Furtividade': 'Destreza',
  'História': 'Inteligência',
  'Intimidação': 'Carisma',
  'Intuição': 'Sabedoria',
  'Investigação': 'Inteligência',
  'Lidar com Animais': 'Sabedoria',
  'Medicina': 'Sabedoria',
  'Natureza': 'Inteligência',
  'Percepção': 'Sabedoria',
  'Persuasão': 'Carisma',
  'Prestidigitação': 'Destreza',
  'Religião': 'Inteligência',
  'Sobrevivência': 'Sabedoria',
};

/// Mantém só os vínculos cuja perícia está em [skills] e cujo atributo está
/// em [attributes].
Map<String, String> pruneSkillAttributes({
  required List<String> skills,
  required List<String> attributes,
  required Map<String, String> links,
}) {
  return {
    for (final entry in links.entries)
      if (skills.contains(entry.key) && attributes.contains(entry.value)) entry.key: entry.value,
  };
}

/// Vínculos com a perícia [oldSkill] renomeada para [newSkill].
Map<String, String> renameSkillInLinks(Map<String, String> links, String oldSkill, String newSkill) => {
      for (final entry in links.entries) (entry.key == oldSkill ? newSkill : entry.key): entry.value,
    };

/// Vínculos que apontavam para [oldAttribute] passam a apontar para [newAttribute].
Map<String, String> renameAttributeInLinks(Map<String, String> links, String oldAttribute, String newAttribute) => {
      for (final entry in links.entries) entry.key: (entry.value == oldAttribute ? newAttribute : entry.value),
    };

/// Vínculos sem a perícia [skill].
Map<String, String> removeSkillFromLinks(Map<String, String> links, String skill) => {
      for (final entry in links.entries)
        if (entry.key != skill) entry.key: entry.value,
    };

/// Vínculos sem os que apontavam para [attribute].
Map<String, String> removeAttributeFromLinks(Map<String, String> links, String attribute) => {
      for (final entry in links.entries)
        if (entry.value != attribute) entry.key: entry.value,
    };

class RpgSystem {
  final String id;
  String name;
  String description;
  List<String> attributes;
  List<String> skills;
  List<String> resources;
  List<String> sections;
  List<int> dice;

  /// Atributo base opcional de cada perícia (perícia → atributo).
  Map<String, String> skillAttributes;

  /// Árvore de Habilidades: exigir atributo mínimo para desbloquear (1.3.76).
  /// Padrão false: o requisito salvo nos nós é ignorado.
  bool treeAttributeRequirement;

  /// Última alteração feita pelo usuário (ISO 8601 UTC), usada para juntar a
  /// sincronização por item. Dados antigos: null.
  String? updatedAt;

  RpgSystem({
    required this.id,
    required this.name,
    this.description = '',
    List<String>? attributes,
    List<String>? skills,
    List<String>? resources,
    List<String>? sections,
    List<int>? dice,
    Map<String, String>? skillAttributes,
    this.treeAttributeRequirement = false,
    this.updatedAt,
  })  : attributes = attributes ?? [],
        skills = skills ?? [],
        resources = resources ?? [],
        sections = sections ?? [],
        dice = dice ?? [4, 6, 8, 10, 12, 20, 100],
        skillAttributes = skillAttributes ?? <String, String>{};

  /// Cópia profunda (listas e mapa novos), opcionalmente com outro id, nome ou
  /// descrição.
  RpgSystem copyWith({String? id, String? name, String? description}) => RpgSystem(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        attributes: List<String>.from(attributes),
        skills: List<String>.from(skills),
        resources: List<String>.from(resources),
        sections: List<String>.from(sections),
        dice: List<int>.from(dice),
        skillAttributes: Map<String, String>.from(skillAttributes),
        treeAttributeRequirement: treeAttributeRequirement,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'attributes': attributes,
        'skills': skills,
        'resources': resources,
        'sections': sections,
        'dice': dice,
        'skillAttributes': skillAttributes,
        // Só grava quando ligado (sistemas de antes ficam com o JSON de antes).
        if (treeAttributeRequirement) 'treeAttributeRequirement': true,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  factory RpgSystem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? '';
    final attributes = List<String>.from(json['attributes'] ?? []);
    final skills = List<String>.from(json['skills'] ?? []);
    final Map<String, String> skillAttributes;
    if (json.containsKey('skillAttributes')) {
      final raw = json['skillAttributes'];
      skillAttributes = <String, String>{
        if (raw is Map)
          for (final entry in raw.entries)
            if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      };
    } else if (id == 'dnd5e') {
      // Dado antigo, de antes do vínculo existir: preenche o padrão do D&D 5e.
      skillAttributes = pruneSkillAttributes(skills: skills, attributes: attributes, links: dnd5eSkillAttributes);
    } else {
      skillAttributes = <String, String>{};
    }
    return RpgSystem(
      id: id,
      name: json['name'] ?? 'Sistema sem nome',
      description: json['description'] ?? '',
      attributes: attributes,
      skills: skills,
      resources: List<String>.from(json['resources'] ?? []),
      sections: List<String>.from(json['sections'] ?? []),
      dice: (json['dice'] as List?)?.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList(),
      skillAttributes: skillAttributes,
      treeAttributeRequirement: json['treeAttributeRequirement'] == true,
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
