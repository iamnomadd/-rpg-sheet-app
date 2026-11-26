part of 'campaigns_screen.dart';

class MasterToolsScreen extends StatelessWidget {
  final String campaignId;
  const MasterToolsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.campaigns.where((c) => c.id == campaignId);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Campanha não encontrada.')));
    }
    final c = matches.first;
    return Scaffold(
      appBar: AppBar(title: Text('Painel do Mestre • ${c.name}')),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: spacedCards([
            Card(
                child: ListTile(
              leading: const Icon(Icons.movie_filter_outlined),
              title: const Text('Cena atual'),
              subtitle: Text(c.masterScene.isEmpty
                  ? 'Nenhuma cena definida.'
                  : c.masterScene),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editScene(context, c),
            )),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.flag_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Objetivos do mestre',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                            IconButton(
                                onPressed: () => _addObjective(context, c),
                                icon: const Icon(Icons.add))
                          ]),
                          if (c.masterObjectives.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('Nenhum objetivo registrado.')),
                          ...c.masterObjectives.asMap().entries.map((e) {
                            final done = e.value.startsWith('[x] ');
                            final label = e.value
                                .replaceFirst(RegExp(r'^\[(x| )\] '), '');
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: done,
                              title: Text(label),
                              onChanged: (_) => _toggleObjective(
                                  context, c, e.key, label, !done),
                              secondary: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      _removeObjective(context, c, e.key)),
                            );
                          }),
                        ]))),
            Card(
                child: ExpansionTile(
              leading: const Icon(Icons.person_search),
              title: Text('NPCs (${c.npcs.length + c.npcSheets.length})'),
              children: (c.npcs.isEmpty && c.npcSheets.isEmpty)
                  ? [const ListTile(title: Text('Nenhum NPC cadastrado.'))]
                  : [
                      ...c.npcSheets.map((npc) {
                        final raw = npc['sheet'];
                        final name = raw is Map
                            ? '${raw['name'] ?? npc['name'] ?? 'NPC'}'
                            : '${npc['name'] ?? 'NPC'}';
                        return ListTile(
                            dense: true,
                            leading:
                                Icon(_npcKindIcon('${npc['kind'] ?? 'NPC'}')),
                            title: Text(name),
                            subtitle: Text('${npc['kind'] ?? 'NPC'}'),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => NpcSheetScreen(
                                        campaignId: c.id,
                                        npcId: '${npc['id']}'))));
                      }),
                      ...c.npcs.map((x) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline),
                          title: Text(x),
                          subtitle: const Text('Formato simples antigo'))),
                    ],
            )),
            Card(
                child: ExpansionTile(
              leading: const Icon(Icons.map_outlined),
              title: Text('Locais (${c.locations.length})'),
              children: c.locations.isEmpty
                  ? [const ListTile(title: Text('Nenhum local cadastrado.'))]
                  : c.locations
                      .map((x) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(x)))
                      .toList(),
            )),
            Card(
                child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Notas privadas'),
              subtitle: Text(
                  c.masterNotes.isEmpty
                      ? 'Nenhuma nota privada.'
                      : c.masterNotes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editPrivateNotes(context, c),
            )),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.history_edu_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('Registro da sessão',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                            IconButton(
                                onPressed: () => _addLog(context, c),
                                icon: const Icon(Icons.add))
                          ]),
                          if (c.sessionLog.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(8),
                                child:
                                    Text('Nenhum acontecimento registrado.')),
                          ...c.sessionLog.reversed.take(20).map((x) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.circle, size: 9),
                              title: Text(x))),
                          if (c.sessionLog.isNotEmpty)
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                    onPressed: () => _clearLog(context, c),
                                    icon:
                                        const Icon(Icons.delete_sweep_outlined),
                                    label: const Text('Limpar registro'))),
                        ]))),
          ])),
    );
  }

  Future<void> _editScene(BuildContext context, Campaign c) async {
    final controller = TextEditingController(text: c.masterScene);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Cena atual'),
                content: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: 'Ex.: Salão do castelo durante o banquete')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salvar'))
                ]));
    if (ok == true && context.mounted) {
      c.masterScene = controller.text.trim();
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _addObjective(BuildContext context, Campaign c) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Novo objetivo'),
                content: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'Ex.: Revelar a pista do medalhão')),
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
      c.masterObjectives.add('[ ] $value');
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _toggleObjective(BuildContext context, Campaign c, int index,
      String label, bool done) async {
    c.masterObjectives[index] = '${done ? '[x]' : '[ ]'} $label';
    await context.read<AppState>().updateCampaign(c);
  }

  Future<void> _removeObjective(
      BuildContext context, Campaign c, int index) async {
    c.masterObjectives.removeAt(index);
    await context.read<AppState>().updateCampaign(c);
  }

  Future<void> _editPrivateNotes(BuildContext context, Campaign c) async {
    final controller = TextEditingController(text: c.masterNotes);
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Notas privadas'),
                content: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: controller,
                    minLines: 7,
                    maxLines: 14,
                    decoration: const InputDecoration(
                        hintText: 'Segredos, planos, pistas e lembretes...')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salvar'))
                ]));
    if (ok == true && context.mounted) {
      c.masterNotes = controller.text;
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _addLog(BuildContext context, Campaign c) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Registrar acontecimento'),
                content: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: 'O que aconteceu na sessão?')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Registrar'))
                ]));
    if (value != null && value.isNotEmpty && context.mounted) {
      c.addSessionLog(value);
      await context.read<AppState>().updateCampaign(c);
    }
  }

  Future<void> _clearLog(BuildContext context, Campaign c) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Limpar registro?'),
                content: const Text(
                    'Os acontecimentos registrados serão removidos.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Limpar'))
                ]));
    if (ok == true && context.mounted) {
      c.sessionLog.clear();
      await context.read<AppState>().updateCampaign(c);
    }
  }
}
