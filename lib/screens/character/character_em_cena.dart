part of 'character_screen.dart';

/// Cards do Em Cena, na ordem padrão ('skillTree' entra no fim).
const _generalCardIds = ['sessionOverview', 'combatCharacter', 'health', 'energy', 'conditions', 'quickActions', 'attributes', 'abilities', 'inventory', 'skillTree'];

/// Nomes dos cards no Personalizar do Em Cena.
const _generalCardLabels = {
  'sessionOverview': 'Sessão',
  'combatCharacter': 'Personagem 2D',
  'health': 'Vida',
  'energy': 'Energia',
  'conditions': 'Condições',
  'quickActions': 'Ações',
  'attributes': 'Atributos',
  'skillTree': 'Árvore de Habilidades',
  'abilities': 'Habilidades fixadas',
  'inventory': 'Itens fixados',
};

/// Ordem salva do Em Cena (só ids válidos, sem repetir) + os que faltam no fim.
List<String> _normalizedGeneralOrder(Character c) {
  final order = <String>[];
  for (final id in c.generalOrder) {
    if (_generalCardIds.contains(id) && !order.contains(id)) order.add(id);
  }
  for (final id in _generalCardIds) {
    if (!order.contains(id)) order.add(id);
  }
  return order;
}

/// Âncoras (GlobalKey) dos cards do Em Cena e dos cabeçalhos dentro deles.
class _EmCenaAnchors {
  /// Altura da barra de abas fixada da ficha: o conteúdo do Em Cena rola por
  /// baixo dela, então o alvo para logo abaixo.
  double pinnedHeight = 0;

  final _cards = <String, GlobalKey>{};
  final _sections = <String, GlobalKey>{};

  GlobalKey card(String id) => _cards.putIfAbsent(id, () => GlobalKey(debugLabel: 'em-cena-card-$id'));

  /// Cabeçalho de um grupo das Ações ('weapons', 'spells', 'consumables',
  /// 'abilities') ou o título "Condições ativas" ('conditions').
  GlobalKey section(String id) => _sections.putIfAbsent(id, () => GlobalKey(debugLabel: 'em-cena-section-$id'));
}

/// Folha "Personalizar": lista arrastável com um SwitchListTile por item e o
/// botão Salvar. Devolve {'order': [...], 'hidden': [...]} ou null.
Future<Map<String, dynamic>?> _showCustomizeSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<String> order,
  required Set<String> hidden,
  required Map<String, String> labels,
  double height = 420,
}) {
  final items = List<String>.from(order);
  final off = <String>{...hidden};
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              ListTile(
                title: Text(title),
                subtitle: Text(subtitle),
              ),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setSheet(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = items.removeAt(oldIndex);
                      items.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (final item in items)
                      SwitchListTile(
                        key: ValueKey(item),
                        value: !off.contains(item),
                        onChanged: (visible) => setSheet(() {
                          if (visible) { off.remove(item); } else { off.add(item); }
                        }),
                        title: Text(labels[item] ?? item),
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
                    onPressed: () => Navigator.pop(ctx, {'order': items, 'hidden': off.toList()}),
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
}

class _GeneralTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final _EmCenaAnchors anchors;
  final Future<void> Function(Character, List<String> order, List<String> hidden) onSaveLayout;
  final Future<void> Function(Character, String, int) onChangeResource;
  final Future<void> Function(Character, String) onEditResource;

  const _GeneralTab({
    required this.character,
    required this.system,
    required this.anchors,
    required this.onSaveLayout,
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
            ThemedResourceIcon(themeId, resourceName.isNotEmpty ? resourceName : title, fallbackIcon: secondary ? Icons.bolt : themedIcon(themeId, 'resources')),
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
            ],
          ]),
          if (resourceName.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('Nenhum recurso configurado.'),
          ],
          const SizedBox(height: 8),
          if (resourceName.isNotEmpty)
            ResourceBarTapTarget(
              label: resourceName,
              onTap: () => onEditResource(character, resourceName),
              child: _ThemedResourceBar(
                value: progress,
                themeId: themeId,
                secondary: secondary,
                resourceName: resourceName.isNotEmpty ? resourceName : title,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _verticalSummaryItems(BuildContext context, List<String> names, Map<String, Map<String, dynamic>> details, {required bool ability}) {
    if (names.isEmpty) {
      return Text(
        ability ? 'Toque na ★ em Habilidades para fixar aqui.' : 'Toque na ★ no Inventário para fixar itens aqui.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
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


  Widget _sessionPill(BuildContext context, IconData icon, String label, {bool warning = false, bool positive = false, VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : positive ? scheme.tertiary : scheme.primary;
    final pill = Container(
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
    if (onTap == null) return pill;
    // Tocável: mesmo formato da pílula; parada, o visual não muda.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: pill),
    );
  }

  /// Pílula do Sessão → rola o Em Cena até o cabeçalho do grupo (dentro do
  /// card Ações) ou até "Condições ativas" (card Condições).
  void _goToSection(BuildContext context, String section) {
    final isCondition = section == 'conditions';
    final cardId = isCondition ? 'conditions' : 'quickActions';
    final hiddenCard = character.hiddenGeneralCards.contains(cardId);
    final hiddenGroup = !isCondition && character.hiddenActionGroups.contains(section);
    if (hiddenCard || hiddenGroup) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Esse grupo está oculto. Ative em Personalizar.')));
      return;
    }
    final state = context.read<AppState>();
    final reduceMotion = state.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
    _scrollTo(section, cardId, reduceMotion);
  }

  /// Rola até o cabeçalho (ou, sem itens no grupo, até o card), deixando-o
  /// no topo da área rolável. No NestedScrollView a primeira rolagem pode só
  /// recolher o cabeçalho da ficha, então repete até o alvo assentar (no
  /// máximo 3 vezes).
  Future<void> _scrollTo(String section, String cardId, bool reduceMotion) async {
    for (var i = 0; i < 3; i++) {
      final target = anchors.section(section).currentContext ?? anchors.card(cardId).currentContext;
      if (target == null || !target.mounted) return;
      final scrollable = Scrollable.maybeOf(target);
      final box = target.findRenderObject();
      final viewport = scrollable?.context.findRenderObject();
      if (scrollable == null || box is! RenderBox || viewport is! RenderBox) return;
      final position = scrollable.position;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final to = (position.pixels + top - anchors.pinnedHeight - 8).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      if ((to - position.pixels).abs() < 1) return;
      if (reduceMotion) {
        position.jumpTo(to);
      } else {
        await position.animateTo(to, duration: const Duration(milliseconds: 320), curve: Curves.easeInOutCubic);
      }
      await WidgetsBinding.instance.endOfFrame;
    }
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
                ThemedSectionIcon(themeId, 'session', fallbackIcon: Icons.bolt_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Sessão', style: TextStyle(fontWeight: FontWeight.w800))),
                Text('Nível ${character.level}', style: Theme.of(context).textTheme.labelLarge),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _sessionPill(context, Icons.gps_fixed, '$weapons arma${weapons == 1 ? '' : 's'}', onTap: () => _goToSection(context, 'weapons')),
                _sessionPill(context, Icons.auto_awesome_outlined, '$spells magia${spells == 1 ? '' : 's'}', onTap: () => _goToSection(context, 'spells')),
                _sessionPill(context, Icons.local_drink_outlined, consumables == 1 ? '1 consumível' : '$consumables consumíveis', onTap: () => _goToSection(context, 'consumables')),
                if (positive > 0) _sessionPill(context, Icons.add_circle_outline, '$positive positivo${positive == 1 ? '' : 's'}', positive: true, onTap: () => _goToSection(context, 'conditions')),
                if (negative > 0) _sessionPill(context, Icons.warning_amber_rounded, '$negative negativo${negative == 1 ? '' : 's'}', warning: true, onTap: () => _goToSection(context, 'conditions')),
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
              anchors: anchors,
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
          anchors: anchors,
        );
      case 'attributes':
        return Card(
          key: const ValueKey('general-attributes'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [ThemedSectionIcon(themeId, 'attributes'), const SizedBox(width: 8), const Text('Atributos', style: TextStyle(fontWeight: FontWeight.bold))]),
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
        // Todos os recursos do sistema além da vida, na ordem do sistema.
        final resources = secondaryResourceNames(system, _lifeResourceName());
        if (resources.isEmpty) {
          return _resourceSummaryCard(
            context,
            keyId: 'energy',
            title: 'Energia',
            resourceName: '',
            secondary: true,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < resources.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _resourceSummaryCard(
                context,
                keyId: i == 0 ? 'energy' : 'resource-${resources[i]}',
                title: resources[i],
                resourceName: resources[i],
                secondary: true,
              ),
            ],
          ],
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
                ThemedSectionIcon(themeId, 'skillTree'),
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
        final lines = character.inventory.where((name) => character.inventoryDetails[name]?['showInScene'] == true).toList();
        return Card(
          key: const ValueKey('general-inventory'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [ThemedSectionIcon(themeId, 'inventory'), const SizedBox(width: 8), const Expanded(child: Text('Itens fixados', style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 8), Text('${lines.length} fixado(s)')]),
              const SizedBox(height: 8),
              _verticalSummaryItems(context, lines, character.inventoryDetails, ability: false),
            ]),
          ),
        );
      case 'abilities':
        final lines = character.abilities.where((name) => character.abilityDetails[name]?['showInScene'] == true).toList();
        return Card(
          key: const ValueKey('general-abilities'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [ThemedSectionIcon(themeId, 'abilities'), const SizedBox(width: 8), const Expanded(child: Text('Habilidades fixadas', style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 8), Text('${lines.length} fixado(s)')]),
              const SizedBox(height: 8),
              _verticalSummaryItems(context, lines, character.abilityDetails, ability: true),
            ]),
          ),
        );
      default:
        return const SizedBox.shrink(key: ValueKey('general-unknown'));
    }
  }

  Future<void> _customize(BuildContext context) async {
    final screen = MediaQuery.sizeOf(context).height;
    final result = await _showCustomizeSheet(
      context,
      title: 'Personalizar Em Cena',
      subtitle: 'Arraste os cards e escolha quais aparecem.',
      order: _normalizedGeneralOrder(character),
      hidden: {...character.hiddenGeneralCards},
      labels: _generalCardLabels,
      height: math.min(560.0, screen * .85),
    );
    if (result == null) return;
    await onSaveLayout(character, List<String>.from(result['order']), List<String>.from(result['hidden']));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _normalizedGeneralOrder(character).where((id) => !character.hiddenGeneralCards.contains(id)).toList();
    return SingleChildScrollView(
      key: const ValueKey('em-cena-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(tooltip: 'Personalizar', visualDensity: VisualDensity.compact, onPressed: () => _customize(context), icon: const Icon(Icons.tune, size: 20)),
        ]),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Nenhum card visível. Toque em Personalizar para escolher.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        for (final id in visible)
          Padding(
            key: ValueKey('general-item-$id'),
            padding: const EdgeInsets.only(bottom: 10),
            child: KeyedSubtree(key: anchors.card(id), child: _summaryCard(context, id)),
          ),
      ]),
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
