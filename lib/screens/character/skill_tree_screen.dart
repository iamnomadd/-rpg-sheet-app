import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../services/skill_tree_templates.dart';
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
  Character? _character(AppState state) {
    for (final character in state.characters) {
      if (character.id == widget.characterId) return character;
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

  bool _isAvailable(Character character, Map<String, dynamic> node) {
    final parentId = (node['parentId'] ?? '').toString();
    if (parentId.isEmpty) return true;
    for (final parent in character.skillTree) {
      if (parent['id']?.toString() == parentId) return parent['unlocked'] == true;
    }
    return true;
  }

  Future<void> _openEditor(Character character, {Map<String, dynamic>? node}) async {
    final editing = node != null;
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

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editing ? 'Editar habilidade da árvore' : 'Nova habilidade da árvore'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(textCapitalization: TextCapitalization.sentences, 
                  controller: name,
                  autofocus: !editing,
                  decoration: const InputDecoration(labelText: 'Nome'),
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final trimmed = name.text.trim();
                if (trimmed.isEmpty) return;
                Navigator.pop(dialogContext, {
                  'name': trimmed,
                  'description': description.text.trim(),
                  'parentId': parentId,
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    description.dispose();
    if (result == null) return;

    if (editing) {
      node['name'] = result['name'];
      node['description'] = result['description'];
      node['parentId'] = result['parentId'];
    } else {
      var level = 1;
      final chosenParentId = result['parentId'] ?? '';
      if (chosenParentId.isNotEmpty) {
        for (final candidate in character.skillTree) {
          if (candidate['id']?.toString() == chosenParentId) {
            level = ((candidate['level'] as num?)?.toInt() ?? 0) + 1;
            break;
          }
        }
      }
      character.skillTree.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': result['name'],
        'description': result['description'],
        'parentId': result['parentId'],
        'level': level,
        'unlocked': false,
      });
    }
    await context.read<AppState>().updateCharacter(character);
    if (mounted) setState(() {});
  }

  Future<void> _generateTemplate(Character character) async {
    final generated = SkillTreeTemplates.forClass(character.className);
    if (generated.isEmpty || character.skillTree.isNotEmpty) return;
    character.skillTree = generated;
    await context.read<AppState>().updateCharacter(character);
    if (mounted) setState(() {});
  }

  Future<void> _toggle(Character character, Map<String, dynamic> node) async {
    final unlocked = node['unlocked'] == true;
    if (!unlocked && !_isAvailable(character, node)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desbloqueie primeiro a habilidade anterior deste ramo.')),
      );
      return;
    }
    node['unlocked'] = !unlocked;
    await context.read<AppState>().updateCharacter(character);
    if (mounted) setState(() {});
  }

  Future<void> _delete(Character character, Map<String, dynamic> node) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir habilidade?'),
        content: Text('Excluir "${node['name'] ?? 'Habilidade'}"? Os ramos ligados a ela voltarão para o início da árvore.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (accepted != true) return;

    final id = node['id']?.toString() ?? '';
    character.skillTree.removeWhere((candidate) => candidate['id']?.toString() == id);
    for (final candidate in character.skillTree) {
      if (candidate['parentId']?.toString() == id) candidate['parentId'] = '';
    }
    await context.read<AppState>().updateCharacter(character);
    if (mounted) setState(() {});
  }

  Future<void> _showNode(Character character, Map<String, dynamic> node) async {
    final description = node['description']?.toString().trim() ?? '';
    final unlocked = node['unlocked'] == true;
    final available = _isAvailable(character, node);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(unlocked ? Icons.lock_open_rounded : available ? Icons.radio_button_unchecked : Icons.lock_outline),
                  const SizedBox(width: 10),
                  Expanded(child: Text(node['name']?.toString() ?? 'Habilidade', style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
              const SizedBox(height: 10),
              if (node['level'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Nível ${node['level']}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
              ],
              Text(description.isEmpty ? 'Sem descrição.' : description),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: available || unlocked
                          ? () {
                              Navigator.pop(sheetContext);
                              _toggle(character, node);
                            }
                          : null,
                      icon: Icon(unlocked ? Icons.lock_outline : Icons.lock_open_outlined),
                      label: Text(unlocked ? 'Bloquear' : 'Desbloquear'),
                    ),
                  ),
                  const SizedBox(width: 8),
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

  /// Maior crescimento de texto entre os cartões (nas larguras do cartão).
  double _nodeTextGrowth(BuildContext context, Character character, SkillTreeLayout layout) {
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    final key = <Object?>[
      layout.compact,
      layout.nodeWidth,
      MediaQuery.textScalerOf(context),
      labelSmall,
      for (final node in character.skillTree) ...[node['name']?.toString(), (node['level'] as num?)?.toInt(), node['unlocked'] == true],
    ];
    final cached = _growthKey;
    if (cached != null && listEquals(cached, key)) return _growthValue;
    skillTreeTextGrowthComputations++;
    var extra = 0.0;
    for (final node in character.skillTree) {
      final name = node['name']?.toString() ?? 'Habilidade';
      final level = (node['level'] as num?)?.toInt();
      double growth;
      if (layout.compact) {
        final width = math.max(1.0, layout.nodeWidth - 10);
        growth = textGrowth(context, name, const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, height: 1.15), maxWidth: width, maxLines: 3) +
            (level == null ? 0 : textGrowth(context, 'Nv $level', labelSmall?.copyWith(fontSize: 10), maxWidth: width));
      } else {
        // Coluna do texto: cartão − padding (16) − ícone (24) − espaço (8) − cadeado (40).
        final width = math.max(1.0, layout.nodeWidth - 88);
        final state = node['unlocked'] == true ? 'Desbloqueada' : 'Disponível';
        growth = textGrowth(context, name, const TextStyle(fontWeight: FontWeight.w700), maxWidth: width, maxLines: 2) +
            textGrowth(context, level == null ? state : 'Nível $level • $state', labelSmall, maxWidth: width);
      }
      extra = math.max(extra, growth);
    }
    _growthKey = key;
    return _growthValue = extra;
  }

  Widget _treeCanvas(Character character) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = computeSkillTreeLayout(character.skillTree, constraints.maxWidth);
        // 0 com texto 1.0 (a árvore fica igual); com texto maior, o cartão
        // cresce o mesmo que o seu texto, para nada estourar.
        final extra = _nodeTextGrowth(context, character, base);
        final layout = extra > 0 ? computeSkillTreeLayout(character.skillTree, constraints.maxWidth, extraNodeHeight: extra) : base;
        final stateById = <String, _NodeState>{};
        for (final node in character.skillTree) {
          final id = node['id']?.toString() ?? '';
          stateById[id] = node['unlocked'] == true
              ? _NodeState.unlocked
              : _isAvailable(character, node)
                  ? _NodeState.available
                  : _NodeState.locked;
        }
        // Rolagem só na vertical: o deslize horizontal fica livre para o
        // PageView das abas da ficha.
        return SingleChildScrollView(
          key: const ValueKey('skill-tree-scroll'),
            child: SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SkillTreePainter(
                        nodes: character.skillTree,
                        positions: layout.positions,
                        nodeWidth: layout.nodeWidth,
                        nodeHeight: layout.nodeHeight,
                        states: stateById,
                        activeColor: scheme.primary,
                        availableColor: scheme.secondary,
                        lockedColor: scheme.outlineVariant,
                      ),
                    ),
                  ),
                  for (final node in character.skillTree.where(
                    (candidate) => layout.positions.containsKey(candidate['id']?.toString() ?? ''),
                  ))
                    Positioned(
                      left: layout.positions[node['id']?.toString() ?? '']!.dx,
                      top: layout.positions[node['id']?.toString() ?? '']!.dy,
                      width: layout.nodeWidth,
                      height: layout.nodeHeight,
                      child: _SkillNodeCard(
                        node: node,
                        state: stateById[node['id']?.toString() ?? ''] ?? _NodeState.locked,
                        icon: themedIcon(state.themeId, 'skillTree'),
                        compact: layout.compact,
                        onTap: () => _showNode(character, node),
                        onToggle: () => _toggle(character, node),
                      ),
                    ),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _body(Character character) {
    final unlocked = character.skillTree.where((node) => node['unlocked'] == true).length;
    final themeId = context.watch<AppState>().themeId;
    final templateLabel = SkillTreeTemplates.templateLabelForClass(character.className);
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

enum _NodeState { unlocked, available, locked }

/// Posições calculadas da árvore (nada disso é gravado na ficha).
class SkillTreeLayout {
  final double width;
  final double height;
  final double nodeWidth;
  final double nodeHeight;
  final int columns;
  final Map<String, Offset> positions;

  const SkillTreeLayout({
    required this.width,
    required this.height,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.columns,
    required this.positions,
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
const _treePaddingX = 16.0;
const _treePaddingY = 24.0;
const _treeGapX = 10.0;
const _treeRowGap = 14.0;
const _treeLevelGap = 52.0;

/// Layout da árvore para a largura disponível: nunca passa da largura, no
/// máximo [skillTreeMaxColumns] cartões lado a lado; nós a mais de um mesmo
/// nível descem para a linha seguinte (cada linha centralizada). A profundidade
/// vem de `parentId` (ciclo ou pai inexistente contam como raiz).
SkillTreeLayout computeSkillTreeLayout(List<Map<String, dynamic>> nodes, double viewportWidth, {double extraNodeHeight = 0}) {
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
      for (var i = 0; i < row.length; i++) {
        positions[row[i]['id']?.toString() ?? ''] = Offset(startX + i * (nodeWidth + _treeGapX), y);
      }
      y += nodeHeight;
    }
  }

  return SkillTreeLayout(
    width: width,
    height: math.max(y + _treePaddingY, 250.0).toDouble(),
    nodeWidth: nodeWidth,
    nodeHeight: nodeHeight,
    columns: columns,
    positions: positions,
  );
}

class _SkillNodeCard extends StatelessWidget {
  final Map<String, dynamic> node;
  final _NodeState state;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool compact;

  const _SkillNodeCard({
    required this.node,
    required this.state,
    required this.icon,
    required this.onTap,
    required this.onToggle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = state == _NodeState.unlocked;
    final available = state == _NodeState.available;
    final borderColor = unlocked ? scheme.primary : available ? scheme.secondary : scheme.outlineVariant;
    final stateLabel = unlocked ? 'Desbloqueada' : available ? 'Disponível' : 'Bloqueada';
    final level = (node['level'] as num?)?.toInt();
    final label = level == null ? stateLabel : 'Nível $level • $stateLabel';
    final name = node['name']?.toString() ?? 'Habilidade';

    if (compact) {
      // Cartão estreito (várias colunas): sem cadeado; desbloquear/bloquear
      // fica na folha de detalhes que abre ao tocar.
      return Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: level == null ? '$name, $stateLabel' : '$name, nível $level, $stateLabel',
        onTap: onTap,
        child: Material(
          color: Theme.of(context).cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor.withValues(alpha: unlocked ? .9 : .55), width: unlocked ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 6, 5, 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  if (level != null) ...[
                    const SizedBox(height: 2),
                    Text('Nv $level', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: borderColor, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withOpacity(unlocked ? .9 : .55), width: unlocked ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                    Text(
                      node['name']?.toString() ?? 'Habilidade',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: borderColor)),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: unlocked ? 'Bloquear' : available ? 'Desbloquear' : 'Requer pré-requisito',
                onPressed: unlocked || available ? onToggle : null,
                icon: Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_outline, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillTreePainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final Map<String, Offset> positions;
  final Map<String, _NodeState> states;
  final double nodeWidth;
  final double nodeHeight;
  final Color activeColor;
  final Color availableColor;
  final Color lockedColor;

  const _SkillTreePainter({
    required this.nodes,
    required this.positions,
    required this.states,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.activeColor,
    required this.availableColor,
    required this.lockedColor,
  });

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
        ..color = color.withOpacity(state == _NodeState.locked ? .38 : .75)
        ..strokeWidth = state == _NodeState.unlocked ? 3 : 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final start = Offset(parent.dx + nodeWidth / 2, parent.dy + nodeHeight);
      final end = Offset(child.dx + nodeWidth / 2, child.dy);
      final middleY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, middleY, end.dx, middleY, end.dx, end.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkillTreePainter oldDelegate) => true;
}
