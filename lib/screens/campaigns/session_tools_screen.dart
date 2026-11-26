part of 'campaigns_screen.dart';

class SessionToolsScreen extends StatelessWidget {
  final String campaignId;
  const SessionToolsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.campaigns.where((c) => c.id == campaignId);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Campanha não encontrada.')));
    }
    final campaign = matches.first;
    final participants = [...campaign.initiative]..sort((a, b) =>
        ((b['value'] ?? 0) as int).compareTo((a['value'] ?? 0) as int));
    final activeIndex = participants.isEmpty
        ? 0
        : campaign.currentTurnIndex.clamp(0, participants.length - 1);

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
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(campaign.combatActive ? 'COMBATE ATIVO' : 'SESSÃO',
                            style: Theme.of(context).textTheme.labelMedium),
                        Text('Rodada ${campaign.sessionRound}',
                            style: Theme.of(context).textTheme.titleLarge),
                      ])),
                  IconButton(
                    tooltip: 'Voltar rodada',
                    onPressed: campaign.sessionRound > 1
                        ? () => _changeRound(context, campaign, -1)
                        : null,
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
                    Expanded(
                        child: Text('Iniciativa',
                            style: Theme.of(context).textTheme.titleMedium)),
                    if (!campaign.combatActive)
                      FilledButton.tonalIcon(
                        onPressed: () => _rollInitiative(context, campaign),
                        icon: const Icon(Icons.casino_outlined),
                        label: const Text('Rolar iniciativa'),
                      ),
                  ]),
                  if (participants.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Nenhum participante na iniciativa.')),
                  ...participants.asMap().entries.map((indexed) {
                    final index = indexed.key;
                    final entry = indexed.value;
                    final done = entry['done'] == true;
                    final current =
                        campaign.combatActive && index == activeIndex && !done;
                    final status = current
                        ? 'Turno atual'
                        : (campaign.combatActive &&
                                index == activeIndex + 1 &&
                                !done
                            ? 'Próximo'
                            : null);
                    final vida = _vidaBar(context, state, campaign, entry);
                    // Jogador: a ficha é a fonte da verdade (+ pendências do mestre).
                    final conditions =
                        _participantConditions(state, campaign, entry);
                    return ListTile(
                      dense: true,
                      selected: current,
                      leading: Checkbox(
                        value: done,
                        onChanged: campaign.combatActive
                            ? (_) => _finishTurn(
                                context, campaign, participants, index)
                            : null,
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
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    tooltip: 'Remover $condition',
                                    onPressed: () =>
                                        _removeParticipantCondition(context,
                                            campaign, entry, condition),
                                    onDeleted: () =>
                                        _removeParticipantCondition(context,
                                            campaign, entry, condition),
                                    deleteButtonTooltipMessage:
                                        'Remover $condition',
                                  )),
                              IconButton(
                                tooltip:
                                    'Adicionar condição a ${entry['name'] ?? 'participante'}',
                                onPressed: () => _addParticipantCondition(
                                    context, campaign, entry),
                                icon: const Icon(Icons.healing_outlined,
                                    size: 18),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
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
                            onPressed: () =>
                                _editInitiativeValue(context, campaign, entry),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Remover do combate',
                            onPressed: () =>
                                _removeInitiative(context, campaign, entry),
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
                        onPressed: () =>
                            _addInitiativeParticipant(context, campaign),
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
                    Expanded(
                        child: Text('Condições gerais',
                            style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                        onPressed: () => _addCondition(context, campaign),
                        icon: const Icon(Icons.add)),
                  ]),
                  if (campaign.conditions.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Nenhuma condição registrada.')),
                  ...campaign.conditions.asMap().entries.map((e) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(e.value),
                        trailing: IconButton(
                          onPressed: () =>
                              _removeCondition(context, campaign, e.key),
                          icon: const Icon(Icons.close),
                        ),
                      )),
                ],
              ),
            ),
          ),
          if (campaign.sessionLog.isNotEmpty)
            Card(
                child: ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico do combate'),
              subtitle: Text('${campaign.sessionLog.length} eventos'),
              children: campaign.sessionLog.reversed
                  .take(20)
                  .map((event) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.chevron_right),
                      title: Text(event)))
                  .toList(),
            )),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Notas rápidas da sessão'),
              subtitle: Text(
                campaign.sessionNotes.isEmpty
                    ? 'Nenhuma nota rápida'
                    : campaign.sessionNotes,
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

  Widget _resourceCard(
      BuildContext context, AppState state, Campaign campaign) {
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
              Expanded(
                  child: Text('Recursos rápidos',
                      style: Theme.of(context).textTheme.titleMedium)),
            ]),
            if (chars.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Nenhuma ficha vinculada à campanha.')),
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
                          onPressed: () => _changeResource(
                              context, state, character.id, resource, -1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: '+1',
                          onPressed: () => _changeResource(
                              context, state, character.id, resource, 1),
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
  ({Map<String, dynamic> npc, Character sheet})? _npcSheet(
      Campaign campaign, String npcId) {
    for (final npc in campaign.npcSheets) {
      final raw = npc['sheet'];
      if ('${npc['id']}' != npcId || raw is! Map) continue;
      try {
        return (
          npc: npc,
          sheet: Character.fromJson(Map<String, dynamic>.from(raw))
        );
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
    final ratio =
        vida.max > 0 ? (vida.current / vida.max).clamp(0.0, 1.0) : 0.0;
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
      Text('${vida.current} / ${vida.max}',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  /// Vida do participante: NPC local pode ser ajustado pelo mestre; jogador
  /// aparece só para leitura (a vida do jogador é dele); avulso não tem barra.
  Widget? _vidaBar(BuildContext context, AppState state, Campaign campaign,
      Map<String, dynamic> entry) {
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

  Future<void> _editNpcVida(BuildContext context, Campaign campaign,
      Map<String, dynamic> entry) async {
    final id = '${entry['id'] ?? ''}';
    if (!id.startsWith('npc:')) return;
    final found = _npcSheet(campaign, id.substring(4));
    if (found == null) return;
    final state = context.read<AppState>();
    final before = readVida(found.sheet);
    final result = await showResourceQuickAdjust(context,
        name: 'Vida', current: before.current, max: before.max);
    if (result == null || !context.mounted) return;
    applyVida(found.sheet, result);
    final after = readVida(found.sheet);
    if (after == before) return;
    found.npc['sheet'] = found.sheet.toJson();
    campaign.addSessionLog(
        '${entry['name'] ?? found.sheet.name}: vida ${before.current}/${before.max} → ${after.current}/${after.max}');
    try {
      await state.updateCampaign(campaign);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível salvar a vida.')));
      }
    }
  }

  Future<void> _syncCombat(Campaign campaign) => _syncCombatState(campaign);

  Future<void> _changeRound(
      BuildContext context, Campaign campaign, int delta) async {
    campaign.sessionRound = (campaign.sessionRound + delta).clamp(1, 9999);
    campaign.addSessionLog(
        'Rodada alterada manualmente para ${campaign.sessionRound}.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _resetRound(BuildContext context, Campaign campaign) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reiniciar rodada?'),
        content:
            const Text('A rodada voltará para 1. A iniciativa será mantida.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reiniciar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      campaign.sessionRound = 1;
      campaign.currentTurnIndex = 0;
      for (final e in campaign.initiative) {
        e['done'] = false;
      }
      campaign.addSessionLog('Rodadas reiniciadas.');
      await context.read<AppState>().updateCampaign(campaign);
      await _syncCombat(campaign);
    }
  }

  Future<void> _rollInitiative(BuildContext context, Campaign campaign) async {
    final state = context.read<AppState>();
    final options = <Map<String, String>>[];
    for (final id in campaign.characterIds) {
      final found = state.characters.where((c) => c.id == id);
      if (found.isNotEmpty) {
        options.add({'id': id, 'name': found.first.name, 'type': 'player'});
      }
    }
    for (final linked in campaign.linkedCharacters) {
      final snapshot = linked['snapshot'];
      if (snapshot is Map) {
        final id = '${snapshot['id'] ?? linked['character_id'] ?? ''}';
        final name = '${snapshot['name'] ?? 'Jogador'}';
        if (!options.any((e) => e['id'] == id)) {
          options.add({'id': id, 'name': name, 'type': 'player'});
        }
      }
    }
    for (final npc in campaign.npcSheets) {
      final raw = npc['sheet'];
      final name = raw is Map
          ? '${raw['name'] ?? npc['name'] ?? 'NPC'}'
          : '${npc['name'] ?? 'NPC'}';
      options.add({'id': 'npc:${npc['id']}', 'name': name, 'type': 'npc'});
    }
    for (var i = 0; i < campaign.npcs.length; i++) {
      options
          .add({'id': 'legacyNpc:$i', 'name': campaign.npcs[i], 'type': 'npc'});
    }
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Adicione jogadores ou NPCs antes de iniciar o combate.')));
      return;
    }

    final selected = <String, bool>{for (final o in options) o['id']!: true};
    final controllers = <String, TextEditingController>{
      for (final o in options) o['id']!: TextEditingController()
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
                title: const Text('Rolar iniciativa'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: options
                        .map((o) => Row(children: [
                              Checkbox(
                                  value: selected[o['id']] == true,
                                  onChanged: (v) => setDialogState(
                                      () => selected[o['id']!] = v == true)),
                              Expanded(child: Text(o['name']!)),
                              SizedBox(
                                  width: 82,
                                  child: TextField(
                                    controller: controllers[o['id']],
                                    enabled: selected[o['id']] == true,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Inic.'),
                                  )),
                            ]))
                        .toList(),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Iniciar')),
                ],
              )),
    );
    if (ok != true || !context.mounted) return;
    final entries = <Map<String, dynamic>>[];
    for (final o in options.where((o) => selected[o['id']] == true)) {
      final value = int.tryParse(controllers[o['id']]!.text.trim());
      if (value == null) continue;
      entries.add({
        'id': o['id'],
        'name': o['name'],
        'type': o['type'],
        'value': value,
        'done': false
      });
    }
    for (final c in controllers.values) {
      c.dispose();
    }
    if (entries.isEmpty) return;
    entries.sort((a, b) {
      final byValue = (b['value'] as int).compareTo(a['value'] as int);
      if (byValue != 0) return byValue;
      return '${a['name']}'
          .toLowerCase()
          .compareTo('${b['name']}'.toLowerCase());
    });
    campaign.initiative = entries;
    campaign.sessionRound = 1;
    campaign.currentTurnIndex = 0;
    campaign.combatActive = true;
    campaign.addSessionLog('Combate iniciado.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _finishTurn(BuildContext context, Campaign campaign,
      List<Map<String, dynamic>> participants, int index) async {
    if (!campaign.combatActive || participants.isEmpty) return;
    final current = campaign.currentTurnIndex.clamp(0, participants.length - 1);
    if (index != current) return;
    participants[index]['done'] = true;
    final finishedName = '${participants[index]['name'] ?? 'Participante'}';
    campaign.addSessionLog(
        'Rodada ${campaign.sessionRound}: $finishedName concluiu o turno.');
    final original = campaign.initiative.firstWhere(
        (e) =>
            e['id'] == participants[index]['id'] &&
            e['value'] == participants[index]['value'],
        orElse: () => participants[index]);
    original['done'] = true;

    if (index >= participants.length - 1) {
      campaign.sessionRound += 1;
      campaign.addSessionLog('Rodada ${campaign.sessionRound} iniciada.');
      campaign.currentTurnIndex = 0;
      for (final e in campaign.initiative) {
        e['done'] = false;
      }
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
        content: const Text(
            'A iniciativa e o estado de turno serão encerrados. Fichas, recursos e condições serão mantidos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    campaign.combatActive = false;
    campaign.currentTurnIndex = 0;
    for (final e in campaign.initiative) {
      e['done'] = false;
    }
    campaign
        .addSessionLog('Combate encerrado na rodada ${campaign.sessionRound}.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _editInitiativeValue(BuildContext context, Campaign campaign,
      Map<String, dynamic> entry) async {
    final controller = TextEditingController(text: '${entry['value'] ?? 0}');
    final value = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text('Iniciativa • ${entry['name'] ?? 'Participante'}'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Iniciativa')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(
                        dialogContext, int.tryParse(controller.text.trim())),
                    child: const Text('Salvar')),
              ],
            ));
    controller.dispose();
    if (value == null || !context.mounted) return;
    final currentId = campaign.combatActive && campaign.initiative.isNotEmpty
        ? ([...campaign.initiative]..sort((a, b) => ((b['value'] ?? 0) as int)
                .compareTo((a['value'] ?? 0) as int)))[
            campaign.currentTurnIndex
                .clamp(0, campaign.initiative.length - 1)]['id']
        : null;
    entry['value'] = value;
    campaign.initiative.sort((a, b) {
      final byValue =
          ((b['value'] ?? 0) as int).compareTo((a['value'] ?? 0) as int);
      if (byValue != 0) return byValue;
      return '${a['name'] ?? ''}'
          .toLowerCase()
          .compareTo('${b['name'] ?? ''}'.toLowerCase());
    });
    if (currentId != null) {
      final ix = campaign.initiative.indexWhere((e) => e['id'] == currentId);
      if (ix >= 0) campaign.currentTurnIndex = ix;
    }
    campaign
        .addSessionLog('Iniciativa de ${entry['name']} alterada para $value.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _addInitiativeParticipant(
      BuildContext context, Campaign campaign) async {
    final state = context.read<AppState>();
    final options = <Map<String, String>>[];
    for (final id in campaign.characterIds) {
      final found = state.characters.where((c) => c.id == id);
      if (found.isNotEmpty && !campaign.initiative.any((e) => e['id'] == id)) {
        options.add({'id': id, 'name': found.first.name, 'type': 'player'});
      }
    }
    for (final linked in campaign.linkedCharacters) {
      final snapshot = linked['snapshot'];
      if (snapshot is Map) {
        final id = '${snapshot['id'] ?? linked['character_id'] ?? ''}';
        if (id.isNotEmpty && !campaign.initiative.any((e) => e['id'] == id)) {
          options.add({
            'id': id,
            'name': '${snapshot['name'] ?? 'Jogador'}',
            'type': 'player'
          });
        }
      }
    }
    for (final npc in campaign.npcSheets) {
      final id = 'npc:${npc['id']}';
      final raw = npc['sheet'];
      final name = raw is Map
          ? '${raw['name'] ?? npc['name'] ?? 'NPC'}'
          : '${npc['name'] ?? 'NPC'}';
      if (!campaign.initiative.any((e) => e['id'] == id)) {
        options.add({'id': id, 'name': name, 'type': 'npc'});
      }
    }
    for (var i = 0; i < campaign.npcs.length; i++) {
      final id = 'legacyNpc:$i';
      if (!campaign.initiative.any((e) => e['id'] == id)) {
        options.add({'id': id, 'name': campaign.npcs[i], 'type': 'npc'});
      }
    }
    options.add({
      'id': 'manual:${DateTime.now().microsecondsSinceEpoch}',
      'name': 'Outro',
      'type': 'manual'
    });
    String? chosen;
    final initiative = TextEditingController();
    final manualName = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Adicionar participante'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      value: chosen,
                      hint: const Text('Participante'),
                      items: options
                          .map((o) => DropdownMenuItem(
                              value: o['id'], child: Text(o['name']!)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => chosen = v),
                    ),
                    if (chosen != null && chosen!.startsWith('manual:'))
                      TextField(
                          controller: manualName,
                          decoration: const InputDecoration(labelText: 'Nome')),
                    TextField(
                        controller: initiative,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Iniciativa')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Adicionar')),
                  ],
                )));
    if (ok != true || chosen == null || !context.mounted) return;
    final value = int.tryParse(initiative.text.trim());
    final selected = options.firstWhere((o) => o['id'] == chosen);
    final name = chosen!.startsWith('manual:')
        ? manualName.text.trim()
        : selected['name']!;
    initiative.dispose();
    manualName.dispose();
    if (value == null || name.isEmpty) return;
    final currentId = campaign.initiative.isEmpty
        ? null
        : ([...campaign.initiative]..sort((a, b) => ((b['value'] ?? 0) as int)
                .compareTo((a['value'] ?? 0) as int)))[
            campaign.currentTurnIndex
                .clamp(0, campaign.initiative.length - 1)]['id'];
    campaign.initiative.add({
      'id': chosen,
      'name': name,
      'type': selected['type'],
      'value': value,
      'done': false
    });
    campaign.initiative.sort((a, b) {
      final byValue =
          ((b['value'] ?? 0) as int).compareTo((a['value'] ?? 0) as int);
      if (byValue != 0) return byValue;
      return '${a['name'] ?? ''}'
          .toLowerCase()
          .compareTo('${b['name'] ?? ''}'.toLowerCase());
    });
    if (currentId != null) {
      final ix = campaign.initiative.indexWhere((e) => e['id'] == currentId);
      if (ix >= 0) campaign.currentTurnIndex = ix;
    }
    campaign.addSessionLog('$name entrou no combate com iniciativa $value.');
    await context.read<AppState>().updateCampaign(campaign);
    await _syncCombat(campaign);
  }

  Future<void> _removeInitiative(BuildContext context, Campaign campaign,
      Map<String, dynamic> entry) async {
    if (!await confirmDelete(context,
        title: 'Remover do combate?',
        message:
            '"${entry['name'] ?? 'Participante'}" será removido da iniciativa.',
        confirmLabel: 'Remover')) {
      return;
    }
    if (!context.mounted) return;
    removeInitiativeParticipant(campaign, entry['id']);
    campaign.addSessionLog(
        '${entry['name'] ?? 'Participante'} removido do combate.');
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
        content: TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Ex.: Envenenado — Goblin')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Adicionar')),
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

  Future<void> _saveCombatChange(
      BuildContext context, AppState state, Campaign campaign) async {
    try {
      await state.updateCampaign(campaign);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível salvar.')));
      }
      return;
    }
    await _syncCombat(campaign);
  }

  /// Seletor de condição do participante: condições pré-definidas (o nome
  /// salvo é o do preset) e "Outra..." com a entrada livre.
  Future<String?> _pickParticipantCondition(
      BuildContext context, List<String> current) async {
    const other = '\u0000outra';
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Adicionar condição'),
        children: [
          ...conditionPresets
              .where((p) => !current.any((c) => sameCondition(c, p.name)))
              .map((p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, p.name),
                    child: Row(children: [
                      Icon(p.icon),
                      const SizedBox(width: 10),
                      Text(p.name)
                    ]),
                  )),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, other),
            child: const Row(children: [
              Icon(Icons.add),
              SizedBox(width: 10),
              Text('Outra...')
            ]),
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
  Future<bool> _syncPlayerCondition(BuildContext context, AppState state,
      Campaign campaign, Map<String, dynamic> entry,
      {String? add, String? remove}) async {
    final id = '${entry['id'] ?? ''}';
    final local = state.characters.where((c) => c.id == id);
    try {
      if (local.isNotEmpty) {
        final character = local.first;
        character.conditions =
            patchedConditions(character.conditions, add: add, remove: remove);
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
      final snapshot = shared?['snapshot'] is Map
          ? shared!['snapshot'] as Map
          : link['snapshot'] as Map;
      final base = pending is Map && pending['conditions'] is List
          ? conditionsFromRaw(pending['conditions'])
          : conditionsFromRaw(snapshot['conditions']);
      final next = patchedConditions(base, add: add, remove: remove);
      await CloudService.updateSharedCharacterPatch(
          session, code, {'conditions': next});
      // O snapshot só muda pela sincronização real; até lá a exibição usa as
      // pendências guardadas no item da iniciativa.
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Não foi possível enviar a condição para a ficha do jogador. Verifique a conexão e tente de novo.'),
        ));
      }
      return false;
    }
  }

  Future<void> _addParticipantCondition(BuildContext context, Campaign campaign,
      Map<String, dynamic> entry) async {
    final state = context.read<AppState>();
    final current = _participantConditions(state, campaign, entry);
    final value = await _pickParticipantCondition(context, current);
    if (value == null || value.isEmpty || !context.mounted) return;
    if (current.any((c) => sameCondition(c, value))) return;
    final id = '${entry['id'] ?? ''}';
    final isPlayer = entry['type'] == 'player';
    final isLocal = isPlayer && state.characters.any((c) => c.id == id);
    final isRemote = isPlayer && !isLocal && _remoteLink(campaign, id) != null;
    if (isPlayer &&
        !await _syncPlayerCondition(context, state, campaign, entry,
            add: value)) {
      return;
    }
    if (isRemote) {
      // Pendente até o snapshot do jogador confirmar.
      entry['conditions'] =
          patchedConditions(initiativeConditions(entry), add: value);
      entry['conditionsRemoved'] = patchedConditions(
          conditionsFromRaw(entry['conditionsRemoved']),
          remove: value);
    } else if (!isLocal) {
      entry['conditions'] =
          patchedConditions(initiativeConditions(entry), add: value);
    }
    campaign
        .addSessionLog('${entry['name'] ?? 'Participante'} ficou com $value.');
    if (!context.mounted) return;
    await _saveCombatChange(context, state, campaign);
  }

  Future<void> _removeParticipantCondition(BuildContext context,
      Campaign campaign, Map<String, dynamic> entry, String condition) async {
    final state = context.read<AppState>();
    final conditions = initiativeConditions(entry);
    final id = '${entry['id'] ?? ''}';
    final isPlayer = entry['type'] == 'player';
    final isLocal = isPlayer && state.characters.any((c) => c.id == id);
    final isRemote = isPlayer && !isLocal && _remoteLink(campaign, id) != null;
    if (isLocal || isRemote) {
      if (!await _syncPlayerCondition(context, state, campaign, entry,
          remove: condition)) {
        return;
      }
      if (isRemote) {
        // Pendente até o snapshot do jogador confirmar.
        entry['conditionsRemoved'] = patchedConditions(
            conditionsFromRaw(entry['conditionsRemoved']),
            add: condition);
        entry['conditions'] = patchedConditions(conditions, remove: condition);
      }
    } else {
      if (!conditions.remove(condition)) return;
      entry['conditions'] = conditions;
    }
    campaign.addSessionLog(
        '${entry['name'] ?? 'Participante'} não está mais com $condition.');
    if (!context.mounted) return;
    await _saveCombatChange(context, state, campaign);
  }

  Future<void> _removeCondition(
      BuildContext context, Campaign campaign, int index) async {
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
        content: TextField(
          textCapitalization: TextCapitalization.sentences,
          controller: controller,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
              hintText:
                  'Turnos, acontecimentos, lembretes e decisões rápidas...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      campaign.sessionNotes = controller.text;
      await context.read<AppState>().updateCampaign(campaign);
    }
  }

  Future<void> _changeResource(BuildContext context, AppState state,
      String characterId, String resource, int delta) async {
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
