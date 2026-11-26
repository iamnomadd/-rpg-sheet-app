part of 'campaigns_screen.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});
  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  bool masterMode = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.campaigns.where((c) => c.id == widget.campaignId);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Campanha não encontrada.')));
    }
    final c = matches.first;
    final visibleIds = masterMode
        ? c.characterIds
        : c.characterIds
            .where((id) => !c.hiddenCharacterIds.contains(id))
            .toList();
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
                  subtitle:
                      Text('Inclui dados privados e ferramentas da sessão.'),
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
          IconButton(
              tooltip: 'Editar campanha',
              icon: const Icon(Icons.edit),
              onPressed: () => _editInfo(context, c)),
        ],
      ),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: spacedCards([
            Card(
                child: SwitchListTile(
              secondary:
                  Icon(masterMode ? Icons.workspace_premium : Icons.person),
              title: Text(masterMode ? 'Modo Mestre' : 'Modo Jogador'),
              subtitle: Text(masterMode
                  ? 'Conteúdo privado e controles do mestre estão visíveis.'
                  : 'Somente informações destinadas aos jogadores.'),
              value: masterMode,
              onChanged: (v) => setState(() => masterMode = v),
            )),
            if (c.description.isNotEmpty)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(c.description))),
            _section(
                context,
                'Personagens',
                Icons.people,
                visibleIds.map((id) {
                  final found = state.characters.where((x) => x.id == id);
                  final name =
                      found.isEmpty ? 'Ficha indisponível' : found.first.name;
                  return masterMode && c.hiddenCharacterIds.contains(id)
                      ? '$name  • oculto'
                      : name;
                }).toList(),
                masterMode ? () => _characters(context, c) : null),
            _section(
                context,
                'NPCs',
                Icons.person_search,
                [
                  ...c.npcs,
                  ...c.npcSheets.map((e) {
                    final raw = e['sheet'];
                    return raw is Map
                        ? '${raw['name'] ?? e['name'] ?? 'NPC'}'
                        : '${e['name'] ?? 'NPC'}';
                  })
                ],
                null,
                editable: false),
            _section(
                context,
                'Locais',
                Icons.map,
                c.locations,
                masterMode
                    ? () => _textList(context, c, 'Local', c.locations)
                    : null,
                editable: masterMode),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.notes),
                    title: const Text('Notas da campanha'),
                    subtitle: Text(c.notes.isEmpty ? 'Nenhuma nota' : c.notes,
                        maxLines: 4, overflow: TextOverflow.ellipsis),
                    onTap:
                        masterMode ? () => _notes(context, c, false) : null)),
            if (masterMode)
              Card(
                  child: ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Painel do Mestre'),
                subtitle: Text(c.masterScene.isEmpty
                    ? '${c.masterObjectives.length} objetivo(s) • ${c.sessionLog.length} registro(s)'
                    : 'Cena: ${c.masterScene}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MasterToolsScreen(campaignId: c.id))),
              )),
            if (masterMode)
              Card(
                  child: ListTile(
                leading: const Icon(Icons.sports_martial_arts),
                title: const Text('Sessão de RPG'),
                subtitle: Text(
                    'Rodada ${c.sessionRound} • ${c.initiative.length} na iniciativa • ${c.conditions.length} condições'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SessionToolsScreen(campaignId: c.id))),
              )),
            if (masterMode)
              Card(
                  child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Notas privadas do mestre'),
                subtitle: Text(
                    c.masterNotes.isEmpty
                        ? 'Nenhuma nota privada'
                        : c.masterNotes,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _notes(context, c, true),
              )),
            if (masterMode)
              Card(
                  child: ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Visibilidade das fichas'),
                subtitle: Text(
                    '${c.hiddenCharacterIds.length} ficha(s) oculta(s) dos jogadores'),
                trailing: const Icon(Icons.tune),
                onTap: () => _visibility(context, c),
              )),
          ])),
    );
  }

  Future<void> _shareCampaign(
      BuildContext context, Campaign campaign, String mode) async {
    final state = context.read<AppState>();
    try {
      if (mode == 'player') {
        await RpgFileService.exportCampaign(campaign, state,
            playerPackage: true);
      } else if (mode == 'master') {
        await RpgFileService.exportCampaign(campaign, state,
            playerPackage: false);
      } else if (mode == 'summary') {
        await RpgFileService.shareCampaignSummary(campaign, state);
      }
    } catch (e) {
      debugPrint('Compartilhar campanha falhou: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível compartilhar. Tente de novo.')),
      );
    }
  }

  Widget _section(BuildContext context, String title, IconData icon,
          List<String> values, VoidCallback? add, {bool editable = false}) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleMedium)),
                      if (add != null)
                        IconButton(onPressed: add, icon: const Icon(Icons.add))
                    ]),
                    if (values.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Nenhum item adicionado.')),
                    ...values.asMap().entries.map((e) => ListTile(
                        dense: true,
                        title: Text(e.value),
                        trailing: editable
                            ? const Icon(Icons.more_horiz, size: 18)
                            : null)),
                  ])));

  Future<void> _editInfo(BuildContext context, Campaign c) async {
    final name = TextEditingController(text: c.name),
        description = TextEditingController(text: c.description);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Editar campanha'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nome')),
                  TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      maxLines: 4)
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salvar'))
                ]));
    if (ok == true && name.text.trim().isNotEmpty && context.mounted) {
      c.name = name.text.trim();
      c.description = description.text.trim();
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _characters(BuildContext context, Campaign c) async {
    final state = context.read<AppState>();
    final selected = Set<String>.from(c.characterIds);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                    title: const Text('Personagens da campanha'),
                    content: SizedBox(
                        width: double.maxFinite,
                        child: state.characters.isEmpty
                            ? const Text('Crie uma ficha primeiro.')
                            : ListView(
                                shrinkWrap: true,
                                children: state.characters
                                    .map((ch) => CheckboxListTile(
                                        value: selected.contains(ch.id),
                                        title: Text(ch.name),
                                        onChanged: (v) => setState(() =>
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
      c.hiddenCharacterIds.removeWhere((id) => !selected.contains(id));
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _visibility(BuildContext context, Campaign c) async {
    final state = context.read<AppState>();
    final hidden = Set<String>.from(c.hiddenCharacterIds);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: const Text('Visibilidade das fichas'),
                  content: SizedBox(
                      width: double.maxFinite,
                      child: c.characterIds.isEmpty
                          ? const Text('Nenhuma ficha na campanha.')
                          : ListView(
                              shrinkWrap: true,
                              children: c.characterIds.map((id) {
                                final found =
                                    state.characters.where((x) => x.id == id);
                                final name = found.isEmpty
                                    ? 'Ficha indisponível'
                                    : found.first.name;
                                return SwitchListTile(
                                    title: Text(name),
                                    subtitle: Text(hidden.contains(id)
                                        ? 'Oculta dos jogadores'
                                        : 'Visível aos jogadores'),
                                    value: !hidden.contains(id),
                                    onChanged: (visible) => setState(() =>
                                        visible
                                            ? hidden.remove(id)
                                            : hidden.add(id)));
                              }).toList())),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Salvar'))
                  ],
                )));
    if (ok == true && context.mounted) {
      c.hiddenCharacterIds = hidden.toList();
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _textList(BuildContext context, Campaign c, String label,
      List<String> target) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text('Adicionar $label'),
                content: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(labelText: 'Nome do $label')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Adicionar'))
                ]));
    if (value != null && value.isNotEmpty && context.mounted) {
      target.add(value);
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _notes(BuildContext context, Campaign c, bool private) async {
    final controller =
        TextEditingController(text: private ? c.masterNotes : c.notes);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(
                    private ? 'Notas privadas do mestre' : 'Notas da campanha'),
                content: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: controller,
                    minLines: 6,
                    maxLines: 12,
                    decoration: InputDecoration(
                        hintText: private
                            ? 'Segredos, planos, pistas e informações do mestre...'
                            : 'Anotações da sessão, pistas, acontecimentos...')),
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
        c.masterNotes = controller.text;
      } else {
        c.notes = controller.text;
      }
      await context.read<AppState>().updateCampaign(c);
    }
  }
}
