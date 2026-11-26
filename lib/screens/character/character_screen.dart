import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/cloud_service.dart';
import 'skill_tree_screen.dart';
import 'player_turn_banner.dart';
import '../../services/rpg_file_service.dart';
import '../../app/abyss_resource_art.dart';
import '../../app/abyss_tab_art.dart';
import '../../app/abyss_theme.dart';
import '../../app/theme.dart';
import '../../app/condition_presets.dart';
import '../../services/skill_tree_templates.dart';
import '../../utils/resource_math.dart';
import '../../utils/action_art.dart';
import 'character_sprites.dart';
import 'resource_delta.dart';
import 'resource_quick_adjust.dart';
import '../../widgets/confirm_delete_dialog.dart';
import 'skill_roll.dart';
import 'custom_sprite.dart';
import 'custom_sprite_sheet.dart';
import '../campaigns/initiative_tools.dart';
import '../../widgets/card_spacing.dart';
import '../../widgets/dispose_on_removed.dart';
import '../../widgets/text_growth.dart';

part 'character_status_tab.dart';
part 'character_em_cena.dart';
part 'character_skills_sections_tab.dart';
part 'character_2d.dart';
part 'character_actions_tab.dart';
part 'character_items_tab.dart';


class CharacterScreen extends StatefulWidget {
  final String characterId;

  const CharacterScreen({super.key, required this.characterId});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  int tab = 0;
  late final PageController _tabController;
  final _resourceDeltas = ResourceDeltaEvents();

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
    _resourceDeltas.dispose();
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
    final result = await showResourceQuickAdjust(
      context,
      name: name,
      current: c.resourceValues[name] ?? 0,
      max: c.resourceMaxValues[name] ?? 0,
    );
    if (result == null) return;
    final before = Map<String, int>.from(c.resourceValues);
    _applyResourceValues(c, name, result);
    _resourceDeltas.reportChanges(before, c.resourceValues);
    await state.updateCharacter(c);
    if (mounted) setState(() {});
  }

  Future<void> _changeResource(Character c, String name, int delta) async {
    final state = context.read<AppState>();
    final max = c.resourceMaxValues[name] ?? 0;
    final current = c.resourceValues[name] ?? 0;
    c.resourceValues[name] = applyResourceDelta(current: current, maximum: max, delta: delta);
    _resourceDeltas.report(name, c.resourceValues[name]! - current);
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

  /// Salva a ordem e os cards escondidos do Em Cena (Personalizar).
  Future<void> _saveGeneralLayout(Character c, List<String> order, List<String> hidden) async {
    c.generalOrder = List<String>.from(order);
    c.hiddenGeneralCards = List<String>.from(hidden);
    await context.read<AppState>().updateCharacter(c);
    if (mounted) setState(() {});
  }

  /// Âncoras do Em Cena (cards e cabeçalhos dos grupos), para as pílulas do
  /// card Sessão rolarem até o lugar certo.
  final _emCenaAnchors = _EmCenaAnchors();

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
    'general' => _GeneralTab(character: c, system: system, anchors: _emCenaAnchors, onSaveLayout: _saveGeneralLayout, onChangeResource: _changeResource, onEditResource: _editResource),
    'attributesResources' => _AttributesResourcesTab(character: c, system: system, onEditAttribute: _editAttribute, onChangeResource: _changeResource, onEditResource: _editResource),
    'abilities' => _CharacterItemsTab(character: c, items: c.abilities, descriptions: c.abilityDescriptions, details: c.abilityDetails, title: 'Habilidades', singular: 'habilidade', hint: 'Nome da habilidade', iconRole: 'abilities', isAbility: true),
    'skillTree' => SkillTreeScreen(characterId: c.id, embedded: true),
    'skills' => _SkillsTab(character: c, system: system, onToggle: _toggleSkill),
    'inventory' => _CharacterItemsTab(character: c, items: c.inventory, descriptions: c.inventoryDescriptions, details: c.inventoryDetails, title: 'Inventário', singular: 'item', hint: 'Nome do item', iconRole: 'inventory', isAbility: false),
    'sections' => _SectionsTab(character: c, system: system, onEdit: _editSection),
    _ => const SizedBox.shrink(),
  };

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
      debugPrint('Consultar solicitações falhou: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível consultar as solicitações. Verifique a conexão.')));
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

    // Canal do número flutuante dos recursos (só mudanças feitas nesta tela).
    return ResourceDeltaScope(events: _resourceDeltas, child: Scaffold(
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
                debugPrint('Compartilhar ficha falhou: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Não foi possível compartilhar a ficha. Verifique a conexão.')),
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
          // 72 com texto 1.0; com texto maior, cresce o mesmo que o rótulo.
          final tabsHeight = 72 + textGrowth(context, 'Ág', Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800));
          _emCenaAnchors.pinnedHeight = tabsHeight;
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _Header(character: c, system: system)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CharacterTabsHeader(
                  height: tabsHeight,
                  child: Material(
                    color: AbyssPalette.of(context).bar,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.32),
                        )),
                      ),
                      child: SizedBox(
                        height: tabsHeight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: order.asMap().entries.map((entry) {
                            final index = entry.key, id = entry.value, selected = tab == index;
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
                              child: AbyssTabCell(
                                selected: selected,
                                reduceMotion: reduceMotion,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                icon: (color, selected) => themedCharacterTabIcon(state.themeId, id, size: 22, color: color, selected: selected),
                                label: _tabLabel(id),
                                labelStyle: Theme.of(context).textTheme.labelMedium,
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
    ));
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

