class RpgSystem {
  final String id;
  String name;
  String description;
  List<String> attributes;
  List<String> skills;
  List<String> resources;
  List<String> sections;
  List<int> dice;

  RpgSystem({
    required this.id,
    required this.name,
    this.description = '',
    List<String>? attributes,
    List<String>? skills,
    List<String>? resources,
    List<String>? sections,
    List<int>? dice,
  })  : attributes = attributes ?? [],
        skills = skills ?? [],
        resources = resources ?? [],
        sections = sections ?? [],
        dice = dice ?? [4, 6, 8, 10, 12, 20, 100];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'attributes': attributes,
        'skills': skills,
        'resources': resources,
        'sections': sections,
        'dice': dice,
      };

  factory RpgSystem.fromJson(Map<String, dynamic> json) => RpgSystem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Sistema sem nome',
        description: json['description'] ?? '',
        attributes: List<String>.from(json['attributes'] ?? []),
        skills: List<String>.from(json['skills'] ?? []),
        resources: List<String>.from(json['resources'] ?? []),
        sections: List<String>.from(json['sections'] ?? []),
        dice: (json['dice'] as List?)?.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList(),
      );
}
