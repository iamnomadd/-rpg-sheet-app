part of 'character_screen.dart';

class _ActionsTab extends StatefulWidget {
  final Character character;
  final RpgSystem system;
  final bool embedded;
  final bool showCombat;
  final bool showResources;
  final bool showConditions;
  final bool showQuickActions;

  /// Âncoras do Em Cena para os cabeçalhos (pílulas do card Sessão).
  final _EmCenaAnchors? anchors;

  const _ActionsTab({
    required this.character,
    required this.system,
    this.embedded = false,
    this.showCombat = true,
    this.showResources = true,
    this.showConditions = true,
    this.showQuickActions = true,
    this.anchors,
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
    final result = await showResourceQuickAdjust(
      context,
      name: name,
      current: widget.character.resourceValues[name] ?? 0,
      max: widget.character.resourceMaxValues[name] ?? 0,
    );
    if (result == null || !mounted) return;
    _applyResourceValues(widget.character, name, result);
    await _save();
  }
  Widget _resource(String name){final current=widget.character.resourceValues[name]??0,max=widget.character.resourceMaxValues[name]??0,value=max<=0?0.0:(current/max).clamp(0.0,1.0);final themeId=context.watch<AppState>().themeId,secondary=name.toLowerCase()!='vida';return Card(child:Padding(padding:const EdgeInsets.fromLTRB(14,10,14,12),child:Column(children:[Row(children:[ThemedResourceIcon(themeId,name,fallbackIcon:secondary?Icons.bolt:themedIcon(themeId,'resources'),size:22),const SizedBox(width:8),Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.w700))),IconButton(tooltip:'Diminuir',visualDensity:VisualDensity.compact,onPressed:()=>_changeResource(name,-1),icon:const Icon(Icons.remove)),Text('$current / $max',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w600)),IconButton(tooltip:'Aumentar',visualDensity:VisualDensity.compact,onPressed:()=>_changeResource(name,1),icon:const Icon(Icons.add))]),const SizedBox(height:7),ResourceBarTapTarget(label:name,onTap:()=>_editResourceValue(name),child:_ThemedResourceBar(value:value,themeId:themeId,secondary:secondary,resourceName:name))])));}

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
    final order = <String>[
      ...widget.character.actionOrder.where(_groups.contains),
      ..._groups.where((g) => !widget.character.actionOrder.contains(g)),
    ];
    final result = await _showCustomizeSheet(
      context,
      title: 'Personalizar Ações',
      subtitle: 'Arraste os grupos e escolha quais aparecem.',
      order: order,
      hidden: {...widget.character.hiddenActionGroups},
      labels: _labels,
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
    if (id == 'consumables') {
      // Zerados (Qtd. 0) vão para o fim do grupo, na mesma ordem entre si.
      final all = c.inventory.where((n) => c.inventoryDetails[n]?['category'] == 'Consumível').toList();
      bool empty(String n) => ((c.inventoryDetails[n]?['quantity'] as num?)?.toInt() ?? 1) <= 0;
      names = [...all.where((n) => !empty(n)), ...all.where(empty)];
    }
    if (id == 'spells') names = c.abilities.where((n) => c.abilityDetails[n]?['category'] == 'Magia').toList();
    if (id == 'abilities') {
      names = c.abilities.where((n) {
        final x = c.abilityDetails[n]?['category'];
        return x == 'Técnica' || x == 'Habilidade';
      }).toList();
    }
    if (names.isEmpty) return const SizedBox.shrink();
    // Lidos uma vez por grupo (não em cada linha).
    final themeId = context.watch<AppState>().themeId;
    final artSize = actionArtSize(compact);

    final groupIcon = switch (id) {
      'weapons' => Icons.gps_fixed,
      'spells' => Icons.auto_awesome_outlined,
      'abilities' => Icons.bolt_outlined,
      _ => Icons.local_drink_outlined,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        key: widget.anchors?.section(id),
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

        final row = Card(
          margin: EdgeInsets.only(bottom: compact ? 5 : 8),
          child: Padding(
            padding: abyssCardInset,
            child: Row(children: [
              // Abissal: ilustração da ação; nos outros temas, o mesmo ícone de antes.
              ActionIconSlot(
                themeId: themeId,
                artPath: ActionArtResolver.resolve(
                  kind: switch (id) { 'weapons' => ActionArtKind.weapon, 'consumables' => ActionArtKind.item, 'spells' => ActionArtKind.spell, _ => ActionArtKind.ability },
                  name: name,
                  description: (id == 'weapons' || id == 'consumables' ? c.inventoryDescriptions[name] : c.abilityDescriptions[name]) ?? '',
                  category: switch (id) { 'consumables' => 'Consumível', 'spells' => 'Magia', _ => d['category']?.toString() ?? '' },
                ),
                size: artSize,
                // Sem arte: ícone fixo por tipo (magia → auto_awesome).
                fallback: Icon(
                  id == 'spells' ? Icons.auto_awesome : groupIcon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
                          ? Icons.auto_awesome
                          : Icons.play_arrow,
                  size: 17,
                ),
                label: Text(actionLabel),
              ),
            ]),
          ),
        );
        // Consumível zerado: a linha inteira fica a 60%.
        return id == 'consumables' && !enabled ? Opacity(key: ValueKey('zeroed-$name'), opacity: .6, child: row) : row;
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
      final conditionsTitle = Text('Condições ativas', key: widget.anchors?.section('conditions'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700));
      final conditionsButton = TextButton.icon(onPressed: _selectConditions, icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Alterar'));
      // Com texto grande, o botão desce de linha em vez de passar da moldura.
      content.add(Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [conditionsTitle, conditionsButton]));
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
