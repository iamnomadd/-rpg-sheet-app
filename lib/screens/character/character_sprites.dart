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

/// Caminho do sprite do personagem para o tema e a pose.
String characterSpritePath({required String themeId, required String pose}) {
  if (themeId == 'vampire') {
    return pose == 'incapacitated'
        ? 'assets/character2d/vampiric_incapacitated.png'
        : pose == 'critical'
            ? 'assets/character2d/vampiric_critical.png'
            : pose == 'agony'
                ? 'assets/character2d/vampiric_agony.png'
                : 'assets/character2d/vampiric_normal.png';
  }
  if (themeId == 'cyberpunk') {
    return pose == 'incapacitated'
        ? 'assets/character2d/cyberpunk_incapacitated.png'
        : pose == 'critical'
            ? 'assets/character2d/cyberpunk_critical.png'
            : pose == 'agony'
                ? 'assets/character2d/cyberpunk_agony.png'
                : 'assets/character2d/cyberpunk_normal.png';
  }
  if (themeId == 'parchment') {
    return pose == 'incapacitated'
        ? 'assets/character2d/pirate_incapacitated.webp'
        : pose == 'critical'
            ? 'assets/character2d/pirate_critical_new.webp'
            : pose == 'agony'
                ? 'assets/character2d/pirate_critical.webp'
                : 'assets/character2d/pirate_normal.webp';
  }
  return 'assets/character2d/${pose == 'incapacitated' ? 'incapacitated' : pose == 'agony' ? 'agony' : 'normal'}.png';
}
