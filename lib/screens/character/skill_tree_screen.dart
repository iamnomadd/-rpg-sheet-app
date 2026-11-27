import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/abyss_theme.dart';
import '../../app/theme.dart';
import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/skill_tree_rules.dart';
import '../../services/skill_tree_templates.dart';
import '../../widgets/dispose_on_removed.dart';
import '../../widgets/text_growth.dart';

class SkillTreeScreen extends StatefulWidget {
  final String characterId;
  final bool embedded;

  const SkillTreeScreen({super.key, required this.characterId, this.embedded = false});

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

/// Quantas vezes o crescimento de texto dos cartões da árvore foi calculado
/// (só para testes do cache).
@visibleForTesting
int skillTreeTextGrowthComputations = 0;

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  /// Legenda dos tipos aberta.
  bool _legendOpen = false;

  Character? _character(AppState state) {
    for (final character in state.characters) {
      if (character.id == widget.characterId) return character;
    }
    return null;
  }

  RpgSystem? _system(Character character) {
    for (final system in context.read<AppState>().systems) {
      if (system.id == character.systemId) return system;
    }
    return null;
  }

  Set<String> _descendantIds(Character character, String id) {
    final result = <String>{};
    void visit(String parent) {
      for (final node in character.skillTree) {
        if ((node['parentId'] ?? '').toString() == parent) {
          final childId = node['id']?.toString() ?? '';
          if (childId.isNotEmpty && result.add(childId)) visit(childId);
        }
      }
    }

    visit(id);
    return result;
  }

  bool _isAvailable(Character character, Map<String, dynamic> node) => nodeParentReady(character, node);

  /// Funções da árvore ligadas no sistema da ficha (sistema apagado: nenhuma).
  SkillTreeFeatures _features(Character character) => SkillTreeFeatures.of(_system(character));

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save(Character character) async {
    await context.read<AppState>().updateCharacter(character);
    if (mounted) setState(() {});
  }

  Future<void> _openEditor(Character character, {Map<String, dynamic>? node}) async {
    final editing = node != null;
    final system = _system(character);
    // O sistema da ficha decide quais funções aparecem (1.3.77).
    final features = SkillTreeFeatures.of(system);
    final requirementOn = features.requirement;
    final name = TextEditingController(text: node?['name']?.toString() ?? '');
    final description = TextEditingController(text: node?['description']?.toString() ?? '');
    String parentId = node?['parentId']?.toString() ?? '';
    final forbidden = editing ? _descendantIds(character, node['id']?.toString() ?? '') : <String>{};
    if (editing) forbidden.add(node['id']?.toString() ?? '');
    final validParentIds = character.skillTree
        .map((candidate) => candidate['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty && !forbidden.contains(id))
        .toSet();
    if (parentId.isNotEmpty && !validParentIds.contains(parentId)) parentId = '';

    // Ramo e "Mais opções" (1.3.76). Os padrões reproduzem a árvore de antes.
    final branchIds = {for (final b in character.skillTreeBranches) b['id']?.toString() ?? ''};
    String branchId = node == null ? '' : nodeBranchId(node);
    if (!branchIds.contains(branchId)) branchId = '';
    String tier = node == null ? 'talento' : nodeTier(node);
    int maxRank = node == null ? 1 : nodeMaxRank(node);
    final rankTexts = [
      for (var i = 1; i <= skillTreeMaxRanks; i++) TextEditingController(text: node == null ? '' : nodeRankText(node, i)),
    ];
    final ownId = node == null ? '' : nodeId(node);
    final exclusive = <String>{
      if (node != null) for (final mate in nodeGroupMates(character, node)) nodeId(mate),
    };
    String reqAttribute = node?['reqAttribute']?.toString() ?? '';
    if (!(system?.attributes.contains(reqAttribute) ?? false)) reqAttribute = '';
    final reqValue = TextEditingController(text: ((node?['reqValue'] as num?)?.toInt() ?? 0) > 0 ? '${node!['reqValue']}' : '');
    bool addToAbilities = node == null ? false : node['addToAbilities'] == true;
    var abilityTouched = editing;
    final ability = node == null ? nodeAbilitySettings(const {}) : nodeAbilitySettings(node);
    String category = ability['category'] as String;
    final resources = character.resourceValues.keys.toList();
    String resource = resources.contains(ability['resource']) ? ability['resource'] as String : (resources.isNotEmpty ? resources.first : '');
    String durationType = ability['durationType'] as String;
    final cost = TextEditingController(text: (ability['cost'] as int) > 0 ? '${ability['cost']}' : '');
    final damage = TextEditingController(text: ability['damage'] as String);
    final turns = TextEditingController(text: ability['turns'] as String);
    String? nameError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => DisposeOnRemoved(
        onRemoved: () {
          name.dispose();
          description.dispose();
          reqValue.dispose();
          cost.dispose();
          damage.dispose();
          turns.dispose();
          for (final c in rankTexts) {
            c.dispose();
          }
        },
        child: StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editing ? 'Editar habilidade da árvore' : 'Nova habilidade da árvore'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(textCapitalization: TextCapitalization.sentences, 
                  controller: name,
                  autofocus: !editing,
                  decoration: InputDecoration(labelText: 'Nome', errorText: nameError),
                ),
                const SizedBox(height: 12),
                TextField(textCapitalization: TextCapitalization.sentences, 
                  controller: description,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Efeito, requisito narrativo, observações...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: parentId,
                  decoration: const InputDecoration(labelText: 'Pré-requisito / ramo anterior'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Nenhum — habilidade inicial')),
                    ...character.skillTree
                        .where((candidate) => !forbidden.contains(candidate['id']?.toString() ?? ''))
                        .map(
                          (candidate) => DropdownMenuItem(
                            value: candidate['id']?.toString() ?? '',
                            child: Text(candidate['name']?.toString() ?? 'Habilidade'),
                          ),
                        ),
                  ],
                  onChanged: (value) => setDialogState(() => parentId = value ?? ''),
                ),
                if (features.branches && character.skillTreeBranches.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('node-branch'),
                    initialValue: branchId,
                    // Itens com bolinha + nome: precisa da largura do campo.
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ramo'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Geral')),
                      for (final b in character.skillTreeBranches)
                        DropdownMenuItem(
                          value: b['id']?.toString() ?? '',
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle, size: 12, color: branchColor(b)),
                            const SizedBox(width: 8),
                            Flexible(child: Text(b['name']?.toString() ?? 'Ramo', overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() => branchId = value ?? ''),
                  ),
                ],
                // Tudo o que não é o básico fica aqui, recolhido; só com
                // alguma função ligada no sistema, e só as ligadas.
                if (features.anyMoreOptions) ...[
                const SizedBox(height: 4),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('node-more-options'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: const Text('Mais opções'),
                    children: [
                      if (features.tiers) ...[
                      Align(alignment: Alignment.centerLeft, child: Text('Tipo', style: Theme.of(context).textTheme.labelLarge)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        key: const ValueKey('node-tier'),
                        showSelectedIcon: false,
                        segments: [for (final t in skillTreeTiers) ButtonSegment(value: t, label: Text(skillTreeTierLabel(t)))],
                        selected: {tier},
                        onSelectionChanged: (value) => setDialogState(() {
                          tier = value.first;
                          // Nova Façanha/Lenda vai para as Habilidades, se a pessoa não escolheu.
                          if (!abilityTouched) addToAbilities = tier != 'talento';
                        }),
                      ),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerLeft, child: Text(skillTreeTierHint(tier), style: Theme.of(context).textTheme.bodySmall)),
                      const SizedBox(height: 12),
                      ],
                      if (features.ranks) ...[
                      DropdownButtonFormField<int>(
                        key: const ValueKey('node-max-rank'),
                        initialValue: maxRank,
                        decoration: const InputDecoration(labelText: 'Níveis de aprimoramento'),
                        items: [for (var i = 1; i <= skillTreeMaxRanks; i++) DropdownMenuItem(value: i, child: Text(i == 1 ? '1 (sem aprimorar)' : '$i'))],
                        onChanged: (value) => setDialogState(() => maxRank = value ?? 1),
                      ),
                      if (maxRank > 1)
                        for (var i = 1; i <= maxRank; i++) ...[
                          const SizedBox(height: 8),
                          TextField(
                            key: ValueKey('node-rank-text-$i'),
                            controller: rankTexts[i - 1],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(labelText: 'Nível $i (opcional)', hintText: i == 1 ? 'Ex.: dano 1d6' : 'Ex.: o dano aumenta para ${i}d6'),
                          ),
                        ],
                      const SizedBox(height: 4),
                      ],
                      if (features.exclusive && character.skillTree.any((other) => nodeId(other) != ownId)) ...[
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft, child: Text('Escolha exclusiva com…', style: Theme.of(context).textTheme.labelLarge)),
                        Align(alignment: Alignment.centerLeft, child: Text('Escolha uma das duas: desbloquear uma fecha as outras.', style: Theme.of(context).textTheme.bodySmall)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final other in character.skillTree.where((other) => nodeId(other) != ownId))
                            FilterChip(
                              label: Text(nodeName(other)),
                              selected: exclusive.contains(nodeId(other)),
                              onSelected: (value) => setDialogState(() => value ? exclusive.add(nodeId(other)) : exclusive.remove(nodeId(other))),
                            ),
                        ]),
                      ],
                      if (requirementOn && (system?.attributes.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              key: const ValueKey('node-req-attribute'),
                              initialValue: reqAttribute,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Requisito: atributo'),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('Nenhum')),
                                for (final a in system!.attributes) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (value) => setDialogState(() => reqAttribute = value ?? ''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: const ValueKey('node-req-value'),
                              controller: reqValue,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '≥ valor'),
                            ),
                          ),
                        ]),
                      ],
                      if (features.abilityLink) ...[
                      const SizedBox(height: 4),
                      SwitchListTile(
                        key: const ValueKey('node-add-ability'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Adicionar às Habilidades ao desbloquear'),
                        value: addToAbilities,
                        onChanged: (value) => setDialogState(() {
                          abilityTouched = true;
                          addToAbilities = value;
                        }),
                      ),
                      if (addToAbilities) ...[
                        DropdownButtonFormField<String>(
                          key: const ValueKey('node-ability-category'),
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          items: [for (final c in const ['Habilidade', 'Magia', 'Técnica', 'Passiva', 'Outro']) DropdownMenuItem(value: c, child: Text(c))],
                          onChanged: (value) => setDialogState(() => category = value ?? category),
                        ),
                        if (category != 'Passiva') ...[
                          const SizedBox(height: 12),
                          TextField(controller: damage, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Dano', hintText: 'Ex.: 1d8, 2d6+3 ou 5')),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo'))),
                            const SizedBox(width: 8),
                            if (resources.isNotEmpty)
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: resource,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Recurso'),
                                  items: [for (final r in resources) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))],
                                  onChanged: (value) => setDialogState(() => resource = value ?? resource),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: durationType,
                            decoration: const InputDecoration(labelText: 'Duração'),
                            items: const [
                              DropdownMenuItem(value: 'instant', child: Text('Direto / instantâneo')),
                              DropdownMenuItem(value: 'turns', child: Text('Por turnos')),
                            ],
                            onChanged: (value) => setDialogState(() => durationType = value ?? durationType),
                          ),
                          if (durationType == 'turns') ...[
                            const SizedBox(height: 12),
                            TextField(controller: turns, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade de turnos')),
                          ],
                        ],
                      ],
                      ],
                    ],
                  ),
                ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final trimmed = name.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => nameError = 'Dê um nome.');
                  return;
                }
                final texts = [for (var i = 0; i < maxRank; i++) rankTexts[i].text.trim()];
                Navigator.pop(dialogContext, {
                  'name': trimmed,
                  'description': description.text.trim(),
                  'parentId': parentId,
                  // Só as funções ligadas no sistema voltam; as outras ficam
                  // como estão no nó (desligar só esconde).
                  if (features.branches) 'branchId': branchId,
                  if (features.tiers) 'tier': tier,
                  if (features.ranks) 'maxRank': maxRank,
                  if (features.ranks) 'rankTexts': maxRank > 1 && texts.any((t) => t.isNotEmpty) ? texts : null,
                  if (features.exclusive) 'exclusive': exclusive.toList(),
                  'reqAttribute': reqAttribute,
                  'reqValue': int.tryParse(reqValue.text.trim()) ?? 0,
                  if (features.abilityLink) 'addToAbilities': addToAbilities,
                  if (features.abilityLink) 'ability': {
                    'category': category,
                    'damage': damage.text.trim(),
                    'cost': (int.tryParse(cost.text.trim()) ?? 0).clamp(0, 999999),
                    'resource': resource,
                    'durationType': durationType,
                    'turns': turns.text.trim(),
                  },
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
      ),
    );

    if (result == null || !mounted) return;

    final Map<String, dynamic> target;
    if (editing) {
      target = node;
      target['name'] = result['name'];
      target['description'] = result['description'];
      target['parentId'] = result['parentId'];
    } else {
      var level = 1;
      final chosenParentId = result['parentId'] as String? ?? '';
      if (chosenParentId.isNotEmpty) {
        for (final candidate in character.skillTree) {
          if (candidate['id']?.toString() == chosenParentId) {
            level = ((candidate['level'] as num?)?.toInt() ?? 0) + 1;
            break;
          }
        }
      }
      target = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': result['name'],
        'description': result['description'],
        'parentId': result['parentId'],
        'level': level,
        'unlocked': false,
      };
      character.skillTree.add(target);
    }
    _applyAdvanced(character, target, result, requirementOn: requirementOn, features: features);
    await _save(character);
  }

  /// Grava os campos de "Mais opções" só quando diferem do padrão (o nó de
  /// antes continua com o mesmo JSON se nada mudar).
  void _applyAdvanced(Character character, Map<String, dynamic> node, Map<String, dynamic> result, {required bool requirementOn, required SkillTreeFeatures features}) {
    // Só grava o que o editor devolveu (funções ligadas); o resto fica igual.
    void put(String key, Object? value, Object? standard) {
      if (!result.containsKey(key == 'reqValue' ? 'reqAttribute' : key)) return;
      if (value == standard || value == null) {
        node.remove(key);
      } else {
        node[key] = value;
      }
    }

    // Campos da habilidade antes desta edição (para o achado da 1.3.76).
    final abilityBefore = jsonEncode(nodeAbilitySettings(node));

    put('branchId', result['branchId'], '');
    put('tier', result['tier'], 'talento');
    put('maxRank', result['maxRank'], 1);
    put('rankTexts', result['rankTexts'], null);
    if (result.containsKey('maxRank') && (node.containsKey('rank') || nodeMaxRank(node) > 1)) {
      // Nível atual dentro do novo máximo.
      setNodeRank(node, nodeRank(node));
    }
    if (requirementOn) {
      final attribute = result['reqAttribute'] as String? ?? '';
      final value = result['reqValue'] as int? ?? 0;
      put('reqAttribute', attribute.isEmpty || value <= 0 ? '' : attribute, '');
      put('reqValue', attribute.isEmpty || value <= 0 ? 0 : value, 0);
    }
    if (result.containsKey('addToAbilities')) {
      put('addToAbilities', result['addToAbilities'] == true ? true : null, null);
      if (result['addToAbilities'] == true) {
        node['ability'] = result['ability'];
      } else {
        node.remove('ability');
      }
    }

    if (result.containsKey('exclusive')) _applyExclusive(character, node, result);

    // Habilidade vinda da árvore: o nome e a descrição acompanham o nó; os
    // outros campos (categoria, custo, recurso, dano, duração) só se mudaram
    // nesta edição. Ajustes feitos na aba Habilidades ficam (1.3.77).
    if (!renameNodeAbility(character, node)) {
      _message('Já existe uma habilidade com esse nome; ela não foi alterada.');
      return;
    }
    if (!features.abilityLink) return;
    if (linkedAbilityName(character, node) != null) {
      refreshNodeAbilityDescription(character, node);
      if (jsonEncode(nodeAbilitySettings(node)) != abilityBefore) applyNodeAbilitySettings(character, node);
    } else if (nodeRank(node) > 0 && node['addToAbilities'] == true && !syncNodeAbility(character, node)) {
      _message('Já existe uma habilidade com esse nome; ela não foi alterada.');
    }
  }

  /// Escolha exclusiva: o nó e os escolhidos ficam no mesmo grupo.
  void _applyExclusive(Character character, Map<String, dynamic> node, Map<String, dynamic> result) {
    final selected = {...(result['exclusive'] as List).cast<String>()};
    final current = nodeGroup(node);
    for (final other in character.skillTree) {
      if (current.isNotEmpty && nodeGroup(other) == current && !selected.contains(nodeId(other))) other.remove('exclusiveGroup');
    }
    if (selected.isEmpty) {
      node.remove('exclusiveGroup');
    } else {
      final group = current.isNotEmpty ? current : 'escolha-${nodeId(node)}';
      node['exclusiveGroup'] = group;
      for (final other in character.skillTree) {
        if (selected.contains(nodeId(other))) other['exclusiveGroup'] = group;
      }
    }
    // Grupo com um só nó não é escolha.
    final counts = <String, int>{};
    for (final other in character.skillTree) {
      final g = nodeGroup(other);
      if (g.isNotEmpty) counts[g] = (counts[g] ?? 0) + 1;
    }
    for (final other in character.skillTree) {
      if ((counts[nodeGroup(other)] ?? 0) == 1) other.remove('exclusiveGroup');
    }
  }

  Future<void> _generateTemplate(Character character) async {
    final generated = SkillTreeTemplates.forClass(character.className);
    if (generated.isEmpty || character.skillTree.isNotEmpty) return;
    character.skillTree = generated;
    await context.read<AppState>().updateCharacter(character);
    if (mounted) setState(() {});
  }

  /// Desbloquear (0 → 1) ou aprimorar (+1).
  Future<void> _raise(Character character, Map<String, dynamic> node) async {
    final block = nodeRaiseBlock(_system(character), character, node);
    if (block != null) {
      _message(block);
      return;
    }
    final before = nodeRank(node);
    setNodeRank(node, before + 1);
    // Sem "Adicionar às Habilidades" no sistema, desbloquear não cria habilidade.
    if (_features(character).abilityLink && node['addToAbilities'] == true) {
      if (before == 0) {
        if (!syncNodeAbility(character, node)) _message('Já existe uma habilidade com esse nome; ela não foi alterada.');
      } else {
        refreshNodeAbilityDescription(character, node);
      }
    }
    await _save(character);
  }

  /// Reduzir (−1). No nível 0 volta a ficar bloqueada; se a habilidade veio da
  /// árvore, pergunta se remove também.
  Future<void> _lower(Character character, Map<String, dynamic> node) async {
    final system = _system(character);
    final features = SkillTreeFeatures.of(system);
    final block = nodeLowerBlock(character, node, system: system);
    if (block != null) {
      _message(block);
      return;
    }
    // Sem Aprimoramento, reduzir é bloquear (vai a 0); o nível salvo some só aí.
    final next = nodeLoweredRank(node, system);
    var removeAbility = false;
    if (next == 0 && features.abilityLink) {
      final linked = linkedAbilityName(character, node);
      if (linked != null) {
        final answer = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remover a habilidade?'),
            content: Text('Remover também a habilidade $linked das Habilidades?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Manter')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remover')),
            ],
          ),
        );
        if (answer == null || !mounted) return;
        removeAbility = answer;
      }
    }
    setNodeRank(node, next);
    if (removeAbility) {
      removeNodeAbility(character, node);
    } else if (next > 0 && features.abilityLink) {
      refreshNodeAbilityDescription(character, node);
    }
    await _save(character);
  }

  /// Botão do cartão: desbloqueia; com um nível só, bloqueia; com mais
  /// níveis, abre o detalhe (Aprimorar/Reduzir).
  Future<void> _toggle(Character character, Map<String, dynamic> node) async {
    if (nodeRank(node) == 0) return _raise(character, node);
    if (!_features(character).ranks || nodeMaxRank(node) == 1) return _lower(character, node);
    return _showNode(character, node);
  }

  Future<void> _delete(Character character, Map<String, dynamic> node) async {
    // Sem "Adicionar às Habilidades" no sistema, não pergunta sobre a habilidade.
    final linked = _features(character).abilityLink ? linkedAbilityName(character, node) : null;
    var removeAbility = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Excluir habilidade?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Excluir "${node['name'] ?? 'Habilidade'}"? Os ramos ligados a ela voltarão para o início da árvore.'),
            // A mesma pergunta do bloquear, na mesma janela (uma pergunta por ação).
            if (linked != null)
              CheckboxListTile(
                key: const ValueKey('delete-remove-ability'),
                contentPadding: EdgeInsets.zero,
                value: removeAbility,
                onChanged: (value) => setDialogState(() => removeAbility = value ?? false),
                title: Text('Remover também a habilidade $linked das Habilidades'),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
          ],
        ),
      ),
    );
    if (accepted != true) return;

    if (linked != null && removeAbility) removeNodeAbility(character, node);
    final id = node['id']?.toString() ?? '';
    character.skillTree.removeWhere((candidate) => candidate['id']?.toString() == id);
    for (final candidate in character.skillTree) {
      if (candidate['parentId']?.toString() == id) candidate['parentId'] = '';
    }
    await _save(character);
  }

  Future<void> _showNode(Character character, Map<String, dynamic> node) async {
    final description = node['description']?.toString().trim() ?? '';
    final system = _system(character);
    final features = SkillTreeFeatures.of(system);
    final rank = nodeRank(node);
    // Sem Aprimoramento: só Desbloquear/Bloquear (o nível salvo fica guardado).
    final maxRank = features.ranks ? nodeMaxRank(node) : 1;
    final unlocked = rank > 0;
    final available = _isAvailable(character, node);
    final closer = features.exclusive ? nodeClosedBy(character, node) : null;
    final requirement = nodeRequirement(system, character, node);
    final block = nodeRaiseBlock(system, character, node);
    final children = nodeChildren(character, node).map(nodeName).toList();
    final branch = features.branches ? nodeBranch(character, node) : null;
    final summary = [
      if (features.tiers) skillTreeTierLabel(nodeTier(node)),
      if (maxRank > 1) 'Aprimoramento $rank de $maxRank',
      if (children.isNotEmpty) 'Desbloqueia: ${children.join(', ')}',
    ].join(' • ');
    final rankText = features.ranks ? nodeRankText(node, rank) : '';
    final nextText = features.ranks && rank < maxRank ? nodeRankText(node, rank + 1) : '';
    final canRaise = rank < maxRank;
    final primaryLabel = canRaise ? (rank == 0 ? 'Desbloquear' : 'Aprimorar') : (maxRank == 1 ? 'Bloquear' : 'Reduzir');
    final error = Theme.of(context).colorScheme.error;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(unlocked ? Icons.lock_open_rounded : available && closer == null ? Icons.radio_button_unchecked : Icons.lock_outline),
                  const SizedBox(width: 10),
                  Expanded(child: Text(node['name']?.toString() ?? 'Habilidade', style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
              const SizedBox(height: 10),
              if (node['level'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Nível ${node['level']}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
              ],
              if (summary.isNotEmpty) Text(summary, key: const ValueKey('node-summary'), style: Theme.of(context).textTheme.labelLarge),
              if (branch != null) ...[
                const SizedBox(height: 4),
                Text('Ramo: ${branch['name'] ?? 'Ramo'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: branchColor(branch))),
              ],
              if (closer != null) ...[
                const SizedBox(height: 6),
                Text('Fechado porque você escolheu: ${nodeName(closer)}', style: TextStyle(color: error)),
              ],
              if (requirement != null) ...[
                const SizedBox(height: 6),
                Text(requirementText(requirement), style: requirement.have < requirement.need ? TextStyle(color: error) : null),
              ],
              if (canRaise && closer == null && !available) ...[
                const SizedBox(height: 6),
                Text(block ?? '', style: TextStyle(color: error)),
              ],
              const SizedBox(height: 10),
              Text(description.isEmpty ? 'Sem descrição.' : description),
              if (rankText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Agora: $rankText'),
              ],
              if (nextText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Próximo nível: $nextText', style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canRaise
                          ? (block == null
                              ? () {
                                  Navigator.pop(sheetContext);
                                  _raise(character, node);
                                }
                              : null)
                          : () {
                              Navigator.pop(sheetContext);
                              _lower(character, node);
                            },
                      icon: Icon(canRaise ? (rank == 0 ? Icons.lock_open_outlined : Icons.arrow_upward) : (maxRank == 1 ? Icons.lock_outline : Icons.arrow_downward)),
                      label: Text(primaryLabel),
                    ),
                  ),
                  if (canRaise && rank > 0) ...[
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _lower(character, node);
                      },
                      child: const Text('Reduzir'),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openEditor(character, node: node);
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Excluir',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _delete(character, node);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cache do [_nodeTextGrowth]: só recalcula quando os cartões (nome, nível,
  // estado), a largura do cartão ou a escala do texto (e o estilo) mudam.
  List<Object?>? _growthKey;
  double _growthValue = 0;

  _NodeState _stateOf(Character character, Map<String, dynamic> node, [SkillTreeFeatures? features]) {
    if (nodeRank(node) > 0) return _NodeState.unlocked;
    if ((features ?? _features(character)).exclusive && nodeClosedBy(character, node) != null) return _NodeState.closed;
    return _isAvailable(character, node) ? _NodeState.available : _NodeState.locked;
  }

  /// Maior crescimento de texto entre os cartões (nas larguras do cartão).
  double _nodeTextGrowth(BuildContext context, Character character, SkillTreeLayout layout, SkillTreeFeatures features) {
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    final key = <Object?>[
      layout.compact,
      layout.nodeWidth,
      MediaQuery.textScalerOf(context),
      labelSmall,
      features.ranks,
      features.tiers,
      features.exclusive,
      for (final node in character.skillTree) ...[node['name']?.toString(), (node['level'] as num?)?.toInt(), _stateOf(character, node, features), nodeRank(node), nodeMaxRank(node), nodeTier(node)],
    ];
    final cached = _growthKey;
    if (cached != null && listEquals(cached, key)) return _growthValue;
    skillTreeTextGrowthComputations++;
    var extra = 0.0;
    for (final node in character.skillTree) {
      final name = node['name']?.toString() ?? 'Habilidade';
      final state = _stateOf(character, node, features);
      double growth;
      if (layout.compact) {
        final width = math.max(1.0, layout.nodeWidth - 10);
        final small = skillNodeCompactLabel(node, ranks: features.ranks);
        growth = textGrowth(context, name, const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, height: 1.15), maxWidth: width, maxLines: 3) +
            (small == null ? 0 : textGrowth(context, small, labelSmall?.copyWith(fontSize: 10), maxWidth: width));
      } else {
        // Coluna do texto: cartão − padding (16) − ícone (24) − espaço (8) − cadeado (40).
        final width = math.max(1.0, layout.nodeWidth - 88);
        final label = skillNodeCardLabel(node, state, ranks: features.ranks);
        growth = textGrowth(context, name, const TextStyle(fontWeight: FontWeight.w700), maxWidth: width, maxLines: 2) +
            textGrowth(context, label, labelSmall, maxWidth: width);
        // Cartão normal estreito: o texto pode quebrar em mais linhas mesmo
        // com texto 1.0; a altura cresce o que faltar para caber.
        final scaler = MediaQuery.textScalerOf(context);
        final needed = measuredTextHeight(context, name, const TextStyle(fontWeight: FontWeight.w700), scaler: scaler, maxWidth: width, maxLines: 2) +
            2 +
            measuredTextHeight(context, label, labelSmall, scaler: scaler, maxWidth: width);
        growth = math.max(growth, (needed - _normalCardTextHeight).ceilToDouble());
      }
      // Selo do tipo (Façanha/Lenda): cresce com o texto também.
      if (features.tiers && nodeTier(node) != 'talento') {
        growth += textGrowth(context, skillTreeTierLabel(nodeTier(node)), labelSmall?.copyWith(fontSize: 10), maxWidth: math.max(1.0, layout.nodeWidth - 10));
      }
      extra = math.max(extra, growth);
    }
    _growthKey = key;
    return _growthValue = extra;
  }

  /// Um desenho da árvore (todos os nós, ou os de um ramo).
  Widget _canvas(Character character, List<Map<String, dynamic>> nodes, SkillTreeLayout layout, Map<String, _NodeState> stateById, SkillTreeFeatures features, {Color? accent, required double minHeight}) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SkillTreePainter(
                nodes: nodes,
                positions: layout.positions,
                heights: layout.nodeHeights,
                nodeWidth: layout.nodeWidth,
                nodeHeight: layout.nodeHeight,
                states: stateById,
                activeColor: accent ?? scheme.primary,
                availableColor: accent ?? scheme.secondary,
                lockedColor: scheme.outlineVariant,
                orColor: scheme.onSurfaceVariant,
                showExclusive: features.exclusive,
              ),
            ),
          ),
          for (final node in nodes.where((candidate) => layout.positions.containsKey(candidate['id']?.toString() ?? '')))
            Positioned(
              left: layout.positions[node['id']?.toString() ?? '']!.dx,
              top: layout.positions[node['id']?.toString() ?? '']!.dy,
              width: layout.nodeWidth,
              height: layout.nodeHeights[node['id']?.toString() ?? ''] ?? layout.nodeHeight,
              child: _SkillNodeCard(
                node: node,
                state: stateById[node['id']?.toString() ?? ''] ?? _NodeState.locked,
                icon: themedIcon(state.themeId, 'skillTree'),
                compact: layout.compact,
                accent: accent,
                tiers: features.tiers,
                ranks: features.ranks,
                onTap: () => _showNode(character, node),
                onToggle: () => _toggle(character, node),
              ),
            ),
        ],
      ),
    );
  }

  Widget _treeCanvas(Character character) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final features = _features(character);
        final stateById = <String, _NodeState>{
          for (final node in character.skillTree) node['id']?.toString() ?? '': _stateOf(character, node, features),
        };
        // Sem Tipos no sistema, todos os cartões no tamanho de sempre.
        final extras = features.tiers ? skillTreeTierExtraHeights(character.skillTree) : const <String, double>{};
        final base = computeSkillTreeLayout(character.skillTree, constraints.maxWidth, extraHeightById: extras);
        // 0 com texto 1.0 (a árvore fica igual); com texto maior, o cartão
        // cresce o mesmo que o seu texto, para nada estourar.
        final extra = _nodeTextGrowth(context, character, base, features);
        final sections = skillTreeSections(character, enabled: features.branches);
        // Um ramo só (ou nenhum): o desenho de sempre.
        if (sections.length <= 1) {
          final layout = extra > 0 ? computeSkillTreeLayout(character.skillTree, constraints.maxWidth, extraNodeHeight: extra, extraHeightById: extras) : base;
          return SingleChildScrollView(
            key: const ValueKey('skill-tree-scroll'),
            child: _canvas(character, character.skillTree, layout, stateById, features, minHeight: 250),
          );
        }
        // Vários ramos: uma seção por ramo, de cima para baixo, com a cor do ramo.
        final scheme = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          key: const ValueKey('skill-tree-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in sections) ...[
                Padding(
                  key: ValueKey('skill-tree-branch-${section.branch?['id'] ?? 'geral'}'),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(children: [
                    Icon(Icons.circle, size: 12, color: section.branch == null ? scheme.outline : branchColor(section.branch!)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.branch == null ? 'Geral' : section.branch!['name']?.toString() ?? 'Ramo',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: section.branch == null ? null : branchColor(section.branch!),
                            ),
                      ),
                    ),
                  ]),
                ),
                _canvas(
                  character,
                  section.nodes,
                  computeSkillTreeLayout(section.nodes, constraints.maxWidth, extraNodeHeight: extra, extraHeightById: extras, minHeight: 0),
                  stateById,
                  features,
                  accent: section.branch == null ? null : branchColor(section.branch!),
                  minHeight: 0,
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBranches(Character character) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _SkillTreeBranchesScreen(characterId: character.id)),
      );

  Widget _body(Character character) {
    final unlocked = character.skillTree.where((node) => node['unlocked'] == true).length;
    final themeId = context.watch<AppState>().themeId;
    final templateLabel = SkillTreeTemplates.templateLabelForClass(character.className);
    final features = _features(character);
    final usesTiers = features.tiers && character.skillTree.any((node) => nodeTier(node) != 'talento');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Icon(themedIcon(themeId, 'skillTree')),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Árvore de Habilidades', style: Theme.of(context).textTheme.titleLarge),
                    Text('$unlocked de ${character.skillTree.length} desbloqueada(s) • role para ver toda a árvore', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (features.branches)
              IconButton(
                tooltip: 'Ramos',
                onPressed: () => _openBranches(character),
                icon: const Icon(Icons.call_split),
              ),
              IconButton(
                tooltip: 'Nova habilidade',
                onPressed: () => _openEditor(character),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
          child: Wrap(
            spacing: 12,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Progressão: cima → baixo', style: TextStyle(fontWeight: FontWeight.w600)),
              _TreeLegendDot(color: Theme.of(context).colorScheme.primary, label: 'Desbloqueada'),
              _TreeLegendDot(color: Theme.of(context).colorScheme.secondary, label: 'Disponível'),
              _TreeLegendDot(color: Theme.of(context).colorScheme.outlineVariant, label: 'Bloqueada'),
            ],
          ),
        ),
        // Legenda dos tipos: só quando a árvore usa Façanha/Lenda; recolhível.
        if (usesTiers)
          InkWell(
            key: const ValueKey('skill-tree-tier-legend'),
            onTap: () => setState(() => _legendOpen = !_legendOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Tipos: Talento, Façanha e Lenda', style: Theme.of(context).textTheme.labelMedium)),
                  Icon(_legendOpen ? Icons.expand_less : Icons.expand_more, size: 18),
                ]),
                if (_legendOpen)
                  for (final tier in skillTreeTiers) Text(skillTreeTierHint(tier), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: character.skillTree.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(themedIcon(themeId, 'skillTree'), size: 52),
                        const SizedBox(height: 12),
                        Text(
                          templateLabel == null
                              ? 'Sua árvore ainda está vazia.'
                              : 'Há uma árvore base disponível para a classe ${character.className}.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        if (templateLabel != null) ...[
                          FilledButton.icon(
                            onPressed: () => _generateTemplate(character),
                            icon: const Icon(Icons.account_tree_outlined),
                            label: Text('Gerar árvore de $templateLabel'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openEditor(character),
                            icon: const Icon(Icons.add),
                            label: const Text('Criar manualmente'),
                          ),
                        ] else
                          FilledButton.icon(
                            onPressed: () => _openEditor(character),
                            icon: const Icon(Icons.add),
                            label: const Text('Criar primeira habilidade'),
                          ),
                      ],
                    ),
                  ),
                )
              : _treeCanvas(character),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final character = _character(context.watch<AppState>());
    if (character == null) return const Center(child: Text('Ficha não encontrada.'));
    if (widget.embedded) return _body(character);
    return Scaffold(
      appBar: AppBar(title: Text('Árvore • ${character.name}')),
      body: _body(character),
    );
  }
}


class _TreeLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _TreeLegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: Theme.of(context).textTheme.labelSmall),
  ]);
}

enum _NodeState { unlocked, available, locked, closed }

/// Legenda do cartão normal: "Nível N • Estado" como antes; com mais de um
/// nível de aprimoramento, também "2/3".
String skillNodeCardLabel(Map<String, dynamic> node, Object state, {bool ranks = true}) {
  final stateLabel = switch (state) {
    _NodeState.unlocked => 'Desbloqueada',
    _NodeState.available => 'Disponível',
    _NodeState.closed => 'Fechada',
    _ => 'Bloqueada',
  };
  final level = (node['level'] as num?)?.toInt();
  final label = level == null ? stateLabel : 'Nível $level • $stateLabel';
  return ranks && nodeMaxRank(node) > 1 ? '$label • ${nodeRank(node)}/${nodeMaxRank(node)}' : label;
}

/// Linha pequena do cartão compacto: "Nv N" como antes; com níveis, "2/3".
String? skillNodeCompactLabel(Map<String, dynamic> node, {bool ranks = true}) {
  final level = (node['level'] as num?)?.toInt();
  final rank = ranks && nodeMaxRank(node) > 1 ? '${nodeRank(node)}/${nodeMaxRank(node)}' : null;
  if (level == null) return rank;
  return rank == null ? 'Nv $level' : 'Nv $level • $rank';
}

/// Altura a mais por tipo: Façanha um pouco maior, Lenda a maior.
const skillTreeFacanhaExtra = 30.0;
const skillTreeLendaExtra = 40.0;

Map<String, double> skillTreeTierExtraHeights(List<Map<String, dynamic>> nodes) => {
      for (final node in nodes)
        if (nodeTier(node) != 'talento') nodeId(node): nodeTier(node) == 'lenda' ? skillTreeLendaExtra : skillTreeFacanhaExtra,
    };

/// Posições calculadas da árvore (nada disso é gravado na ficha).
class SkillTreeLayout {
  final double width;
  final double height;
  final double nodeWidth;
  final double nodeHeight;
  final int columns;
  final Map<String, Offset> positions;

  /// Altura de cada cartão (Talento = [nodeHeight]; Façanha e Lenda, maiores).
  final Map<String, double> nodeHeights;

  const SkillTreeLayout({
    required this.width,
    required this.height,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.columns,
    required this.positions,
    this.nodeHeights = const {},
  });

  /// Cartão estreito: versão compacta, sem o botão de cadeado.
  bool get compact => nodeWidth < skillTreeCompactBelow;
}

const skillTreeMaxColumns = 4;
const skillTreeCardMinWidth = 72.0;
const skillTreeCardMaxWidth = 154.0;
const skillTreeCompactBelow = 120.0;
const skillTreeCardHeight = 92.0;
const skillTreeCompactCardHeight = 108.0;
/// Altura útil da coluna de texto do cartão normal: [skillTreeCardHeight]
/// menos o padding vertical (8 + 7).
const _normalCardTextHeight = skillTreeCardHeight - 15;
const _treePaddingX = 16.0;
const _treePaddingY = 24.0;
const _treeGapX = 10.0;
const _treeRowGap = 14.0;
const _treeLevelGap = 52.0;

/// Layout da árvore para a largura disponível: nunca passa da largura, no
/// máximo [skillTreeMaxColumns] cartões lado a lado; nós a mais de um mesmo
/// nível descem para a linha seguinte (cada linha centralizada). A profundidade
/// vem de `parentId` (ciclo ou pai inexistente contam como raiz). Com
/// [extraHeightById] (Façanha/Lenda), a linha cresce o do maior cartão e os
/// menores ficam centralizados nela.
SkillTreeLayout computeSkillTreeLayout(
  List<Map<String, dynamic>> nodes,
  double viewportWidth, {
  double extraNodeHeight = 0,
  Map<String, double> extraHeightById = const {},
  double minHeight = 250,
}) {
  final width = math.max(0.0, viewportWidth);
  final byId = <String, Map<String, dynamic>>{
    for (final node in nodes)
      if ((node['id']?.toString() ?? '').isNotEmpty) node['id'].toString(): node,
  };
  final depthCache = <String, int>{};

  int depthOf(Map<String, dynamic> node, Set<String> visiting) {
    final id = node['id']?.toString() ?? '';
    if (depthCache.containsKey(id)) return depthCache[id]!;
    if (!visiting.add(id)) return 0;
    final parentId = (node['parentId'] ?? '').toString();
    final parent = byId[parentId];
    final depth = parent == null ? 0 : depthOf(parent, visiting) + 1;
    visiting.remove(id);
    depthCache[id] = depth;
    return depth;
  }

  final levels = <int, List<Map<String, dynamic>>>{};
  for (final node in nodes) {
    final depth = depthOf(node, <String>{});
    levels.putIfAbsent(depth, () => []).add(node);
  }
  final maxCount = levels.values.fold<int>(1, (value, level) => math.max(value, level.length));

  final usable = math.max(0.0, width - _treePaddingX * 2);
  var fit = 1;
  for (var c = skillTreeMaxColumns; c > 1; c--) {
    if ((usable - (c - 1) * _treeGapX) / c >= skillTreeCardMinWidth) {
      fit = c;
      break;
    }
  }
  final columns = math.min(skillTreeMaxColumns, math.min(maxCount, fit));
  final nodeWidth = math.min(skillTreeCardMaxWidth, (usable - (columns - 1) * _treeGapX) / columns).clamp(0.0, skillTreeCardMaxWidth).toDouble();
  // Altura de sempre; com texto maior, [extraNodeHeight] acompanha o texto.
  final nodeHeight = (nodeWidth < skillTreeCompactBelow ? skillTreeCompactCardHeight : skillTreeCardHeight) + math.max(0.0, extraNodeHeight);

  final positions = <String, Offset>{};
  final heights = <String, double>{};
  var y = _treePaddingY;
  final depths = levels.keys.toList()..sort();
  for (var d = 0; d < depths.length; d++) {
    if (d > 0) y += _treeLevelGap;
    final levelNodes = levels[depths[d]]!;
    for (var start = 0; start < levelNodes.length; start += columns) {
      if (start > 0) y += _treeRowGap;
      final row = levelNodes.sublist(start, math.min(start + columns, levelNodes.length));
      final rowWidth = row.length * nodeWidth + (row.length - 1) * _treeGapX;
      final startX = (width - rowWidth) / 2;
      final rowExtra = row.fold<double>(0, (value, node) => math.max(value, extraHeightById[node['id']?.toString() ?? ''] ?? 0));
      for (var i = 0; i < row.length; i++) {
        final id = row[i]['id']?.toString() ?? '';
        final ownExtra = extraHeightById[id] ?? 0;
        heights[id] = nodeHeight + ownExtra;
        positions[id] = Offset(startX + i * (nodeWidth + _treeGapX), y + (rowExtra - ownExtra) / 2);
      }
      y += nodeHeight + rowExtra;
    }
  }

  return SkillTreeLayout(
    width: width,
    height: math.max(y + _treePaddingY, minHeight).toDouble(),
    nodeWidth: nodeWidth,
    nodeHeight: nodeHeight,
    columns: columns,
    positions: positions,
    nodeHeights: heights,
  );
}

class _SkillNodeCard extends StatelessWidget {
  final Map<String, dynamic> node;
  final _NodeState state;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool compact;

  /// Cor do ramo (vários ramos); null = cores de sempre.
  final Color? accent;

  /// Funções ligadas no sistema: Tipos (selo/tamanho) e Aprimoramento ("2/3").
  final bool tiers;
  final bool ranks;

  const _SkillNodeCard({
    required this.node,
    required this.state,
    required this.icon,
    required this.onTap,
    required this.onToggle,
    this.compact = false,
    this.accent,
    this.tiers = true,
    this.ranks = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = state == _NodeState.unlocked;
    final available = state == _NodeState.available;
    final closed = state == _NodeState.closed;
    final borderColor = unlocked ? (accent ?? scheme.primary) : available ? (accent ?? scheme.secondary) : scheme.outlineVariant;
    final stateLabel = unlocked ? 'Desbloqueada' : available ? 'Disponível' : closed ? 'Fechada' : 'Bloqueada';
    final level = (node['level'] as num?)?.toInt();
    final label = skillNodeCardLabel(node, state, ranks: ranks);
    final name = node['name']?.toString() ?? 'Habilidade';
    final tier = tiers ? nodeTier(node) : 'talento';
    final badge = tier == 'talento'
        ? null
        : Container(
            key: ValueKey('skill-node-tier-${nodeId(node)}'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: borderColor.withValues(alpha: .8)), borderRadius: BorderRadius.circular(6)),
            child: Text(skillTreeTierLabel(tier), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: borderColor, fontSize: 10)),
          );

    Widget frame(Widget content, double radius) {
      // Talento: o cartão de sempre. Façanha: borda dupla. Lenda: borda dupla
      // na cor dourada da paleta e brilho suave estático (sem animação).
      final outerWidth = tier == 'lenda' ? 2.5 : (unlocked ? 2.0 : 1.0);
      Widget card = Material(
        color: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor.withValues(alpha: unlocked ? .9 : .55), width: outerWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: tier == 'talento'
              ? content
              : Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius - 3),
                    border: Border.all(
                      color: (tier == 'lenda' ? AbyssPalette.of(context).goldLight : borderColor).withValues(alpha: unlocked ? .75 : .4),
                    ),
                  ),
                  child: content,
                ),
        ),
      );
      if (tier == 'lenda') {
        card = DecoratedBox(
          key: ValueKey('skill-node-lenda-${nodeId(node)}'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [BoxShadow(color: (accent ?? AbyssPalette.of(context).gold).withValues(alpha: unlocked ? .35 : .15), blurRadius: 12)],
          ),
          child: card,
        );
      }
      // Fechada pela escolha: aparência apagada.
      return closed ? Opacity(opacity: .5, child: card) : card;
    }

    if (compact) {
      // Cartão estreito (várias colunas): sem cadeado; desbloquear/bloquear
      // fica na folha de detalhes que abre ao tocar.
      final small = skillNodeCompactLabel(node, ranks: ranks);
      return Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: level == null ? '$name, $stateLabel' : '$name, nível $level, $stateLabel',
        onTap: onTap,
        child: frame(
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (badge != null) ...[badge, const SizedBox(height: 2)],
                Icon(icon, color: borderColor, size: 18),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, height: 1.15),
                  ),
                ),
                if (small != null) ...[
                  const SizedBox(height: 2),
                  Text(small, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: borderColor, fontSize: 10)),
                ],
              ],
            ),
          ),
          14,
        ),
      );
    }

    return frame(
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 7),
        child: Row(
          children: [
            Icon(icon, color: borderColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[badge, const SizedBox(height: 3)],
                  Flexible(
                    child: Text(
                      node['name']?.toString() ?? 'Habilidade',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: borderColor)),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: unlocked ? (ranks && nodeMaxRank(node) > 1 ? 'Aprimorar ou reduzir' : 'Bloquear') : available ? 'Desbloquear' : closed ? 'Fechada pela escolha' : 'Requer pré-requisito',
              onPressed: unlocked || available ? onToggle : (closed ? onTap : null),
              icon: Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_outline, size: 18),
            ),
          ],
        ),
      ),
      16,
    );
  }
}

class _SkillTreePainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final Map<String, Offset> positions;
  final Map<String, double> heights;
  final Map<String, _NodeState> states;
  final double nodeWidth;
  final double nodeHeight;
  final Color activeColor;
  final Color availableColor;
  final Color lockedColor;
  final Color orColor;
  final bool showExclusive;

  const _SkillTreePainter({
    required this.nodes,
    required this.positions,
    required this.heights,
    required this.states,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.activeColor,
    required this.availableColor,
    required this.lockedColor,
    required this.orColor,
    this.showExclusive = true,
  });

  double _height(String id) => heights[id] ?? nodeHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      final id = node['id']?.toString() ?? '';
      final parentId = (node['parentId'] ?? '').toString();
      if (parentId.isEmpty) continue;
      final parent = positions[parentId];
      final child = positions[id];
      if (parent == null || child == null) continue;

      final state = states[id] ?? _NodeState.locked;
      final color = state == _NodeState.unlocked
          ? activeColor
          : state == _NodeState.available
              ? availableColor
              : lockedColor;
      final paint = Paint()
        ..color = color.withValues(alpha: state == _NodeState.locked || state == _NodeState.closed ? .38 : .75)
        ..strokeWidth = state == _NodeState.unlocked ? 3 : 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final start = Offset(parent.dx + nodeWidth / 2, parent.dy + _height(parentId));
      final end = Offset(child.dx + nodeWidth / 2, child.dy);
      final middleY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, middleY, end.dx, middleY, end.dx, end.dy);
      canvas.drawPath(path, paint);
    }

    // Escolha exclusiva: um "OU" discreto entre os nós do mesmo grupo.
    if (!showExclusive) return;
    final groups = <String, List<String>>{};
    for (final node in nodes) {
      final group = nodeGroup(node);
      final id = nodeId(node);
      if (group.isNotEmpty && positions.containsKey(id)) groups.putIfAbsent(group, () => []).add(id);
    }
    final dash = Paint()
      ..color = orColor.withValues(alpha: .5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final ids in groups.values) {
      ids.sort((a, b) => positions[a]!.dx.compareTo(positions[b]!.dx));
      for (var i = 0; i + 1 < ids.length; i++) {
        final a = positions[ids[i]]!;
        final b = positions[ids[i + 1]]!;
        final from = Offset(a.dx + nodeWidth / 2, a.dy + _height(ids[i]) + 6);
        final to = Offset(b.dx + nodeWidth / 2, b.dy + _height(ids[i + 1]) + 6);
        final distance = (to - from).distance;
        final steps = (distance / 6).floor();
        for (var s = 0; s < steps; s += 2) {
          canvas.drawLine(Offset.lerp(from, to, s / steps)!, Offset.lerp(from, to, math.min(1.0, (s + 1) / steps))!, dash);
        }
        final painter = TextPainter(
          text: TextSpan(text: 'OU', style: TextStyle(color: orColor, fontSize: 9, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        final mid = Offset.lerp(from, to, .5)!;
        painter.paint(canvas, mid - Offset(painter.width / 2, -1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkillTreePainter oldDelegate) => true;
}

/// Ramos da árvore: criar, renomear, escolher a cor e apagar (os nós do ramo
/// apagado vão para "Geral"). Sem diálogos: tudo na própria lista.
class _SkillTreeBranchesScreen extends StatelessWidget {
  final String characterId;
  const _SkillTreeBranchesScreen({required this.characterId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final character = state.characters.where((c) => c.id == characterId).firstOrNull;
    if (character == null) return const Scaffold(body: Center(child: Text('Ficha não encontrada.')));
    Future<void> save() => context.read<AppState>().updateCharacter(character);
    return Scaffold(
      appBar: AppBar(title: const Text('Ramos da árvore')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          addSkillTreeBranch(character);
          save();
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo ramo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(
            'Cada ramo junta habilidades com um nome e uma cor. As sem ramo ficam em "Geral".',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (character.skillTreeBranches.isEmpty) const Text('Nenhum ramo ainda.'),
          for (final branch in character.skillTreeBranches)
            Card(
              key: ValueKey('branch-${branch['id']}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                child: Row(children: [
                  PopupMenuButton<int>(
                    tooltip: 'Cor do ramo',
                    icon: Icon(Icons.circle, color: branchColor(branch)),
                    onSelected: (color) {
                      branch['color'] = color;
                      save();
                    },
                    itemBuilder: (_) => [
                      for (final color in skillTreeBranchColors)
                        PopupMenuItem(value: color.toARGB32(), child: Icon(Icons.circle, color: color)),
                    ],
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('branch-name-${branch['id']}'),
                      initialValue: branch['name']?.toString() ?? '',
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Nome do ramo'),
                      onChanged: (value) {
                        branch['name'] = value.trim().isEmpty ? 'Ramo' : value.trim();
                        save();
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Apagar ramo',
                    onPressed: () {
                      removeSkillTreeBranch(character, branch['id']?.toString() ?? '');
                      save();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ramo apagado. As habilidades dele foram para "Geral".')));
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
