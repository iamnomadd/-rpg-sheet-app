class Campaign {
  final String id;
  String name;
  String description;
  List<String> characterIds;
  List<String> hiddenCharacterIds;
  List<String> npcs;
  List<Map<String, dynamic>> npcSheets;
  List<String> locations;
  String notes;
  String masterNotes;
  String sessionNotes;
  int sessionRound;
  List<Map<String, dynamic>> initiative;
  List<String> conditions;
  String masterScene;
  List<String> masterObjectives;
  List<String> sessionLog;
  List<Map<String, dynamic>> linkedCharacters;
  bool combatActive;
  int currentTurnIndex;

  Campaign({
    required this.id,
    required this.name,
    this.description = '',
    List<String>? characterIds,
    List<String>? hiddenCharacterIds,
    List<String>? npcs,
    List<Map<String, dynamic>>? npcSheets,
    List<String>? locations,
    this.notes = '',
    this.masterNotes = '',
    this.sessionNotes = '',
    this.sessionRound = 1,
    List<Map<String, dynamic>>? initiative,
    List<String>? conditions,
    this.masterScene = '',
    List<String>? masterObjectives,
    List<String>? sessionLog,
    List<Map<String, dynamic>>? linkedCharacters,
    this.combatActive = false,
    this.currentTurnIndex = 0,
  })  : characterIds = characterIds ?? [],
        hiddenCharacterIds = hiddenCharacterIds ?? [],
        npcs = npcs ?? [],
        npcSheets = npcSheets ?? [],
        locations = locations ?? [],
        initiative = initiative ?? [],
        conditions = conditions ?? [],
        masterObjectives = masterObjectives ?? [],
        sessionLog = sessionLog ?? [],
        linkedCharacters = linkedCharacters ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'characterIds': characterIds,
        'hiddenCharacterIds': hiddenCharacterIds,
        'npcs': npcs,
        'npcSheets': npcSheets,
        'locations': locations,
        'notes': notes,
        'masterNotes': masterNotes,
        'sessionNotes': sessionNotes,
        'sessionRound': sessionRound,
        'initiative': initiative,
        'conditions': conditions,
        'masterScene': masterScene,
        'masterObjectives': masterObjectives,
        'sessionLog': sessionLog,
        'linkedCharacters': linkedCharacters,
        'combatActive': combatActive,
        'currentTurnIndex': currentTurnIndex,
      };

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Campanha',
        description: json['description'] ?? '',
        characterIds: List<String>.from(json['characterIds'] ?? []),
        hiddenCharacterIds: List<String>.from(json['hiddenCharacterIds'] ?? []),
        npcs: List<String>.from(json['npcs'] ?? []),
        npcSheets: (json['npcSheets'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        locations: List<String>.from(json['locations'] ?? []),
        notes: json['notes'] ?? '',
        masterNotes: json['masterNotes'] ?? '',
        sessionNotes: json['sessionNotes'] ?? '',
        sessionRound: json['sessionRound'] ?? 1,
        initiative: (json['initiative'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        conditions: List<String>.from(json['conditions'] ?? []),
        masterScene: json['masterScene'] ?? '',
        masterObjectives: List<String>.from(json['masterObjectives'] ?? []),
        sessionLog: List<String>.from(json['sessionLog'] ?? []),
        linkedCharacters: (json['linkedCharacters'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        combatActive: json['combatActive'] == true,
        currentTurnIndex: json['currentTurnIndex'] is int ? json['currentTurnIndex'] : 0,
      );
}
