import '../../models/character.dart';
import '../character/resource_quick_adjust.dart';

/// Chave do recurso de vida da ficha. Sistemas embutidos usam 'PV'; como o
/// fromJson sempre cria 'Vida', 'PV' tem preferência quando existe.
String lifeResourceKey(Character sheet) {
  String? find(String name) {
    for (final key in sheet.resourceValues.keys) {
      if (key.trim().toLowerCase() == name) return key;
    }
    return null;
  }

  return find('pv') ?? find('vida') ?? 'Vida';
}

/// True se a chave é um recurso de vida ('Vida' ou 'PV', sem diferenciar
/// maiúsculas e ignorando espaços nas pontas).
bool isLifeResourceKey(String key) {
  final name = key.trim().toLowerCase();
  return name == 'vida' || name == 'pv';
}

/// Vida atual e máxima: recurso de vida (PV ou Vida) ou hp/maxHp.
({int current, int max}) readVida(Character sheet) {
  final key = lifeResourceKey(sheet);
  return (
    current: sheet.resourceValues[key] ?? sheet.hp,
    max: sheet.resourceMaxValues[key] ?? sheet.maxHp,
  );
}

/// Grava a vida como a ficha do NPC grava: máximo em 0..999999, atual em
/// 0..máximo. Atualiza a chave de vida resolvida e hp/maxHp; 'Vida' é
/// espelhada só se já existir (nunca é criada ao lado de 'PV'), para o card
/// de vida da ficha do NPC (que lê 'Vida' ?? hp) mostrar o mesmo valor.
void applyVida(Character sheet, ResourceValues values) {
  final max = values.max.clamp(0, 999999).toInt();
  final current = values.current.clamp(0, max).toInt();
  final key = lifeResourceKey(sheet);
  sheet.resourceValues[key] = current;
  sheet.resourceMaxValues[key] = max;
  if (sheet.resourceValues.containsKey('Vida')) sheet.resourceValues['Vida'] = current;
  if (sheet.resourceMaxValues.containsKey('Vida')) sheet.resourceMaxValues['Vida'] = max;
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

/// Condições a partir de um valor qualquer (ex.: snapshot['conditions']).
/// Tipo errado vira lista vazia.
List<String> conditionsFromRaw(Object? raw) {
  if (raw is! List) return [];
  return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
}

bool sameCondition(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// Une listas de condições sem duplicar (sem diferenciar maiúsculas),
/// mantendo a primeira grafia encontrada.
List<String> mergeConditions(Iterable<String> first, Iterable<String> second) {
  final result = <String>[];
  for (final condition in [...first, ...second]) {
    if (condition.trim().isEmpty) continue;
    if (!result.any((c) => sameCondition(c, condition))) result.add(condition);
  }
  return result;
}

/// Lista final de condições depois de adicionar e/ou remover uma condição,
/// sem duplicar e sem diferenciar maiúsculas.
List<String> patchedConditions(Iterable<String> current, {String? add, String? remove}) {
  var result = mergeConditions(current, const []);
  if (remove != null) result = result.where((c) => !sameCondition(c, remove)).toList();
  if (add != null && add.trim().isNotEmpty && !result.any((c) => sameCondition(c, add))) result.add(add);
  return result;
}
