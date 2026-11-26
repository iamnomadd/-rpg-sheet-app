part of 'campaigns_screen.dart';

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});
  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen>
    with SingleTickerProviderStateMixin {
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
    _syncTimer = Timer(delay, () {
      if (mounted) _autoSync();
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
    final state = context.read<AppState>();
    final found = state.campaigns.where((c) => c.id == _campaignId);
    if (found.isEmpty) return;
    _syncBusy = true;
    try {
      final synced =
          await _refreshRemotePlayers(context, found.first, quiet: true);
      if (synced) {
        _syncFailures = 0;
        if (mounted) setState(() => _lastSync = DateTime.now());
      } else {
        _syncFailures++;
      }
    } finally {
      _syncBusy = false;
      if (mounted) {
        final delay = _syncFailures == 0
            ? const Duration(seconds: 4)
            : Duration(
                seconds: (4 * (1 << _syncFailures.clamp(0, 2))).clamp(8, 20));
        _scheduleAutoSync(delay);
      }
    }
  }

  Future<void> _createCampaign(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Nova campanha'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(labelText: 'Nome da campanha')),
                const SizedBox(height: 10),
                TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrição')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Criar'))
              ],
            ));
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    final campaign = Campaign(
        id: const Uuid().v4(),
        name: name.text.trim(),
        description: description.text.trim());
    await context.read<AppState>().addCampaign(campaign);
    if (mounted) setState(() => _campaignId = campaign.id);
  }

  Future<void> _selectCampaign(
      BuildContext context, List<Campaign> campaigns) async {
    final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(
                  title: Text('Campanhas',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              ...campaigns.map((c) => ListTile(
                  leading: Icon(c.id == _campaignId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
                  title: Text(c.name),
                  subtitle: c.description.isEmpty
                      ? null
                      : Text(c.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, c.id))),
              const Divider(height: 1),
              ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Criar nova campanha'),
                  onTap: () => Navigator.pop(context, '__new__')),
            ])));
    if (!mounted || selected == null) return;
    if (selected == '__new__') return _createCampaign(context);
    setState(() => _campaignId = selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.campaigns.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: const Text('Mestre')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.workspace_premium_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text('Crie sua primeira campanha',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                        'Cada campanha mantém jogadores, NPCs, sessão e notas separadamente.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                        onPressed: () => _createCampaign(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Criar campanha')),
                  ]))));
    }
    final id = state.campaigns.any((c) => c.id == _campaignId)
        ? _campaignId!
        : state.campaigns.first.id;
    _campaignId = id;
    final c = state.campaigns.firstWhere((x) => x.id == id);
    return Scaffold(
      appBar: AppBar(title: const Text('Mestre'), actions: [
        IconButton(
            tooltip: 'Nova campanha',
            onPressed: () => _createCampaign(context),
            icon: const Icon(Icons.add))
      ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _selectCampaign(context, state.campaigns),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.menu_book_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(c.name,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text('Trocar campanha',
                                style: Theme.of(context).textTheme.bodySmall)
                          ])),
                      const Icon(Icons.keyboard_arrow_down),
                    ])))),
        TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumo'),
              Tab(icon: Icon(Icons.people_outline), text: 'Jogadores'),
              Tab(icon: Icon(Icons.person_search_outlined), text: 'NPCs'),
              Tab(
                  icon: Icon(Icons.sports_martial_arts_outlined),
                  text: 'Sessão'),
              Tab(icon: Icon(Icons.notes_outlined), text: 'Notas')
            ]),
        const Divider(height: 1),
        Expanded(
            child: TabBarView(controller: _tabs, children: [
          _summary(context, state, c),
          _players(context, state, c),
          _npcs(context, c),
          _session(context, c),
          _notes(context, c)
        ])),
      ]),
    );
  }

  Widget _summary(BuildContext context, AppState state, Campaign c) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _masterStatusCard(context, c),
        if (c.description.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c.description,
                  style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _metricCard(context, Icons.people_outline, 'Jogadores',
                  '${c.characterIds.length + c.linkedCharacters.where((x) => x['status'] == 'approved').length}')),
          const SizedBox(width: 8),
          Expanded(
              child: _metricCard(context, Icons.person_search_outlined, 'NPCs',
                  '${c.npcs.length + c.npcSheets.length}')),
          const SizedBox(width: 8),
          Expanded(
              child: _metricCard(context, Icons.sports_martial_arts_outlined,
                  'Rodada', '${c.sessionRound}')),
        ]),
        const SizedBox(height: 8),
        Card(
            margin: cardSpacingMargin,
            child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: Icon(c.combatActive
                    ? Icons.play_circle_fill
                    : Icons.pause_circle_outline),
                title: Text(c.combatActive
                    ? 'Sessão em andamento'
                    : 'Sessão preparada'),
                subtitle: Text(
                    '${c.initiative.length} na iniciativa • ${c.conditions.length} condições'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _tabs.animateTo(3);
                })),
        Card(
            margin: cardSpacingMargin,
            child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Cena atual'),
                subtitle: Text(c.masterScene.isEmpty
                    ? 'Nenhuma cena definida.'
                    : c.masterScene),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MasterToolsScreen(campaignId: c.id))))),
      ]);

  Widget _masterStatusCard(BuildContext context, Campaign c) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(.28)),
          color: accent.withOpacity(.07)),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: accent.withOpacity(.16)),
            child: Icon(
                c.combatActive
                    ? Icons.sports_martial_arts
                    : Icons.workspace_premium_outlined,
                color: accent)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.combatActive ? 'Combate ativo' : 'Painel do Mestre',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
              _syncBusy
                  ? 'Sincronizando jogadores...'
                  : _lastSync == null
                      ? 'Sincronização automática ativa'
                      : 'Sincronizado • ${TimeOfDay.fromDateTime(_lastSync!).format(context)}',
              style: Theme.of(context).textTheme.bodySmall),
        ])),
        IconButton(
            tooltip: 'Sincronizar agora',
            onPressed: _syncBusy ? null : _autoSync,
            icon: Icon(_syncBusy ? Icons.sync : Icons.cloud_done_outlined)),
      ]),
    );
  }

  Widget _metricCard(
          BuildContext context, IconData icon, String label, String value) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(.45)),
        child: Column(children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
        ]),
      );

  Widget _players(BuildContext context, AppState state, Campaign c) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Vincular ficha por código'),
                subtitle: const Text(
                    'Solicite acesso seguro à ficha de outro jogador.'),
                trailing: Wrap(children: [
                  IconButton(
                      tooltip: 'Atualizar vínculos',
                      onPressed: () => _refreshRemotePlayers(context, c),
                      icon: const Icon(Icons.sync)),
                  const Icon(Icons.chevron_right)
                ]),
                onTap: () => _linkByCode(context, c))),
        if (c.linkedCharacters.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Vínculos remotos',
              style: Theme.of(context).textTheme.titleMedium),
          ...c.linkedCharacters.map((x) {
            final snap = Map<String, dynamic>.from(x['snapshot'] as Map? ?? {});
            final resources =
                Map<String, dynamic>.from(snap['resourceValues'] as Map? ?? {});
            final max = Map<String, dynamic>.from(
                snap['resourceMaxValues'] as Map? ?? {});
            final conditions = (snap['conditions'] as List? ?? [])
                .map((e) => e.toString())
                .toList();
            return Card(
                margin: cardSpacingMargin,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      leading: CircleAvatar(
                          child: Icon(x['status'] == 'approved'
                              ? Icons.person
                              : Icons.hourglass_top)),
                      title: Text(snap['name']?.toString() ?? 'Ficha vinculada',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(x['status'] == 'approved'
                                ? 'Ficha sincronizada'
                                : 'Aguardando aprovação'),
                            if (resources.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                      resources.entries
                                          .map((e) =>
                                              '${e.key} ${e.value}/${max[e.key] ?? e.value}')
                                          .take(3)
                                          .join('  •  '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)),
                          ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(x['status'] == 'approved'
                                      ? Icons.cloud_done_outlined
                                      : Icons.cloud_queue_outlined),
                                  if (conditions.isNotEmpty)
                                    Text('${conditions.length} status',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall)
                                ])),
                        PopupMenuButton<String>(
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'unlink',
                                      child: Text('Desvincular'))
                                ],
                            onSelected: (v) {
                              if (v == 'unlink') _unlinkRemote(context, c, x);
                            }),
                      ]),
                      onTap: x['status'] == 'approved'
                          ? () => _editRemoteCharacter(context, c, x)
                          : null,
                    )));
          })
        ],
        Row(children: [
          Expanded(
              child: Text('Jogadores locais',
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              tooltip: 'Selecionar fichas locais',
              onPressed: () => _pickLocalPlayers(context, state, c),
              icon: const Icon(Icons.person_add_alt_1))
        ]),
        if (c.characterIds.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum jogador vinculado a esta campanha.'))),
        ...c.characterIds.map((id) {
          final found = state.characters.where((x) => x.id == id);
          if (found.isEmpty) return const SizedBox.shrink();
          final ch = found.first;
          return Card(
              margin: cardSpacingMargin,
              child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: const Icon(Icons.person_outline),
                  title: Text(ch.name),
                  subtitle: Text(ch.resourceValues.entries
                      .map((e) =>
                          '${e.key}: ${e.value}/${ch.resourceMaxValues[e.key] ?? e.value}')
                      .take(3)
                      .join(' • ')),
                  trailing: ch.conditions.isEmpty
                      ? null
                      : Text('${ch.conditions.length} status')));
        }),
      ]);

  Future<void> _linkByCode(BuildContext context, Campaign c) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Vincular ficha'),
              content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Código da ficha', hintText: 'AB12-CD34')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, ctrl.text.trim().toUpperCase()),
                    child: const Text('Solicitar acesso'))
              ],
            ));
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      final session = await CloudService.ensureSession();
      final shared = await CloudService.lookupSharedCharacter(session, code);
      if (shared == null) throw Exception('Código de ficha não encontrado.');
      await CloudService.requestCharacterLink(session, shared, c.id);
      c.linkedCharacters.removeWhere((e) => e['shareCode'] == code);
      c.linkedCharacters.add({
        'shareCode': code,
        'status': 'pending',
        'snapshot': <String, dynamic>{
          'id': shared['character_id'],
          'name': shared['display_name'] ?? 'Ficha'
        },
        'ownerId': shared['owner_id']
      });
      await context.read<AppState>().updateCampaign(c);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação enviada ao jogador.')));
    } catch (e) {
      debugPrint('Vincular ficha falhou: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Não foi possível vincular a ficha. Confira o código e a conexão.')));
    }
  }

  /// Desfaz o vínculo com uma ficha remota: primeiro na nuvem; só se der
  /// certo, tira da campanha e da iniciativa.
  Future<void> _unlinkRemote(
      BuildContext context, Campaign c, Map<String, dynamic> link) async {
    final snap = link['snapshot'] is Map ? link['snapshot'] as Map : const {};
    final name = '${snap['name'] ?? 'Ficha'}';
    if (!await confirmDelete(context,
        title: 'Desvincular ficha?',
        message:
            '"$name" sairá da campanha e da iniciativa. Para vincular de novo, o jogador precisará aprovar um novo pedido.',
        confirmLabel: 'Desvincular')) {
      return;
    }
    if (!context.mounted) return;
    final state = context.read<AppState>();
    final code = '${link['shareCode'] ?? ''}';
    try {
      final session = await CloudService.ensureSession();
      if (link['status'] == 'approved') {
        // Melhor esforço: o jogador não aplica depois um patch antigo do Mestre.
        try {
          await CloudService.updateSharedCharacterPatch(
              session, code, <String, dynamic>{});
        } catch (_) {}
      }
      final requestId = '${link['requestId'] ?? ''}';
      final deleted = requestId.isNotEmpty
          ? await CloudService.deleteLinkRequest(session, requestId)
          : await CloudService.deleteOwnLinkRequestByCode(session, c.id, code);
      // Nada apagado: se a linha já não existe (ex.: o jogador apagou a
      // ficha), é sucesso; se ainda existe, a falha é real.
      final stillExists = deleted
          ? null
          : await CloudService.linkRequestExists(session,
              requestId: requestId, campaignId: c.id, shareCode: code);
      if (!canRemoveLinkLocally(deleted: deleted, stillExists: stillExists)) {
        throw Exception(
            'o servidor ainda não permite desfazer vínculos. A atualização do banco (migration v150) precisa ser aplicada.');
      }
    } catch (e) {
      debugPrint('Desvincular falhou: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Não foi possível desvincular. Verifique a conexão.')));
      }
      return;
    }
    final initiativeChanged = removeRemoteLink(c, link);
    await state.updateCampaign(c);
    if (initiativeChanged) await _syncCombatState(c);
  }

  Future<void> _editRemoteCharacter(
      BuildContext context, Campaign c, Map<String, dynamic> link) async {
    final snap = Map<String, dynamic>.from(link['snapshot'] as Map? ?? {});
    final resources =
        Map<String, dynamic>.from(snap['resourceValues'] as Map? ?? {});
    final conditions =
        (snap['conditions'] as List? ?? []).map((e) => e.toString()).toList();
    // A vida (Vida/PV) do jogador é só dele: o mestre não vê nem envia esse campo.
    final ctrls = {
      for (final e in resources.entries)
        if (!isLifeResourceKey(e.key))
          e.key: TextEditingController(text: '${e.value}')
    };
    final cond = TextEditingController(text: conditions.join(', '));
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Atualizar ${snap['name'] ?? 'ficha'}'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                ...ctrls.entries.map((e) => TextField(
                    controller: e.value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: e.key))),
                TextField(
                    controller: cond,
                    decoration: const InputDecoration(
                        labelText: 'Condições',
                        hintText: 'Separadas por vírgula'),
                    maxLines: 2),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Enviar ao jogador'))
              ],
            ));
    if (ok != true || !context.mounted) return;
    final values = <String, int>{};
    for (final e in ctrls.entries) {
      final v = int.tryParse(e.value.text.trim());
      if (v != null) values[e.key] = v;
    }
    final newConditions = cond.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      final session = await CloudService.ensureSession();
      await CloudService.updateSharedCharacterPatch(
          session,
          '${link['shareCode']}',
          {'resourceValues': values, 'conditions': newConditions});
    } catch (e) {
      debugPrint('Sincronizar vínculo falhou: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Não foi possível sincronizar. Verifique a conexão.')));
      }
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
      if (entry.containsKey('conditions') || pruned.add.isNotEmpty) {
        entry['conditions'] = pruned.add;
      }
      if (entry.containsKey('conditionsRemoved') || pruned.remove.isNotEmpty) {
        entry['conditionsRemoved'] = pruned.remove;
      }
    }
  }

  Future<bool> _refreshRemotePlayers(BuildContext context, Campaign c,
      {bool quiet = false}) async {
    // Capturado antes dos awaits: salva mesmo se a tela fechar durante a busca.
    final appState = context.read<AppState>();
    try {
      final session = await CloudService.ensureSession();
      final links = await CloudService.approvedLinksForCampaign(session, c.id);
      final approvedCodes = <String>{};
      final missingShared = <String>{};
      for (final link in links) {
        approvedCodes.add('${link['share_code']}');
        final shared = await CloudService.sharedCharacterByCode(
            session, '${link['share_code']}');
        if (shared == null) {
          // Ficha apagada pelo jogador: o vínculo sai da lista e, se o
          // servidor permitir, da nuvem também (melhor esforço).
          missingShared.add('${link['share_code']}');
          try {
            await CloudService.deleteLinkRequest(session, '${link['id']}');
          } catch (_) {}
          continue;
        }
        c.linkedCharacters
            .removeWhere((e) => e['shareCode'] == link['share_code']);
        c.linkedCharacters.add({
          'requestId': link['id'],
          'shareCode': link['share_code'],
          'status': 'approved',
          'snapshot': shared['snapshot'],
          'ownerId': shared['owner_id']
        });
      }
      var initiativeChanged = false;
      for (final stale in staleRemoteLinks(
          local: c.linkedCharacters,
          approvedCodes: approvedCodes,
          missingSharedCodes: missingShared)) {
        initiativeChanged = removeRemoteLink(c, stale) || initiativeChanged;
      }
      _pruneConfirmedConditions(c);
      await appState.updateCampaign(c);
      if (initiativeChanged) await _syncCombatState(c);
      return true;
    } catch (e) {
      debugPrint('Atualizar vínculos falhou: $e');
      if (!quiet && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível atualizar os vínculos. Verifique a conexão.')));
      }
      return false;
    }
  }

  Future<void> _pickLocalPlayers(
      BuildContext context, AppState state, Campaign c) async {
    final selected = Set<String>.from(c.characterIds);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('Jogadores da campanha'),
                    content: SizedBox(
                        width: double.maxFinite,
                        child: state.characters.isEmpty
                            ? const Text('Nenhuma ficha criada neste aparelho.')
                            : ListView(
                                shrinkWrap: true,
                                children: state.characters
                                    .map((ch) => CheckboxListTile(
                                        value: selected.contains(ch.id),
                                        title: Text(ch.name),
                                        onChanged: (v) => setLocal(() =>
                                            v == true
                                                ? selected.add(ch.id)
                                                : selected.remove(ch.id))))
                                    .toList())),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Salvar'))
                    ])));
    if (ok == true && context.mounted) {
      c.characterIds = selected.toList();
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Widget _npcs(BuildContext context, Campaign c) {
    final total = c.npcSheets.length + c.npcs.length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NPCs e Monstros',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('Fichas controladas pelo Mestre',
              style: Theme.of(context).textTheme.bodySmall)
        ])),
        FilledButton.tonalIcon(
            onPressed: () => _addNpc(context, c),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar')),
      ]),
      const SizedBox(height: 12),
      if (total == 0)
        const Card(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.person_search_outlined, size: 38),
                  SizedBox(height: 10),
                  Text('Nenhum NPC ou monstro cadastrado.'),
                  SizedBox(height: 4),
                  Text('Crie uma ficha própria ou copie uma ficha existente.',
                      textAlign: TextAlign.center)
                ]))),
      ...spacedCards(c.npcSheets.map((npc) {
        final raw = npc['sheet'];
        final sheet = raw is Map
            ? Character.fromJson(Map<String, dynamic>.from(raw))
            : null;
        final kind = '${npc['kind'] ?? 'NPC'}';
        final hp = sheet?.resourceValues['Vida'] ?? sheet?.hp ?? 0;
        final max = sheet?.resourceMaxValues['Vida'] ?? sheet?.maxHp ?? 0;
        return Card(
            child: ListTile(
          leading: CircleAvatar(child: Icon(_npcKindIcon(kind))),
          title: Text(sheet?.name ?? '${npc['name'] ?? 'NPC'}'),
          subtitle: Text(
              '$kind • Vida $hp/$max${npc['source'] == 'character' ? ' • cópia de ficha' : ''}'),
          trailing: PopupMenuButton<String>(
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Abrir ficha')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir'))
                  ],
              onSelected: (v) async {
                if (v == 'open') {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NpcSheetScreen(
                              campaignId: c.id, npcId: '${npc['id']}')));
                }
                if (v == 'duplicate') {
                  await _duplicateNpc(context, c, npc);
                }
                if (v == 'delete') {
                  final npcName = sheet?.name ?? '${npc['name'] ?? 'NPC'}';
                  if (!await confirmDelete(context,
                      title: 'Excluir NPC?',
                      message:
                          '"$npcName" e sua ficha serão removidos da campanha e da iniciativa.')) {
                    return;
                  }
                  if (!context.mounted) return;
                  c.npcSheets.remove(npc);
                  c.initiative
                      .removeWhere((e) => e['id'] == 'npc:${npc['id']}');
                  await context.read<AppState>().updateCampaign(c);
                }
              }),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      NpcSheetScreen(campaignId: c.id, npcId: '${npc['id']}'))),
        ));
      })),
      if (c.npcs.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('NPCs antigos', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        ...spacedCards(c.npcs.asMap().entries.map((e) => Card(
            child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(e.value),
                subtitle: const Text('Formato simples antigo'),
                trailing: PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'convert',
                              child: Text('Converter em ficha')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir'))
                        ],
                    onSelected: (v) async {
                      if (v == 'convert') {
                        await _convertLegacyNpc(context, c, e.key, e.value);
                      }
                      if (v == 'delete') {
                        if (!await confirmDelete(context,
                            title: 'Excluir NPC?',
                            message:
                                '"${e.value}" será removido da campanha.')) {
                          return;
                        }
                        if (!context.mounted) return;
                        c.npcs.removeAt(e.key);
                        await context.read<AppState>().updateCampaign(c);
                      }
                    }))))),
      ],
    ]);
  }

  IconData _npcKindIcon(String kind) => switch (kind) {
        'Monstro' => Icons.bug_report_outlined,
        'Chefe' => Icons.workspace_premium_outlined,
        'Aliado' => Icons.shield_outlined,
        _ => Icons.person_outline
      };

  Future<void> _addNpc(BuildContext context, Campaign c) async {
    final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (sheet) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Criar NPC / Monstro'),
                      subtitle:
                          const Text('Montar uma ficha controlada pelo Mestre'),
                      onTap: () => Navigator.pop(sheet, 'new')),
                  ListTile(
                      leading: const Icon(Icons.content_copy),
                      title: const Text('Usar ficha existente'),
                      subtitle: const Text(
                          'Cria uma cópia independente de uma ficha de personagem'),
                      onTap: () => Navigator.pop(sheet, 'copy')),
                ]))));
    if (choice == 'new' && context.mounted) await _createNpcSheet(context, c);
    if (choice == 'copy' && context.mounted) {
      await _copyCharacterAsNpc(context, c);
    }
  }

  Future<void> _createNpcSheet(BuildContext context, Campaign c,
      {String? initialName}) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: initialName ?? '');
    String kind = 'NPC';
    String systemId =
        state.systems.isEmpty ? 'generic' : state.systems.first.id;
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
            builder: (context, setD) => AlertDialog(
                    title: const Text('Criar NPC / Monstro'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Nome')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          value: kind,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const ['NPC', 'Monstro', 'Aliado', 'Chefe']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setD(() => kind = v ?? kind)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          value: systemId,
                          decoration:
                              const InputDecoration(labelText: 'Sistema'),
                          items: state.systems
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) =>
                              setD(() => systemId = v ?? systemId)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Criar ficha'))
                    ])));
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    final matches = state.systems.where((s) => s.id == systemId);
    final system = matches.isEmpty ? null : matches.first;
    final id = const Uuid().v4();
    final resources = <String, int>{};
    final resourceMax = <String, int>{};
    for (final r in system?.resources ?? const ['Vida', 'Energia']) {
      resources[r] = r == 'Vida' || r == 'PV' ? 10 : 0;
      resourceMax[r] = r == 'Vida' || r == 'PV' ? 10 : 0;
    }
    if (resources.isEmpty) {
      resources['Vida'] = 10;
      resourceMax['Vida'] = 10;
    }
    final attrs = <String, int>{
      for (final a in system?.attributes ??
          const ['FOR', 'DES', 'CON', 'INT', 'SAB', 'CAR'])
        a: 10
    };
    final ch = Character(
        id: id,
        name: name.text.trim(),
        player: 'Mestre',
        systemId: systemId,
        attributes: attrs,
        resourceValues: resources,
        resourceMaxValues: resourceMax,
        skills: List<String>.from(system?.skills ?? const []));
    c.npcSheets.add({
      'id': id,
      'name': ch.name,
      'kind': kind,
      'source': 'custom',
      'sheet': ch.toJson()
    });
    await state.updateCampaign(c);
    if (context.mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NpcSheetScreen(campaignId: c.id, npcId: id)));
    }
  }

  Future<void> _copyCharacterAsNpc(BuildContext context, Campaign c) async {
    final state = context.read<AppState>();
    if (state.characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma ficha criada para copiar.')));
      return;
    }
    final chosen = await showDialog<String>(
        context: context,
        builder: (d) => SimpleDialog(
            title: const Text('Escolher ficha'),
            children: state.characters
                .map((ch) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(d, ch.id),
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(ch.name),
                        subtitle: Text(
                            ch.player.isEmpty ? 'Sem jogador' : ch.player))))
                .toList()));
    if (chosen == null || !context.mounted) return;
    final original = state.characters.firstWhere((ch) => ch.id == chosen);
    String kind = 'NPC';
    final k = await showDialog<String>(
        context: context,
        builder: (d) => SimpleDialog(
            title: const Text('Tipo da cópia'),
            children: ['NPC', 'Monstro', 'Aliado', 'Chefe']
                .map((x) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(d, x), child: Text(x)))
                .toList()));
    if (k != null) kind = k;
    final id = const Uuid().v4();
    final data = Map<String, dynamic>.from(original.toJson());
    data['id'] = id;
    data['player'] = 'Mestre';
    data['shareCode'] = '';
    // A cópia para NPC não leva o personagem 2D personalizado (as imagens não se repetem dentro da campanha).
    data['customSpriteImages'] = <String, String>{};
    data['customSpriteEnabled'] = false;
    final copy = Character.fromJson(data);
    c.npcSheets.add({
      'id': id,
      'name': copy.name,
      'kind': kind,
      'source': 'character',
      'sourceCharacterId': original.id,
      'sheet': copy.toJson()
    });
    await state.updateCampaign(c);
    if (context.mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NpcSheetScreen(campaignId: c.id, npcId: id)));
    }
  }

  Future<void> _duplicateNpc(
      BuildContext context, Campaign c, Map<String, dynamic> npc) async {
    final id = const Uuid().v4();
    final copy = Map<String, dynamic>.from(npc);
    copy['id'] = id;
    final raw = npc['sheet'];
    if (raw is Map) {
      final data = Map<String, dynamic>.from(raw);
      data['id'] = id;
      data['name'] = '${data['name'] ?? 'NPC'} (cópia)';
      copy['name'] = data['name'];
      copy['sheet'] = data;
    }
    c.npcSheets.add(copy);
    await context.read<AppState>().updateCampaign(c);
  }

  Future<void> _convertLegacyNpc(
      BuildContext context, Campaign c, int index, String name) async {
    final state = context.read<AppState>();
    final id = const Uuid().v4();
    final ch = Character(id: id, name: name, player: 'Mestre');
    c.npcSheets.add({
      'id': id,
      'name': name,
      'kind': 'NPC',
      'source': 'legacy',
      'sheet': ch.toJson()
    });
    c.npcs.removeAt(index);
    await state.updateCampaign(c);
    if (context.mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NpcSheetScreen(campaignId: c.id, npcId: id)));
    }
  }

  Widget _session(BuildContext context, Campaign c) {
    final ordered = [...c.initiative]..sort((a, b) =>
        ((b['value'] ?? 0) as int).compareTo((a['value'] ?? 0) as int));
    final ix =
        ordered.isEmpty ? 0 : c.currentTurnIndex.clamp(0, ordered.length - 1);
    final current = c.combatActive && ordered.isNotEmpty ? ordered[ix] : null;
    final done = ordered.where((e) => e['done'] == true).length;
    final currentConditions = current == null
        ? <String>[]
        : _participantConditions(context.read<AppState>(), c, current);
    return ListView(padding: const EdgeInsets.all(16), children: [
      ...spacedCards([
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(c.combatActive
                            ? Icons.sports_martial_arts
                            : Icons.pause_circle_outline),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                c.combatActive
                                    ? 'Combate ativo'
                                    : 'Sem combate ativo',
                                style: Theme.of(context).textTheme.titleLarge)),
                        Text('Rodada ${c.sessionRound}')
                      ]),
                      if (current != null) ...[
                        const SizedBox(height: 12),
                        Text('TURNO ATUAL',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text('${current['name']}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                            'Iniciativa ${current['value']} • $done/${ordered.length} concluídos'),
                        if (currentConditions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: currentConditions
                                  .map((condition) => Chip(
                                      label: Text(condition),
                                      visualDensity: VisualDensity.compact))
                                  .toList())
                        ]
                      ],
                    ]))),
        if (ordered.isNotEmpty)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ordem de iniciativa',
                            style: Theme.of(context).textTheme.titleMedium),
                        ...ordered.asMap().entries.map((e) {
                          final active = c.combatActive && e.key == ix;
                          final finished = e.value['done'] == true;
                          final isPlayer = e.value['type'] == 'player';
                          final isNpc = e.value['type'] == 'npc' &&
                              '${e.value['id']}'.startsWith('npc:');
                          return ListTile(
                            dense: true,
                            leading: Icon(finished
                                ? Icons.check_circle
                                : active
                                    ? Icons.play_circle_fill
                                    : Icons.radio_button_unchecked),
                            title: Text('${e.value['name']}'),
                            subtitle: Text(active
                                ? 'Jogando agora'
                                : isPlayer
                                    ? 'Toque para ver ficha rápida'
                                    : isNpc
                                        ? 'Toque para controlar a ficha'
                                        : 'NPC / participante'),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${e.value['value']}'),
                              if (isPlayer || isNpc)
                                const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.chevron_right))
                            ]),
                            onTap: isPlayer
                                ? () => _showCombatPlayer(context, c, e.value)
                                : isNpc
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => NpcSheetScreen(
                                                campaignId: c.id,
                                                npcId: '${e.value['id']}'
                                                    .substring(4))))
                                    : null,
                          );
                        }),
                      ]))),
        FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SessionToolsScreen(campaignId: c.id))),
            icon: const Icon(Icons.open_in_new),
            label: Text(c.combatActive
                ? 'Abrir controle da sessão'
                : 'Preparar sessão')),
      ]),
      if (c.sessionLog.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Histórico recente',
            style: Theme.of(context).textTheme.titleMedium),
        ...c.sessionLog.reversed.take(5).map((e) => ListTile(
            dense: true, leading: const Icon(Icons.history), title: Text(e)))
      ],
    ]);
  }

  Future<void> _showCombatPlayer(BuildContext context, Campaign c,
      Map<String, dynamic> participant) async {
    final state = context.read<AppState>();
    Map<String, dynamic>? snap;
    final local =
        state.characters.where((ch) => ch.id == '${participant['id']}');
    if (local.isNotEmpty) snap = local.first.toJson();
    if (snap == null) {
      for (final link in c.linkedCharacters) {
        final raw = link['snapshot'];
        if (raw is Map && '${raw['id']}' == '${participant['id']}') {
          snap = Map<String, dynamic>.from(raw);
          break;
        }
      }
    }
    if (snap == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ficha vinculada ainda não foi sincronizada.')));
      }
      return;
    }
    final resources =
        Map<String, dynamic>.from(snap['resourceValues'] as Map? ?? {});
    final max =
        Map<String, dynamic>.from(snap['resourceMaxValues'] as Map? ?? {});
    final conditions =
        (snap['conditions'] as List? ?? []).map((e) => e.toString()).toList();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('${snap!['name'] ?? participant['name']}',
                              style:
                                  Theme.of(sheetContext).textTheme.titleLarge))
                    ]),
                    const SizedBox(height: 16),
                    Text('Recursos',
                        style: Theme.of(sheetContext).textTheme.titleMedium),
                    if (resources.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Nenhum recurso registrado.')),
                    ...resources.entries.map((r) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.key),
                        trailing: Text('${r.value}/${max[r.key] ?? r.value}'))),
                    const SizedBox(height: 8),
                    Text('Condições',
                        style: Theme.of(sheetContext).textTheme.titleMedium),
                    if (conditions.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Nenhuma condição ativa.')),
                    if (conditions.isNotEmpty)
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: conditions
                              .map((x) => Chip(label: Text(x)))
                              .toList()),
                  ]),
            )));
  }

  Widget _notes(BuildContext context, Campaign c) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            margin: cardSpacingMargin,
            child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: const Icon(Icons.lock_outline),
                title: const Text('Notas privadas do Mestre'),
                subtitle: Text(
                    c.masterNotes.isEmpty
                        ? 'Nenhuma nota privada.'
                        : c.masterNotes,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editNotes(context, c, true))),
        Card(
            margin: cardSpacingMargin,
            child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: const Icon(Icons.notes_outlined),
                title: const Text('Notas da campanha'),
                subtitle: Text(c.notes.isEmpty ? 'Nenhuma nota.' : c.notes,
                    maxLines: 4, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editNotes(context, c, false))),
      ]);
  Future<void> _editNotes(
      BuildContext context, Campaign c, bool private) async {
    final ctrl = TextEditingController(text: private ? c.masterNotes : c.notes);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(
                    private ? 'Notas privadas do Mestre' : 'Notas da campanha'),
                content: TextField(controller: ctrl, minLines: 6, maxLines: 12),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salvar'))
                ]));
    if (ok == true && context.mounted) {
      if (private) {
        c.masterNotes = ctrl.text;
      } else {
        c.notes = ctrl.text;
      }
      await context.read<AppState>().updateCampaign(c);
    }
  }
}
