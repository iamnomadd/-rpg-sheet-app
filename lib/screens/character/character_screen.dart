import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/cloud_service.dart';
import 'skill_tree_screen.dart';
import 'player_turn_banner.dart';
import '../../services/rpg_file_service.dart';
import '../../app/theme.dart';
import '../../app/condition_presets.dart';
import '../../services/skill_tree_templates.dart';
import '../../utils/resource_math.dart';
import '../../utils/spell_icon.dart';


Future<int?> _askResourceAmount(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  String? errorText;
  final result = await showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, errorText: errorText),
          onSubmitted: (_) {
            final amount = int.tryParse(controller.text.trim());
            if (amount == null || amount <= 0) {
              setDialogState(() => errorText = 'Informe um valor maior que zero.');
              return;
            }
            Navigator.pop(dialogContext, amount);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) {
                setDialogState(() => errorText = 'Informe um valor maior que zero.');
                return;
              }
              Navigator.pop(dialogContext, amount);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

class CharacterScreen extends StatefulWidget {
  final String characterId;

  const CharacterScreen({super.key, required this.characterId});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  int tab = 0;
  late final PageController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = PageController(initialPage: tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().publishExistingShareCodes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Character? _findCharacter(AppState state) {
    for (final c in state.characters) {
      if (c.id == widget.characterId) return c;
    }
    return null;
  }

  RpgSystem? _findSystem(AppState state, Character character) {
    for (final system in state.systems) {
      if (system.id == character.systemId) return system;
    }
    return state.systems.isNotEmpty ? state.systems.first : null;
  }

  Widget _compactLines(List<String> lines, String emptyText) {
    if (lines.isEmpty) {
      return Text(emptyText);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
    );
  }

  Future<void> _editBasic() async {
    final state = context.read<AppState>();
    final c = _findCharacter(state);
    if (c == null) return;

    final name = TextEditingController(text: c.name);
    final player = TextEditingController(text: c.player);
    final originalClassName = c.className;
    final className = TextEditingController(text: c.className);
    final race = TextEditingController(text: c.race);
    final background = TextEditingController(text: c.background);
    final level = TextEditingController(text: c.level.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dados do personagem'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 10),
              TextField(controller: player, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Jogador')),
              const SizedBox(height: 10),
              TextField(controller: className, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Classe')),
              const SizedBox(height: 10),
              TextField(controller: race, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Raça')),
              const SizedBox(height: 10),
              TextField(controller: background, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Antecedente')),
              const SizedBox(height: 10),
              TextField(controller: level, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nível')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (result == true) {
      c.name = name.text.trim().isEmpty ? c.name : name.text.trim();
      c.player = player.text.trim();
      c.className = className.text.trim();
      c.race = race.text.trim();
      c.background = background.text.trim();
      c.level = (int.tryParse(level.text) ?? c.level).clamp(1, 999);
      final classChanged = originalClassName.trim().toLowerCase() != c.className.trim().toLowerCase();
      if (classChanged && c.skillTree.isEmpty && SkillTreeTemplates.hasTemplate(c.className)) {
        c.skillTree = SkillTreeTemplates.forClass(c.className);
      }
      await state.updateCharacter(c);
      if (mounted) setState(() {});
    }

    name.dispose(); player.dispose(); className.dispose(); race.dispose(); background.dispose(); level.dispose();
  }

  Future<void> _editResource(Character c, String name) async {
    final state = context.read<AppState>();
    final current = c.resourceValues[name] ?? 0;
    final maximum = c.resourceMaxValues[name] ?? 0;
    final value = TextEditingController(text: current.toString());
    final max = TextEditingController(text: maximum.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Configurar $name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor atual')),
          const SizedBox(height: 10),
          TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor máximo')),
          if (name.toLowerCase() == 'vida') ...[
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Ajuste rápido', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.heart_broken_outlined),
                  label: const Text('Receber dano'),
                  onPressed: () async {
                    final amount = await _askResourceAmount(context, title: 'Receber dano', label: 'Dano recebido');
                    if (amount == null) return;
                    final base = int.tryParse(value.text) ?? current;
                    final limit = (int.tryParse(max.text) ?? maximum).clamp(0, 999999).toInt();
                    value.text = applyResourceDelta(current: base, maximum: limit, delta: -amount).toString();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Curar'),
                  onPressed: () async {
                    final amount = await _askResourceAmount(context, title: 'Curar', label: 'Vida recuperada');
                    if (amount == null) return;
                    final base = int.tryParse(value.text) ?? current;
                    final limit = (int.tryParse(max.text) ?? maximum).clamp(0, 999999).toInt();
                    value.text = applyResourceDelta(current: base, maximum: limit, delta: amount).toString();
                  },
                ),
              ),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (result == true) {
      final newMax = (int.tryParse(max.text) ?? maximum).clamp(0, 999999);
      c.resourceMaxValues[name] = newMax;
      c.resourceValues[name] = (int.tryParse(value.text) ?? current).clamp(0, newMax);
      if (name.toLowerCase() == 'vida') { c.maxHp = newMax; c.hp = c.resourceValues[name]!; }
      if (name.toLowerCase() == 'energia') { c.maxEnergy = newMax; c.energy = c.resourceValues[name]!; }
      await state.updateCharacter(c);
      if (mounted) setState(() {});
    }
    value.dispose(); max.dispose();
  }

  Future<void> _changeResource(Character c, String name, int delta) async {
    final state = context.read<AppState>();
    final max = c.resourceMaxValues[name] ?? 0;
    final current = c.resourceValues[name] ?? 0;
    c.resourceValues[name] = applyResourceDelta(current: current, maximum: max, delta: delta);
    if (name.toLowerCase() == 'vida') c.hp = c.resourceValues[name]!;
    if (name.toLowerCase() == 'energia') c.energy = c.resourceValues[name]!;
    await state.updateCharacter(c);
    if (mounted) setState(() {});
  }

  Future<void> _editAttribute(Character c, String name) async {
    final controller = TextEditingController(text: (c.attributes[name] ?? 0).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $name'),
        content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('Salvar')),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    c.attributes[name] = result;
    await context.read<AppState>().updateCharacter(c);
    if (mounted) setState(() {});
  }

  Future<void> _editSection(Character c, String name) async {
    final controller = TextEditingController(text: c.sectionNotes[name] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(name),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences, minLines: 5, maxLines: 12, decoration: const InputDecoration(hintText: 'Escreva aqui...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    c.sectionNotes[name] = result;
    await context.read<AppState>().updateCharacter(c);
    if (mounted) setState(() {});
  }

  Future<void> _toggleSkill(Character c, String skill) async {
    if (c.skills.contains(skill)) { c.skills.remove(skill); } else { c.skills.add(skill); }
    await context.read<AppState>().updateCharacter(c);
    if (mounted) setState(() {});
  }

  Future<void> _reorderGeneral(Character c, int oldIndex, int newIndex) async {
    const validIds = ['sessionOverview', 'combatCharacter', 'health', 'energy', 'conditions', 'quickActions', 'attributes', 'abilities', 'inventory'];
    final order = <String>[];
    for (final id in c.generalOrder) {
      if (validIds.contains(id) && !order.contains(id)) order.add(id);
    }
    for (final id in validIds) {
      if (!order.contains(id)) order.add(id);
    }
    if (newIndex > oldIndex) newIndex -= 1;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    c.generalOrder = order;
    await context.read<AppState>().updateCharacter(c);
    if (mounted) setState(() {});
  }


  static const _defaultTabOrder = ['general', 'attributesResources', 'abilities', 'skills', 'inventory', 'skillTree', 'sections'];

  List<String> _normalizedTabOrder(Character c) {
    final order = <String>[];
    for (final id in c.sheetTabOrder) {
      if (_defaultTabOrder.contains(id) && !order.contains(id)) order.add(id);
    }
    for (final id in _defaultTabOrder) {
      if (!order.contains(id)) order.add(id);
    }
    return order;
  }

  String _tabLabel(String id) => switch (id) {
    'general' => 'Em Cena',
    'attributesResources' => 'Status',
    'abilities' => 'Habilidades',
    'actions' => 'Ações',
    'skillTree' => 'Árvore',
    'skills' => 'Perícias',
    'inventory' => 'Inventário',
    'sections' => 'Seções',
    _ => id,
  };

  Widget _tabPage(String id, Character c, RpgSystem system) => switch (id) {
    'general' => _GeneralTab(character: c, system: system, onReorder: _reorderGeneral, onChangeResource: _changeResource, onEditResource: _editResource),
    'attributesResources' => _AttributesResourcesTab(character: c, system: system, onEditAttribute: _editAttribute, onChangeResource: _changeResource, onEditResource: _editResource),
    'abilities' => _CharacterItemsTab(character: c, items: c.abilities, descriptions: c.abilityDescriptions, details: c.abilityDetails, title: 'Habilidades', singular: 'habilidade', hint: 'Nome da habilidade', iconRole: 'abilities', isAbility: true),
    'skillTree' => SkillTreeScreen(characterId: c.id, embedded: true),
    'skills' => _SkillsTab(character: c, system: system, onToggle: _toggleSkill),
    'inventory' => _CharacterItemsTab(character: c, items: c.inventory, descriptions: c.inventoryDescriptions, details: c.inventoryDetails, title: 'Inventário', singular: 'item', hint: 'Nome do item', iconRole: 'inventory', isAbility: false),
    'sections' => _SectionsTab(character: c, system: system, onEdit: _editSection),
    _ => const SizedBox.shrink(),
  };

  Future<void> _customizeSheet(Character c) async {
    var draft = _normalizedTabOrder(c);
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('Personalizar ficha'),
                  subtitle: const Text('Arraste para escolher a ordem das abas. A aba Resumo também pode ser reposicionada.'),
                  trailing: TextButton(
                    onPressed: () => setSheetState(() => draft = List<String>.from(_defaultTabOrder)),
                    child: const Text('Restaurar'),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: draft.length,
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = draft.removeAt(oldIndex);
                        draft.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final id = draft[index];
                      return ListTile(
                        key: ValueKey('sheet-tab-$id'),
                        leading: themedCharacterTabIcon(context.read<AppState>().themeId, id, size: 22, color: Theme.of(context).colorScheme.primary),
                        title: Text(_tabLabel(id)),
                        trailing: const Icon(Icons.drag_handle),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, draft),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar organização'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == null) return;
    c.sheetTabOrder = saved;
    tab = 0;
    if (_tabController.hasClients) _tabController.jumpToPage(0);
    await context.read<AppState>().updateCharacter(c);
    if (mounted) setState(() {});
  }

  Future<void> _manageMasterRequests(BuildContext context) async {
    try {
      final session = await CloudService.ensureSession();
      final requests = await CloudService.incomingLinkRequests(session);
      if (!context.mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitações de Mestre'),
        content: SizedBox(width: double.maxFinite, child: requests.isEmpty
          ? const Text('Nenhuma solicitação pendente.')
          : ListView(shrinkWrap: true, children: requests.map((r) => ListTile(
              leading: const Icon(Icons.link),
              title: Text('Campanha ${r['campaign_id']}'),
              subtitle: Text('Código ${r['share_code']}'),
              trailing: Wrap(children: [
                IconButton(tooltip: 'Recusar', icon: const Icon(Icons.close), onPressed: () async { await CloudService.updateLinkStatus(session, '${r['id']}', 'rejected'); if (dialogContext.mounted) Navigator.pop(dialogContext); }),
                IconButton(tooltip: 'Aprovar', icon: const Icon(Icons.check), onPressed: () async { await CloudService.updateLinkStatus(session, '${r['id']}', 'approved'); if (dialogContext.mounted) Navigator.pop(dialogContext); }),
              ]),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar'))],
      ));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível consultar solicitações: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = _findCharacter(state);
    if (c == null) return const Scaffold(body: Center(child: Text('Ficha não encontrada.')));
    final system = _findSystem(state, c);
    if (system == null) return const Scaffold(body: Center(child: Text('Sistema não encontrado.')));
    final reduceMotion = state.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;

    // Garante que fichas antigas recebam os campos do sistema atual.
    for (final attribute in system.attributes) { c.attributes.putIfAbsent(attribute, () => 10); }
    for (final resource in system.resources) {
      c.resourceValues.putIfAbsent(resource, () => 0);
      c.resourceMaxValues.putIfAbsent(resource, () => 0);
    }
    for (final section in system.sections) { c.sectionNotes.putIfAbsent(section, () => ''); }

    return Scaffold(
      bottomNavigationBar: PlayerTurnBanner(character: c),
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            tooltip: 'Solicitações de Mestre',
            icon: const Icon(Icons.how_to_reg_outlined),
            onPressed: () => _manageMasterRequests(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.ios_share),
            onSelected: (value) async {
              try {
                if (value == 'master') {
                  final state = context.read<AppState>();
                  if (c.shareCode.isEmpty) {
                    final raw = c.id.replaceAll('-', '').toUpperCase();
                    c.shareCode = '${raw.substring(0, 4)}-${raw.substring(4, 8)}';
                    await state.updateCharacter(c);
                  }
                  final session = await CloudService.ensureSession();
                  await CloudService.publishCharacter(session, c.toJson(), c.shareCode);
                  if (!context.mounted) return;
                  await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Código da ficha'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Passe este código ao Mestre. O vínculo só será concluído após sua aprovação.'), const SizedBox(height: 16), SelectableText(c.shareCode, style: Theme.of(context).textTheme.headlineMedium)]), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))]));
                } else if (value == 'file') {
                  await RpgFileService.exportCharacter(c, system);
                } else if (value == 'summary') {
                  await RpgFileService.shareCharacterSummary(c, system);
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Não foi possível compartilhar: $e')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'master', child: ListTile(leading: Icon(Icons.link), title: Text('Compartilhar com Mestre'), subtitle: Text('Gera o código único desta ficha.'))),
              PopupMenuItem(
                value: 'file',
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Compartilhar ficha .rpg'),
                  subtitle: Text('Outra pessoa pode importar e editar uma cópia.'),
                ),
              ),
              PopupMenuItem(
                value: 'summary',
                child: ListTile(
                  leading: Icon(Icons.text_snippet_outlined),
                  title: Text('Compartilhar resumo'),
                  subtitle: Text('Envia uma versão em texto para consulta.'),
                ),
              ),
            ],
          ),
          IconButton(onPressed: _editBasic, icon: const Icon(Icons.edit), tooltip: 'Editar dados'),
        ],
      ),
      body: Builder(
        builder: (context) {
          final order = _normalizedTabOrder(c);
          if (tab >= order.length) tab = 0;
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _Header(character: c, system: system)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CharacterTabsHeader(
                  height: 72,
                  child: Material(
                    color: state.themeId == 'parchment' ? Theme.of(context).colorScheme.surface.withOpacity(.96) : Theme.of(context).scaffoldBackgroundColor,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: state.themeId == 'vampire'
                              ? const Color(0xFFB7211C)
                              : Theme.of(context).colorScheme.outlineVariant.withOpacity(.32),
                        )),
                      ),
                      child: SizedBox(
                        height: 72,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: order.asMap().entries.map((entry) {
                            final index = entry.key, id = entry.value, selected = tab == index;
                            final colors = Theme.of(context).colorScheme;
                            final vampire = state.themeId == 'vampire';
                            return InkWell(
                              onTap: () {
                                final previousTab = tab;
                                setState(() => tab = index);
                                if (reduceMotion) {
                                  _tabController.jumpToPage(index);
                                } else {
                                  final distance = (index - previousTab).abs();
                                  _tabController.animateToPage(
                                    index,
                                    duration: Duration(milliseconds: (380 + (distance - 1).clamp(0, 3) * 40).toInt()),
                                    curve: Curves.easeInOutCubic,
                                  );
                                }
                              },
                              child: AnimatedContainer(
                                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(
                                    color: selected ? colors.primary : Colors.transparent,
                                    width: selected ? 4 : 4,
                                  )),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    themedCharacterTabIcon(
                                      state.themeId,
                                      id,
                                      size: 22,
                                      color: vampire ? colors.primary : (selected ? colors.primary : colors.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _tabLabel(id),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: selected ? colors.primary : colors.onSurface,
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            body: PageView(
              controller: _tabController,
              allowImplicitScrolling: true,
              onPageChanged: (index) { if (mounted) setState(() => tab = index); },
              children: order.map((id) => RepaintBoundary(child: _tabPage(id, c, system))).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _CharacterTabsHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _CharacterTabsHeader({required this.height, required this.child});

  @override double get minExtent => height;
  @override double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _CharacterTabsHeader oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}


class _GeneralTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, int, int) onReorder;
  final Future<void> Function(Character, String, int) onChangeResource;
  final Future<void> Function(Character, String) onEditResource;

  const _GeneralTab({
    required this.character,
    required this.system,
    required this.onReorder,
    required this.onChangeResource,
    required this.onEditResource,
  });

  Widget _compactLines(List<String> lines, String emptyText) {
    if (lines.isEmpty) return Text(emptyText);
    return Text(lines.take(5).join('\n'));
  }

  String _lifeResourceName() {
    for (final name in system.resources) {
      if (name.toLowerCase() == 'vida') return name;
    }
    return system.resources.isNotEmpty ? system.resources.first : '';
  }

  String _energyResourceName() {
    for (final name in system.resources) {
      if (name.toLowerCase() == 'energia') return name;
    }
    for (final name in system.resources) {
      if (name != _lifeResourceName()) return name;
    }
    return '';
  }

  Widget _resourceSummaryCard(
    BuildContext context, {
    required String keyId,
    required String title,
    required String resourceName,
    required bool secondary,
  }) {
    final theme = Theme.of(context);
    final value = resourceName.isEmpty ? 0 : (character.resourceValues[resourceName] ?? 0);
    final max = resourceName.isEmpty ? 0 : (character.resourceMaxValues[resourceName] ?? 0);
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final themeId = context.watch<AppState>().themeId;
    return Card(
      key: ValueKey('general-$keyId'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(secondary ? Icons.bolt : themedIcon(themeId, 'resources')),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (resourceName.isNotEmpty) ...[
              IconButton(
                tooltip: 'Diminuir',
                visualDensity: VisualDensity.compact,
                onPressed: () => onChangeResource(character, resourceName, -1),
                icon: const Icon(Icons.remove),
              ),
              Text('$value / $max', style: theme.textTheme.titleMedium),
              IconButton(
                tooltip: 'Aumentar',
                visualDensity: VisualDensity.compact,
                onPressed: () => onChangeResource(character, resourceName, 1),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Ajustar valor',
                visualDensity: VisualDensity.compact,
                onPressed: () => onEditResource(character, resourceName),
                icon: const Icon(Icons.tune, size: 20),
              ),
            ],
          ]),
          if (resourceName.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('Nenhum recurso configurado.'),
          ],
          const SizedBox(height: 8),
          if (resourceName.isNotEmpty)
            _ThemedResourceBar(
              value: progress,
              themeId: themeId,
              secondary: secondary,
            ),
        ]),
      ),
    );
  }

  Widget _verticalSummaryItems(BuildContext context, List<String> names, Map<String, Map<String, dynamic>> details, {required bool ability}) {
    if (names.isEmpty) return Text(ability ? 'Nenhuma habilidade.' : 'Nenhum item.');
    final compact = context.watch<AppState>().compactMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: names.take(5).map((name) {
        final d = details[name] ?? const <String, dynamic>{};
        final category = d['category']?.toString().trim().isNotEmpty == true ? d['category'].toString() : (ability ? 'Habilidade' : 'Outro');
        final damage = d['damage']?.toString().trim() ?? '';
        final qty = d['quantity']?.toString() ?? '';
        final ammo = d['ammo']?.toString() ?? '';
        final ammoMax = d['ammoMax']?.toString() ?? '';
        final cost = d['cost']?.toString() ?? '';
        final resource = d['resource']?.toString() ?? 'Energia';
        final durationType = d['durationType']?.toString() ?? '';
        final turns = d['turns']?.toString() ?? '';
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 6 : 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (damage.isNotEmpty) Text('Dano: $damage'),
            if (!ability && category == 'Consumível') Text('Quantidade: ${qty.isEmpty ? '1' : qty}'),
            if (!ability && category == 'Arma' && ammoMax.isNotEmpty) Text('Munição: ${ammo.isEmpty ? ammoMax : ammo}/$ammoMax'),
            if (ability && category == 'Magia' && cost.isNotEmpty) Text('Custo: $cost $resource'),
            if (ability && durationType == 'turns' && turns.isNotEmpty) Text('Duração: $turns turno(s)'),
            if (ability && durationType == 'instant') const Text('Duração: Instantânea'),
          ]),
        );
      }).toList(),
    );
  }


  Widget _sessionPill(BuildContext context, IconData icon, String label, {bool warning = false, bool positive = false}) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : positive ? scheme.tertiary : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _summaryCard(BuildContext context, String id) {
    final themeId = context.watch<AppState>().themeId;
    switch (id) {
      case 'sessionOverview':
        final weapons = character.inventory.where((n) => character.inventoryDetails[n]?['category'] == 'Arma').length;
        final consumables = character.inventory.where((n) => character.inventoryDetails[n]?['category'] == 'Consumível').length;
        final spells = character.abilities.where((n) => character.abilityDetails[n]?['category'] == 'Magia').length;
        final negative = character.conditions.where((n) => conditionPresetFor(n)?.positive != true).length;
        final positive = character.conditions.where((n) => conditionPresetFor(n)?.positive == true).length;
        return Card(
          key: const ValueKey('general-session-overview'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.bolt_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Sessão', style: TextStyle(fontWeight: FontWeight.w800))),
                Text('Nível ${character.level}', style: Theme.of(context).textTheme.labelLarge),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _sessionPill(context, Icons.gps_fixed, '$weapons arma${weapons == 1 ? '' : 's'}'),
                _sessionPill(context, Icons.auto_awesome_outlined, '$spells magia${spells == 1 ? '' : 's'}'),
                _sessionPill(context, Icons.local_drink_outlined, '$consumables consumível${consumables == 1 ? '' : 'is'}'),
                if (positive > 0) _sessionPill(context, Icons.add_circle_outline, '$positive positivo${positive == 1 ? '' : 's'}', positive: true),
                if (negative > 0) _sessionPill(context, Icons.warning_amber_rounded, '$negative negativo${negative == 1 ? '' : 's'}', warning: true),
              ]),
            ]),
          ),
        );
      case 'combatCharacter':
        return _ActionsTab(
          character: character,
          system: system,
          embedded: true,
          showCombat: true,
          showResources: false,
          showConditions: false,
          showQuickActions: false,
        );
      case 'conditions':
        return Card(
          key: const ValueKey('general-conditions'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _ActionsTab(
              character: character,
              system: system,
              embedded: true,
              showCombat: false,
              showResources: false,
              showConditions: true,
              showQuickActions: false,
            ),
          ),
        );
      case 'quickActions':
        return _ActionsTab(
          character: character,
          system: system,
          embedded: true,
          showCombat: false,
          showResources: false,
          showConditions: false,
          showQuickActions: true,
        );
      case 'attributes':
        return Card(
          key: const ValueKey('general-attributes'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(themedIcon(themeId, 'attributes')), const SizedBox(width: 8), const Text('Atributos', style: TextStyle(fontWeight: FontWeight.bold))]),
              const SizedBox(height: 10),
              if (system.attributes.isEmpty)
                const Text('Nenhum atributo configurado.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: system.attributes.map((name) => Chip(label: Text('$name: ${character.attributes[name] ?? 0}'))).toList(),
                ),
            ]),
          ),
        );
      case 'health':
        final resource = _lifeResourceName();
        return _resourceSummaryCard(
          context,
          keyId: 'health',
          title: resource.isEmpty ? 'Vida' : resource,
          resourceName: resource,
          secondary: false,
        );
      case 'energy':
        final resource = _energyResourceName();
        return _resourceSummaryCard(
          context,
          keyId: 'energy',
          title: resource.isEmpty ? 'Energia' : resource,
          resourceName: resource,
          secondary: true,
        );
      case 'skillTree':
        final unlocked = character.skillTree.where((node) => node['unlocked'] == true).toList();
        final names = unlocked.map((node) => node['name']?.toString() ?? 'Habilidade').where((name) => name.isNotEmpty).toList();
        return Card(
          key: const ValueKey('general-skill-tree'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(themedIcon(themeId, 'skillTree')),
                const SizedBox(width: 8),
                const Expanded(child: Text('Árvore de Habilidades', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('${unlocked.length}/${character.skillTree.length}'),
              ]),
              const SizedBox(height: 8),
              _compactLines(names, character.skillTree.isEmpty ? 'Nenhuma skill criada.' : 'Nenhuma skill desbloqueada.'),
            ]),
          ),
        );
      case 'inventory':
        final lines = character.inventory;
        return Card(
          key: const ValueKey('general-inventory'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(themedIcon(themeId, 'inventory')), const SizedBox(width: 8), const Text('Inventário', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${character.inventory.length} item(ns)')]),
              const SizedBox(height: 8),
              _verticalSummaryItems(context, lines, character.inventoryDetails, ability: false),
            ]),
          ),
        );
      case 'abilities':
        final lines = character.abilities;
        return Card(
          key: const ValueKey('general-abilities'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(themedIcon(themeId, 'abilities')), const SizedBox(width: 8), const Text('Habilidades', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${character.abilities.length}')]),
              const SizedBox(height: 8),
              _verticalSummaryItems(context, lines, character.abilityDetails, ability: true),
            ]),
          ),
        );
      default:
        return const SizedBox.shrink(key: ValueKey('general-unknown'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final validIds = const ['sessionOverview', 'combatCharacter', 'health', 'energy', 'conditions', 'quickActions', 'attributes', 'abilities', 'inventory'];
    final order = <String>[];
    for (final id in character.generalOrder) {
      if (validIds.contains(id) && !order.contains(id)) order.add(id);
    }
    for (final id in validIds) {
      if (!order.contains(id)) order.add(id);
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: order.length,
      onReorder: (oldIndex, newIndex) => onReorder(character, oldIndex, newIndex),
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final id = order[index];
        return Padding(
          key: ValueKey('general-item-$id'),
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: _summaryCard(context, id)),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.drag_handle)),
            ),
          ]),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  const _Header({required this.character, required this.system});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(character.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${character.race.isEmpty ? 'Sem raça' : character.race} • ${character.className.isEmpty ? 'Sem classe' : character.className} • Nível ${character.level}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(.42),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant.withOpacity(.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Flexible(child: Text(system.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600))),
            ]),
          ),
        ])),
      ]),
    );
  }
}

class _AttributesResourcesTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, String) onEditAttribute;
  final Future<void> Function(Character, String, int) onChangeResource;
  final Future<void> Function(Character, String) onEditResource;

  const _AttributesResourcesTab({
    required this.character,
    required this.system,
    required this.onEditAttribute,
    required this.onChangeResource,
    required this.onEditResource,
  });

  @override
  Widget build(BuildContext context) {
    final themeId = context.watch<AppState>().themeId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(themedIcon(themeId, 'attributes'), size: 22),
            const SizedBox(width: 8),
            Text('Atributos', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 10),
        if (system.attributes.isEmpty)
          const Text('Este sistema não possui atributos configurados.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: system.attributes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, index) {
              final name = system.attributes[index];
              final value = character.attributes[name] ?? 0;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onEditAttribute(character, name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 0),
                        Text(
                          '$value',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(themedIcon(themeId, 'resources')),
            const SizedBox(width: 8),
            Text('Recursos', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 10),
        if (system.resources.isEmpty)
          const Text('Este sistema não possui recursos configurados.'),
        ...system.resources.map((name) {
          final value = character.resourceValues[name] ?? 0;
          final max = character.resourceMaxValues[name] ?? 0;
          final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(name.toLowerCase() == 'vida'
                          ? themedIcon(themeId, 'resources')
                          : Icons.bolt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () => onChangeResource(character, name, -1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$value / $max'),
                      IconButton(
                        onPressed: () => onChangeResource(character, name, 1),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        onPressed: () => onEditResource(character, name),
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                  _ThemedResourceBar(
                    value: progress,
                    themeId: themeId,
                    secondary: name.toLowerCase() != 'vida',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ThemedResourceBar extends StatelessWidget {
  final double value;
  final String themeId;
  final bool secondary;

  const _ThemedResourceBar({
    required this.value,
    required this.themeId,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fillColors = themedResourceBarColors(themeId, secondary: secondary);
    final trackColor = themedResourceTrackColor(themeId);
    final scheme = Theme.of(context).colorScheme;
    final normalized = value.clamp(0.0, 1.0);

    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.45)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(.08),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * normalized;
          return Stack(
            children: [
              if (fillWidth > 0)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                  width: fillWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: fillColors),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ),
              if (themeId == 'cyberpunk' && fillWidth > 18)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CyberpunkBarPainter(progress: normalized),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CyberpunkBarPainter extends CustomPainter {
  final double progress;
  const _CyberpunkBarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final activeWidth = size.width * progress;
    final paint = Paint()
      ..color = Colors.white.withOpacity(.14)
      ..strokeWidth = 1;
    const segment = 16.0;
    for (double x = segment; x < activeWidth; x += segment) {
      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberpunkBarPainter oldDelegate) => oldDelegate.progress != progress;
}

class _SkillsTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, String) onToggle;
  const _SkillsTab({required this.character, required this.system, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Perícias do sistema', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (system.skills.isEmpty) const Text('Este sistema não possui perícias configuradas.')
      else ...system.skills.map((skill) => Card(child: CheckboxListTile(value: character.skills.contains(skill), onChanged: (_) => onToggle(character, skill), title: Text(skill), secondary: const Icon(Icons.psychology)))),
      const SizedBox(height: 16),
      if (character.skills.isNotEmpty) Text('Perícias selecionadas: ${character.skills.join(', ')}', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _SectionsTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, String) onEdit;
  const _SectionsTab({required this.character, required this.system, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text('Seções da ficha', style: Theme.of(context).textTheme.titleLarge)),
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.tune, size: 15),
          label: Text(system.name),
        ),
      ]),
      const SizedBox(height: 10),
      if (system.sections.isEmpty) const Text('Este sistema não possui seções configuradas.'),
      ...system.sections.map((section) => Card(child: ListTile(title: Text(section), subtitle: Text((character.sectionNotes[section] ?? '').isEmpty ? 'Toque para preencher.' : character.sectionNotes[section]!), trailing: const Icon(Icons.edit), onTap: () => onEdit(character, section)))),
    ]);
  }
}


class _CombatCharacter2D extends StatelessWidget {
  final Character character;
  final Animation<double> idle;
  const _CombatCharacter2D({required this.character, required this.idle});

  List<String> get _negativeStatuses => character.conditions.where((name) {
    final preset = conditionPresetFor(name);
    return preset == null || !preset.positive;
  }).toList();

  List<String> get _positiveStatuses => character.conditions.where((name) {
    final preset = conditionPresetFor(name);
    return preset?.positive == true;
  }).toList();

  bool _positiveContains(String fragment) =>
      _positiveStatuses.any((s) => s.toLowerCase().contains(fragment));

  int get _life {
    for (final entry in character.resourceValues.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'vida' || key == 'pv') return entry.value;
    }
    return character.hp;
  }

  int get _lifeMax {
    for (final entry in character.resourceMaxValues.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'vida' || key == 'pv') return entry.value;
    }
    return 0;
  }

  bool _statusContains(String fragment) =>
      _negativeStatuses.any((s) => s.toLowerCase().contains(fragment));

  double get _lifeRatio => _lifeMax > 0 ? (_life / _lifeMax).clamp(0.0, 1.0) : 1.0;

  String get _pose {
    if (_life <= 0) return 'incapacitated';
    if (_lifeRatio <= .30) return 'agony';
    if (_negativeStatuses.isNotEmpty) return 'agony';
    return 'normal';
  }

  String get _healthLabel {
    if (_life <= 0) return 'Incapacitado';
    if (_lifeRatio <= .30) return 'Crítico';
    if (_lifeRatio <= .60) return 'Ferido';
    if (_negativeStatuses.isNotEmpty) return 'Afetado';
    return 'Estável';
  }

  String get _asset => 'assets/character2d/${_pose == 'incapacitated' ? 'incapacitated' : _pose == 'agony' ? 'agony' : 'normal'}.png';

  Widget _statusEffects(BuildContext context, double phase) {
    final scheme = Theme.of(context).colorScheme;
    final burning = _statusContains('queim') || _statusContains('fogo');
    final poisoned = _statusContains('enven') || _statusContains('veneno');
    final frozen = _statusContains('congel') || _statusContains('gelo');
    final bleeding = _statusContains('sangr');
    final stunned = _statusContains('atordo') || _statusContains('tonto');
    final protected = _positiveContains('proteg');
    final inspired = _positiveContains('inspir');
    final strengthened = _positiveContains('fortal');
    final accelerated = _positiveContains('aceler');
    final regenerating = _positiveContains('regener');

    return IgnorePointer(
      child: Stack(children: [
        if (burning)
          ...List.generate(5, (i) => Positioned(
            left: 54.0 + i * 23 + (i.isEven ? phase * 4 : -phase * 3),
            bottom: 20.0 + (i % 2) * 10 + phase * 8,
            child: Transform.scale(
              scale: .75 + phase * .28,
              child: Icon(Icons.local_fire_department, size: 20 + phase * 4, color: Colors.deepOrange.withOpacity(.50 + phase * .20)),
            ),
          )),
        if (poisoned)
          ...List.generate(6, (i) => Positioned(
            left: 45.0 + (i * 29) % 140,
            top: 35.0 + (i * 31) % 105 - phase * 8,
            child: Container(
              width: 5 + (i % 3) * 2,
              height: 5 + (i % 3) * 2,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(.28 + phase * .22)),
            ),
          )),
        if (frozen)
          ...List.generate(5, (i) => Positioned(
            left: 62.0 + (i * 31) % 125,
            top: 35.0 + (i * 37) % 130 + (phase - .5) * 7,
            child: Icon(Icons.ac_unit, size: 11 + (i % 3) * 3, color: Colors.lightBlueAccent.withOpacity(.35 + phase * .22)),
          )),
        if (bleeding)
          ...List.generate(3, (i) => Positioned(
            left: 88.0 + i * 24,
            top: 105.0 + i * 16 + phase * 7,
            child: Icon(Icons.water_drop, size: 13 + i * 2, color: Colors.redAccent.withOpacity(.42 + phase * .20)),
          )),
        if (stunned)
          Positioned(
            top: 12, left: 0, right: 0,
            child: Transform.rotate(
              angle: (phase - .5) * .18,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.star, size: 14, color: scheme.primary.withOpacity(.75)),
                const SizedBox(width: 25),
                Icon(Icons.blur_circular, size: 17, color: scheme.primary.withOpacity(.7)),
                const SizedBox(width: 24),
                Icon(Icons.star, size: 12, color: scheme.primary.withOpacity(.65)),
              ]),
            ),
          ),
        if (protected)
          Positioned(
            left: 48, right: 48, top: 25, bottom: 18,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                border: Border.all(color: scheme.primary.withOpacity(.30 + phase * .16), width: 2),
                boxShadow: [BoxShadow(color: scheme.primary.withOpacity(.08 + phase * .06), blurRadius: 16)],
              ),
            ),
          ),
        if (inspired)
          ...List.generate(4, (i) => Positioned(
            left: 55.0 + i * 38,
            top: 22.0 + (i.isEven ? phase * 14 : (1 - phase) * 16),
            child: Icon(Icons.auto_awesome, size: 12 + (i % 2) * 5, color: Colors.amberAccent.withOpacity(.55 + phase * .25)),
          )),
        if (strengthened)
          Positioned(
            left: 65, right: 65, bottom: 18,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(color: scheme.primary.withOpacity(.28 + phase * .18), blurRadius: 18, spreadRadius: 3)],
              ),
            ),
          ),
        if (accelerated)
          ...List.generate(3, (i) => Positioned(
            left: 45.0 - phase * (10 + i * 4),
            top: 72.0 + i * 35,
            child: Container(
              width: 35 + i * 9, height: 2,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: scheme.primary.withOpacity(.25 + phase * .25)),
            ),
          )),
        if (regenerating)
          ...List.generate(5, (i) => Positioned(
            left: 64.0 + (i * 29) % 115,
            bottom: 25.0 + (i * 24) % 110 + phase * 13,
            child: Icon(Icons.add, size: 10 + (i % 2) * 4, color: Colors.greenAccent.withOpacity(.48 + phase * .24)),
          )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negatives = _negativeStatuses;
    final positives = _positiveStatuses;
    final visibleStatuses = [...negatives, ...positives];
    final incapacitated = _pose == 'incapacitated';
    final agony = _pose == 'agony';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(children: [
          Row(children: [
            Text('Estado do personagem', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _healthLabel,
                key: ValueKey('$_pose-$_healthLabel'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: incapacitated || agony ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: idle,
            builder: (context, _) {
              final phase = idle.value;
              final wounded = !incapacitated && _lifeRatio <= .60;
              final breath = incapacitated ? 0.0 : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 2.7 : (phase - .5) * 3.6;
              final lean = incapacitated ? 0.0 : agony ? -.018 + (phase - .5) * .034 : wounded ? -.009 + (phase - .5) * .016 : (phase - .5) * .008;
              final scale = incapacitated ? 1.0 : 1.0 + (agony ? phase * .005 : wounded ? phase * .006 : phase * .009);
              final sideSway = incapacitated ? 0.0 : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 1.2 : (phase - .5) * .6;
              return SizedBox(
                height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        (agony ? scheme.error : scheme.primary).withOpacity(.08 + phase * .035),
                        Colors.transparent,
                      ],
                      radius: .74,
                    ),
                  ))),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Transform.translate(
                      key: ValueKey(_pose),
                      offset: Offset(sideSway, breath),
                      child: Transform.rotate(
                        angle: lean,
                        child: Transform.scale(
                          scale: scale,
                          child: Image.asset(_asset, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: _statusEffects(context, phase)),
                ]),
              );
            },
          ),
          if (visibleStatuses.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: visibleStatuses.map((name) {
                final preset = conditionPresetFor(name);
                final positive = preset?.positive == true;
                return Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    preset?.icon ?? Icons.flag_outlined,
                    size: 16,
                    color: positive ? scheme.tertiary : scheme.error,
                  ),
                  label: Text(name),
                  side: BorderSide(color: (positive ? scheme.tertiary : scheme.error).withOpacity(.22)),
                );
              }).toList(),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ActionsTab extends StatefulWidget {
  final Character character;
  final RpgSystem system;
  final bool embedded;
  final bool showCombat;
  final bool showResources;
  final bool showConditions;
  final bool showQuickActions;

  const _ActionsTab({
    required this.character,
    required this.system,
    this.embedded = false,
    this.showCombat = true,
    this.showResources = true,
    this.showConditions = true,
    this.showQuickActions = true,
  });

  @override State<_ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<_ActionsTab> with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  static const _groups = ['weapons', 'spells', 'abilities', 'consumables'];
  static const _labels = {'weapons':'Armas','spells':'Magias','abilities':'Habilidades','consumables':'Consumíveis'};
  @override void initState(){super.initState();_idle=AnimationController(vsync:this,duration:const Duration(milliseconds:2600))..repeat(reverse:true);}
  @override void dispose(){_idle.dispose();super.dispose();}
  Future<void> _save() async {await context.read<AppState>().updateCharacter(widget.character);if(!mounted)return;setState((){});}
  void _actionError(String message){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}

  Future<void> _useItem(String name) async {
    final d=widget.character.inventoryDetails[name]??=<String,dynamic>{}; final cat=d['category']?.toString()??'Outro';
    if(cat=='Consumível'){
      final q=(d['quantity'] as num?)?.toInt()??1;if(q<=0){_actionError('Sem unidades de $name.');return;}
      d['quantity']=q-1; final effect=(d['effectValue'] as num?)?.toInt()??0; final resource=d['effectResource']?.toString()??'';
      if(effect!=0 && resource.isNotEmpty && widget.character.resourceValues.containsKey(resource)){
        final cur=widget.character.resourceValues[resource]??0, max=widget.character.resourceMaxValues[resource]??cur;
        widget.character.resourceValues[resource]=(cur+effect).clamp(0,max);
        if(resource.toLowerCase()=='vida')widget.character.hp=widget.character.resourceValues[resource]!;
        if(resource.toLowerCase()=='energia')widget.character.energy=widget.character.resourceValues[resource]!;
      }
      return _save();
    }
    if(cat=='Arma'){
      final max=(d['ammoMax'] as num?)?.toInt()??0, ammo=(d['ammo'] as num?)?.toInt()??max;
      if(max>0){if(ammo<=0){_actionError('$name está sem munição.');return;}d['ammo']=ammo-1;}
      return _save();
    }
  }
  Future<void> _reload(String name) async {
    final d=widget.character.inventoryDetails[name]??=<String,dynamic>{};final max=(d['ammoMax'] as num?)?.toInt()??0, current=(d['ammo'] as num?)?.toInt()??0;if(max<=0||current>=max)return;
    final needed=max-current, ammoItem=d['ammoItem']?.toString()??'';
    if(ammoItem.isEmpty){d['ammo']=max;return _save();}
    final stock=widget.character.inventoryDetails[ammoItem];if(stock==null){_actionError('Estoque de munição não encontrado.');return;}
    final available=(stock['quantity'] as num?)?.toInt()??0;if(available<=0){_actionError('Sem $ammoItem no inventário.');return;}
    final used=available<needed?available:needed;d['ammo']=current+used;stock['quantity']=available-used;
    return _save();
  }
  Future<void> _cast(String name) async {final d=widget.character.abilityDetails[name]??=<String,dynamic>{};final cost=(d['cost'] as num?)?.toInt()??0;final resource=d['resource']?.toString().isNotEmpty==true?d['resource'].toString():'Energia';final current=widget.character.resourceValues[resource]??0;if(current<cost){_actionError('$resource insuficiente para $name.');return;}widget.character.resourceValues[resource]=current-cost;if(resource.toLowerCase()=='energia')widget.character.energy=current-cost;if(resource.toLowerCase()=='vida')widget.character.hp=current-cost;await _save();}
  Future<void> _changeResource(String name,int delta) async{final current=widget.character.resourceValues[name]??0,max=widget.character.resourceMaxValues[name]??0;widget.character.resourceValues[name]=applyResourceDelta(current:current,maximum:max,delta:delta);if(name.toLowerCase()=='vida')widget.character.hp=widget.character.resourceValues[name]!;if(name.toLowerCase()=='energia')widget.character.energy=widget.character.resourceValues[name]!;await _save();}
  Future<void> _editResourceValue(String name) async {
    final current = widget.character.resourceValues[name] ?? 0;
    final maxValue = widget.character.resourceMaxValues[name] ?? 0;
    final a = TextEditingController(text: '$current');
    final b = TextEditingController(text: '$maxValue');
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajustar $name'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Atual'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: b, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Máximo'))),
          ]),
          if (name.toLowerCase() == 'vida') ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.heart_broken_outlined),
                  label: const Text('Receber dano'),
                  onPressed: () async {
                    final amount = await _askResourceAmount(context, title: 'Receber dano', label: 'Dano recebido');
                    if (amount == null) return;
                    final base = int.tryParse(a.text) ?? current;
                    final limit = (int.tryParse(b.text) ?? maxValue).clamp(0, 999999).toInt();
                    a.text = applyResourceDelta(current: base, maximum: limit, delta: -amount).toString();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Curar'),
                  onPressed: () async {
                    final amount = await _askResourceAmount(context, title: 'Curar', label: 'Vida recuperada');
                    if (amount == null) return;
                    final base = int.tryParse(a.text) ?? current;
                    final limit = (int.tryParse(b.text) ?? maxValue).clamp(0, 999999).toInt();
                    a.text = applyResourceDelta(current: base, maximum: limit, delta: amount).toString();
                  },
                ),
              ),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, [int.tryParse(a.text) ?? current, int.tryParse(b.text) ?? maxValue]), child: const Text('Salvar')),
        ],
      ),
    );
    a.dispose();
    b.dispose();
    if (result == null) return;
    final nextMax = result[1] < 0 ? 0 : result[1];
    widget.character.resourceMaxValues[name] = nextMax;
    widget.character.resourceValues[name] = result[0].clamp(0, nextMax);
    if (name.toLowerCase() == 'vida') widget.character.hp = widget.character.resourceValues[name]!;
    if (name.toLowerCase() == 'energia') widget.character.energy = widget.character.resourceValues[name]!;
    await _save();
  }
  Widget _resource(String name){final current=widget.character.resourceValues[name]??0,max=widget.character.resourceMaxValues[name]??0,value=max<=0?0.0:(current/max).clamp(0.0,1.0);final themeId=context.watch<AppState>().themeId,secondary=name.toLowerCase()!='vida';return Card(child:Padding(padding:const EdgeInsets.fromLTRB(14,10,14,12),child:Column(children:[Row(children:[Icon(secondary?Icons.bolt:themedIcon(themeId,'resources'),size:22),const SizedBox(width:8),Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w700))),IconButton(tooltip:'Diminuir',visualDensity:VisualDensity.compact,onPressed:()=>_changeResource(name,-1),icon:const Icon(Icons.remove)),Text('$current / $max',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w600)),IconButton(tooltip:'Aumentar',visualDensity:VisualDensity.compact,onPressed:()=>_changeResource(name,1),icon:const Icon(Icons.add)),IconButton(tooltip:'Ajustar valor',visualDensity:VisualDensity.compact,onPressed:()=>_editResourceValue(name),icon:const Icon(Icons.tune,size:20))]),const SizedBox(height:7),_ThemedResourceBar(value:value,themeId:themeId,secondary:secondary)])));}

  Future<void> _selectConditions() async {
    final initial = widget.character.conditions.toSet();
    final selected = <String>{...initial};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final custom = selected.where((name) => conditionPresetFor(name) == null).toList();
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 18),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Condições do personagem', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text('Marque as condições ativas. Você pode alterar várias de uma vez.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Text('Condições', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: conditionPresets.map((preset) {
                      final active = selected.contains(preset.name);
                      return FilterChip(
                        selected: active,
                        avatar: Icon(preset.icon, size: 18),
                        label: Text(preset.name),
                        onSelected: (value) => setSheetState(() => value ? selected.add(preset.name) : selected.remove(preset.name)),
                      );
                    }).toList(),
                  ),
                  if (custom.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('Condições antigas/personalizadas', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: custom.map((name) => InputChip(
                      avatar: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(name),
                      onDeleted: () => setSheetState(() => selected.remove(name)),
                    )).toList()),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    TextButton(onPressed: () => setSheetState(selected.clear), child: const Text('Limpar')),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => Navigator.pop(sheetContext, selected), child: const Text('Aplicar')),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    final ordered = <String>[
      ...conditionPresets.where((preset) => result.contains(preset.name)).map((preset) => preset.name),
      ...result.where((name) => conditionPresetFor(name) == null),
    ];
    widget.character.conditions = ordered;
    await _save();
  }

  Widget _conditionChip(String name) {
    final preset = conditionPresetFor(name);
    final scheme = Theme.of(context).colorScheme;
    return InputChip(
      avatar: Icon(preset?.icon ?? Icons.flag_outlined, size: 18, color: preset?.positive == true ? scheme.tertiary : scheme.primary),
      label: Text(name),
      onPressed: _selectConditions,
      onDeleted: () async {
        widget.character.conditions.remove(name);
        await _save();
      },
    );
  }
  Future<void> _customize() async {
    var order = <String>[
      ...widget.character.actionOrder.where(_groups.contains),
      ..._groups.where((g) => !widget.character.actionOrder.contains(g)),
    ];
    var hidden = <String>{...widget.character.hiddenActionGroups};
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const ListTile(
                  title: Text('Personalizar Ações'),
                  subtitle: Text('Arraste os grupos e escolha quais aparecem.'),
                ),
                Expanded(
                  child: ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setSheet(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = order.removeAt(oldIndex);
                        order.insert(newIndex, item);
                      });
                    },
                    children: [
                      for (final group in order)
                        SwitchListTile(
                          key: ValueKey(group),
                          value: !hidden.contains(group),
                          onChanged: (visible) => setSheet(() {
                            if (visible) { hidden.remove(group); } else { hidden.add(group); }
                          }),
                          title: Text(_labels[group]!),
                          secondary: const Icon(Icons.drag_handle),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, {'order': order, 'hidden': hidden.toList()}),
                      child: const Text('Salvar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      widget.character.actionOrder = List<String>.from(result['order']);
      widget.character.hiddenActionGroups = List<String>.from(result['hidden']);
      await _save();
    }
  }

  Widget _group(String id, bool compact) {
    final c = widget.character;
    List<String> names = [];
    if (id == 'weapons') names = c.inventory.where((n) => c.inventoryDetails[n]?['category'] == 'Arma').toList();
    if (id == 'consumables') names = c.inventory.where((n) => c.inventoryDetails[n]?['category'] == 'Consumível').toList();
    if (id == 'spells') names = c.abilities.where((n) => c.abilityDetails[n]?['category'] == 'Magia').toList();
    if (id == 'abilities') names = c.abilities.where((n) {
      final x = c.abilityDetails[n]?['category'];
      return x == 'Técnica' || x == 'Habilidade';
    }).toList();
    if (names.isEmpty) return const SizedBox.shrink();

    final groupIcon = switch (id) {
      'weapons' => Icons.gps_fixed,
      'spells' => Icons.auto_awesome_outlined,
      'abilities' => Icons.bolt_outlined,
      _ => Icons.local_drink_outlined,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(2, compact ? 5 : 10, 2, 6),
        child: Row(children: [
          Icon(groupIcon, size: 18),
          const SizedBox(width: 7),
          Text(_labels[id]!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${names.length}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
      ...names.map((name) {
        final d = (id == 'weapons' || id == 'consumables') ? c.inventoryDetails[name] ?? {} : c.abilityDetails[name] ?? {};
        final sub = <String>[];
        final damage = d['damage']?.toString() ?? '';
        if (damage.isNotEmpty) sub.add('Dano $damage');

        var enabled = true;
        var actionLabel = 'Usar';
        if (id == 'weapons') {
          actionLabel = 'Atacar';
          final max = (d['ammoMax'] as num?)?.toInt() ?? 0;
          final ammo = (d['ammo'] as num?)?.toInt() ?? max;
          if (max > 0) {
            sub.add('Munição $ammo/$max');
            enabled = ammo > 0;
          }
          final linked = d['ammoItem']?.toString() ?? '';
          if (linked.isNotEmpty) sub.add('Reserva ${c.inventoryDetails[linked]?['quantity'] ?? 0}');
        }
        if (id == 'consumables') {
          final q = (d['quantity'] as num?)?.toInt() ?? 1;
          sub.add('Qtd. $q');
          enabled = q > 0;
        }
        if (id == 'spells' || id == 'abilities') {
          actionLabel = id == 'spells' ? 'Lançar' : 'Usar';
          final cost = (d['cost'] as num?)?.toInt() ?? 0;
          final resource = d['resource']?.toString().isNotEmpty == true ? d['resource'].toString() : 'Energia';
          if (cost > 0) {
            sub.add('$cost $resource');
            enabled = (c.resourceValues[resource] ?? 0) >= cost;
          }
        }

        return Card(
          margin: EdgeInsets.only(bottom: compact ? 5 : 8),
          child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 9 : 11, compact ? 7 : 9, compact ? 7 : 9, compact ? 7 : 9),
            child: Row(children: [
              Icon(
                id == 'spells'
                    ? SpellIconResolver.resolve(name, description: c.abilityDescriptions[name] ?? '')
                    : groupIcon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (sub.isNotEmpty)
                  Text(sub.join(' • '), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              if (id == 'weapons' && ((d['ammoMax'] as num?)?.toInt() ?? 0) > 0)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _reload(name),
                  tooltip: 'Recarregar',
                  icon: const Icon(Icons.refresh),
                ),
              FilledButton.tonalIcon(
                onPressed: enabled ? () => id == 'spells' || id == 'abilities' ? _cast(name) : _useItem(name) : null,
                icon: Icon(
                  id == 'weapons'
                      ? Icons.gps_fixed
                      : id == 'spells'
                          ? SpellIconResolver.resolve(name, description: c.abilityDescriptions[name] ?? '')
                          : Icons.play_arrow,
                  size: 17,
                ),
                label: Text(actionLabel),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final compact = context.watch<AppState>().compactMode;
    final order = [
      ...c.actionOrder.where(_groups.contains),
      ..._groups.where((g) => !c.actionOrder.contains(g)),
    ];
    final content = <Widget>[];

    if (widget.showCombat) {
      content.add(_CombatCharacter2D(character: c, idle: _idle));
    }
    if (widget.showResources) {
      if (content.isNotEmpty) content.add(SizedBox(height: compact ? 8 : 12));
      content.add(_resource('Vida'));
      content.add(SizedBox(height: compact ? 6 : 8));
      content.add(_resource('Energia'));
    }
    if (widget.showConditions) {
      if (content.isNotEmpty) content.add(SizedBox(height: compact ? 10 : 14));
      content.add(Row(children: [
        Text('Condições ativas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(onPressed: _selectConditions, icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Alterar')),
      ]));
      content.add(c.conditions.isEmpty
          ? Text('Nenhuma condição ativa.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
          : Wrap(spacing: 7, runSpacing: 7, children: c.conditions.map(_conditionChip).toList()));
    }
    if (widget.showQuickActions) {
      if (content.isNotEmpty) content.add(SizedBox(height: compact ? 10 : 14));
      content.add(Row(children: [
        Text('Ações', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(tooltip: 'Personalizar', visualDensity: VisualDensity.compact, onPressed: _customize, icon: const Icon(Icons.tune, size: 20)),
      ]));
      content.addAll(order.where((g) => !c.hiddenActionGroups.contains(g)).map((g) => _group(g, compact)));
    }

    return widget.embedded
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content)
        : ListView(
            padding: EdgeInsets.fromLTRB(compact ? 10 : 16, compact ? 10 : 14, compact ? 10 : 16, 28),
            children: content,
          );
  }
}

class _CharacterItemsTab extends StatefulWidget {
  final Character character;
  final List<String> items;
  final Map<String, String> descriptions;
  final Map<String, Map<String, dynamic>> details;
  final String title;
  final String singular;
  final String hint;
  final String iconRole;
  final bool isAbility;

  const _CharacterItemsTab({
    required this.character,
    required this.items,
    required this.descriptions,
    required this.details,
    required this.title,
    required this.singular,
    required this.hint,
    required this.iconRole,
    required this.isAbility,
  });

  @override
  State<_CharacterItemsTab> createState() => _CharacterItemsTabState();
}

class _CharacterItemsTabState extends State<_CharacterItemsTab> {
  String _inventoryFilter = 'Todos';
  String _abilityFilter = 'Todos';
  final TextEditingController _abilitySearch = TextEditingController();
  @override
  void dispose() {
    _abilitySearch.dispose();
    super.dispose();
  }

  IconData _itemIcon(String category, {String name = '', String description = ''}) {
    if (widget.isAbility) {
      if (category == 'Magia') return SpellIconResolver.resolve(name, description: description);
      return category == 'Técnica' ? Icons.sports_martial_arts : Icons.bolt_outlined;
    }
    return switch (category) {
      'Arma' => Icons.gps_fixed,
      'Armadura' => Icons.shield_outlined,
      'Consumível' => Icons.local_drink_outlined,
      'Munição' => Icons.more_horiz,
      'Acessório' => Icons.diamond_outlined,
      'Ferramenta' => Icons.build_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }
  List<String> get _categories => widget.isAbility
      ? const ['Habilidade', 'Magia', 'Técnica', 'Passiva', 'Outro']
      : const ['Arma', 'Armadura', 'Consumível', 'Munição', 'Acessório', 'Ferramenta', 'Outro'];

  Future<void> _openEditor({int? index}) async {
    final editing = index != null;
    final oldName = editing ? widget.items[index] : '';
    final old = editing ? (widget.details[oldName] ?? <String, dynamic>{}) : <String, dynamic>{};
    final name = TextEditingController(text: oldName);
    final description = TextEditingController(text: editing ? (widget.descriptions[oldName] ?? '') : '');
    final damage = TextEditingController(text: old['damage']?.toString() ?? '');
    final turns = TextEditingController(text: old['turns']?.toString() ?? '');
    final quantity = TextEditingController(text: old['quantity']?.toString() ?? '1');
    final ammo = TextEditingController(text: old['ammo']?.toString() ?? '');
    final ammoMax = TextEditingController(text: old['ammoMax']?.toString() ?? '');
    final cost = TextEditingController(text: old['cost']?.toString() ?? '');
    final effectValue = TextEditingController(text: old['effectValue']?.toString() ?? '');
    String effectResource = old['effectResource']?.toString() ?? 'Vida';
    String ammoItem = old['ammoItem']?.toString() ?? '';
    String resource = old['resource']?.toString() ?? 'Energia';
    String category = old['category']?.toString() ?? (widget.isAbility ? 'Habilidade' : 'Outro');
    if (!_categories.contains(category)) category = widget.isAbility ? 'Habilidade' : 'Outro';
    String durationType = old['durationType']?.toString() ?? 'instant';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMagic = widget.isAbility && category == 'Magia';
          final isPassive = widget.isAbility && category == 'Passiva';
          final isActiveAbility = widget.isAbility && !isPassive;
          final isWeapon = !widget.isAbility && category == 'Arma';
          final isConsumable = !widget.isAbility && category == 'Consumível';
          final isAmmo = !widget.isAbility && category == 'Munição';
          return AlertDialog(
            title: Text(editing ? 'Editar ${widget.singular}' : 'Adicionar ${widget.singular}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, textCapitalization: TextCapitalization.sentences, autofocus: !editing, decoration: InputDecoration(labelText: widget.hint)),
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  initialSelection: category,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Categoria'),
                  menuStyle: const MenuStyle(alignment: AlignmentDirectional.bottomStart),
                  dropdownMenuEntries: _categories.map((e) => DropdownMenuEntry(value: e, label: e)).toList(),
                  onSelected: (v) { if (v != null) setDialogState(() => category = v); },
                ),
                const SizedBox(height: 12),
                TextField(controller: description, textCapitalization: TextCapitalization.sentences, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Detalhes, efeitos, observações...')),
                if (isWeapon || isActiveAbility) ...[
                  const SizedBox(height: 12),
                  TextField(controller: damage, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Dano', hintText: 'Ex.: 1d8, 2d6+3 ou 5')),
                ],
                if (isWeapon) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: ammo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Munição atual'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: ammoMax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Munição máxima'))),
                  ]),
                
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: widget.character.inventory.contains(ammoItem) ? ammoItem : '',
                    decoration: const InputDecoration(labelText: 'Estoque de munição vinculado'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Nenhum — recarga livre')),
                      ...widget.character.inventory.where((i) { final cat = widget.character.inventoryDetails[i]?['category']; return i != oldName && (cat == 'Munição' || (i == ammoItem && cat == 'Consumível')); }).map((i) => DropdownMenuItem(value: i, child: Text(i))),
                    ],
                    onChanged: (v) => setDialogState(() => ammoItem = v ?? ''),
                  ),
                ],
                if (isConsumable || isAmmo) ...[
                  const SizedBox(height: 12),
                  TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade')),
                ],
                if (isConsumable) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: widget.character.resourceValues.containsKey(effectResource) ? effectResource : (widget.character.resourceValues.keys.isNotEmpty ? widget.character.resourceValues.keys.first : null),
                      decoration: const InputDecoration(labelText: 'Efeito opcional'),
                      items: widget.character.resourceValues.keys.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setDialogState(() => effectResource = v ?? effectResource),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: effectValue, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Valor', hintText: 'Ex.: 10 ou -5'))),
                  ]),
                ],
                if (isActiveAbility) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo'))),
                    const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<String>(value: widget.character.resourceValues.containsKey(resource) ? resource : (widget.character.resourceValues.keys.isNotEmpty ? widget.character.resourceValues.keys.first : 'Energia'), decoration: const InputDecoration(labelText: 'Recurso'), items: widget.character.resourceValues.keys.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => setDialogState(() => resource = v ?? resource))),
                  ]),
                ],
                if (isActiveAbility) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: durationType,
                    decoration: const InputDecoration(labelText: 'Duração'),
                    items: const [
                      DropdownMenuItem(value: 'instant', child: Text('Direto / instantâneo')),
                      DropdownMenuItem(value: 'turns', child: Text('Por turnos')),
                    ],
                    onChanged: (v) => setDialogState(() => durationType = v ?? durationType),
                  ),
                  if (durationType == 'turns') ...[
                    const SizedBox(height: 12),
                    TextField(controller: turns, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade de turnos')),
                  ],
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  final n = name.text.trim();
                  if (n.isEmpty) return;
                  Navigator.pop(dialogContext, {
                    'name': n,
                    'description': description.text.trim(),
                    'category': category,
                    'damage': (isWeapon || isActiveAbility) ? damage.text.trim() : '',
                    'durationType': isActiveAbility ? durationType : '',
                    'turns': isActiveAbility && durationType == 'turns' ? turns.text.trim() : '',
                    'quantity': (isConsumable || isAmmo) ? (int.tryParse(quantity.text) ?? 1).clamp(0, 999999) : null,
                    'ammo': isWeapon ? (int.tryParse(ammo.text) ?? 0).clamp(0, 999999) : null,
                    'ammoMax': isWeapon ? (int.tryParse(ammoMax.text) ?? 0).clamp(0, 999999) : null,
                    'ammoItem': isWeapon ? ammoItem : '',
                    'effectResource': isConsumable ? effectResource : '',
                    'effectValue': isConsumable ? (int.tryParse(effectValue.text) ?? 0) : 0,
                    'cost': isActiveAbility ? (int.tryParse(cost.text) ?? 0).clamp(0, 999999) : null,
                    'resource': isActiveAbility ? resource : '',
                  });
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose(); description.dispose(); damage.dispose(); turns.dispose(); quantity.dispose(); ammo.dispose(); ammoMax.dispose(); cost.dispose(); effectValue.dispose();
    if (result == null) return;
    final newName = result['name'] as String;
    if (editing) {
      widget.items[index] = newName;
      if (oldName != newName) {
        widget.descriptions.remove(oldName);
        widget.details.remove(oldName);
      }
    } else {
      widget.items.add(newName);
    }
    widget.descriptions[newName] = result['description'] as String? ?? '';
    widget.details[newName] = Map<String, dynamic>.from(result)..remove('name')..remove('description');
    await context.read<AppState>().updateCharacter(widget.character);
    if (mounted) setState(() {});
  }

  Future<void> _delete(int index) async {
    final removed = widget.items[index];
    widget.items.removeAt(index);
    widget.descriptions.remove(removed);
    widget.details.remove(removed);
    await context.read<AppState>().updateCharacter(widget.character);
    if (mounted) setState(() {});
  }

  Future<void> _changeItemQuantity(String item, int delta) async {
    final d = widget.details[item] ??= <String, dynamic>{};
    final category = d['category']?.toString() ?? 'Outro';
    if (category != 'Consumível' && category != 'Munição') return;
    final current = (d['quantity'] as num?)?.toInt() ?? 1;
    d['quantity'] = (current + delta).clamp(0, 999999);
    await context.read<AppState>().updateCharacter(widget.character);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final icon = themedIcon(context.watch<AppState>().themeId, widget.iconRole);
    final compact = context.watch<AppState>().compactMode;
    final scheme = Theme.of(context).colorScheme;

    final inventoryFilters = const ['Todos', 'Arma', 'Armadura', 'Consumível', 'Munição', 'Acessório', 'Ferramenta', 'Outro'];
    final abilityFilters = const ['Todos', 'Habilidade', 'Magia', 'Técnica', 'Passiva', 'Outro'];
    final activeFilter = widget.isAbility ? _abilityFilter : _inventoryFilter;
    final abilityQuery = widget.isAbility ? _abilitySearch.text.trim().toLowerCase() : '';
    final visibleEntries = widget.items.asMap().entries.where((entry) {
      final category = widget.details[entry.value]?['category']?.toString() ?? 'Outro';
      if (activeFilter != 'Todos' && category != activeFilter) return false;
      if (abilityQuery.isEmpty) return true;
      final description = widget.descriptions[entry.value]?.toLowerCase() ?? '';
      return entry.value.toLowerCase().contains(abilityQuery) ||
          category.toLowerCase().contains(abilityQuery) ||
          description.contains(abilityQuery);
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 16, compact ? 10 : 14, compact ? 10 : 16, 28),
      children: [
        Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (widget.items.isNotEmpty)
            Text('${visibleEntries.length}/${widget.items.length}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          IconButton(onPressed: () => _openEditor(), tooltip: 'Adicionar', icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 8),
        if (widget.isAbility) ...[
          TextField(
            controller: _abilitySearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar habilidades, magias ou técnicas',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _abilitySearch.text.isEmpty ? null : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close, size: 19),
                onPressed: () { _abilitySearch.clear(); setState(() {}); },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: (widget.isAbility ? abilityFilters : inventoryFilters).length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final filters = widget.isAbility ? abilityFilters : inventoryFilters;
              final category = filters[index];
              final selected = activeFilter == category;
              final count = category == 'Todos'
                  ? widget.items.length
                  : widget.items.where((item) => (widget.details[item]?['category']?.toString() ?? 'Outro') == category).length;
              if (category != 'Todos' && count == 0) return const SizedBox.shrink();
              return FilterChip(
                selected: selected,
                avatar: category == 'Todos' ? const Icon(Icons.apps, size: 16) : Icon(_itemIcon(category), size: 16),
                label: Text(category == 'Todos' ? 'Todos ($count)' : '$category ($count)'),
                onSelected: (_) => setState(() {
                  if (widget.isAbility) {
                    _abilityFilter = category;
                  } else {
                    _inventoryFilter = category;
                  }
                }),
              );
            },
          ),
        ),
        SizedBox(height: compact ? 7 : 11),
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Column(children: [
              Icon(widget.isAbility ? Icons.bolt_outlined : Icons.inventory_2_outlined, size: 34, color: scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(widget.isAbility ? 'Nenhuma habilidade adicionada.' : 'Inventário vazio.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ])),
          )
        else if (visibleEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhum item nesta categoria.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
          )
        else
          ...visibleEntries.map((entry) {
            final item = entry.value;
            final detail = widget.details[item] ?? const <String, dynamic>{};
            final category = detail['category']?.toString() ?? 'Outro';
            final damage = detail['damage']?.toString() ?? '';
            final qty = (detail['quantity'] as num?)?.toInt() ?? 1;
            final ammo = (detail['ammo'] as num?)?.toInt() ?? 0;
            final ammoMax = (detail['ammoMax'] as num?)?.toInt() ?? 0;
            final ammoItem = detail['ammoItem']?.toString() ?? '';
            final cost = detail['cost']?.toString() ?? '';
            final resource = detail['resource']?.toString() ?? 'Energia';
            final description = widget.descriptions[item]?.trim() ?? '';
            final meta = <String>[];
            if (damage.isNotEmpty) meta.add('Dano $damage');
            if (!widget.isAbility && category == 'Arma' && ammoMax > 0) meta.add('Munição $ammo/$ammoMax');
            if (!widget.isAbility && category == 'Arma' && ammoItem.isNotEmpty) {
              meta.add('Reserva ${widget.character.inventoryDetails[ammoItem]?['quantity'] ?? 0}');
            }
            if (widget.isAbility && category != 'Passiva') {
              if (cost.isNotEmpty && cost != '0') meta.add('$cost $resource');
              final durationType = detail['durationType']?.toString() ?? '';
              final turns = detail['turns']?.toString() ?? '';
              if (durationType == 'turns' && turns.isNotEmpty) meta.add('$turns turno${turns == '1' ? '' : 's'}');
              if (durationType == 'instant') meta.add('Instantânea');
              final parsedCost = int.tryParse(cost) ?? 0;
              if (parsedCost > 0) {
                final available = widget.character.resourceValues[resource] ?? 0;
                meta.add(available >= parsedCost ? 'Disponível' : 'Recurso insuficiente');
              }
            }
            if (widget.isAbility && category == 'Passiva') meta.add('Sempre ativa');

            final stackable = !widget.isAbility && (category == 'Consumível' || category == 'Munição');

            return Card(
              margin: EdgeInsets.only(bottom: compact ? 6 : 9),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openEditor(index: entry.key),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 9 : 11),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(
                      width: compact ? 36 : 42,
                      height: compact ? 36 : 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withOpacity(.42), borderRadius: BorderRadius.circular(11)),
                      child: Icon(
                        _itemIcon(category, name: item, description: widget.descriptions[item] ?? ''),
                        size: compact ? 19 : 21,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (stackable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: scheme.primary.withOpacity(.09), borderRadius: BorderRadius.circular(8)),
                            child: Text('×$qty', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        [category, ...meta].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withOpacity(.82))),
                      ],
                    ])),
                    if (stackable) ...[
                      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Diminuir quantidade', onPressed: qty > 0 ? () => _changeItemQuantity(item, -1) : null, icon: const Icon(Icons.remove_circle_outline, size: 20)),
                      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Aumentar quantidade', onPressed: () => _changeItemQuantity(item, 1), icon: const Icon(Icons.add_circle_outline, size: 20)),
                    ],
                    PopupMenuButton<String>(
                      tooltip: 'Opções',
                      onSelected: (v) {
                        if (v == 'edit') _openEditor(index: entry.key);
                        if (v == 'delete') _delete(entry.key);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                  ]),
                ),
              ),
            );
          }),
      ],
    );
  }
}
