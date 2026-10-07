// Regras puras do personagem 2D: pose por vida e sprite por tema.

/// Pose do personagem: 'incapacitated', 'critical', 'agony' ou 'normal'.
String characterPoseFor({required int life, required int lifeMax, required bool hasNegativeStatus}) {
  final lifeRatio = lifeMax > 0 ? (life / lifeMax).clamp(0.0, 1.0) : 1.0;
  if (life <= 0) return 'incapacitated';
  if (lifeRatio <= .30) return 'critical';
  if (lifeRatio <= .40) return 'agony';
  if (hasNegativeStatus) return 'agony';
  return 'normal';
}

const _defaultCharacterSprites = <String, String>{
  'incapacitated': 'assets/character2d/incapacitated.png',
  'critical': 'assets/character2d/critical.png',
  'agony': 'assets/character2d/agony.png',
  'normal': 'assets/character2d/normal.png',
};

/// Sprites próprios por tema (4 poses cada). Temas fora deste mapa usam
/// [_defaultCharacterSprites].
const _themeCharacterSprites = <String, Map<String, String>>{
  'vampire': {
    'incapacitated': 'assets/character2d/vampiric_incapacitated.png',
    'critical': 'assets/character2d/vampiric_critical.png',
    'agony': 'assets/character2d/vampiric_agony.png',
    'normal': 'assets/character2d/vampiric_normal.png',
  },
  'cyberpunk': {
    'incapacitated': 'assets/character2d/cyberpunk_incapacitated.png',
    'critical': 'assets/character2d/cyberpunk_critical.png',
    'agony': 'assets/character2d/cyberpunk_agony.png',
    'normal': 'assets/character2d/cyberpunk_normal.png',
  },
  'parchment': {
    'incapacitated': 'assets/character2d/pirate_incapacitated.webp',
    'critical': 'assets/character2d/pirate_critical_new.webp',
    'agony': 'assets/character2d/pirate_critical.webp',
    'normal': 'assets/character2d/pirate_normal.webp',
  },
};

/// Se o tema tem sprites próprios (renderizados na área fixa de 198×198).
bool characterUsesSpecialSprite(String themeId) => _themeCharacterSprites.containsKey(themeId);

/// Caminho do sprite do personagem para o tema e a pose.
String characterSpritePath({required String themeId, required String pose}) {
  final sprites = _themeCharacterSprites[themeId] ?? _defaultCharacterSprites;
  return sprites[pose] ?? sprites['normal']!;
}
