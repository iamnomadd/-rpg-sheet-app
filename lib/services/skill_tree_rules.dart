// Regras da Árvore de Habilidades (1.3.76): ramos, tipos (Talento, Façanha,
// Lenda), níveis de aprimoramento, escolhas exclusivas, requisito de atributo
// opcional e a ligação com as Habilidades da ficha.
//
// Formato do nó (todos os campos novos são OPCIONAIS; o padrão reproduz a
// árvore de antes):
//   id, name, description, parentId, level (profundidade), unlocked, template
//   tier            'talento' (padrão) | 'facanha' | 'lenda'
//   maxRank         1..5 (padrão 1)
//   rank            0..maxRank (padrão: unlocked ? 1 : 0); unlocked = rank > 0
//   rankTexts       [texto do nível 1, texto do nível 2, ...] (opcional)
//   branchId        id do ramo ('' = "Geral")
//   exclusiveGroup  nome do grupo de escolha exclusiva ('' = nenhum)
//   reqAttribute    atributo do requisito ('' = nenhum; só vale se o sistema
//   reqValue        valor mínimo           ligar treeAttributeRequirement)
//   addToAbilities  bool (padrão false): cria a habilidade ao desbloquear
//   ability         {category, damage, cost, resource, durationType, turns}
//
// Ramo (character.skillTreeBranches): {id, name, color (ARGB int)}.

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/rpg_system.dart';

/// Funções da árvore habilitadas pelo sistema da ficha (1.3.77). Sistema não
/// encontrado = tudo desligado. Desligar só esconde/ignora: os dados dos nós e
/// da ficha continuam guardados.
class SkillTreeFeatures {
  final bool branches;
  final bool tiers;
  final bool ranks;
  final bool exclusive;
  final bool requirement;
  final bool abilityLink;

  const SkillTreeFeatures({
    this.branches = false,
    this.tiers = false,
    this.ranks = false,
    this.exclusive = false,
    this.requirement = false,
    this.abilityLink = false,
  });

  static const none = SkillTreeFeatures();

  factory SkillTreeFeatures.of(RpgSystem? system) => system == null
      ? none
      : SkillTreeFeatures(
          branches: system.treeBranches,
          tiers: system.treeTiers,
          ranks: system.treeRanks,
          exclusive: system.treeExclusive,
          requirement: system.treeAttributeRequirement,
          abilityLink: system.treeAbilityLink,
        );

  /// Alguma função de "Mais opções" ligada (Ramos fica no editor principal).
  bool get anyMoreOptions => tiers || ranks || exclusive || requirement || abilityLink;
}

/// Tipos de nó.
const skillTreeTiers = ['talento', 'facanha', 'lenda'];

/// Nome do tipo na interface.
String skillTreeTierLabel(String tier) => switch (tier) {
      'facanha' => 'Façanha',
      'lenda' => 'Lenda',
      _ => 'Talento',
    };

/// Uma frase por tipo (legenda e editor).
String skillTreeTierHint(String tier) => switch (tier) {
      'facanha' => 'Façanha: uma habilidade marcante.',
      'lenda' => 'Lenda: o ápice do ramo, que muda o jeito de jogar.',
      _ => 'Talento: uma melhoria comum.',
    };

/// Máximo de níveis de aprimoramento por habilidade.
const skillTreeMaxRanks = 5;

/// Cores dos ramos (contraste ≥ 3:1 sobre o card de todos os temas).
const skillTreeBranchColors = <Color>[
  Color(0xFFFF6B6B), // vermelho
  Color(0xFFFFA94D), // laranja
  Color(0xFFFFD43B), // amarelo
  Color(0xFF69DB7C), // verde
  Color(0xFF38D9A9), // verde-água
  Color(0xFF4DABF7), // azul
  Color(0xFFB197FC), // violeta
  Color(0xFFF783AC), // rosa
];

String _str(Object? value) => value?.toString() ?? '';

String nodeId(Map<String, dynamic> node) => _str(node['id']);
String nodeName(Map<String, dynamic> node) => _str(node['name']).isEmpty ? 'Habilidade' : _str(node['name']);

String nodeTier(Map<String, dynamic> node) {
  final tier = _str(node['tier']);
  return skillTreeTiers.contains(tier) ? tier : 'talento';
}

int nodeMaxRank(Map<String, dynamic> node) => ((node['maxRank'] as num?)?.toInt() ?? 1).clamp(1, skillTreeMaxRanks);

int nodeRank(Map<String, dynamic> node) {
  final rank = (node['rank'] as num?)?.toInt();
  if (rank == null) return node['unlocked'] == true ? 1 : 0;
  return rank.clamp(0, nodeMaxRank(node));
}

String nodeBranchId(Map<String, dynamic> node) => _str(node['branchId']);
String nodeGroup(Map<String, dynamic> node) => _str(node['exclusiveGroup']);

/// Texto do nível [rank] (1..max), ou ''.
String nodeRankText(Map<String, dynamic> node, int rank) {
  final texts = node['rankTexts'];
  if (texts is! List || rank < 1 || rank > texts.length) return '';
  return _str(texts[rank - 1]).trim();
}

/// Grava o nível e mantém unlocked coerente (unlocked = nível > 0).
void setNodeRank(Map<String, dynamic> node, int rank) {
  final value = rank.clamp(0, nodeMaxRank(node));
  node['rank'] = value;
  node['unlocked'] = value > 0;
}

Map<String, dynamic>? _byId(Character c, String id) {
  if (id.isEmpty) return null;
  for (final node in c.skillTree) {
    if (nodeId(node) == id) return node;
  }
  return null;
}

/// O pai está desbloqueado (nível ≥ 1), ou não há pai.
bool nodeParentReady(Character c, Map<String, dynamic> node) {
  final parent = _byId(c, _str(node['parentId']));
  return parent == null || nodeRank(parent) >= 1;
}

/// Filhos diretos do nó.
List<Map<String, dynamic>> nodeChildren(Character c, Map<String, dynamic> node) =>
    [for (final other in c.skillTree) if (_str(other['parentId']) == nodeId(node) && nodeId(node).isNotEmpty) other];

/// Algum filho direto está desbloqueado.
bool nodeHasUnlockedChild(Character c, Map<String, dynamic> node) => nodeChildren(c, node).any((child) => nodeRank(child) > 0);

/// O nó escolhido do mesmo grupo de escolha exclusiva que fecha [node], ou null.
Map<String, dynamic>? nodeClosedBy(Character c, Map<String, dynamic> node) {
  final group = nodeGroup(node);
  if (group.isEmpty) return null;
  for (final other in c.skillTree) {
    if (identical(other, node) || nodeId(other) == nodeId(node)) continue;
    if (nodeGroup(other) == group && nodeRank(other) > 0) return other;
  }
  return null;
}

/// Outros nós do mesmo grupo de escolha exclusiva.
List<Map<String, dynamic>> nodeGroupMates(Character c, Map<String, dynamic> node) {
  final group = nodeGroup(node);
  if (group.isEmpty) return const [];
  return [for (final other in c.skillTree) if (nodeId(other) != nodeId(node) && nodeGroup(other) == group) other];
}

/// Requisito de atributo que vale (sistema com o interruptor ligado e nó com
/// requisito), ou null.
({String attribute, int need, int have})? nodeRequirement(RpgSystem? system, Character c, Map<String, dynamic> node) {
  if (system == null || !system.treeAttributeRequirement) return null;
  final attribute = _str(node['reqAttribute']);
  final need = (node['reqValue'] as num?)?.toInt() ?? 0;
  if (attribute.isEmpty || need <= 0) return null;
  return (attribute: attribute, need: need, have: c.attributes[attribute] ?? 0);
}

String requirementText(({String attribute, int need, int have}) r) => 'Precisa de ${r.attribute} ${r.need} (você tem ${r.have})';

/// Mensagem do porquê não dá para desbloquear/aprimorar, ou null se dá.
String? nodeRaiseBlock(RpgSystem? system, Character c, Map<String, dynamic> node) {
  final features = SkillTreeFeatures.of(system);
  // Sem Aprimoramento, desbloqueada já é o máximo.
  if (nodeRank(node) >= (features.ranks ? nodeMaxRank(node) : 1)) return 'Já está no nível máximo.';
  final closer = features.exclusive ? nodeClosedBy(c, node) : null;
  if (closer != null) return 'Fechado pela escolha: ${nodeName(closer)}';
  if (!nodeParentReady(c, node)) return 'Desbloqueie primeiro a habilidade anterior deste ramo.';
  final requirement = nodeRequirement(system, c, node);
  if (requirement != null && requirement.have < requirement.need) return requirementText(requirement);
  return null;
}

/// Mensagem do porquê não dá para reduzir, ou null se dá. Só impede voltar a
/// 0 com um filho desbloqueado (decisão do dono, 1.3.76). Sem Aprimoramento
/// no [system], reduzir é bloquear (vai direto a 0).
String? nodeLowerBlock(Character c, Map<String, dynamic> node, {RpgSystem? system}) {
  final rank = nodeRank(node);
  if (rank <= 0) return 'Esta habilidade já está bloqueada.';
  final toZero = rank == 1 || !SkillTreeFeatures.of(system).ranks;
  if (toZero && nodeHasUnlockedChild(c, node)) return 'Bloqueie primeiro as habilidades que dependem desta.';
  return null;
}

/// Nível depois de reduzir: −1 com Aprimoramento; sem ele, 0 (bloquear).
int nodeLoweredRank(Map<String, dynamic> node, RpgSystem? system) => SkillTreeFeatures.of(system).ranks ? nodeRank(node) - 1 : 0;

// ------------------------------------------------------------------ ramos

/// Ramo do nó (null = "Geral").
Map<String, dynamic>? nodeBranch(Character c, Map<String, dynamic> node) {
  final id = nodeBranchId(node);
  if (id.isEmpty) return null;
  for (final branch in c.skillTreeBranches) {
    if (_str(branch['id']) == id) return branch;
  }
  return null;
}

Color branchColor(Map<String, dynamic> branch) {
  final raw = branch['color'];
  final value = raw is num ? raw.toInt() : int.tryParse(_str(raw));
  return value == null ? skillTreeBranchColors.first : Color(value);
}

/// Cria um ramo com a próxima cor da lista.
Map<String, dynamic> addSkillTreeBranch(Character c, {String? name, String? id}) {
  final branch = <String, dynamic>{
    'id': id ?? 'ramo-${DateTime.now().microsecondsSinceEpoch}',
    'name': (name ?? '').trim().isEmpty ? 'Ramo ${c.skillTreeBranches.length + 1}' : name!.trim(),
    'color': skillTreeBranchColors[c.skillTreeBranches.length % skillTreeBranchColors.length].toARGB32(),
  };
  c.skillTreeBranches.add(branch);
  return branch;
}

/// Apaga o ramo; os nós dele vão para "Geral" (nenhum nó é apagado).
void removeSkillTreeBranch(Character c, String branchId) {
  c.skillTreeBranches.removeWhere((b) => _str(b['id']) == branchId);
  for (final node in c.skillTree) {
    if (nodeBranchId(node) == branchId) node['branchId'] = '';
  }
}

/// Grupos de nós por ramo, na ordem dos ramos e com "Geral" (null) primeiro.
/// Ramo sem nós não aparece.
List<({Map<String, dynamic>? branch, List<Map<String, dynamic>> nodes})> skillTreeSections(Character c, {bool enabled = true}) {
  // Ramos desligados no sistema: uma coluna única (os branchId ficam guardados).
  if (!enabled) return [if (c.skillTree.isNotEmpty) (branch: null, nodes: c.skillTree)];
  final known = {for (final b in c.skillTreeBranches) _str(b['id'])};
  final general = [for (final n in c.skillTree) if (!known.contains(nodeBranchId(n))) n];
  return [
    if (general.isNotEmpty) (branch: null, nodes: general),
    for (final b in c.skillTreeBranches)
      if (c.skillTree.any((n) => nodeBranchId(n) == _str(b['id'])))
        (branch: b, nodes: [for (final n in c.skillTree) if (nodeBranchId(n) == _str(b['id'])) n]),
  ];
}

// ------------------------------------------------------------ habilidades

/// Campos da habilidade criada pelo nó (mesmo formato do editor de habilidades).
Map<String, dynamic> nodeAbilitySettings(Map<String, dynamic> node) {
  final raw = node['ability'];
  final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  return {
    'category': _str(map['category']).isEmpty ? 'Habilidade' : _str(map['category']),
    'damage': _str(map['damage']),
    'cost': (map['cost'] as num?)?.toInt() ?? 0,
    'resource': _str(map['resource']),
    'durationType': _str(map['durationType']).isEmpty ? 'instant' : _str(map['durationType']),
    'turns': _str(map['turns']),
  };
}

/// Descrição da habilidade: a do nó mais o texto do nível atual.
String nodeAbilityDescription(Map<String, dynamic> node) {
  final description = _str(node['description']).trim();
  final rankText = nodeRankText(node, nodeRank(node));
  return [if (description.isNotEmpty) description, if (rankText.isNotEmpty) rankText].join('\n\n');
}

/// Nome da habilidade da ficha que veio deste nó, ou null.
String? linkedAbilityName(Character c, Map<String, dynamic> node) {
  for (final name in c.abilities) {
    if (_str(c.abilityDetails[name]?['fromTree']) == nodeId(node) && nodeId(node).isNotEmpty) return name;
  }
  return null;
}

/// Cria (ou atualiza) a habilidade do nó. Devolve false se já existe uma
/// habilidade com o mesmo nome que NÃO veio deste nó (ela não é alterada).
bool syncNodeAbility(Character c, Map<String, dynamic> node) {
  final name = nodeName(node);
  final linked = linkedAbilityName(c, node);
  if (linked == null && c.abilities.contains(name)) return false;
  final key = linked ?? name;
  if (linked == null) c.abilities.add(key);
  final settings = nodeAbilitySettings(node);
  final passive = settings['category'] == 'Passiva';
  c.abilityDescriptions[key] = nodeAbilityDescription(node);
  c.abilityDetails[key] = {
    ...?c.abilityDetails[key],
    'category': settings['category'],
    'damage': passive ? '' : settings['damage'],
    'durationType': passive ? '' : settings['durationType'],
    'turns': passive || settings['durationType'] != 'turns' ? '' : settings['turns'],
    'quantity': null,
    'ammo': null,
    'ammoMax': null,
    'ammoItem': '',
    'effectResource': '',
    'effectValue': 0,
    'cost': passive ? null : settings['cost'],
    'resource': passive ? '' : settings['resource'],
    'showInScene': c.abilityDetails[key]?['showInScene'] == true,
    'fromTree': nodeId(node),
  };
  return true;
}

/// Copia para a habilidade vinda do nó os campos de categoria, custo,
/// recurso, dano e duração (só quando eles mudaram no editor do nó).
void applyNodeAbilitySettings(Character c, Map<String, dynamic> node) {
  final linked = linkedAbilityName(c, node);
  if (linked == null) return;
  final settings = nodeAbilitySettings(node);
  final passive = settings['category'] == 'Passiva';
  c.abilityDetails[linked] = {
    ...?c.abilityDetails[linked],
    'category': settings['category'],
    'damage': passive ? '' : settings['damage'],
    'durationType': passive ? '' : settings['durationType'],
    'turns': passive || settings['durationType'] != 'turns' ? '' : settings['turns'],
    'cost': passive ? null : settings['cost'],
    'resource': passive ? '' : settings['resource'],
  };
}

/// Atualiza só a descrição da habilidade vinda do nó (novo nível).
void refreshNodeAbilityDescription(Character c, Map<String, dynamic> node) {
  final linked = linkedAbilityName(c, node);
  if (linked != null) c.abilityDescriptions[linked] = nodeAbilityDescription(node);
}

/// Remove a habilidade vinda do nó (só se ainda for dela).
void removeNodeAbility(Character c, Map<String, dynamic> node) {
  final linked = linkedAbilityName(c, node);
  if (linked == null) return;
  c.abilities.remove(linked);
  c.abilityDescriptions.remove(linked);
  c.abilityDetails.remove(linked);
}

/// Renomeia a habilidade vinda do nó para o nome novo do nó. Devolve false
/// se o nome novo já é de outra habilidade (nada muda).
bool renameNodeAbility(Character c, Map<String, dynamic> node) {
  final linked = linkedAbilityName(c, node);
  final name = nodeName(node);
  if (linked == null || linked == name) return true;
  if (c.abilities.contains(name)) return false;
  final index = c.abilities.indexOf(linked);
  c.abilities[index] = name;
  final description = c.abilityDescriptions.remove(linked);
  if (description != null) c.abilityDescriptions[name] = description;
  final details = c.abilityDetails.remove(linked);
  if (details != null) c.abilityDetails[name] = details;
  return true;
}
