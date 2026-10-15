import '../../models/campaign.dart';
import '../../models/character.dart';
import '../../models/rpg_system.dart';
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

/// Condições exibidas para um jogador remoto: as da ficha (snapshot) menos
/// as remoções pendentes, mais as adições pendentes, sem duplicar.
List<String> playerDisplayConditions(List<String> sheet, List<String> pendingAdd, List<String> pendingRemove) {
  final kept = sheet.where((c) => !pendingRemove.any((r) => sameCondition(r, c)));
  return mergeConditions(kept, pendingAdd);
}

/// Tira das pendências o que a ficha já confirmou: adição que já está na
/// ficha e remoção que já não está mais.
({List<String> add, List<String> remove}) pruneConfirmed(List<String> sheet, List<String> pendingAdd, List<String> pendingRemove) {
  bool inSheet(String condition) => sheet.any((c) => sameCondition(c, condition));
  return (
    add: pendingAdd.where((c) => !inSheet(c)).toList(),
    remove: pendingRemove.where(inSheet).toList(),
  );
}

/// Patch do mestre que só traz condições ('resourceValues' ausente ou vazio):
/// o jogador aplica automaticamente.
bool isConditionsOnlyPatch(Map<String, dynamic> patch) {
  if (patch['conditions'] is! List) return false;
  final resources = patch['resourceValues'];
  return resources == null || (resources is Map && resources.isEmpty);
}

/// Recursos de um patch do mestre, sem as chaves de vida ('Vida'/'PV'):
/// a vida do jogador é só dele.
Map<String, int> patchResourcesWithoutLife(Object? raw) {
  final result = <String, int>{};
  if (raw is! Map) return result;
  raw.forEach((key, value) {
    if (value is num && !isLifeResourceKey('$key')) result['$key'] = value.toInt();
  });
  return result;
}

/// Recursos secundários do jogador em Em Cena: todos os recursos do sistema,
/// na ordem do sistema, menos o recurso de vida.
List<String> secondaryResourceNames(RpgSystem system, String lifeName) =>
    system.resources.where((name) => name != lifeName).toList();


/// Recursos secundários da ficha do NPC (sem vida, sem duplicar por
/// trim + minúsculas). Com o sistema encontrado: os do sistema na ordem dele,
/// depois chaves extras da ficha fora do sistema com atual ou máximo
/// diferente de 0 (evita a 'Energia' 0/0 que o fromJson cria). Sem o sistema
/// (systemResources null): todas as chaves da ficha que não são de vida.
List<String> npcSecondaryResourceNames({
  required List<String>? systemResources,
  required Map<String, int> values,
  required Map<String, int> maxValues,
}) {
  String norm(String name) => name.trim().toLowerCase();
  final result = <String>[];
  void add(String name) {
    if (name.trim().isEmpty || isLifeResourceKey(name)) return;
    if (result.any((r) => norm(r) == norm(name))) return;
    result.add(name);
  }

  if (systemResources == null) {
    values.keys.forEach(add);
    return result;
  }
  systemResources.forEach(add);
  for (final key in values.keys) {
    if (systemResources.any((r) => norm(r) == norm(key))) continue;
    if ((values[key] ?? 0) != 0 || (maxValues[key] ?? 0) != 0) add(key);
  }
  return result;
}

/// Remove um participante da iniciativa ajustando currentTurnIndex (mesma
/// lógica de "Remover do combate"); sem participantes, encerra o combate.
void removeInitiativeParticipant(Campaign campaign, Object? id) {
  final ordered=[...campaign.initiative]..sort((a,b)=>((b['value']??0) as int).compareTo((a['value']??0) as int));
  final oldIndex=ordered.isEmpty ? 0 : campaign.currentTurnIndex.clamp(0,ordered.length-1);
  final currentId=ordered.isEmpty ? null : ordered[oldIndex]['id'];
  final removingCurrent=currentId==id;
  campaign.initiative.removeWhere((e)=>e['id']==id);
  if(campaign.initiative.isEmpty){
    campaign.combatActive=false;
    campaign.currentTurnIndex=0;
  } else if(removingCurrent){
    campaign.currentTurnIndex=oldIndex.clamp(0,campaign.initiative.length-1);
  } else if(currentId!=null){
    final refreshed=[...campaign.initiative]..sort((a,b)=>((b['value']??0) as int).compareTo((a['value']??0) as int));
    final ix=refreshed.indexWhere((e)=>e['id']==currentId);
    campaign.currentTurnIndex=ix<0 ? 0 : ix;
  }
}

/// Tira um vínculo remoto da campanha e os participantes 'player' dele da
/// iniciativa. Devolve true se a iniciativa mudou.
bool removeRemoteLink(Campaign campaign, Map<String, dynamic> link) {
  final code = '${link['shareCode'] ?? ''}';
  campaign.linkedCharacters.removeWhere((e) => identical(e, link) || (code.isNotEmpty && '${e['shareCode'] ?? ''}' == code));
  final snapshot = link['snapshot'];
  final id = snapshot is Map ? '${snapshot['id'] ?? ''}' : '';
  if (id.isEmpty) return false;
  final ids = campaign.initiative.where((e) => e['type'] == 'player' && '${e['id']}' == id).map((e) => e['id']).toList();
  for (final participant in ids) {
    removeInitiativeParticipant(campaign, participant);
  }
  return ids.isNotEmpty;
}

/// Vínculos aprovados guardados no Mestre que devem sair da lista: não estão
/// mais entre os aprovados da nuvem ou a ficha compartilhada foi apagada.
/// approvedCodes null = a busca falhou, e nada é removido. Pendentes ficam.
List<Map<String, dynamic>> staleRemoteLinks({
  required List<Map<String, dynamic>> local,
  required Set<String>? approvedCodes,
  required Set<String> missingSharedCodes,
}) {
  if (approvedCodes == null) return [];
  return local.where((e) {
    if (e['status'] != 'approved') return false;
    final code = '${e['shareCode'] ?? ''}';
    return !approvedCodes.contains(code) || missingSharedCodes.contains(code);
  }).toList();
}

/// Depois do DELETE do vínculo: pode tirar da lista local se apagou agora ou
/// se a linha já não existia. stillExists null = a consulta não foi feita ou
/// falhou, e aí só vale o que o DELETE apagou.
bool canRemoveLinkLocally({required bool deleted, bool? stillExists}) => deleted || stillExists == false;
