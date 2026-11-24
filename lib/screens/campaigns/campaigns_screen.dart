import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/condition_presets.dart';
import '../../models/campaign.dart';
import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../services/cloud_service.dart';
import '../../services/rpg_file_service.dart';
import 'npc_sheet_screen.dart';
import 'initiative_tools.dart';
import '../character/resource_quick_adjust.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/card_spacing.dart';


IconData _npcKindIcon(String kind) => switch (kind) {
  'Monstro' => Icons.bug_report_outlined,
  'Chefe' => Icons.workspace_premium_outlined,
  'Aliado' => Icons.shield_outlined,
  _ => Icons.person_outline,
};

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});
  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _campaignId;
  Timer? _syncTimer;
  bool _syncBusy = false;
  DateTime? _lastSync;
  int _syncFailures = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _scheduleAutoSync(const Duration(seconds: 1));
  }

  void _scheduleAutoSync(Duration delay) {
    _syncTimer?.cancel();
    _syncTimer=Timer(delay,(){
      if(mounted)_autoSync();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _autoSync() async {
    if (!mounted || _syncBusy || _campaignId == null) return;
    final state=context.read<AppState>();
    final found=state.campaigns.where((c)=>c.id==_campaignId);
    if(found.isEmpty) return;
    _syncBusy=true;
    try {
      final synced = await _refreshRemotePlayers(context, found.first, quiet:true);
      if(synced){
        _syncFailures=0;
        if(mounted)setState(()=>_lastSync=DateTime.now());
      }else{
        _syncFailures++;
      }
    } finally {
      _syncBusy=false;
      if(mounted){
        final delay=_syncFailures==0
            ? const Duration(seconds:4)
            : Duration(seconds:(4 * (1 << _syncFailures.clamp(0,2))).clamp(8,20));
        _scheduleAutoSync(delay);
      }
    }
  }

  Future<void> _createCampaign(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Nova campanha'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome da campanha')),
        const SizedBox(height: 10),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Criar'))],
    ));
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    final campaign = Campaign(id: const Uuid().v4(), name: name.text.trim(), description: description.text.trim());
    await context.read<AppState>().addCampaign(campaign);
    if (mounted) setState(() => _campaignId = campaign.id);
  }

  Future<void> _selectCampaign(BuildContext context, List<Campaign> campaigns) async {
    final selected = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ListTile(title: Text('Campanhas', style: TextStyle(fontWeight: FontWeight.w700))),
      ...campaigns.map((c) => ListTile(leading: Icon(c.id == _campaignId ? Icons.radio_button_checked : Icons.radio_button_off), title: Text(c.name), subtitle: c.description.isEmpty ? null : Text(c.description, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => Navigator.pop(context, c.id))),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.add), title: const Text('Criar nova campanha'), onTap: () => Navigator.pop(context, '__new__')),
    ])));
    if (!mounted || selected == null) return;
    if (selected == '__new__') return _createCampaign(context);
    setState(() => _campaignId = selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.campaigns.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Mestre')), body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.workspace_premium_outlined, size: 64), const SizedBox(height: 16),
        Text('Crie sua primeira campanha', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
        const Text('Cada campanha mantém jogadores, NPCs, sessão e notas separadamente.', textAlign: TextAlign.center), const SizedBox(height: 20),
        FilledButton.icon(onPressed: () => _createCampaign(context), icon: const Icon(Icons.add), label: const Text('Criar campanha')),
      ]))));
    }
    final id = state.campaigns.any((c) => c.id == _campaignId) ? _campaignId! : state.campaigns.first.id;
    _campaignId = id;
    final c = state.campaigns.firstWhere((x) => x.id == id);
    return Scaffold(
      appBar: AppBar(title: const Text('Mestre'), actions: [IconButton(tooltip: 'Nova campanha', onPressed: () => _createCampaign(context), icon: const Icon(Icons.add))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _selectCampaign(context, state.campaigns), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
          const Icon(Icons.menu_book_outlined), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.name, style: Theme.of(context).textTheme.titleLarge), Text('Trocar campanha', style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.keyboard_arrow_down),
        ])))),
        TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumo'), Tab(icon: Icon(Icons.people_outline), text: 'Jogadores'), Tab(icon: Icon(Icons.person_search_outlined), text: 'NPCs'), Tab(icon: Icon(Icons.sports_martial_arts_outlined), text: 'Sessão'), Tab(icon: Icon(Icons.notes_outlined), text: 'Notas')]),
        const Divider(height: 1),
        Expanded(child: TabBarView(controller: _tabs, children: [_summary(context, state, c), _players(context, state, c), _npcs(context, c), _session(context, c), _notes(context, c)])),
      ]),
    );
  }

  Widget _summary(BuildContext context, AppState state, Campaign c) => ListView(padding: const EdgeInsets.all(16), children: [
    _masterStatusCard(context,c),
    if (c.description.isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Text(c.description,style:Theme.of(context).textTheme.bodyMedium)),
    const SizedBox(height:12),
    Row(children:[
      Expanded(child:_metricCard(context,Icons.people_outline,'Jogadores','${c.characterIds.length+c.linkedCharacters.where((x)=>x['status']=='approved').length}')),
      const SizedBox(width:8),
      Expanded(child:_metricCard(context,Icons.person_search_outlined,'NPCs','${c.npcs.length + c.npcSheets.length}')),
      const SizedBox(width:8),
      Expanded(child:_metricCard(context,Icons.sports_martial_arts_outlined,'Rodada','${c.sessionRound}')),
    ]),
    const SizedBox(height:8),
    Card(margin: cardSpacingMargin, child:ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading:Icon(c.combatActive?Icons.play_circle_fill:Icons.pause_circle_outline),title:Text(c.combatActive?'Sessão em andamento':'Sessão preparada'),subtitle:Text('${c.initiative.length} na iniciativa • ${c.conditions.length} condições'),trailing:const Icon(Icons.chevron_right),onTap:(){_tabs.animateTo(3);})), 
    Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.movie_filter_outlined), title: const Text('Cena atual'), subtitle: Text(c.masterScene.isEmpty ? 'Nenhuma cena definida.' : c.masterScene), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MasterToolsScreen(campaignId: c.id))))),
  ]);

  Widget _masterStatusCard(BuildContext context, Campaign c) {
    final accent=Theme.of(context).colorScheme.primary;
    return Container(
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:accent.withOpacity(.28)),color:accent.withOpacity(.07)),
      child:Row(children:[
        Container(width:44,height:44,decoration:BoxDecoration(shape:BoxShape.circle,color:accent.withOpacity(.16)),child:Icon(c.combatActive?Icons.sports_martial_arts:Icons.workspace_premium_outlined,color:accent)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(c.combatActive?'Combate ativo':'Painel do Mestre',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),
          const SizedBox(height:2),
          Text(_syncBusy?'Sincronizando jogadores...':_lastSync==null?'Sincronização automática ativa':'Sincronizado • ${TimeOfDay.fromDateTime(_lastSync!).format(context)}',style:Theme.of(context).textTheme.bodySmall),
        ])),
        IconButton(tooltip:'Sincronizar agora',onPressed:_syncBusy?null:_autoSync,icon:Icon(_syncBusy?Icons.sync:Icons.cloud_done_outlined)),
      ]),
    );
  }

  Widget _metricCard(BuildContext context, IconData icon, String label, String value) => Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:12),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),color:Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45)),
    child:Column(children:[Icon(icon,size:20),const SizedBox(height:6),Text(value,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),Text(label,style:Theme.of(context).textTheme.labelSmall,maxLines:1,overflow:TextOverflow.ellipsis)]),
  );

  Widget _players(BuildContext context, AppState state, Campaign c) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(child: ListTile(leading: const Icon(Icons.link), title: const Text('Vincular ficha por código'), subtitle: const Text('Solicite acesso seguro à ficha de outro jogador.'), trailing: Wrap(children: [IconButton(tooltip: 'Atualizar vínculos', onPressed: () => _refreshRemotePlayers(context, c), icon: const Icon(Icons.sync)), const Icon(Icons.chevron_right)]), onTap: () => _linkByCode(context, c))),
    if (c.linkedCharacters.isNotEmpty) ...[const SizedBox(height: 8), Text('Vínculos remotos', style: Theme.of(context).textTheme.titleMedium), ...c.linkedCharacters.map((x) { final snap=Map<String,dynamic>.from(x['snapshot'] as Map? ?? {}); final resources=Map<String,dynamic>.from(snap['resourceValues'] as Map? ?? {}); final max=Map<String,dynamic>.from(snap['resourceMaxValues'] as Map? ?? {}); final conditions=(snap['conditions'] as List? ?? []).map((e)=>e.toString()).toList(); return Card(margin: cardSpacingMargin, child:Padding(padding:const EdgeInsets.symmetric(vertical:2),child:ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading:CircleAvatar(child:Icon(x['status']=='approved'?Icons.person:Icons.hourglass_top)),
      title:Text(snap['name']?.toString() ?? 'Ficha vinculada',style:const TextStyle(fontWeight:FontWeight.w600)),
      subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(x['status']=='approved'?'Ficha sincronizada':'Aguardando aprovação'),
        if(resources.isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text(resources.entries.map((e)=>'${e.key} ${e.value}/${max[e.key] ?? e.value}').take(3).join('  •  '),maxLines:2,overflow:TextOverflow.ellipsis)),
      ]),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(x['status']=='approved'?Icons.cloud_done_outlined:Icons.cloud_queue_outlined),if(conditions.isNotEmpty)Text('${conditions.length} status',style:Theme.of(context).textTheme.labelSmall)]),
        PopupMenuButton<String>(itemBuilder:(_)=>const [PopupMenuItem(value:'unlink',child:Text('Desvincular'))],onSelected:(v){if(v=='unlink')_unlinkRemote(context,c,x);}),
      ]),
      onTap:x['status']=='approved'?()=>_editRemoteCharacter(context,c,x):null,
    ))); })],
    Row(children: [Expanded(child: Text('Jogadores locais', style: Theme.of(context).textTheme.titleMedium)), IconButton(tooltip: 'Selecionar fichas locais', onPressed: () => _pickLocalPlayers(context, state, c), icon: const Icon(Icons.person_add_alt_1))]),
    if (c.characterIds.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum jogador vinculado a esta campanha.'))),
    ...c.characterIds.map((id) { final found=state.characters.where((x)=>x.id==id); if(found.isEmpty) return const SizedBox.shrink(); final ch=found.first; return Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.person_outline), title: Text(ch.name), subtitle: Text(ch.resourceValues.entries.map((e)=>'${e.key}: ${e.value}/${ch.resourceMaxValues[e.key] ?? e.value}').take(3).join(' • ')), trailing: ch.conditions.isEmpty ? null : Text('${ch.conditions.length} status'))); }),
  ]);

  Future<void> _linkByCode(BuildContext context, Campaign c) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Vincular ficha'),
      content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código da ficha', hintText: 'AB12-CD34')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim().toUpperCase()), child: const Text('Solicitar acesso'))],
    ));
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      final session = await CloudService.ensureSession();
      final shared = await CloudService.lookupSharedCharacter(session, code);
      if (shared == null) throw Exception('Código de ficha não encontrado.');
      await CloudService.requestCharacterLink(session, shared, c.id);
      c.linkedCharacters.removeWhere((e) => e['shareCode'] == code);
      c.linkedCharacters.add({'shareCode': code, 'status': 'pending', 'snapshot': <String,dynamic>{'id': shared['character_id'], 'name': shared['display_name'] ?? 'Ficha'}, 'ownerId': shared['owner_id']});
      await context.read<AppState>().updateCampaign(c);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação enviada ao jogador.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível vincular: $e')));
    }
  }

  /// Desfaz o vínculo com uma ficha remota: primeiro na nuvem; só se der
  /// certo, tira da campanha e da iniciativa.
  Future<void> _unlinkRemote(BuildContext context, Campaign c, Map<String,dynamic> link) async {
    final snap=link['snapshot'] is Map ? link['snapshot'] as Map : const {};
    final name='${snap['name'] ?? 'Ficha'}';
    if(!await confirmDelete(context,title:'Desvincular ficha?',message:'"$name" sairá da campanha e da iniciativa. Para vincular de novo, o jogador precisará aprovar um novo pedido.',confirmLabel:'Desvincular'))return;
    if(!context.mounted)return;
    final state=context.read<AppState>();
    final code='${link['shareCode'] ?? ''}';
    try {
      final session=await CloudService.ensureSession();
      if(link['status']=='approved'){
        // Melhor esforço: o jogador não aplica depois um patch antigo do Mestre.
        try { await CloudService.updateSharedCharacterPatch(session,code,<String,dynamic>{}); } catch (_) {}
      }
      final requestId='${link['requestId'] ?? ''}';
      final deleted=requestId.isNotEmpty
          ? await CloudService.deleteLinkRequest(session,requestId)
          : await CloudService.deleteOwnLinkRequestByCode(session,c.id,code);
      // Nada apagado: se a linha já não existe (ex.: o jogador apagou a
      // ficha), é sucesso; se ainda existe, a falha é real.
      final stillExists=deleted ? null : await CloudService.linkRequestExists(session,requestId:requestId,campaignId:c.id,shareCode:code);
      if(!canRemoveLinkLocally(deleted:deleted,stillExists:stillExists)) throw Exception('o servidor ainda não permite desfazer vínculos. A atualização do banco (migration v150) precisa ser aplicada.');
    } catch(e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Não foi possível desvincular: $e')));
      return;
    }
    final initiativeChanged=removeRemoteLink(c,link);
    await state.updateCampaign(c);
    if(initiativeChanged) await _syncCombatState(c);
  }

  Future<void> _editRemoteCharacter(BuildContext context, Campaign c, Map<String,dynamic> link) async {
    final snap=Map<String,dynamic>.from(link['snapshot'] as Map? ?? {});
    final resources=Map<String,dynamic>.from(snap['resourceValues'] as Map? ?? {});
    final conditions=(snap['conditions'] as List? ?? []).map((e)=>e.toString()).toList();
    // A vida (Vida/PV) do jogador é só dele: o mestre não vê nem envia esse campo.
    final ctrls={for(final e in resources.entries) if(!isLifeResourceKey(e.key)) e.key: TextEditingController(text:'${e.value}')};
    final cond=TextEditingController(text:conditions.join(', '));
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:Text('Atualizar ${snap['name'] ?? 'ficha'}'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ...ctrls.entries.map((e)=>TextField(controller:e.value,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:e.key))),
        TextField(controller:cond,decoration:const InputDecoration(labelText:'Condições',hintText:'Separadas por vírgula'),maxLines:2),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Enviar ao jogador'))],
    ));
    if(ok!=true || !context.mounted) return;
    final values=<String,int>{}; for(final e in ctrls.entries){ final v=int.tryParse(e.value.text.trim()); if(v!=null) values[e.key]=v; }
    final newConditions=cond.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
    try {
      final session=await CloudService.ensureSession();
      await CloudService.updateSharedCharacterPatch(session,'${link['shareCode']}',{'resourceValues':values,'conditions':newConditions});
    } catch(e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Não foi possível sincronizar: $e')));
    }
  }

  /// Tira das pendências de condição dos jogadores remotos o que o snapshot
  /// novo já confirmou.
  void _pruneConfirmedConditions(Campaign c) {
    for (final entry in c.initiative) {
      if (entry['type'] != 'player') continue;
      final link = _remoteLink(c, '${entry['id'] ?? ''}');
      if (link == null) continue;
      final pruned = pruneConfirmed(
        conditionsFromRaw((link['snapshot'] as Map)['conditions']),
        initiativeConditions(entry),
        conditionsFromRaw(entry['conditionsRemoved']),
      );
      if (entry.containsKey('conditions') || pruned.add.isNotEmpty) entry['conditions'] = pruned.add;
      if (entry.containsKey('conditionsRemoved') || pruned.remove.isNotEmpty) entry['conditionsRemoved'] = pruned.remove;
    }
  }

  Future<bool> _refreshRemotePlayers(BuildContext context, Campaign c, {bool quiet=false}) async {
    // Capturado antes dos awaits: salva mesmo se a tela fechar durante a busca.
    final appState = context.read<AppState>();
    try {
      final session = await CloudService.ensureSession();
      final links = await CloudService.approvedLinksForCampaign(session, c.id);
      final approvedCodes = <String>{};
      final missingShared = <String>{};
      for (final link in links) {
        approvedCodes.add('${link['share_code']}');
        final shared = await CloudService.sharedCharacterByCode(session, '${link['share_code']}');
        if (shared == null) {
          // Ficha apagada pelo jogador: o vínculo sai da lista e, se o
          // servidor permitir, da nuvem também (melhor esforço).
          missingShared.add('${link['share_code']}');
          try { await CloudService.deleteLinkRequest(session, '${link['id']}'); } catch (_) {}
          continue;
        }
        c.linkedCharacters.removeWhere((e) => e['shareCode'] == link['share_code']);
        c.linkedCharacters.add({'requestId': link['id'], 'shareCode': link['share_code'], 'status': 'approved', 'snapshot': shared['snapshot'], 'ownerId': shared['owner_id']});
      }
      var initiativeChanged = false;
      for (final stale in staleRemoteLinks(local: c.linkedCharacters, approvedCodes: approvedCodes, missingSharedCodes: missingShared)) {
        initiativeChanged = removeRemoteLink(c, stale) || initiativeChanged;
      }
      _pruneConfirmedConditions(c);
      await appState.updateCampaign(c);
      if (initiativeChanged) await _syncCombatState(c);
      return true;
    } catch (e) {
      if (!quiet && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível atualizar vínculos: $e')));
      return false;
    }
  }

  Future<void> _pickLocalPlayers(BuildContext context, AppState state, Campaign c) async {
    final selected=Set<String>.from(c.characterIds);
    final ok=await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context,setLocal)=>AlertDialog(title: const Text('Jogadores da campanha'), content: SizedBox(width: double.maxFinite, child: state.characters.isEmpty ? const Text('Nenhuma ficha criada neste aparelho.') : ListView(shrinkWrap:true, children: state.characters.map((ch)=>CheckboxListTile(value:selected.contains(ch.id), title:Text(ch.name), onChanged:(v)=>setLocal(()=>v==true?selected.add(ch.id):selected.remove(ch.id)))).toList())), actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Salvar'))])));
    if(ok==true && context.mounted){c.characterIds=selected.toList(); await context.read<AppState>().updateCampaign(c);}
  }

  Widget _npcs(BuildContext context, Campaign c) {
    final total = c.npcSheets.length + c.npcs.length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('NPCs e Monstros',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:2),Text('Fichas controladas pelo Mestre',style:Theme.of(context).textTheme.bodySmall)])),
        FilledButton.tonalIcon(onPressed:()=>_addNpc(context,c),icon:const Icon(Icons.add),label:const Text('Adicionar')),
      ]),
      const SizedBox(height:12),
      if(total==0) const Card(child:Padding(padding:EdgeInsets.all(20),child:Column(children:[Icon(Icons.person_search_outlined,size:38),SizedBox(height:10),Text('Nenhum NPC ou monstro cadastrado.'),SizedBox(height:4),Text('Crie uma ficha própria ou copie uma ficha existente.',textAlign:TextAlign.center)]))),
      ...spacedCards(c.npcSheets.map((npc){
        final raw=npc['sheet']; final sheet=raw is Map ? Character.fromJson(Map<String,dynamic>.from(raw)) : null; final kind='${npc['kind'] ?? 'NPC'}';
        final hp=sheet?.resourceValues['Vida'] ?? sheet?.hp ?? 0; final max=sheet?.resourceMaxValues['Vida'] ?? sheet?.maxHp ?? 0;
        return Card(child:ListTile(
          leading:CircleAvatar(child:Icon(_npcKindIcon(kind))),
          title:Text(sheet?.name ?? '${npc['name'] ?? 'NPC'}'),
          subtitle:Text('$kind • Vida $hp/$max${npc['source']=='character' ? ' • cópia de ficha' : ''}'),
          trailing:PopupMenuButton<String>(itemBuilder:(_)=>const [PopupMenuItem(value:'open',child:Text('Abrir ficha')),PopupMenuItem(value:'duplicate',child:Text('Duplicar')),PopupMenuItem(value:'delete',child:Text('Excluir'))],onSelected:(v)async{
            if(v=='open'){await Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:'${npc['id']}')));}
            if(v=='duplicate'){await _duplicateNpc(context,c,npc);}
            if(v=='delete'){final npcName=sheet?.name ?? '${npc['name'] ?? 'NPC'}';if(!await confirmDelete(context,title:'Excluir NPC?',message:'"$npcName" e sua ficha serão removidos da campanha e da iniciativa.'))return;if(!context.mounted)return;c.npcSheets.remove(npc);c.initiative.removeWhere((e)=>e['id']=='npc:${npc['id']}');await context.read<AppState>().updateCampaign(c);}
          }),
          onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:'${npc['id']}'))),
        ));
      })),
      if(c.npcs.isNotEmpty)...[
        const SizedBox(height:10),
        Text('NPCs antigos',style:Theme.of(context).textTheme.labelLarge),
        const SizedBox(height:4),
        ...spacedCards(c.npcs.asMap().entries.map((e)=>Card(child:ListTile(leading:const Icon(Icons.person_outline),title:Text(e.value),subtitle:const Text('Formato simples antigo'),trailing:PopupMenuButton<String>(itemBuilder:(_)=>const [PopupMenuItem(value:'convert',child:Text('Converter em ficha')),PopupMenuItem(value:'delete',child:Text('Excluir'))],onSelected:(v)async{if(v=='convert')await _convertLegacyNpc(context,c,e.key,e.value);if(v=='delete'){if(!await confirmDelete(context,title:'Excluir NPC?',message:'"${e.value}" será removido da campanha.'))return;if(!context.mounted)return;c.npcs.removeAt(e.key);await context.read<AppState>().updateCampaign(c);}}))))),
      ],
    ]);
  }

  IconData _npcKindIcon(String kind)=>switch(kind){'Monstro'=>Icons.bug_report_outlined,'Chefe'=>Icons.workspace_premium_outlined,'Aliado'=>Icons.shield_outlined,_=>Icons.person_outline};

  Future<void> _addNpc(BuildContext context, Campaign c) async {
    final choice=await showModalBottomSheet<String>(context:context,builder:(sheet)=>SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(leading:const Icon(Icons.add_circle_outline),title:const Text('Criar NPC / Monstro'),subtitle:const Text('Montar uma ficha controlada pelo Mestre'),onTap:()=>Navigator.pop(sheet,'new')),
      ListTile(leading:const Icon(Icons.content_copy),title:const Text('Usar ficha existente'),subtitle:const Text('Cria uma cópia independente de uma ficha de personagem'),onTap:()=>Navigator.pop(sheet,'copy')),
    ]))));
    if(choice=='new' && context.mounted) await _createNpcSheet(context,c);
    if(choice=='copy' && context.mounted) await _copyCharacterAsNpc(context,c);
  }

  Future<void> _createNpcSheet(BuildContext context, Campaign c, {String? initialName}) async {
    final state=context.read<AppState>(); final name=TextEditingController(text:initialName??''); String kind='NPC'; String systemId=state.systems.isEmpty?'generic':state.systems.first.id;
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(context,setD)=>AlertDialog(title:const Text('Criar NPC / Monstro'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,autofocus:true,decoration:const InputDecoration(labelText:'Nome')),
      const SizedBox(height:10),DropdownButtonFormField<String>(value:kind,decoration:const InputDecoration(labelText:'Tipo'),items:const ['NPC','Monstro','Aliado','Chefe'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setD(()=>kind=v??kind)),
      const SizedBox(height:10),DropdownButtonFormField<String>(value:systemId,decoration:const InputDecoration(labelText:'Sistema'),items:state.systems.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.name))).toList(),onChanged:(v)=>setD(()=>systemId=v??systemId)),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Criar ficha'))])));
    if(ok!=true||name.text.trim().isEmpty||!context.mounted)return;
    final matches=state.systems.where((s)=>s.id==systemId); final system=matches.isEmpty?null:matches.first; final id=const Uuid().v4();
    final resources=<String,int>{}; final resourceMax=<String,int>{}; for(final r in system?.resources ?? const ['Vida','Energia']){resources[r]=r=='Vida'||r=='PV'?10:0;resourceMax[r]=r=='Vida'||r=='PV'?10:0;}
    if(resources.isEmpty){resources['Vida']=10;resourceMax['Vida']=10;}
    final attrs=<String,int>{for(final a in system?.attributes ?? const ['FOR','DES','CON','INT','SAB','CAR']) a:10};
    final ch=Character(id:id,name:name.text.trim(),player:'Mestre',systemId:systemId,attributes:attrs,resourceValues:resources,resourceMaxValues:resourceMax,skills:List<String>.from(system?.skills ?? const []));
    c.npcSheets.add({'id':id,'name':ch.name,'kind':kind,'source':'custom','sheet':ch.toJson()}); await state.updateCampaign(c);
    if(context.mounted)await Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:id)));
  }

  Future<void> _copyCharacterAsNpc(BuildContext context, Campaign c) async {
    final state=context.read<AppState>(); if(state.characters.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nenhuma ficha criada para copiar.')));return;}
    final chosen=await showDialog<String>(context:context,builder:(d)=>SimpleDialog(title:const Text('Escolher ficha'),children:state.characters.map((ch)=>SimpleDialogOption(onPressed:()=>Navigator.pop(d,ch.id),child:ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.badge_outlined),title:Text(ch.name),subtitle:Text(ch.player.isEmpty?'Sem jogador':ch.player)))).toList())); if(chosen==null||!context.mounted)return;
    final original=state.characters.firstWhere((ch)=>ch.id==chosen); String kind='NPC'; final k=await showDialog<String>(context:context,builder:(d)=>SimpleDialog(title:const Text('Tipo da cópia'),children:['NPC','Monstro','Aliado','Chefe'].map((x)=>SimpleDialogOption(onPressed:()=>Navigator.pop(d,x),child:Text(x))).toList()));
    if(k!=null)kind=k;
    final id=const Uuid().v4(); final data=Map<String,dynamic>.from(original.toJson()); data['id']=id; data['player']='Mestre'; data['shareCode']='';
    final copy=Character.fromJson(data); c.npcSheets.add({'id':id,'name':copy.name,'kind':kind,'source':'character','sourceCharacterId':original.id,'sheet':copy.toJson()}); await state.updateCampaign(c);
    if(context.mounted)await Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:id)));
  }

  Future<void> _duplicateNpc(BuildContext context, Campaign c, Map<String,dynamic> npc) async {final id=const Uuid().v4();final copy=Map<String,dynamic>.from(npc);copy['id']=id;final raw=npc['sheet'];if(raw is Map){final data=Map<String,dynamic>.from(raw);data['id']=id;data['name']='${data['name'] ?? 'NPC'} (cópia)';copy['name']=data['name'];copy['sheet']=data;}c.npcSheets.add(copy);await context.read<AppState>().updateCampaign(c);}
  Future<void> _convertLegacyNpc(BuildContext context, Campaign c, int index, String name) async {final state=context.read<AppState>();final id=const Uuid().v4();final ch=Character(id:id,name:name,player:'Mestre');c.npcSheets.add({'id':id,'name':name,'kind':'NPC','source':'legacy','sheet':ch.toJson()});c.npcs.removeAt(index);await state.updateCampaign(c);if(context.mounted)await Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:id)));}

  Widget _session(BuildContext context, Campaign c) {
    final ordered=[...c.initiative]..sort((a,b)=>((b['value']??0) as int).compareTo((a['value']??0) as int));
    final ix=ordered.isEmpty ? 0 : c.currentTurnIndex.clamp(0, ordered.length-1);
    final current=c.combatActive && ordered.isNotEmpty ? ordered[ix] : null;
    final done=ordered.where((e)=>e['done']==true).length;
    final currentConditions=current==null ? <String>[] : _participantConditions(context.read<AppState>(),c,current);
    return ListView(padding: const EdgeInsets.all(16), children: [
      ...spacedCards([
      Card(child: Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(c.combatActive?Icons.sports_martial_arts:Icons.pause_circle_outline),const SizedBox(width:10),Expanded(child:Text(c.combatActive?'Combate ativo':'Sem combate ativo',style:Theme.of(context).textTheme.titleLarge)),Text('Rodada ${c.sessionRound}')]),
        if(current!=null)...[const SizedBox(height:12),Text('TURNO ATUAL',style:Theme.of(context).textTheme.labelMedium),const SizedBox(height:4),Text('${current['name']}',style:Theme.of(context).textTheme.headlineSmall),Text('Iniciativa ${current['value']} • $done/${ordered.length} concluídos'),
          if(currentConditions.isNotEmpty)...[const SizedBox(height:8),Wrap(spacing:6,runSpacing:4,children:currentConditions.map((condition)=>Chip(label:Text(condition),visualDensity:VisualDensity.compact)).toList())]],
      ]))),
      if(ordered.isNotEmpty) Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Ordem de iniciativa',style:Theme.of(context).textTheme.titleMedium),
        ...ordered.asMap().entries.map((e){final active=c.combatActive&&e.key==ix;final finished=e.value['done']==true;final isPlayer=e.value['type']=='player';final isNpc=e.value['type']=='npc' && '${e.value['id']}'.startsWith('npc:');return ListTile(
          dense:true,
          leading:Icon(finished?Icons.check_circle:active?Icons.play_circle_fill:Icons.radio_button_unchecked),
          title:Text('${e.value['name']}'),
          subtitle:Text(active?'Jogando agora':isPlayer?'Toque para ver ficha rápida':isNpc?'Toque para controlar a ficha':'NPC / participante'),
          trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${e.value['value']}'),if(isPlayer||isNpc)const Padding(padding:EdgeInsets.only(left:8),child:Icon(Icons.chevron_right))]),
          onTap:isPlayer?()=>_showCombatPlayer(context,c,e.value):isNpc?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:'${e.value['id']}'.substring(4)))):null,
        );}),
      ]))),
      FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SessionToolsScreen(campaignId:c.id))),icon:const Icon(Icons.open_in_new),label:Text(c.combatActive?'Abrir controle da sessão':'Preparar sessão')),
      ]),
      if(c.sessionLog.isNotEmpty)...[const SizedBox(height:16),Text('Histórico recente',style:Theme.of(context).textTheme.titleMedium),...c.sessionLog.reversed.take(5).map((e)=>ListTile(dense:true,leading:const Icon(Icons.history),title:Text(e)))],
    ]);
  }

  Future<void> _showCombatPlayer(BuildContext context, Campaign c, Map<String,dynamic> participant) async {
    final state=context.read<AppState>();
    Map<String,dynamic>? snap;
    final local=state.characters.where((ch)=>ch.id=='${participant['id']}');
    if(local.isNotEmpty) snap=local.first.toJson();
    if(snap==null){
      for(final link in c.linkedCharacters){
        final raw=link['snapshot'];
        if(raw is Map && '${raw['id']}'=='${participant['id']}'){snap=Map<String,dynamic>.from(raw);break;}
      }
    }
    if(snap==null){
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ficha vinculada ainda não foi sincronizada.')));
      return;
    }
    final resources=Map<String,dynamic>.from(snap['resourceValues'] as Map? ?? {});
    final max=Map<String,dynamic>.from(snap['resourceMaxValues'] as Map? ?? {});
    final conditions=(snap['conditions'] as List? ?? []).map((e)=>e.toString()).toList();
    if(!context.mounted)return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(sheetContext)=>SafeArea(child:Padding(
      padding:const EdgeInsets.fromLTRB(20,16,20,24),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.person_outline),const SizedBox(width:10),Expanded(child:Text('${snap!['name'] ?? participant['name']}',style:Theme.of(sheetContext).textTheme.titleLarge))]),
        const SizedBox(height:16),
        Text('Recursos',style:Theme.of(sheetContext).textTheme.titleMedium),
        if(resources.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Nenhum recurso registrado.')),
        ...resources.entries.map((r)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(r.key),trailing:Text('${r.value}/${max[r.key] ?? r.value}'))),
        const SizedBox(height:8),
        Text('Condições',style:Theme.of(sheetContext).textTheme.titleMedium),
        if(conditions.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Nenhuma condição ativa.')),
        if(conditions.isNotEmpty)Wrap(spacing:8,runSpacing:8,children:conditions.map((x)=>Chip(label:Text(x))).toList()),
      ]),
    )));
  }

  Widget _notes(BuildContext context, Campaign c) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.lock_outline), title: const Text('Notas privadas do Mestre'), subtitle: Text(c.masterNotes.isEmpty?'Nenhuma nota privada.':c.masterNotes,maxLines:4,overflow:TextOverflow.ellipsis), trailing:const Icon(Icons.edit_outlined), onTap:()=>_editNotes(context,c,true))),
    Card(margin: cardSpacingMargin, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.notes_outlined), title: const Text('Notas da campanha'), subtitle: Text(c.notes.isEmpty?'Nenhuma nota.':c.notes,maxLines:4,overflow:TextOverflow.ellipsis), trailing:const Icon(Icons.edit_outlined), onTap:()=>_editNotes(context,c,false))),
  ]);
  Future<void> _editNotes(BuildContext context, Campaign c, bool private) async { final ctrl=TextEditingController(text:private?c.masterNotes:c.notes); final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:Text(private?'Notas privadas do Mestre':'Notas da campanha'),content:TextField(controller:ctrl,minLines:6,maxLines:12),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Salvar'))])); if(ok==true&&context.mounted){if(private){c.masterNotes=ctrl.text;}else{c.notes=ctrl.text;}await context.read<AppState>().updateCampaign(c);} }
}

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final _search = TextEditingController();
  String _sort = 'recent';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addCampaign(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova campanha'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome da campanha'),
          ),
          const SizedBox(height: 10),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: description,
            decoration: const InputDecoration(labelText: 'Descrição'),
            maxLines: 3,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Criar')),
        ],
      ),
    );
    if (result != true || name.text.trim().isEmpty || !context.mounted) return;
    await context.read<AppState>().addCampaign(
      Campaign(
        id: const Uuid().v4(),
        name: name.text.trim(),
        description: description.text.trim(),
      ),
    );
  }

  List<Campaign> _visibleCampaigns(AppState state) {
    final query = _search.text.trim().toLowerCase();
    final list = state.campaigns.where((campaign) {
      if (query.isEmpty) return true;
      return campaign.name.toLowerCase().contains(query) ||
          campaign.description.toLowerCase().contains(query) ||
          campaign.npcs.any((e) => e.toLowerCase().contains(query)) ||
          campaign.npcSheets.any((e) => '${e['name'] ?? ((e['sheet'] is Map) ? e['sheet']['name'] : '')}'.toLowerCase().contains(query)) ||
          campaign.locations.any((e) => e.toLowerCase().contains(query));
    }).toList();

    if (_sort == 'name') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == 'characters') {
      list.sort((a, b) => b.characterIds.length.compareTo(a.characterIds.length));
    } else if (_sort == 'content') {
      int contentCount(Campaign c) => c.npcs.length + c.npcSheets.length + c.locations.length + c.sessionLog.length;
      list.sort((a, b) => contentCount(b).compareTo(contentCount(a)));
    } else {
      final order = {for (var i = 0; i < state.campaigns.length; i++) state.campaigns[i].id: i};
      list.sort((a, b) => (order[b.id] ?? 0).compareTo(order[a.id] ?? 0));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final campaigns = _visibleCampaigns(state);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campanhas'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Ordenar',
              icon: const Icon(Icons.sort),
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'recent', child: Text('Mais recentes')),
                PopupMenuItem(value: 'name', child: Text('Nome')),
                PopupMenuItem(value: 'characters', child: Text('Mais personagens')),
                PopupMenuItem(value: 'content', child: Text('Mais conteúdo')),
              ],
            ),
            IconButton(
              tooltip: 'Nova campanha',
              onPressed: () => _addCampaign(context),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: state.campaigns.isEmpty
            ? _emptyState(context)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar campanhas, NPCs ou locais',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: Row(
                      children: [
                        Text(
                          '${campaigns.length} de ${state.campaigns.length} campanha(s)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          _sortLabel(),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: campaigns.isEmpty
                        ? const Center(child: Text('Nenhuma campanha encontrada.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: campaigns.length,
                            itemBuilder: (_, index) => _campaignCard(context, campaigns[index]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  String _sortLabel() => switch (_sort) {
        'name' => 'Por nome',
        'characters' => 'Por personagens',
        'content' => 'Por conteúdo',
        _ => 'Mais recentes',
      };

  Widget _emptyState(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_2_outlined, size: 52, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('Suas campanhas ficam aqui', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Organize personagens, NPCs, locais, notas e ferramentas de sessão em um só lugar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _addCampaign(context),
                icon: const Icon(Icons.add),
                label: const Text('Criar campanha'),
              ),
            ],
          ),
        ),
      );

  Widget _campaignCard(BuildContext context, Campaign campaign) {
    final theme = Theme.of(context);
    final contentCount = campaign.npcs.length + campaign.npcSheets.length + campaign.locations.length;
    return Card(
      margin: cardSpacingMargin,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: campaign.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.groups_2_outlined, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaign.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (campaign.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        campaign.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: [
                        _metric(Icons.person_outline, '${campaign.characterIds.length} personagens'),
                        _metric(Icons.person_search_outlined, '${campaign.npcs.length + campaign.npcSheets.length} NPCs'),
                        _metric(Icons.location_on_outlined, '${campaign.locations.length} locais'),
                        if (campaign.sessionLog.isNotEmpty)
                          _metric(Icons.history, '${campaign.sessionLog.length} registros'),
                        if (contentCount == 0 && campaign.characterIds.isEmpty)
                          _metric(Icons.auto_awesome_outlined, 'Nova campanha'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções',
                onSelected: (value) {
                  if (value == 'open') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: campaign.id)),
                    );
                  } else if (value == 'delete') {
                    _confirmDelete(context, campaign);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Abrir campanha')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Future<void> _confirmDelete(BuildContext context, Campaign campaign) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir campanha?'),
        content: Text('A campanha “${campaign.name}” será excluída. As fichas não serão apagadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteCampaign(campaign.id);
    }
  }
}

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});
  @override State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  bool masterMode = false;


  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.campaigns.where((c) => c.id == widget.campaignId);
    if (matches.isEmpty) return const Scaffold(body: Center(child: Text('Campanha não encontrada.')));
    final c = matches.first;
    final visibleIds = masterMode ? c.characterIds : c.characterIds.where((id) => !c.hiddenCharacterIds.contains(id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Compartilhar campanha',
            icon: const Icon(Icons.ios_share),
            onSelected: (value) => _shareCampaign(context, c, value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'player',
                child: ListTile(
                  leading: Icon(Icons.group_outlined),
                  title: Text('Pacote para jogadores'),
                  subtitle: Text('Sem notas privadas e sem fichas ocultas.'),
                ),
              ),
              PopupMenuItem(
                value: 'master',
                child: ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('Cópia completa do mestre'),
                  subtitle: Text('Inclui dados privados e ferramentas da sessão.'),
                ),
              ),
              PopupMenuItem(
                value: 'summary',
                child: ListTile(
                  leading: Icon(Icons.text_snippet_outlined),
                  title: Text('Compartilhar resumo'),
                  subtitle: Text('Resumo público da campanha em texto.'),
                ),
              ),
            ],
          ),
          IconButton(tooltip: 'Editar campanha', icon: const Icon(Icons.edit), onPressed: () => _editInfo(context, c)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: spacedCards([
        Card(child: SwitchListTile(
          secondary: Icon(masterMode ? Icons.workspace_premium : Icons.person),
          title: Text(masterMode ? 'Modo Mestre' : 'Modo Jogador'),
          subtitle: Text(masterMode ? 'Conteúdo privado e controles do mestre estão visíveis.' : 'Somente informações destinadas aos jogadores.'),
          value: masterMode, onChanged: (v) => setState(() => masterMode = v),
        )),
        if (c.description.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(c.description))),
        _section(context, 'Personagens', Icons.people, visibleIds.map((id) {
          final found = state.characters.where((x) => x.id == id);
          final name = found.isEmpty ? 'Ficha indisponível' : found.first.name;
          return masterMode && c.hiddenCharacterIds.contains(id) ? '$name  • oculto' : name;
        }).toList(), masterMode ? () => _characters(context, c) : null),
        _section(context, 'NPCs', Icons.person_search, [...c.npcs, ...c.npcSheets.map((e){final raw=e['sheet'];return raw is Map ? '${raw['name'] ?? e['name'] ?? 'NPC'}' : '${e['name'] ?? 'NPC'}';})], null, editable: false),
        _section(context, 'Locais', Icons.map, c.locations, masterMode ? () => _textList(context, c, 'Local', c.locations) : null, editable: masterMode),
        Card(child: ListTile(leading: const Icon(Icons.notes), title: const Text('Notas da campanha'), subtitle: Text(c.notes.isEmpty ? 'Nenhuma nota' : c.notes, maxLines: 4, overflow: TextOverflow.ellipsis), onTap: masterMode ? () => _notes(context, c, false) : null)),
        if (masterMode) Card(child: ListTile(
          leading: const Icon(Icons.dashboard_customize_outlined), title: const Text('Painel do Mestre'),
          subtitle: Text(c.masterScene.isEmpty
              ? '${c.masterObjectives.length} objetivo(s) • ${c.sessionLog.length} registro(s)'
              : 'Cena: ${c.masterScene}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MasterToolsScreen(campaignId: c.id))),
        )),
        if (masterMode) Card(child: ListTile(
          leading: const Icon(Icons.sports_martial_arts), title: const Text('Sessão de RPG'),
          subtitle: Text('Rodada ${c.sessionRound} • ${c.initiative.length} na iniciativa • ${c.conditions.length} condições'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionToolsScreen(campaignId: c.id))),
        )),
        if (masterMode) Card(child: ListTile(
          leading: const Icon(Icons.lock_outline), title: const Text('Notas privadas do mestre'),
          subtitle: Text(c.masterNotes.isEmpty ? 'Nenhuma nota privada' : c.masterNotes, maxLines: 4, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right), onTap: () => _notes(context, c, true),
        )),
        if (masterMode) Card(child: ListTile(
          leading: const Icon(Icons.visibility_off_outlined), title: const Text('Visibilidade das fichas'),
          subtitle: Text('${c.hiddenCharacterIds.length} ficha(s) oculta(s) dos jogadores'),
          trailing: const Icon(Icons.tune), onTap: () => _visibility(context, c),
        )),
      ])),
    );
  }

  Future<void> _shareCampaign(BuildContext context, Campaign campaign, String mode) async {
    final state = context.read<AppState>();
    try {
      if (mode == 'player') {
        await RpgFileService.exportCampaign(campaign, state, playerPackage: true);
      } else if (mode == 'master') {
        await RpgFileService.exportCampaign(campaign, state, playerPackage: false);
      } else if (mode == 'summary') {
        await RpgFileService.shareCampaignSummary(campaign, state);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível compartilhar: $e')),
      );
    }
  }

  Widget _section(BuildContext context, String title, IconData icon, List<String> values, VoidCallback? add, {bool editable = false}) => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (add != null) IconButton(onPressed: add, icon: const Icon(Icons.add))]),
      if (values.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Nenhum item adicionado.')),
      ...values.asMap().entries.map((e) => ListTile(dense: true, title: Text(e.value), trailing: editable ? const Icon(Icons.more_horiz, size: 18) : null)),
    ])));

  Future<void> _editInfo(BuildContext context, Campaign c) async {
    final name = TextEditingController(text: c.name), description = TextEditingController(text: c.description);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Editar campanha'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(textCapitalization: TextCapitalization.sentences, controller: name, decoration: const InputDecoration(labelText: 'Nome')), TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição'), maxLines: 4)]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))]));
    if (ok == true && name.text.trim().isNotEmpty && context.mounted) { c.name = name.text.trim(); c.description = description.text.trim(); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _characters(BuildContext context, Campaign c) async {
    final state = context.read<AppState>(); final selected = Set<String>.from(c.characterIds);
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Personagens da campanha'), content: SizedBox(width: double.maxFinite, child: state.characters.isEmpty ? const Text('Crie uma ficha primeiro.') : ListView(shrinkWrap: true, children: state.characters.map((ch) => CheckboxListTile(value: selected.contains(ch.id), title: Text(ch.name), onChanged: (v) => setState(() => v == true ? selected.add(ch.id) : selected.remove(ch.id)))).toList())), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))])));
    if (ok == true && context.mounted) { c.characterIds = selected.toList(); c.hiddenCharacterIds.removeWhere((id) => !selected.contains(id)); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _visibility(BuildContext context, Campaign c) async {
    final state = context.read<AppState>(); final hidden = Set<String>.from(c.hiddenCharacterIds);
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Visibilidade das fichas'),
      content: SizedBox(width: double.maxFinite, child: c.characterIds.isEmpty ? const Text('Nenhuma ficha na campanha.') : ListView(shrinkWrap: true, children: c.characterIds.map((id) {
        final found = state.characters.where((x) => x.id == id); final name = found.isEmpty ? 'Ficha indisponível' : found.first.name;
        return SwitchListTile(title: Text(name), subtitle: Text(hidden.contains(id) ? 'Oculta dos jogadores' : 'Visível aos jogadores'), value: !hidden.contains(id), onChanged: (visible) => setState(() => visible ? hidden.remove(id) : hidden.add(id)));
      }).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))],
    )));
    if (ok == true && context.mounted) { c.hiddenCharacterIds = hidden.toList(); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _textList(BuildContext context, Campaign c, String label, List<String> target) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: Text('Adicionar $label'), content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, autofocus: true, decoration: InputDecoration(labelText: 'Nome do $label')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Adicionar'))]));
    if (value != null && value.isNotEmpty && context.mounted) { target.add(value); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _notes(BuildContext context, Campaign c, bool private) async {
    final controller = TextEditingController(text: private ? c.masterNotes : c.notes);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(private ? 'Notas privadas do mestre' : 'Notas da campanha'), content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, minLines: 6, maxLines: 12, decoration: InputDecoration(hintText: private ? 'Segredos, planos, pistas e informações do mestre...' : 'Anotações da sessão, pistas, acontecimentos...')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))]));
    if (ok == true && context.mounted) { if (private) { c.masterNotes = controller.text; } else { c.notes = controller.text; } await context.read<AppState>().updateCampaign(c); }
  }
}

class MasterToolsScreen extends StatelessWidget {
  final String campaignId;
  const MasterToolsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.campaigns.where((c) => c.id == campaignId);
    if (matches.isEmpty) return const Scaffold(body: Center(child: Text('Campanha não encontrada.')));
    final c = matches.first;
    return Scaffold(
      appBar: AppBar(title: Text('Painel do Mestre • ${c.name}')),
      body: ListView(padding: const EdgeInsets.all(16), children: spacedCards([
        Card(child: ListTile(
          leading: const Icon(Icons.movie_filter_outlined),
          title: const Text('Cena atual'),
          subtitle: Text(c.masterScene.isEmpty ? 'Nenhuma cena definida.' : c.masterScene),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editScene(context, c),
        )),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.flag_outlined), const SizedBox(width: 8), Expanded(child: Text('Objetivos do mestre', style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => _addObjective(context, c), icon: const Icon(Icons.add))]),
          if (c.masterObjectives.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Nenhum objetivo registrado.')),
          ...c.masterObjectives.asMap().entries.map((e) {
            final done = e.value.startsWith('[x] ');
            final label = e.value.replaceFirst(RegExp(r'^\[(x| )\] '), '');
            return CheckboxListTile(
              dense: true, contentPadding: EdgeInsets.zero, value: done, title: Text(label),
              onChanged: (_) => _toggleObjective(context, c, e.key, label, !done),
              secondary: IconButton(icon: const Icon(Icons.close), onPressed: () => _removeObjective(context, c, e.key)),
            );
          }),
        ]))),
        Card(child: ExpansionTile(
          leading: const Icon(Icons.person_search), title: Text('NPCs (${c.npcs.length + c.npcSheets.length})'),
          children: (c.npcs.isEmpty && c.npcSheets.isEmpty) ? [const ListTile(title: Text('Nenhum NPC cadastrado.'))] : [
            ...c.npcSheets.map((npc){final raw=npc['sheet'];final name=raw is Map?'${raw['name'] ?? npc['name'] ?? 'NPC'}':'${npc['name'] ?? 'NPC'}';return ListTile(dense:true,leading:Icon(_npcKindIcon('${npc['kind'] ?? 'NPC'}')),title:Text(name),subtitle:Text('${npc['kind'] ?? 'NPC'}'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NpcSheetScreen(campaignId:c.id,npcId:'${npc['id']}'))));}),
            ...c.npcs.map((x)=>ListTile(dense:true,leading:const Icon(Icons.person_outline),title:Text(x),subtitle:const Text('Formato simples antigo'))),
          ],
        )),
        Card(child: ExpansionTile(
          leading: const Icon(Icons.map_outlined), title: Text('Locais (${c.locations.length})'),
          children: c.locations.isEmpty ? [const ListTile(title: Text('Nenhum local cadastrado.'))] : c.locations.map((x) => ListTile(dense: true, leading: const Icon(Icons.place_outlined), title: Text(x))).toList(),
        )),
        Card(child: ListTile(
          leading: const Icon(Icons.lock_outline), title: const Text('Notas privadas'),
          subtitle: Text(c.masterNotes.isEmpty ? 'Nenhuma nota privada.' : c.masterNotes, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.edit_outlined), onTap: () => _editPrivateNotes(context, c),
        )),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.history_edu_outlined), const SizedBox(width: 8), Expanded(child: Text('Registro da sessão', style: Theme.of(context).textTheme.titleMedium)), IconButton(onPressed: () => _addLog(context, c), icon: const Icon(Icons.add))]),
          if (c.sessionLog.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Nenhum acontecimento registrado.')),
          ...c.sessionLog.reversed.take(20).map((x) => ListTile(dense: true, leading: const Icon(Icons.circle, size: 9), title: Text(x))),
          if (c.sessionLog.isNotEmpty) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _clearLog(context, c), icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Limpar registro'))),
        ]))),
      ])),
    );
  }

  Future<void> _editScene(BuildContext context, Campaign c) async {
    final controller = TextEditingController(text: c.masterScene);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Cena atual'), content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex.: Salão do castelo durante o banquete')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))]));
    if (ok == true && context.mounted) { c.masterScene = controller.text.trim(); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _addObjective(BuildContext context, Campaign c) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Novo objetivo'), content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: Revelar a pista do medalhão')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Adicionar'))]));
    if (value != null && value.isNotEmpty && context.mounted) { c.masterObjectives.add('[ ] $value'); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _toggleObjective(BuildContext context, Campaign c, int index, String label, bool done) async {
    c.masterObjectives[index] = '${done ? '[x]' : '[ ]'} $label';
    await context.read<AppState>().updateCampaign(c);
  }

  Future<void> _removeObjective(BuildContext context, Campaign c, int index) async {
    c.masterObjectives.removeAt(index); await context.read<AppState>().updateCampaign(c);
  }

  Future<void> _editPrivateNotes(BuildContext context, Campaign c) async {
    final controller = TextEditingController(text: c.masterNotes);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Notas privadas'), content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, minLines: 7, maxLines: 14, decoration: const InputDecoration(hintText: 'Segredos, planos, pistas e lembretes...')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar'))]));
    if (ok == true && context.mounted) { c.masterNotes = controller.text; await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _addLog(BuildContext context, Campaign c) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Registrar acontecimento'), content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'O que aconteceu na sessão?')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Registrar'))]));
    if (value != null && value.isNotEmpty && context.mounted) { c.sessionLog.add(value); await context.read<AppState>().updateCampaign(c); }
  }

  Future<void> _clearLog(BuildContext context, Campaign c) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Limpar registro?'), content: const Text('Os acontecimentos registrados serão removidos.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Limpar'))]));
    if (ok == true && context.mounted) { c.sessionLog.clear(); await context.read<AppState>().updateCampaign(c); }
  }
}

/// Vínculo remoto (com shareCode) do jogador com esse id, se houver.
Map<String, dynamic>? _remoteLink(Campaign campaign, String id) {
  for (final link in campaign.linkedCharacters) {
    final snapshot = link['snapshot'];
    if (snapshot is Map && '${snapshot['id']}' == id && '${link['shareCode'] ?? ''}'.isNotEmpty) return link;
  }
  return null;
}

/// Condições exibidas para o participante. A ficha do jogador é a fonte da
/// verdade: local mostra só character.conditions; remoto mostra o snapshot
/// com as pendências do mestre (entry['conditions'] = adições,
/// entry['conditionsRemoved'] = remoções). NPC/avulso ou jogador sem ficha:
/// entry['conditions'] como lista definitiva.
List<String> _participantConditions(AppState state, Campaign campaign, Map<String, dynamic> entry) {
  if (entry['type'] != 'player') return initiativeConditions(entry);
  final id = '${entry['id'] ?? ''}';
  final local = state.characters.where((c) => c.id == id);
  if (local.isNotEmpty) return conditionsFromRaw(local.first.conditions);
  final link = _remoteLink(campaign, id);
  if (link == null) return initiativeConditions(entry);
  return playerDisplayConditions(
    conditionsFromRaw((link['snapshot'] as Map)['conditions']),
    initiativeConditions(entry),
    conditionsFromRaw(entry['conditionsRemoved']),
  );
}

/// Publica o estado de combate da campanha (rodada, turno e iniciativa).
Future<void> _syncCombatState(Campaign campaign) async {
  try {
    final session = await CloudService.ensureSession();
    await CloudService.publishSessionState(session, campaign.id, {
      'round': campaign.sessionRound,
      'active': campaign.combatActive,
      'current_index': campaign.currentTurnIndex,
      'initiative': campaign.initiative,
    });
  } catch (_) {}
}

class SessionToolsScreen extends StatelessWidget {
  final String campaignId;
  const SessionToolsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.campaigns.where((c) => c.id == campaignId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Campanha não encontrada.')));
    }
    final campaign = matches.first;
    final participants = [...campaign.initiative]
      ..sort((a, b) => ((b['value'] ?? 0) as int).compareTo((a['value'] ?? 0) as int));
    final activeIndex = participants.isEmpty ? 0 : campaign.currentTurnIndex.clamp(0, participants.length - 1);

    return Scaffold(
      appBar: AppBar(title: Text('Sessão • ${campaign.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: spacedCards([
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.repeat),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(campaign.combatActive ? 'COMBATE ATIVO' : 'SESSÃO', style: Theme.of(context).textTheme.labelMedium),
                    Text('Rodada ${campaign.sessionRound}', style: Theme.of(context).textTheme.titleLarge),
                  ])),
                  IconButton(
                    tooltip: 'Voltar rodada',
                    onPressed: campaign.sessionRound > 1 ? () => _changeRound(context, campaign, -1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Avançar rodada',
                    onPressed: () => _changeRound(context, campaign, 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Reiniciar',
                    onPressed: () => _resetRound(context, campaign),
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.format_list_numbered),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Iniciativa', style: Theme.of(context).textTheme.titleMedium)),
                    if (!campaign.combatActive)
                      FilledButton.tonalIcon(
                        onPressed: () => _rollInitiative(context, campaign),
                        icon: const Icon(Icons.casino_outlined),
                        label: const Text('Rolar iniciativa'),
                      ),
                  ]),
                  if (participants.isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('Nenhum participante na iniciativa.')),
                  ...participants.asMap().entries.map((indexed) {
                    final index = indexed.key;
                    final entry = indexed.value;
                    final done = entry['done'] == true;
                    final current = campaign.combatActive && index == activeIndex && !done;
                    final status = current
                        ? 'Turno atual'
                        : (campaign.combatActive && index == activeIndex + 1 && !done ? 'Próximo' : null);
                    final vida = _vidaBar(context, state, campaign, entry);
                    // Jogador: a ficha é a fonte da verdade (+ pendências do mestre).
                    final conditions = _participantConditions(state, campaign, entry);
                    return ListTile(
                      dense: true,
                      selected: current,
                      leading: Checkbox(
                        value: done,
                        onChanged: campaign.combatActive ? (_) => _finishTurn(context, campaign, participants, index) : null,
                      ),
                      title: Text((entry['name'] ?? 'Participante').toString()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status != null) Text(status),
                          if (vida != null) vida,
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...conditions.map((condition) => InputChip(
                                    label: Text(condition),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    tooltip: 'Remover $condition',
                                    onPressed: () => _removeParticipantCondition(context, campaign, entry, condition),
                                    onDeleted: () => _removeParticipantCondition(context, campaign, entry, condition),
                                    deleteButtonTooltipMessage: 'Remover $condition',
                                  )),
                              IconButton(
                                tooltip: 'Adicionar condição a ${entry['name'] ?? 'participante'}',
                                onPressed: () => _addParticipantCondition(context, campaign, entry),
                                icon: const Icon(Icons.healing_outlined, size: 18),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          CircleAvatar(child: Text('${entry['value'] ?? 0}')),
                          IconButton(
                            tooltip: 'Editar iniciativa',
                            onPressed: () => _editInitiativeValue(context, campaign, entry),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Remover do combate',
                            onPressed: () => _removeInitiative(context, campaign, entry),
                            icon: const Icon(Icons.person_remove_outlined),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (campaign.combatActive) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _addInitiativeParticipant(context, campaign),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Adicionar participante'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _endCombat(context, campaign),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Encerrar combate'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _resourceCard(context, state, campaign),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.healing),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Condições gerais', style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(onPressed: () => _addCondition(context, campaign), icon: const Icon(Icons.add)),
                  ]),
                  if (campaign.conditions.isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('Nenhuma condição registrada.')),
                  ...campaign.conditions.asMap().entries.map((e) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(e.value),
                        trailing: IconButton(
                          onPressed: () => _removeCondition(context, campaign, e.key),
                          icon: const Icon(Icons.close),
                        ),
                      )),
                ],
              ),
            ),
          ),
          if (campaign.sessionLog.isNotEmpty)
            Card(child: ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico do combate'),
              subtitle: Text('${campaign.sessionLog.length} eventos'),
              children: campaign.sessionLog.reversed.take(20).map((event) => ListTile(dense:true, leading:const Icon(Icons.chevron_right), title:Text(event))).toList(),
            )),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Notas rápidas da sessão'),
              subtitle: Text(
                campaign.sessionNotes.isEmpty ? 'Nenhuma nota rápida' : campaign.sessionNotes,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _sessionNotes(context, campaign),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _resourceCard(BuildContext context, AppState state, Campaign campaign) {
    final chars = campaign.characterIds
        .map((id) => state.characters.where((c) => c.id == id))
        .where((m) => m.isNotEmpty)
        .map((m) => m.first)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.favorite_outline),
              const SizedBox(width: 8),
              Expanded(child: Text('Recursos rápidos', style: Theme.of(context).textTheme.titleMedium)),
            ]),
            if (chars.isEmpty)
              const Padding(padding: EdgeInsets.all(8), child: Text('Nenhuma ficha vinculada à campanha.')),
            ...chars.map((character) => ExpansionTile(
                  title: Text(character.name),
                  children: character.resourceValues.keys.map((resource) {
                    final current = character.resourceValues[resource] ?? 0;
                    final max = character.resourceMaxValues[resource] ?? 0;
                    return ListTile(
                      dense: true,
                      title: Text(resource),
                      subtitle: Text(max > 0 ? '$current / $max' : '$current'),
                      trailing: Wrap(spacing: 4, children: [
                        IconButton(
                          tooltip: '-1',
                          onPressed: () => _changeResource(context, state, character.id, resource, -1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: '+1',
                          onPressed: () => _changeResource(context, state, character.id, resource, 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ]),
                    );
                  }).toList(),
                )),
          ],
        ),
      ),
    );
  }

  /// Ficha de um NPC da campanha pelo id (sem o prefixo 'npc:').
  ({Map<String, dynamic> npc, Character sheet})? _npcSheet(Campaign campaign, String npcId) {
    for (final npc in campaign.npcSheets) {
      final raw = npc['sheet'];
      if ('${npc['id']}' != npcId || raw is! Map) continue;
      try {
        return (npc: npc, sheet: Character.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Ficha do jogador, local ou do snapshot do vínculo remoto, só para leitura.
  Character? _playerSheet(AppState state, Campaign campaign, String id) {
    final local = state.characters.where((ch) => ch.id == id);
    if (local.isNotEmpty) return local.first;
    for (final link in campaign.linkedCharacters) {
      final raw = link['snapshot'];
      if (raw is Map && '${raw['id']}' == id) {
        try {
          return Character.fromJson(Map<String, dynamic>.from(raw));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  Widget _vidaLine(BuildContext context, ({int current, int max}) vida) {
    final ratio = vida.max > 0 ? (vida.current / vida.max).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      const Icon(Icons.favorite_outline, size: 14),
      const SizedBox(width: 6),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: ratio, minHeight: 6),
        ),
      ),
      const SizedBox(width: 8),
      Text('${vida.current} / ${vida.max}', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  /// Vida do participante: NPC local pode ser ajustado pelo mestre; jogador
  /// aparece só para leitura (a vida do jogador é dele); avulso não tem barra.
  Widget? _vidaBar(BuildContext context, AppState state, Campaign campaign, Map<String, dynamic> entry) {
    final id = '${entry['id'] ?? ''}';
    if (entry['type'] == 'npc' && id.startsWith('npc:')) {
      final found = _npcSheet(campaign, id.substring(4));
      if (found == null) return null;
      return ResourceBarTapTarget(
        label: 'vida de ${entry['name'] ?? found.sheet.name}',
        onTap: () => _editNpcVida(context, campaign, entry),
        child: _vidaLine(context, readVida(found.sheet)),
      );
    }
    if (entry['type'] == 'player') {
      final sheet = _playerSheet(state, campaign, id);
      if (sheet == null) return null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _vidaLine(context, readVida(sheet)),
      );
    }
    return null;
  }

  Future<void> _editNpcVida(BuildContext context, Campaign campaign, Map<String, dynamic> entry) async {
    final id = '${entry['id'] ?? ''}';
    if (!id.startsWith('npc:')) return;
    final found = _npcSheet(campaign, id.substring(4));
    if (found == null) return;
    final state = context.read<AppState>();
    final before = readVida(found.sheet);
    final result = await showResourceQuickAdjust(context, name: 'Vida', current: before.current, max: before.max);
    if (result == null || !context.mounted) return;
    applyVida(found.sheet, result);
    final after = readVida(found.sheet);
    if (after == before) return;
    found.npc['sheet'] = found.sheet.toJson();
    campaign.sessionLog.add('${entry['name'] ?? found.sheet.name}: vida ${before.current}/${before.max} → ${after.current}/${after.max}');
    try {
      await state.updateCampaign(campaign);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível salvar a vida.')));
      }
    }
  }

  Future<void> _syncCombat(Campaign campaign) => _syncCombatState(campaign);

  Future<void> _changeRound(BuildContext context, Campaign campaign, int delta) async {
    campaign.sessionRound = (campaign.sessionRound + delta).clamp(1, 9999);
    campaign.sessionLog.add('Rodada alterada manualmente para ${campaign.sessionRound}.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _resetRound(BuildContext context, Campaign campaign) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reiniciar rodada?'),
        content: const Text('A rodada voltará para 1. A iniciativa será mantida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      campaign.sessionRound = 1;
      campaign.currentTurnIndex = 0;
      for(final e in campaign.initiative){e['done']=false;}
      campaign.sessionLog.add('Rodadas reiniciadas.');
      await context.read<AppState>().updateCampaign(campaign);
      await _syncCombat(campaign);
    }
  }

  Future<void> _rollInitiative(BuildContext context, Campaign campaign) async {
    final state = context.read<AppState>();
    final options = <Map<String, String>>[];
    for (final id in campaign.characterIds) {
      final found = state.characters.where((c) => c.id == id);
      if (found.isNotEmpty) options.add({'id': id, 'name': found.first.name, 'type': 'player'});
    }
    for (final linked in campaign.linkedCharacters) {
      final snapshot = linked['snapshot'];
      if (snapshot is Map) {
        final id = '${snapshot['id'] ?? linked['character_id'] ?? ''}';
        final name = '${snapshot['name'] ?? 'Jogador'}';
        if (!options.any((e) => e['id'] == id)) options.add({'id': id, 'name': name, 'type': 'player'});
      }
    }
    for (final npc in campaign.npcSheets) {
      final raw=npc['sheet'];
      final name=raw is Map ? '${raw['name'] ?? npc['name'] ?? 'NPC'}' : '${npc['name'] ?? 'NPC'}';
      options.add({'id': 'npc:${npc['id']}', 'name': name, 'type': 'npc'});
    }
    for (var i = 0; i < campaign.npcs.length; i++) {
      options.add({'id': 'legacyNpc:$i', 'name': campaign.npcs[i], 'type': 'npc'});
    }
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione jogadores ou NPCs antes de iniciar o combate.')));
      return;
    }

    final selected = <String, bool>{for (final o in options) o['id']!: true};
    final controllers = <String, TextEditingController>{for (final o in options) o['id']!: TextEditingController()};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Rolar iniciativa'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: options.map((o) => Row(children: [
              Checkbox(value: selected[o['id']] == true, onChanged: (v) => setDialogState(() => selected[o['id']!] = v == true)),
              Expanded(child: Text(o['name']!)),
              SizedBox(width: 82, child: TextField(
                controller: controllers[o['id']],
                enabled: selected[o['id']] == true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Inic.'),
              )),
            ])).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Iniciar')),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    final entries = <Map<String, dynamic>>[];
    for (final o in options.where((o) => selected[o['id']] == true)) {
      final value = int.tryParse(controllers[o['id']]!.text.trim());
      if (value == null) continue;
      entries.add({'id': o['id'], 'name': o['name'], 'type': o['type'], 'value': value, 'done': false});
    }
    for (final c in controllers.values) { c.dispose(); }
    if (entries.isEmpty) return;
    entries.sort((a,b) {
      final byValue=(b['value'] as int).compareTo(a['value'] as int);
      if(byValue!=0) return byValue;
      return '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase());
    });
    campaign.initiative = entries;
    campaign.sessionRound = 1;
    campaign.currentTurnIndex = 0;
    campaign.combatActive = true;
    campaign.sessionLog.add('Combate iniciado.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _finishTurn(BuildContext context, Campaign campaign, List<Map<String, dynamic>> participants, int index) async {
    if (!campaign.combatActive || participants.isEmpty) return;
    final current = campaign.currentTurnIndex.clamp(0, participants.length - 1);
    if (index != current) return;
    participants[index]['done'] = true;
    final finishedName='${participants[index]['name'] ?? 'Participante'}';
    campaign.sessionLog.add('Rodada ${campaign.sessionRound}: $finishedName concluiu o turno.');
    final original = campaign.initiative.firstWhere((e) =>
      e['id'] == participants[index]['id'] && e['value'] == participants[index]['value'],
      orElse: () => participants[index]);
    original['done'] = true;

    if (index >= participants.length - 1) {
      campaign.sessionRound += 1;
      campaign.sessionLog.add('Rodada ${campaign.sessionRound} iniciada.');
      campaign.currentTurnIndex = 0;
      for (final e in campaign.initiative) { e['done'] = false; }
    } else {
      campaign.currentTurnIndex = index + 1;
    }
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _endCombat(BuildContext context, Campaign campaign) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Encerrar combate?'),
        content: const Text('A iniciativa e o estado de turno serão encerrados. Fichas, recursos e condições serão mantidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    campaign.combatActive = false;
    campaign.currentTurnIndex = 0;
    for (final e in campaign.initiative) { e['done'] = false; }
    campaign.sessionLog.add('Combate encerrado na rodada ${campaign.sessionRound}.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _editInitiativeValue(BuildContext context, Campaign campaign, Map<String, dynamic> entry) async {
    final controller=TextEditingController(text:'${entry['value'] ?? 0}');
    final value=await showDialog<int>(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text('Iniciativa • ${entry['name'] ?? 'Participante'}'),
      content:TextField(controller:controller,autofocus:true,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Iniciativa')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(dialogContext,int.tryParse(controller.text.trim())),child:const Text('Salvar')),
      ],
    ));
    controller.dispose();
    if(value==null || !context.mounted) return;
    final currentId=campaign.combatActive && campaign.initiative.isNotEmpty
      ? ([...campaign.initiative]..sort((a,b)=>((b['value']??0) as int).compareTo((a['value']??0) as int)))[campaign.currentTurnIndex.clamp(0,campaign.initiative.length-1)]['id']
      : null;
    entry['value']=value;
    campaign.initiative.sort((a,b){
      final byValue=((b['value']??0) as int).compareTo((a['value']??0) as int);
      if(byValue!=0) return byValue;
      return '${a['name'] ?? ''}'.toLowerCase().compareTo('${b['name'] ?? ''}'.toLowerCase());
    });
    if(currentId!=null){
      final ix=campaign.initiative.indexWhere((e)=>e['id']==currentId);
      if(ix>=0) campaign.currentTurnIndex=ix;
    }
    campaign.sessionLog.add('Iniciativa de ${entry['name']} alterada para $value.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _addInitiativeParticipant(BuildContext context, Campaign campaign) async {
    final state=context.read<AppState>();
    final options=<Map<String,String>>[];
    for(final id in campaign.characterIds){
      final found=state.characters.where((c)=>c.id==id);
      if(found.isNotEmpty && !campaign.initiative.any((e)=>e['id']==id)){
        options.add({'id':id,'name':found.first.name,'type':'player'});
      }
    }
    for(final linked in campaign.linkedCharacters){
      final snapshot=linked['snapshot'];
      if(snapshot is Map){
        final id='${snapshot['id'] ?? linked['character_id'] ?? ''}';
        if(id.isNotEmpty && !campaign.initiative.any((e)=>e['id']==id)){
          options.add({'id':id,'name':'${snapshot['name'] ?? 'Jogador'}','type':'player'});
        }
      }
    }
    for(final npc in campaign.npcSheets){
      final id='npc:${npc['id']}';
      final raw=npc['sheet']; final name=raw is Map ? '${raw['name'] ?? npc['name'] ?? 'NPC'}' : '${npc['name'] ?? 'NPC'}';
      if(!campaign.initiative.any((e)=>e['id']==id)) options.add({'id':id,'name':name,'type':'npc'});
    }
    for(var i=0;i<campaign.npcs.length;i++){
      final id='legacyNpc:$i';
      if(!campaign.initiative.any((e)=>e['id']==id)) options.add({'id':id,'name':campaign.npcs[i],'type':'npc'});
    }
    options.add({'id':'manual:${DateTime.now().microsecondsSinceEpoch}','name':'Outro','type':'manual'});
    String? chosen;
    final initiative=TextEditingController();
    final manualName=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setDialogState)=>AlertDialog(
      title:const Text('Adicionar participante'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(
          value:chosen,
          hint:const Text('Participante'),
          items:options.map((o)=>DropdownMenuItem(value:o['id'],child:Text(o['name']!))).toList(),
          onChanged:(v)=>setDialogState(()=>chosen=v),
        ),
        if(chosen!=null && chosen!.startsWith('manual:'))
          TextField(controller:manualName,decoration:const InputDecoration(labelText:'Nome')),
        TextField(controller:initiative,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Iniciativa')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Adicionar')),
      ],
    )));
    if(ok!=true || chosen==null || !context.mounted) return;
    final value=int.tryParse(initiative.text.trim());
    final selected=options.firstWhere((o)=>o['id']==chosen);
    final name=chosen!.startsWith('manual:') ? manualName.text.trim() : selected['name']!;
    initiative.dispose(); manualName.dispose();
    if(value==null || name.isEmpty) return;
    final currentId=campaign.initiative.isEmpty ? null : ([...campaign.initiative]..sort((a,b)=>((b['value']??0) as int).compareTo((a['value']??0) as int)))[campaign.currentTurnIndex.clamp(0,campaign.initiative.length-1)]['id'];
    campaign.initiative.add({'id':chosen,'name':name,'type':selected['type'],'value':value,'done':false});
    campaign.initiative.sort((a,b){
      final byValue=((b['value']??0) as int).compareTo((a['value']??0) as int);
      if(byValue!=0) return byValue;
      return '${a['name'] ?? ''}'.toLowerCase().compareTo('${b['name'] ?? ''}'.toLowerCase());
    });
    if(currentId!=null){
      final ix=campaign.initiative.indexWhere((e)=>e['id']==currentId);
      if(ix>=0) campaign.currentTurnIndex=ix;
    }
    campaign.sessionLog.add('$name entrou no combate com iniciativa $value.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _removeInitiative(BuildContext context, Campaign campaign, Map<String, dynamic> entry) async {
    if (!await confirmDelete(context, title: 'Remover do combate?', message: '"${entry['name'] ?? 'Participante'}" será removido da iniciativa.', confirmLabel: 'Remover')) return;
    if (!context.mounted) return;
    removeInitiativeParticipant(campaign, entry['id']);
    campaign.sessionLog.add('${entry['name'] ?? 'Participante'} removido do combate.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  /// Seletor de condição (entrada livre), o mesmo das condições gerais.
  Future<String?> _askConditionName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Adicionar condição'),
        content: TextField(textCapitalization: TextCapitalization.sentences, controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: Envenenado — Goblin')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Adicionar')),
        ],
      ),
    );
  }

  Future<void> _addCondition(BuildContext context, Campaign campaign) async {
    final value = await _askConditionName(context);
    if (value != null && value.isNotEmpty && context.mounted) {
      campaign.conditions.add(value);
      await context.read<AppState>().updateCampaign(campaign);
    }
  }

  Future<void> _saveCombatChange(BuildContext context, AppState state, Campaign campaign) async {
    try {
      await state.updateCampaign(campaign);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível salvar.')));
      }
      return;
    }
    await _syncCombat(campaign);
  }

  /// Seletor de condição do participante: condições pré-definidas (o nome
  /// salvo é o do preset) e "Outra..." com a entrada livre.
  Future<String?> _pickParticipantCondition(BuildContext context, List<String> current) async {
    const other = '\u0000outra';
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Adicionar condição'),
        children: [
          ...conditionPresets.where((p) => !current.any((c) => sameCondition(c, p.name))).map((p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, p.name),
                child: Row(children: [Icon(p.icon), const SizedBox(width: 10), Text(p.name)]),
              )),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, other),
            child: const Row(children: [Icon(Icons.add), SizedBox(width: 10), Text('Outra...')]),
          ),
        ],
      ),
    );
    if (picked != other) return picked;
    if (!context.mounted) return null;
    final typed = await _askConditionName(context);
    if (typed == null || typed.isEmpty) return typed;
    return conditionPresetFor(typed)?.name ?? typed;
  }

  /// Leva a mudança de condição para a ficha do jogador: local grava em
  /// character.conditions; remota envia patch só com 'conditions' (nunca
  /// vida/recursos). Devolve false se não foi possível sincronizar.
  Future<bool> _syncPlayerCondition(BuildContext context, AppState state, Campaign campaign, Map<String, dynamic> entry, {String? add, String? remove}) async {
    final id = '${entry['id'] ?? ''}';
    final local = state.characters.where((c) => c.id == id);
    try {
      if (local.isNotEmpty) {
        final character = local.first;
        character.conditions = patchedConditions(character.conditions, add: add, remove: remove);
        await state.updateCharacter(character);
        return true;
      }
      final link = _remoteLink(campaign, id);
      if (link == null) return true;
      final session = await CloudService.ensureSession();
      final code = '${link['shareCode']}';
      // Base atual: patch pendente do mestre (se já tiver condições) ou o
      // snapshot mais recente da ficha; o patch substitui o anterior.
      final shared = await CloudService.sharedCharacterByCode(session, code);
      final pending = shared?['master_patch'];
      final snapshot = shared?['snapshot'] is Map ? shared!['snapshot'] as Map : link['snapshot'] as Map;
      final base = pending is Map && pending['conditions'] is List
          ? conditionsFromRaw(pending['conditions'])
          : conditionsFromRaw(snapshot['conditions']);
      final next = patchedConditions(base, add: add, remove: remove);
      await CloudService.updateSharedCharacterPatch(session, code, {'conditions': next});
      // O snapshot só muda pela sincronização real; até lá a exibição usa as
      // pendências guardadas no item da iniciativa.
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível enviar a condição para a ficha do jogador. Verifique a conexão e tente de novo.'),
        ));
      }
      return false;
    }
  }

  Future<void> _addParticipantCondition(BuildContext context, Campaign campaign, Map<String, dynamic> entry) async {
    final state = context.read<AppState>();
    final current = _participantConditions(state, campaign, entry);
    final value = await _pickParticipantCondition(context, current);
    if (value == null || value.isEmpty || !context.mounted) return;
    if (current.any((c) => sameCondition(c, value))) return;
    final id = '${entry['id'] ?? ''}';
    final isPlayer = entry['type'] == 'player';
    final isLocal = isPlayer && state.characters.any((c) => c.id == id);
    final isRemote = isPlayer && !isLocal && _remoteLink(campaign, id) != null;
    if (isPlayer && !await _syncPlayerCondition(context, state, campaign, entry, add: value)) return;
    if (isRemote) {
      // Pendente até o snapshot do jogador confirmar.
      entry['conditions'] = patchedConditions(initiativeConditions(entry), add: value);
      entry['conditionsRemoved'] = patchedConditions(conditionsFromRaw(entry['conditionsRemoved']), remove: value);
    } else if (!isLocal) {
      entry['conditions'] = patchedConditions(initiativeConditions(entry), add: value);
    }
    campaign.sessionLog.add('${entry['name'] ?? 'Participante'} ficou com $value.');
    if (!context.mounted) return;
    await _saveCombatChange(context, state, campaign);
  }

  Future<void> _removeParticipantCondition(BuildContext context, Campaign campaign, Map<String, dynamic> entry, String condition) async {
    final state = context.read<AppState>();
    final conditions = initiativeConditions(entry);
    final id = '${entry['id'] ?? ''}';
    final isPlayer = entry['type'] == 'player';
    final isLocal = isPlayer && state.characters.any((c) => c.id == id);
    final isRemote = isPlayer && !isLocal && _remoteLink(campaign, id) != null;
    if (isLocal || isRemote) {
      if (!await _syncPlayerCondition(context, state, campaign, entry, remove: condition)) return;
      if (isRemote) {
        // Pendente até o snapshot do jogador confirmar.
        entry['conditionsRemoved'] = patchedConditions(conditionsFromRaw(entry['conditionsRemoved']), add: condition);
        entry['conditions'] = patchedConditions(conditions, remove: condition);
      }
    } else {
      if (!conditions.remove(condition)) return;
      entry['conditions'] = conditions;
    }
    campaign.sessionLog.add('${entry['name'] ?? 'Participante'} não está mais com $condition.');
    if (!context.mounted) return;
    await _saveCombatChange(context, state, campaign);
  }

  Future<void> _removeCondition(BuildContext context, Campaign campaign, int index) async {
    if (index < 0 || index >= campaign.conditions.length) return;
    campaign.conditions.removeAt(index);
    await context.read<AppState>().updateCampaign(campaign);
  }

  Future<void> _sessionNotes(BuildContext context, Campaign campaign) async {
    final controller = TextEditingController(text: campaign.sessionNotes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notas rápidas da sessão'),
        content: TextField(textCapitalization: TextCapitalization.sentences, 
          controller: controller,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(hintText: 'Turnos, acontecimentos, lembretes e decisões rápidas...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      campaign.sessionNotes = controller.text;
      await context.read<AppState>().updateCampaign(campaign);
    }
  }

  Future<void> _changeResource(BuildContext context, AppState state, String characterId, String resource, int delta) async {
    final matches = state.characters.where((c) => c.id == characterId);
    if (matches.isEmpty) return;
    final character = matches.first;
    final current = character.resourceValues[resource] ?? 0;
    final max = character.resourceMaxValues[resource] ?? 0;
    var next = current + delta;
    if (next < 0) next = 0;
    if (max > 0 && next > max) next = max;
    character.resourceValues[resource] = next;
    await context.read<AppState>().updateCharacter(character);
  }
}
