import '../../models/character.dart';
import '../character/resource_quick_adjust.dart';

/// Vida atual e máxima de uma ficha, como a ficha do NPC lê:
/// resourceValues['Vida'] (ou hp) e resourceMaxValues['Vida'] (ou maxHp).
({int current, int max}) readVida(Character sheet) => (
      current: sheet.resourceValues['Vida'] ?? sheet.hp,
      max: sheet.resourceMaxValues['Vida'] ?? sheet.maxHp,
    );

/// Grava a vida como a ficha do NPC grava: máximo em 0..999999, atual em
/// 0..máximo, mantendo resourceValues/resourceMaxValues['Vida'] e hp/maxHp iguais.
void applyVida(Character sheet, ResourceValues values) {
  final max = values.max.clamp(0, 999999).toInt();
  final current = values.current.clamp(0, max).toInt();
  sheet.resourceValues['Vida'] = current;
  sheet.resourceMaxValues['Vida'] = max;
  sheet.hp = current;
  sheet.maxHp = max;
}


/// Condições de um participante da iniciativa. Item sem a chave (combates
/// antigos) ou com tipo errado vira lista vazia.
List<String> initiativeConditions(Map<String, dynamic> entry) {
  final raw = entry['conditions'];
  if (raw is! List) return [];
  return raw.map((e) => '$e').toList();
}
