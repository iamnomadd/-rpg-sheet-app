import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/campaign.dart';
import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/rpg_file_service.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('Importar/exportar falhou: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível concluir. Tente de novo.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import(BuildContext context) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final state = context.read<AppState>();
      final result = await RpgFileService.importInto(state);
      if (!mounted || result == 'cancelled') return;
      final message = switch (result) {
        'system' => 'Sistema importado com sucesso.',
        'character' => 'Ficha e sistema importados com sucesso.',
        'campaign' => 'Campanha, fichas e sistemas importados com sucesso.',
        'backup' => 'Backup restaurado com sucesso.',
        _ => 'Importação concluída.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Importar arquivo falhou: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo inválido. Escolha um arquivo .rpg exportado pelo RPG Sheet.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = await RpgFileService.pickBackupForRestore();
      if (!mounted || data == null) return;

      final summary = RpgFileService.backupSummary(data);
      var restoreGameData = true;
      var restoreRollData = true;
      var restorePreferences = true;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Restaurar backup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${summary['characters']} fichas • ${summary['systems']} sistemas • ${summary['campaigns']} campanhas',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary['savedRolls']} favoritos • ${summary['diceHistory']} rolagens no histórico',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Escolha o que deseja restaurar. As categorias selecionadas substituirão somente os dados equivalentes deste aparelho.',
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fichas, sistemas e campanhas'),
                    subtitle: const Text('Restaura os dados principais em conjunto para manter os vínculos.'),
                    value: restoreGameData,
                    onChanged: (value) => setDialogState(() => restoreGameData = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rolagens e favoritos'),
                    value: restoreRollData,
                    onChanged: (value) => setDialogState(() => restoreRollData = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preferências'),
                    subtitle: const Text('Tema, texto maior e modo compacto quando disponíveis no backup.'),
                    value: restorePreferences,
                    onChanged: (value) => setDialogState(() => restorePreferences = value ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: restoreGameData || restoreRollData || restorePreferences
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Restaurar selecionados'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true || !mounted) return;
      await context.read<AppState>().restoreBackupSections(
            data,
            restoreGameData: restoreGameData,
            restoreRollData: restoreRollData,
            restorePreferences: restorePreferences,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restaurado com sucesso.')),
        );
      }
    } catch (e) {
      debugPrint('Restaurar backup falhou: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível restaurar. Confira se o arquivo é um backup .rpg válido.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportSystem(BuildContext context, RpgSystem system) =>
      _run(() => RpgFileService.exportSystem(system));

  Future<void> _exportCharacter(BuildContext context, Character character) async {
    final state = context.read<AppState>();
    final system = state.systems.firstWhere(
      (s) => s.id == character.systemId,
      orElse: () => state.systems.first,
    );
    await _run(() => RpgFileService.exportCharacter(character, system));
  }

  Future<void> _exportCampaign(BuildContext context, Campaign campaign, bool playerPackage) async {
    final state = context.read<AppState>();
    await _run(() => RpgFileService.exportCampaign(
          campaign,
          state,
          playerPackage: playerPackage,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Importar e exportar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Arquivos .rpg'),
              subtitle: Text('Use este formato para compartilhar dados, criar backups completos e migrar entre versões/dispositivos.'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : () => _import(context),
            icon: const Icon(Icons.file_open),
            label: const Text('Importar arquivo .rpg'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _restoreBackup(context),
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar backup seletivamente'),
          ),
          const SizedBox(height: 24),
          Text('Exportar backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _run(() => RpgFileService.exportBackup(state)),
            icon: const Icon(Icons.backup),
            label: const Text('Criar backup completo'),
          ),
          const SizedBox(height: 24),
          Text('Exportar sistemas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...state.systems.map(
            (system) => Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(system.name),
                subtitle: Text('${system.attributes.length} atributos • ${system.skills.length} perícias'),
                trailing: IconButton(
                  tooltip: 'Exportar sistema',
                  onPressed: busy ? null : () => _exportSystem(context, system),
                  icon: const Icon(Icons.ios_share),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Exportar fichas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.characters.isEmpty)
            const Text('Nenhuma ficha criada.')
          else
            ...state.characters.map(
              (character) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(character.name),
                  subtitle: Text('Nível ${character.level}'),
                  trailing: IconButton(
                    tooltip: 'Exportar ficha',
                    onPressed: busy ? null : () => _exportCharacter(context, character),
                    icon: const Icon(Icons.ios_share),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Compartilhar campanhas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.campaigns.isEmpty)
            const Text('Nenhuma campanha criada.')
          else
            ...state.campaigns.map(
              (campaign) => Card(
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(campaign.name),
                  subtitle: const Text('Escolha pacote para jogadores ou cópia completa.'),
                  trailing: PopupMenuButton<String>(
                    enabled: !busy,
                    icon: const Icon(Icons.ios_share),
                    onSelected: (value) => _exportCampaign(context, campaign, value == 'player'),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'player', child: Text('Pacote para jogadores')),
                      PopupMenuItem(value: 'master', child: Text('Cópia completa do mestre')),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
