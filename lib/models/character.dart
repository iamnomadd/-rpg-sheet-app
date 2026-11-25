class Character {
  final String id;
  String name;
  String player;
  String systemId;
  String className;
  String race;
  String background;
  String history;
  String portraitPath;
  String fullBodyPath;
  int level;
  int hp;
  int maxHp;
  int energy;
  int maxEnergy;
  Map<String, int> attributes;
  Map<String, int> resourceValues;
  Map<String, int> resourceMaxValues;
  Map<String, String> sectionNotes;
  List<String> skills;
  List<String> abilities;
  List<String> inventory;
  List<String> equipment;
  Map<String, String> abilityDescriptions;
  Map<String, String> inventoryDescriptions;
  Map<String, Map<String, dynamic>> abilityDetails;
  Map<String, Map<String, dynamic>> inventoryDetails;
  List<Map<String, dynamic>> skillTree;
  List<String> generalOrder;
  List<String> sheetTabOrder;
  List<String> conditions;
  List<String> actionOrder;
  List<String> hiddenActionGroups;

  /// Cards do Em Cena escondidos no Personalizar. Ficha nova ou antiga sem a
  /// chave começa com ['skillTree'] (o card Árvore começa desligado; os outros
  /// continuam visíveis).
  List<String> hiddenGeneralCards;
  String shareCode;
  /// Imagens próprias do personagem 2D: pose ('normal', 'agony', 'critical',
  /// 'incapacitated') → data URI. Vazio = usa o personagem do tema.
  Map<String, String> customSpriteImages;
  /// Liga/desliga as imagens próprias sem apagá-las.
  bool customSpriteEnabled;

  Character({
    required this.id,
    required this.name,
    this.player = '',
    this.systemId = 'generic',
    this.className = '',
    this.race = '',
    this.background = '',
    this.history = '',
    this.portraitPath = '',
    this.fullBodyPath = '',
    this.level = 1,
    this.hp = 10,
    this.maxHp = 10,
    this.energy = 0,
    this.maxEnergy = 0,
    Map<String, int>? attributes,
    Map<String, int>? resourceValues,
    Map<String, int>? resourceMaxValues,
    Map<String, String>? sectionNotes,
    List<String>? skills,
    List<String>? abilities,
    List<String>? inventory,
    List<String>? equipment,
    Map<String, String>? abilityDescriptions,
    Map<String, String>? inventoryDescriptions,
    Map<String, Map<String, dynamic>>? abilityDetails,
    Map<String, Map<String, dynamic>>? inventoryDetails,
    List<Map<String, dynamic>>? skillTree,
    List<String>? generalOrder,
    List<String>? sheetTabOrder,
    List<String>? conditions,
    List<String>? actionOrder,
    List<String>? hiddenActionGroups,
    List<String>? hiddenGeneralCards,
    this.shareCode = '',
    Map<String, String>? customSpriteImages,
    this.customSpriteEnabled = false,
  })  : customSpriteImages = customSpriteImages ?? {},
        attributes = attributes ?? {'FOR': 10, 'DES': 10, 'CON': 10, 'INT': 10, 'SAB': 10, 'CAR': 10},
        resourceValues = resourceValues ?? {'Vida': 10, 'Energia': 0},
        resourceMaxValues = resourceMaxValues ?? {'Vida': 10, 'Energia': 0},
        sectionNotes = sectionNotes ?? {},
        skills = skills ?? [],
        abilities = abilities ?? [],
        inventory = inventory ?? [],
        equipment = equipment ?? [],
        abilityDescriptions = abilityDescriptions ?? {},
        inventoryDescriptions = inventoryDescriptions ?? {},
        abilityDetails = abilityDetails ?? {},
        inventoryDetails = inventoryDetails ?? {},
        skillTree = skillTree ?? [],
        generalOrder = generalOrder ?? ['health', 'energy', 'attributes', 'skillTree', 'abilities', 'inventory'],
        sheetTabOrder = sheetTabOrder ?? ['general', 'attributesResources', 'actions', 'skillTree', 'abilities', 'skills', 'inventory', 'sections'],
        conditions = conditions ?? [],
        actionOrder = actionOrder ?? ['weapons', 'spells', 'abilities', 'consumables'],
        hiddenActionGroups = hiddenActionGroups ?? [],
        hiddenGeneralCards = hiddenGeneralCards ?? ['skillTree'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'player': player,
        'systemId': systemId,
        'className': className,
        'race': race,
        'background': background,
        'history': history,
        'portraitPath': portraitPath,
        'fullBodyPath': fullBodyPath,
        'level': level,
        'hp': hp,
        'maxHp': maxHp,
        'energy': energy,
        'maxEnergy': maxEnergy,
        'attributes': attributes,
        'resourceValues': resourceValues,
        'resourceMaxValues': resourceMaxValues,
        'sectionNotes': sectionNotes,
        'skills': skills,
        'abilities': abilities,
        'inventory': inventory,
        'equipment': equipment,
        'abilityDescriptions': abilityDescriptions,
        'inventoryDescriptions': inventoryDescriptions,
        'abilityDetails': abilityDetails,
        'inventoryDetails': inventoryDetails,
        'skillTree': skillTree,
        'generalOrder': generalOrder,
        'sheetTabOrder': sheetTabOrder,
        'conditions': conditions,
        'actionOrder': actionOrder,
        'hiddenActionGroups': hiddenActionGroups,
        'hiddenGeneralCards': hiddenGeneralCards,
        'shareCode': shareCode,
        'customSpriteImages': customSpriteImages,
        'customSpriteEnabled': customSpriteEnabled,
      };

  static const _customSpritePoses = {'normal', 'agony', 'critical', 'incapacitated'};

  /// Leitura tolerante: só poses conhecidas com data URI de imagem; sem a
  /// imagem 'normal' o conjunto é ignorado (ficha abre com o personagem do tema).
  static Map<String, String> _parseCustomSpriteImages(Object? raw) {
    if (raw is! Map) return {};
    final images = <String, String>{};
    raw.forEach((key, value) {
      final pose = key.toString();
      if (_customSpritePoses.contains(pose) && value is String && value.startsWith('data:image/')) images[pose] = value;
    });
    return images.containsKey('normal') ? images : {};
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    final oldHp = (json['hp'] ?? 10) as int;
    final oldMaxHp = (json['maxHp'] ?? 10) as int;
    final oldEnergy = (json['energy'] ?? 0) as int;
    final oldMaxEnergy = (json['maxEnergy'] ?? 0) as int;

    final parsedAttributes = Map<String, int>.from(json['attributes'] ?? {});
    final parsedResources = Map<String, int>.from(json['resourceValues'] ?? {});
    final parsedMaxResources = Map<String, int>.from(json['resourceMaxValues'] ?? {});
    final parsedSections = Map<String, String>.from(json['sectionNotes'] ?? {});

    if (!parsedResources.containsKey('Vida')) parsedResources['Vida'] = oldHp;
    if (!parsedMaxResources.containsKey('Vida')) parsedMaxResources['Vida'] = oldMaxHp;
    if (!parsedResources.containsKey('Energia')) parsedResources['Energia'] = oldEnergy;
    if (!parsedMaxResources.containsKey('Energia')) parsedMaxResources['Energia'] = oldMaxEnergy;

    return Character(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Sem nome',
      player: json['player'] ?? '',
      systemId: json['systemId'] ?? 'generic',
      className: json['className'] ?? '',
      race: json['race'] ?? '',
      background: json['background'] ?? '',
      history: json['history'] ?? '',
      portraitPath: json['portraitPath'] ?? '',
      fullBodyPath: json['fullBodyPath'] ?? '',
      level: json['level'] ?? 1,
      hp: oldHp,
      maxHp: oldMaxHp,
      energy: oldEnergy,
      maxEnergy: oldMaxEnergy,
      attributes: parsedAttributes,
      resourceValues: parsedResources,
      resourceMaxValues: parsedMaxResources,
      sectionNotes: parsedSections,
      skills: List<String>.from(json['skills'] ?? []),
      abilities: List<String>.from(json['abilities'] ?? []),
      inventory: List<String>.from(json['inventory'] ?? []),
      equipment: List<String>.from(json['equipment'] ?? []),
      abilityDescriptions: Map<String, String>.from(json['abilityDescriptions'] ?? {}),
      inventoryDescriptions: Map<String, String>.from(json['inventoryDescriptions'] ?? {}),
      abilityDetails: (json['abilityDetails'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map? ?? {}))),
      inventoryDetails: (json['inventoryDetails'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map? ?? {}))),
      skillTree: (json['skillTree'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      generalOrder: (json['generalOrder'] as List?)?.map((e) => e.toString()).toList() ?? ['health', 'energy', 'attributes', 'skillTree', 'abilities', 'inventory'],
      sheetTabOrder: (json['sheetTabOrder'] as List?)?.map((e) => e.toString()).toList() ?? ['general', 'attributesResources', 'actions', 'skillTree', 'abilities', 'skills', 'inventory', 'sections'],
      conditions: (json['conditions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      actionOrder: (json['actionOrder'] as List?)?.map((e) => e.toString()).toList() ?? ['weapons', 'spells', 'abilities', 'consumables'],
      hiddenActionGroups: (json['hiddenActionGroups'] as List?)?.map((e) => e.toString()).toList() ?? [],
      hiddenGeneralCards: (json['hiddenGeneralCards'] as List?)?.map((e) => e.toString()).toList() ?? ['skillTree'],
      shareCode: json['shareCode']?.toString() ?? '',
      customSpriteImages: _parseCustomSpriteImages(json['customSpriteImages']),
      customSpriteEnabled: json['customSpriteEnabled'] == true,
    );
  }
}
