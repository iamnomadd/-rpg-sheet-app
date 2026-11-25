import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/abyss_theme.dart' show usesAbyssDesign;
import '../../app/condition_presets.dart';
import '../../models/campaign.dart';
import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../utils/resource_math.dart';
import '../../utils/action_art.dart';
import '../../utils/spell_icon.dart';
import '../character/resource_quick_adjust.dart';
import 'initiative_tools.dart';
import '../../widgets/card_spacing.dart';

class NpcSheetScreen extends StatefulWidget {
  final String campaignId;
  final String npcId;
  const NpcSheetScreen({super.key, required this.campaignId, required this.npcId});

  @override
  State<NpcSheetScreen> createState() => _NpcSheetScreenState();
}

class _NpcSheetScreenState extends State<NpcSheetScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Campaign? _campaign(AppState state) {
    final matches = state.campaigns.where((c) => c.id == widget.campaignId);
    return matches.isEmpty ? null : matches.first;
  }

  Map<String, dynamic>? _npc(Campaign c) {
    final matches = c.npcSheets.where((n) => '${n['id']}' == widget.npcId);
    return matches.isEmpty ? null : matches.first;
  }

  Character? _sheet(Map<String, dynamic> npc) {
    final raw = npc['sheet'];
    if (raw is! Map) return null;
    return Character.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> _save(Campaign campaign, Map<String, dynamic> npc, Character sheet) async {
    npc['name'] = sheet.name;
    npc['sheet'] = sheet.toJson();
    await context.read<AppState>().updateCampaign(campaign);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final campaign = _campaign(state);
    if (campaign == null) return const Scaffold(body: Center(child: Text('Campanha não encontrada.')));
    final npc = _npc(campaign);
    if (npc == null) return const Scaffold(body: Center(child: Text('NPC não encontrado.')));
    final sheet = _sheet(npc);
    if (sheet == null) return const Scaffold(body: Center(child: Text('Ficha do NPC inválida.')));
    final kind = '${npc['kind'] ?? 'NPC'}';

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sheet.name),
          Text(kind, style: Theme.of(context).textTheme.labelSmall),
        ]),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumo'),
            Tab(icon: Icon(Icons.favorite_outline), text: 'Status'),
            Tab(icon: Icon(Icons.sports_martial_arts_outlined), text: 'Ações'),
            Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Habilidades'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventário'),
            Tab(icon: Icon(Icons.notes_outlined), text: 'Notas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _summary(campaign, npc, sheet),
          _status(campaign, npc, sheet),
          _actions(campaign, npc, sheet),
          _stringList(campaign, npc, sheet, title: 'Habilidades', items: sheet.abilities, descriptions: sheet.abilityDescriptions),
          _stringList(campaign, npc, sheet, title: 'Inventário', items: sheet.inventory, descriptions: sheet.inventoryDescriptions),
          _notes(campaign, npc, sheet),
        ],
      ),
    );
  }

  Widget _summary(Campaign campaign, Map<String, dynamic> npc, Character sheet) {
    final state = context.watch<AppState>();
    final matchingSystems = state.systems.where((s) => s.id == sheet.systemId);
    final systemName = matchingSystems.isEmpty ? sheet.systemId : matchingSystems.first.name;
    final vida = readVida(sheet);
    final hp = vida.current;
    final maxHp = vida.max;
    final secondaryResources = npcSecondaryResourceNames(
      systemResources: matchingSystems.isEmpty ? null : matchingSystems.first.resources,
      values: sheet.resourceValues,
      maxValues: sheet.resourceMaxValues,
    );
    final weapons = sheet.inventory.where((n) => sheet.inventoryDetails[n]?['category'] == 'Arma' || (sheet.inventoryDetails[n]?['damage']?.toString().trim().isNotEmpty ?? false)).toList();
    final consumables = sheet.inventory.where((n) => sheet.inventoryDetails[n]?['category'] == 'Consumível').toList();
    final spells = sheet.abilities.where((n) => sheet.abilityDetails[n]?['category'] == 'Magia').toList();
    final positives = sheet.conditions.where((n) => conditionPresetFor(n)?.positive == true).length;
    final negatives = sheet.conditions.where((n) => conditionPresetFor(n)?.positive != true).length;

    Widget resourceCard(String name, int value, int max, {required IconData icon}) => Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: name.isEmpty ? null : () => _editResource(campaign, npc, sheet, name),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(child: Text(name.isEmpty ? 'Recurso' : name, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('$value / $max', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble()),
          ]),
        ),
      ),
    );

    Widget sectionTitle(IconData icon, String text, {String? trailing}) => Row(children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
      if (trailing != null) Text(trailing, style: Theme.of(context).textTheme.labelLarge),
    ]);

    final ordered = <String>[];
    const defaults = ['sessionOverview', 'health', 'energy', 'conditions', 'attributes', 'quickActions', 'abilities', 'inventory'];
    for (final id in sheet.generalOrder) {
      if (defaults.contains(id) && !ordered.contains(id)) ordered.add(id);
    }
    for (final id in defaults) {
      if (!ordered.contains(id)) ordered.add(id);
    }

    Widget cardFor(String id) {
      switch (id) {
        case 'sessionOverview':
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                sectionTitle(Icons.bolt_outlined, 'Sessão', trailing: 'Nível ${sheet.level}'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(avatar: const Icon(Icons.gps_fixed, size: 16), label: Text('${weapons.length} arma${weapons.length == 1 ? '' : 's'}')),
                  Chip(avatar: const Icon(Icons.auto_awesome_outlined, size: 16), label: Text('${spells.length} magia${spells.length == 1 ? '' : 's'}')),
                  Chip(avatar: const Icon(Icons.local_drink_outlined, size: 16), label: Text('${consumables.length} consumível${consumables.length == 1 ? '' : 'is'}')),
                  if (positives > 0) Chip(avatar: const Icon(Icons.add_circle_outline, size: 16), label: Text('$positives positivo${positives == 1 ? '' : 's'}')),
                  if (negatives > 0) Chip(avatar: const Icon(Icons.warning_amber_rounded, size: 16), label: Text('$negatives negativo${negatives == 1 ? '' : 's'}')),
                ]),
              ]),
            ),
          );
        case 'health':
          return resourceCard('Vida', hp, maxHp, icon: Icons.favorite_outline);
        case 'energy':
          if (secondaryResources.isEmpty) return resourceCard('', 0, 0, icon: Icons.bolt_outlined);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < secondaryResources.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              resourceCard(
                secondaryResources[i],
                sheet.resourceValues[secondaryResources[i]] ?? 0,
                sheet.resourceMaxValues[secondaryResources[i]] ?? 0,
                icon: Icons.bolt_outlined,
              ),
            ],
          ]);
        case 'conditions':
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _tabs.animateTo(1),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  sectionTitle(Icons.health_and_safety_outlined, 'Condições', trailing: '${sheet.conditions.length}'),
                  const SizedBox(height: 10),
                  if (sheet.conditions.isEmpty)
                    const Text('Nenhuma condição ativa.')
                  else
                    Wrap(spacing: 7, runSpacing: 7, children: sheet.conditions.take(6).map((c) => Chip(label: Text(c))).toList()),
                ]),
              ),
            ),
          );
        case 'attributes':
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                sectionTitle(Icons.hexagon_outlined, 'Atributos'),
                const SizedBox(height: 10),
                if (sheet.attributes.isEmpty)
                  const Text('Nenhum atributo configurado.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sheet.attributes.entries.map((e) => ActionChip(
                      label: Text('${e.key}: ${e.value}'),
                      onPressed: () => _editAttribute(campaign, npc, sheet, e.key),
                    )).toList(),
                  ),
              ]),
            ),
          );
        case 'quickActions':
          final quick = <MapEntry<String, String>>[
            ...weapons.take(3).map((name) => MapEntry(name, 'Dano ${sheet.inventoryDetails[name]?['damage'] ?? '—'}')),
            ...sheet.abilities.take(3).map((name) => MapEntry(name, sheet.abilityDescriptions[name] ?? 'Habilidade')),
          ].take(5).toList();
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _tabs.animateTo(2),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  sectionTitle(Icons.flash_on_outlined, 'Ações rápidas'),
                  const SizedBox(height: 10),
                  if (quick.isEmpty)
                    const Text('Nenhuma ação cadastrada.')
                  else
                    ...quick.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.chevron_right, size: 18),
                        const SizedBox(width: 4),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                      ]),
                    )),
                ]),
              ),
            ),
          );
        case 'abilities':
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _tabs.animateTo(3),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  sectionTitle(Icons.auto_awesome_outlined, 'Habilidades', trailing: '${sheet.abilities.length}'),
                  const SizedBox(height: 10),
                  if (sheet.abilities.isEmpty)
                    const Text('Nenhuma habilidade.')
                  else
                    ...sheet.abilities.take(5).map((name) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if ((sheet.abilityDescriptions[name] ?? '').isNotEmpty)
                          Text(sheet.abilityDescriptions[name]!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    )),
                ]),
              ),
            ),
          );
        case 'inventory':
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _tabs.animateTo(4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  sectionTitle(Icons.inventory_2_outlined, 'Inventário', trailing: '${sheet.inventory.length} item(ns)'),
                  const SizedBox(height: 10),
                  if (sheet.inventory.isEmpty)
                    const Text('Nenhum item.')
                  else
                    ...sheet.inventory.take(5).map((name) {
                      final d = sheet.inventoryDetails[name] ?? const <String, dynamic>{};
                      final category = d['category']?.toString() ?? 'Item';
                      final damage = d['damage']?.toString().trim() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(damage.isEmpty ? category : '$category • Dano $damage'),
                        ]),
                      );
                    }),
                ]),
              ),
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: ordered.length + 1,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex == 0 || newIndex == 0) return;
        var from = oldIndex - 1;
        var to = newIndex - 1;
        if (to > from) to -= 1;
        final moved = ordered.removeAt(from);
        ordered.insert(to.clamp(0, ordered.length).toInt(), moved);
        sheet.generalOrder = [...ordered];
        await _save(campaign, npc, sheet);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            key: const ValueKey('npc-summary-identity'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 27, child: Icon(_kindIcon('${npc['kind'] ?? 'NPC'}'))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sheet.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${npc['kind'] ?? 'NPC'} • ${sheet.race.isEmpty ? 'Sem raça' : sheet.race} • ${sheet.className.isEmpty ? 'Sem classe' : sheet.className}'),
                      const SizedBox(height: 2),
                      Text('Nível ${sheet.level} • $systemName', style: Theme.of(context).textTheme.bodySmall),
                    ])),
                    IconButton(onPressed: () => _editIdentity(campaign, npc, sheet), icon: const Icon(Icons.edit_outlined)),
                  ]),
                  if (sheet.background.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Antecedente', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(sheet.background),
                  ],
                ]),
              ),
            ),
          );
        }
        final id = ordered[index - 1];
        return Padding(
          key: ValueKey('npc-summary-$id'),
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: cardFor(id)),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.drag_handle)),
            ),
          ]),
        );
      },
    );
  }

  Widget _status(Campaign campaign, Map<String, dynamic> npc, Character sheet) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Condições ativas', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (sheet.conditions.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma condição ativa.'))),
      Wrap(spacing: 8, runSpacing: 8, children: sheet.conditions.map((c) => InputChip(
        label: Text(c),
        onDeleted: () async { sheet.conditions.remove(c); await _save(campaign, npc, sheet); },
      )).toList()),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: () => _chooseCondition(campaign, npc, sheet), icon: const Icon(Icons.add), label: const Text('Adicionar condição')),
    ],
  );

  Widget _actions(Campaign campaign, Map<String, dynamic> npc, Character sheet) {
    final weaponNames = sheet.inventory.where((name) => (sheet.inventoryDetails[name]?['damage']?.toString().trim().isNotEmpty ?? false)).toList();
    final themeId = context.watch<AppState>().themeId;
    final artSize = actionArtSize(context.watch<AppState>().compactMode);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text('Ataques', style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => _addAction(campaign, npc, sheet, weapon: true), icon: const Icon(Icons.add))]),
      if (weaponNames.isEmpty) const Card(margin: cardSpacingMargin, child: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Nenhum ataque cadastrado.'))),
      ...weaponNames.map((name) { final d = sheet.inventoryDetails[name] ?? {}; return Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ActionIconSlot(
          themeId: themeId,
          artPath: usesAbyssDesign(themeId) ? ActionArtResolver.resolve(kind: ActionArtKind.weapon, name: name, description: sheet.inventoryDescriptions[name] ?? '') : null,
          size: artSize,
          fallback: const Icon(Icons.gps_fixed),
        ),
        title: Text(name),
        subtitle: Text('Dano ${d['damage'] ?? '—'}${d['ammo'] != null ? ' • Munição ${d['ammo']}' : ''}'),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _editAction(campaign, npc, sheet, name, weapon: true),
      )); }),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: Text('Poderes / Magias', style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => _addAction(campaign, npc, sheet, weapon: false), icon: const Icon(Icons.add))]),
      if (sheet.abilities.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma habilidade cadastrada.'))),
      ...sheet.abilities.map((name) { final d = sheet.abilityDetails[name] ?? {}; final isSpell = d['category'] == 'Magia'; return Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ActionIconSlot(
          themeId: themeId,
          artPath: usesAbyssDesign(themeId)
              ? ActionArtResolver.resolve(kind: isSpell ? ActionArtKind.spell : ActionArtKind.ability, name: name, description: sheet.abilityDescriptions[name] ?? '', category: d['category']?.toString() ?? '')
              : null,
          size: artSize,
          fallback: Icon(
            isSpell ? SpellIconResolver.resolve(name, description: sheet.abilityDescriptions[name] ?? '') : Icons.auto_awesome,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(name),
        subtitle: Text([if ((d['damage'] ?? '').toString().isNotEmpty) 'Dano ${d['damage']}', if ((sheet.abilityDescriptions[name] ?? '').isNotEmpty) sheet.abilityDescriptions[name]!].join(' • ')),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _editAction(campaign, npc, sheet, name, weapon: false),
      )); }),
    ]);
  }

  Widget _stringList(Campaign campaign, Map<String, dynamic> npc, Character sheet, {required String title, required List<String> items, required Map<String,String> descriptions}) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => _addSimpleItem(campaign, npc, sheet, title, items, descriptions), icon: const Icon(Icons.add))]),
      if (items.isEmpty) Card(margin: cardSpacingMargin, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Nenhum item em $title.'))),
      ...items.map((name) => Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(name),
        subtitle: (descriptions[name] ?? '').isEmpty ? null : Text(descriptions[name]!),
        trailing: PopupMenuButton<String>(itemBuilder: (_) => const [PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))], onSelected: (v) async {
          if (v == 'delete') { items.remove(name); descriptions.remove(name); await _save(campaign, npc, sheet); }
          else { await _editSimpleItem(campaign, npc, sheet, name, items, descriptions); }
        }),
      ))),
    ],
  );

  Widget _notes(Campaign campaign, Map<String, dynamic> npc, Character sheet) {
    final ctrl = TextEditingController(text: sheet.sectionNotes['npcNotes'] ?? '');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Notas privadas do Mestre', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(controller: ctrl, minLines: 10, maxLines: 18, decoration: const InputDecoration(hintText: 'Táticas, personalidade, segredos, comportamento em combate...')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () async { sheet.sectionNotes['npcNotes'] = ctrl.text; await _save(campaign, npc, sheet); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notas salvas.'))); }, icon: const Icon(Icons.save_outlined), label: const Text('Salvar notas')),
    ]);
  }

  IconData _kindIcon(String kind) => switch (kind) { 'Monstro' => Icons.bug_report_outlined, 'Chefe' => Icons.workspace_premium_outlined, 'Aliado' => Icons.shield_outlined, _ => Icons.person_outline };

  Future<void> _editIdentity(Campaign campaign, Map<String,dynamic> npc, Character sheet) async {
    final name = TextEditingController(text: sheet.name);
    final race = TextEditingController(text: sheet.race);
    final className = TextEditingController(text: sheet.className);
    final background = TextEditingController(text: sheet.background);
    final level = TextEditingController(text: '${sheet.level}');
    String kind='${npc['kind'] ?? 'NPC'}';
    final ok=await showDialog<bool>(
      context:context,
      builder:(d)=>StatefulBuilder(builder:(context,setD)=>AlertDialog(
        title:const Text('Identidade do NPC'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:name,decoration:const InputDecoration(labelText:'Nome')),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(initialValue:kind,items:const ['NPC','Monstro','Aliado','Chefe'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setD(()=>kind=v??kind),decoration:const InputDecoration(labelText:'Tipo')),
          const SizedBox(height:10),
          TextField(controller:race,decoration:const InputDecoration(labelText:'Raça / espécie')),
          const SizedBox(height:10),
          TextField(controller:className,decoration:const InputDecoration(labelText:'Classe / arquétipo')),
          const SizedBox(height:10),
          TextField(controller:background,decoration:const InputDecoration(labelText:'Antecedente / identidade')),
          const SizedBox(height:10),
          TextField(controller:level,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nível')),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar')),
        ],
      )),
    );
    if(ok==true && name.text.trim().isNotEmpty){
      sheet.name=name.text.trim();
      sheet.race=race.text.trim();
      sheet.className=className.text.trim();
      sheet.background=background.text.trim();
      sheet.level=(int.tryParse(level.text.trim()) ?? sheet.level).clamp(1,999);
      npc['kind']=kind;
      await _save(campaign,npc,sheet);
    }
    name.dispose(); race.dispose(); className.dispose(); background.dispose(); level.dispose();
  }

  Future<void> _editAttribute(Campaign campaign, Map<String,dynamic> npc, Character sheet, String key) async {
    final c=TextEditingController(text:'${sheet.attributes[key] ?? 0}');
    final v=await showDialog<int>(context:context,builder:(d)=>AlertDialog(title:Text('Atributo $key'),content:TextField(controller:c,keyboardType:TextInputType.number,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,int.tryParse(c.text.trim())),child:const Text('Salvar'))]));
    if(v!=null){sheet.attributes[key]=v;await _save(campaign,npc,sheet);}
  }

  Future<void> _editResource(Campaign campaign, Map<String,dynamic> npc, Character sheet, String key) async {
    final isLife = isLifeResourceKey(key);
    final vida = isLife ? readVida(sheet) : null;
    final current = vida?.current ?? sheet.resourceValues[key] ?? 0;
    final maximum = vida?.max ?? sheet.resourceMaxValues[key] ?? current;
    final value = TextEditingController(text: '$current');
    final max = TextEditingController(text: '$maximum');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Configurar $key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Valor atual'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: max,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Valor máximo'),
              ),
              if (key.toLowerCase() == 'vida') ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ajuste rápido',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.heart_broken_outlined),
                        label: const Text('Receber dano'),
                        onPressed: () async {
                          final amount = await _askResourceAmount(
                            context,
                            title: 'Receber dano',
                            label: 'Dano recebido',
                          );
                          if (amount == null) return;
                          final base = int.tryParse(value.text) ?? current;
                          final limit = (int.tryParse(max.text) ?? maximum).clamp(0, 999999).toInt();
                          setDialogState(() {
                            value.text = applyResourceDelta(
                              current: base,
                              maximum: limit,
                              delta: -amount,
                            ).toString();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.favorite_outline),
                        label: const Text('Curar'),
                        onPressed: () async {
                          final amount = await _askResourceAmount(
                            context,
                            title: 'Curar',
                            label: 'Vida recuperada',
                          );
                          if (amount == null) return;
                          final base = int.tryParse(value.text) ?? current;
                          final limit = (int.tryParse(max.text) ?? maximum).clamp(0, 999999).toInt();
                          setDialogState(() {
                            value.text = applyResourceDelta(
                              current: base,
                              maximum: limit,
                              delta: amount,
                            ).toString();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final newMax = (int.tryParse(max.text) ?? maximum).clamp(0, 999999).toInt();
      final newValue = (int.tryParse(value.text) ?? current).clamp(0, newMax).toInt();
      if (isLife) {
        // Vida e PV ficam iguais: grava na chave de vida resolvida, espelha
        // 'Vida' se existir e mantém hp/maxHp.
        applyVida(sheet, ResourceValues(current: newValue, max: newMax));
      } else {
        sheet.resourceValues[key] = newValue;
        sheet.resourceMaxValues[key] = newMax;
      }
      await _save(campaign, npc, sheet);
    }

    value.dispose();
    max.dispose();
  }

  Future<int?> _askResourceAmount(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, hintText: 'Ex.: 15'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text.trim());
              if (amount == null || amount < 0) return;
              Navigator.pop(dialogContext, amount);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _chooseCondition(Campaign campaign, Map<String,dynamic> npc, Character sheet) async {
    final name=await showDialog<String>(context:context,builder:(d)=>SimpleDialog(title:const Text('Adicionar condição'),children:[...conditionPresets.where((p)=>!sheet.conditions.contains(p.name)).map((p)=>SimpleDialogOption(onPressed:()=>Navigator.pop(d,p.name),child:Row(children:[Icon(p.icon),const SizedBox(width:10),Text(p.name)]))),SimpleDialogOption(onPressed:()async{final ctrl=TextEditingController();final x=await showDialog<String>(context:d,builder:(x)=>AlertDialog(title:const Text('Condição personalizada'),content:TextField(controller:ctrl,autofocus:true),actions:[FilledButton(onPressed:()=>Navigator.pop(x,ctrl.text.trim()),child:const Text('Adicionar'))]));if(d.mounted)Navigator.pop(d,x);},child:const Row(children:[Icon(Icons.add),SizedBox(width:10),Text('Personalizada')]))]));
    if(name!=null && name.isNotEmpty && !sheet.conditions.contains(name)){sheet.conditions.add(name);await _save(campaign,npc,sheet);}
  }

  Future<void> _addAction(Campaign campaign, Map<String,dynamic> npc, Character sheet,{required bool weapon}) async => _editAction(campaign,npc,sheet,'',weapon:weapon);
  Future<void> _editAction(Campaign campaign, Map<String,dynamic> npc, Character sheet,String oldName,{required bool weapon}) async {
    final details=weapon ? sheet.inventoryDetails : sheet.abilityDetails; final descriptions=weapon ? sheet.inventoryDescriptions : sheet.abilityDescriptions; final items=weapon ? sheet.inventory : sheet.abilities;
    final raw=details[oldName] ?? <String,dynamic>{}; final name=TextEditingController(text:oldName);final damage=TextEditingController(text:'${raw['damage'] ?? ''}');final desc=TextEditingController(text:descriptions[oldName] ?? '');
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(oldName.isEmpty?'Nova ação':'Editar ação'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nome')),TextField(controller:damage,decoration:const InputDecoration(labelText:'Dano (ex.: 1d8+3)')),TextField(controller:desc,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'Descrição'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar'))]));
    final n=name.text.trim();if(ok!=true||n.isEmpty)return;if(oldName.isNotEmpty&&oldName!=n){items.remove(oldName);details.remove(oldName);descriptions.remove(oldName);}if(!items.contains(n))items.add(n);details[n]={...raw,'damage':damage.text.trim()};descriptions[n]=desc.text.trim();await _save(campaign,npc,sheet);
  }

  Future<void> _addSimpleItem(Campaign campaign, Map<String,dynamic> npc, Character sheet,String title,List<String> items,Map<String,String> descriptions) async => _editSimpleItem(campaign,npc,sheet,'',items,descriptions);
  Future<void> _editSimpleItem(Campaign campaign, Map<String,dynamic> npc, Character sheet,String oldName,List<String> items,Map<String,String> descriptions) async {
    final name=TextEditingController(text:oldName);final desc=TextEditingController(text:descriptions[oldName]??'');final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(oldName.isEmpty?'Adicionar':'Editar'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nome')),TextField(controller:desc,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'Descrição'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar'))]));final n=name.text.trim();if(ok!=true||n.isEmpty)return;if(oldName.isNotEmpty&&oldName!=n){items.remove(oldName);descriptions.remove(oldName);}if(!items.contains(n))items.add(n);descriptions[n]=desc.text.trim();await _save(campaign,npc,sheet);
  }
}
