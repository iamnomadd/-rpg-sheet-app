part of 'character_screen.dart';

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
  final TextEditingController _inventorySearch = TextEditingController();
  @override
  void dispose() {
    _abilitySearch.dispose();
    _inventorySearch.dispose();
    super.dispose();
  }

  IconData _itemIcon(String category, {String name = '', String description = ''}) {
    if (widget.isAbility) {
      // Magia: sem nome (chip de filtro) fica o contorno de sempre; numa linha
      // sem arte, o ícone fixo de magia.
      if (category == 'Magia') return name.isEmpty ? Icons.auto_awesome_outlined : Icons.auto_awesome;
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
    final showInScene = old['showInScene'] == true;
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
    // Erro mostrado no campo de nome (vazio ou repetido).
    String? nameError;
    String norm(String value) => value.trim().toLowerCase();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      // Os campos são descartados só quando o diálogo sai da árvore (depois da
      // animação de saída), e não logo que ele fecha.
      builder: (dialogContext) => DisposeOnRemoved(
        onRemoved: () {
          name.dispose(); description.dispose(); damage.dispose(); turns.dispose(); quantity.dispose(); ammo.dispose(); ammoMax.dispose(); cost.dispose(); effectValue.dispose();
        },
        child: StatefulBuilder(
        builder: (context, setDialogState) {
          final isPassive = widget.isAbility && category == 'Passiva';
          final isActiveAbility = widget.isAbility && !isPassive;
          final isWeapon = !widget.isAbility && category == 'Arma';
          final isConsumable = !widget.isAbility && category == 'Consumível';
          final isAmmo = !widget.isAbility && category == 'Munição';
          return AlertDialog(
            title: Text(editing ? 'Editar ${widget.singular}' : 'Adicionar ${widget.singular}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: !editing,
                  decoration: InputDecoration(labelText: widget.hint, errorText: nameError, errorMaxLines: 3),
                  onChanged: (_) { if (nameError != null) setDialogState(() => nameError = null); },
                ),
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  initialSelection: category,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Categoria'),
                  menuStyle: const MenuStyle(alignment: AlignmentDirectional.bottomStart),
                  dropdownMenuEntries: _categories.map((e) => DropdownMenuEntry(value: e, label: e)).toList(),
                  onSelected: (v) { if (v != null) setDialogState(() => category = v); },
                ),
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
                // Descrição: sempre o último campo.
                const SizedBox(height: 12),
                TextField(controller: description, textCapitalization: TextCapitalization.sentences, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Detalhes, efeitos, observações...')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  final n = name.text.trim();
                  if (n.isEmpty) {
                    setDialogState(() => nameError = 'Dê um nome.');
                    return;
                  }
                  // Outro item da mesma lista com o mesmo nome (sem diferença de
                  // maiúsculas/minúsculas e espaços nas pontas). Manter o
                  // próprio nome ao editar continua permitido.
                  final keepsOwnName = editing && norm(n) == norm(oldName);
                  final duplicate = !keepsOwnName && widget.items.asMap().entries.any((e) => e.key != index && norm(e.value) == norm(n));
                  if (duplicate) {
                    setDialogState(() => nameError = widget.isAbility
                        ? 'Já existe uma habilidade com esse nome. Use outro nome.'
                        : 'Já existe um item com esse nome. Aumente a quantidade ou use outro nome.');
                    return;
                  }
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
      ),
    );
    if (result == null) return;
    final newName = result['name'] as String;
    if (editing) {
      widget.items[index] = newName;
      // Ficha antiga com nomes repetidos: se outra linha ainda usa o nome
      // antigo, os dados dele ficam (o item renomeado leva uma cópia).
      if (oldName != newName && !widget.items.contains(oldName)) {
        widget.descriptions.remove(oldName);
        widget.details.remove(oldName);
        // Armas que usavam o item renomeado como estoque de munição passam a
        // apontar para o nome novo.
        if (!widget.isAbility) {
          for (final d in widget.details.values) {
            if (d['ammoItem'] == oldName) d['ammoItem'] = newName;
          }
        }
      }
    } else {
      widget.items.add(newName);
    }
    widget.descriptions[newName] = result['description'] as String? ?? '';
    widget.details[newName] = Map<String, dynamic>.from(result)..remove('name')..remove('description');
    widget.details[newName]!['showInScene'] = showInScene;
    await context.read<AppState>().updateCharacter(widget.character);
    if (mounted) setState(() {});
  }

  Future<void> _delete(int index) async {
    final removed = widget.items[index];
    final confirmed = await confirmDelete(
      context,
      title: 'Excluir ${widget.singular}?',
      message: '"$removed" será removido desta ficha.',
    );
    if (!confirmed || !mounted) return;
    widget.items.removeAt(index);
    // Ficha antiga com nomes repetidos: enquanto outra linha tiver o mesmo
    // nome, a descrição e os detalhes (e o vínculo de munição) ficam.
    if (!widget.items.contains(removed)) {
      widget.descriptions.remove(removed);
      widget.details.remove(removed);
      if (!widget.isAbility) {
        for (final d in widget.details.values) {
          if (d['ammoItem'] == removed) d['ammoItem'] = '';
        }
      }
    }
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


  Future<void> _toggleInScene(String item) async {
    final detail = widget.details[item] ??= <String, dynamic>{};
    detail['showInScene'] = detail['showInScene'] != true;
    await context.read<AppState>().updateCharacter(widget.character);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.watch<AppState>().compactMode;
    final themeId = context.watch<AppState>().themeId;
    final scheme = Theme.of(context).colorScheme;

    final inventoryFilters = const ['Todos', 'Arma', 'Armadura', 'Consumível', 'Munição', 'Acessório', 'Ferramenta', 'Outro'];
    final abilityFilters = const ['Todos', 'Habilidade', 'Magia', 'Técnica', 'Passiva', 'Outro'];
    final activeFilter = widget.isAbility ? _abilityFilter : _inventoryFilter;
    final searchQuery = (widget.isAbility ? _abilitySearch : _inventorySearch).text.trim().toLowerCase();
    final visibleEntries = widget.items.asMap().entries.where((entry) {
      final category = widget.details[entry.value]?['category']?.toString() ?? 'Outro';
      if (activeFilter != 'Todos' && category != activeFilter) return false;
      if (searchQuery.isEmpty) return true;
      final description = widget.descriptions[entry.value]?.toLowerCase() ?? '';
      return entry.value.toLowerCase().contains(searchQuery) ||
          category.toLowerCase().contains(searchQuery) ||
          description.contains(searchQuery);
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 16, compact ? 10 : 14, compact ? 10 : 16, 28),
      children: [
        Row(children: [
          ThemedSectionIcon(themeId, widget.iconRole, size: 20),
          const SizedBox(width: 8),
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (widget.items.isNotEmpty)
            Text('${visibleEntries.length}/${widget.items.length}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          IconButton(onPressed: () => _openEditor(), tooltip: 'Adicionar', icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: widget.isAbility ? _abilitySearch : _inventorySearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.isAbility
                ? 'Buscar habilidades, magias ou técnicas'
                : 'Buscar itens, armas, consumíveis ou equipamentos',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: (widget.isAbility ? _abilitySearch : _inventorySearch).text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close, size: 19),
                    onPressed: () {
                      (widget.isAbility ? _abilitySearch : _inventorySearch).clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: abyssChipBarHeight(context, 38),
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
              margin: EdgeInsets.only(bottom: compact ? 6 : cardSpacing),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openEditor(index: entry.key),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 9 : 11),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    // Abissal: ilustração no lugar do quadrado cinza com ícone.
                    ActionIconSlot(
                      themeId: themeId,
                      artPath: ActionArtResolver.resolve(
                        kind: widget.isAbility ? ActionArtKind.ability : ActionArtKind.item,
                        name: item,
                        description: widget.descriptions[item] ?? '',
                        category: category,
                      ),
                      size: actionArtSize(compact),
                      fallback: Container(
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
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: detail['showInScene'] == true ? 'Desafixar do Em Cena' : 'Fixar no Em Cena',
                      onPressed: () => _toggleInScene(item),
                      icon: Icon(
                        detail['showInScene'] == true ? Icons.star : Icons.star_border,
                        size: 20,
                        color: detail['showInScene'] == true ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Excluir',
                      onPressed: () => _delete(entry.key),
                      icon: const Icon(Icons.delete_outline, size: 20),
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
