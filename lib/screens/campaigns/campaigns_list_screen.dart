part of 'campaigns_screen.dart';

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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Criar')),
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
          campaign.npcSheets.any((e) =>
              '${e['name'] ?? ((e['sheet'] is Map) ? e['sheet']['name'] : '')}'
                  .toLowerCase()
                  .contains(query)) ||
          campaign.locations.any((e) => e.toLowerCase().contains(query));
    }).toList();

    if (_sort == 'name') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == 'characters') {
      list.sort(
          (a, b) => b.characterIds.length.compareTo(a.characterIds.length));
    } else if (_sort == 'content') {
      int contentCount(Campaign c) =>
          c.npcs.length +
          c.npcSheets.length +
          c.locations.length +
          c.sessionLog.length;
      list.sort((a, b) => contentCount(b).compareTo(contentCount(a)));
    } else {
      final order = {
        for (var i = 0; i < state.campaigns.length; i++)
          state.campaigns[i].id: i
      };
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
                PopupMenuItem(
                    value: 'characters', child: Text('Mais personagens')),
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
                        Expanded(
                          child: Text(
                            '${campaigns.length} de ${state.campaigns.length} campanha(s)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          _sortLabel(),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: campaigns.isEmpty
                        ? const Center(
                            child: Text('Nenhuma campanha encontrada.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: campaigns.length,
                            itemBuilder: (_, index) =>
                                _campaignCard(context, campaigns[index]),
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
              Icon(Icons.groups_2_outlined,
                  size: 52, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('Suas campanhas ficam aqui',
                  style: Theme.of(context).textTheme.titleLarge),
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
    final contentCount = campaign.npcs.length +
        campaign.npcSheets.length +
        campaign.locations.length;
    return Card(
      margin: cardSpacingMargin,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CampaignDetailScreen(campaignId: campaign.id)),
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
                child: Icon(Icons.groups_2_outlined,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaign.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
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
                        _metric(Icons.person_outline,
                            '${campaign.characterIds.length} personagens'),
                        _metric(Icons.person_search_outlined,
                            '${campaign.npcs.length + campaign.npcSheets.length} NPCs'),
                        _metric(Icons.location_on_outlined,
                            '${campaign.locations.length} locais'),
                        if (campaign.sessionLog.isNotEmpty)
                          _metric(Icons.history,
                              '${campaign.sessionLog.length} registros'),
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
                      MaterialPageRoute(
                          builder: (_) =>
                              CampaignDetailScreen(campaignId: campaign.id)),
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
        content: Text(
            'A campanha “${campaign.name}” será excluída. As fichas não serão apagadas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteCampaign(campaign.id);
    }
  }
}
