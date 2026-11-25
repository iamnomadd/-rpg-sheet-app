import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../character/character_screen.dart';
import '../../widgets/card_spacing.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newCharacter(BuildContext context) async {
    final state = context.read<AppState>();
    final nameController = TextEditingController();
    String? selectedSystemId =
        state.systems.isNotEmpty ? state.systems.first.id : null;
    String? nameError;

    final result = await showDialog<_NewCharacterData>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nova ficha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(textCapitalization: TextCapitalization.sentences, 
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nome do personagem',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: nameError,
                ),
                onChanged: (_) {
                  if (nameError != null) setDialogState(() => nameError = null);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSystemId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sistema de RPG',
                  prefixIcon: Icon(Icons.auto_awesome),
                ),
                items: state.systems
                    .map(
                      (system) => DropdownMenuItem<String>(
                        value: system.id,
                        child: Text(system.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedSystemId = value);
                },
              ),
              const SizedBox(height: 8),
              if (selectedSystemId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _systemSummary(state.systems, selectedSystemId!),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => nameError = 'Dê um nome.');
                  return;
                }
                if (selectedSystemId == null) return;

                Navigator.pop(
                  dialogContext,
                  _NewCharacterData(
                    name: name,
                    systemId: selectedSystemId!,
                  ),
                );
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();

    if (result == null || !context.mounted) return;

    final character = await context.read<AppState>().addCharacter(
          name: result.name,
          systemId: result.systemId,
        );

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterScreen(characterId: character.id),
      ),
    );
  }

  String _systemSummary(List<RpgSystem> systems, String id) {
    final system = systems.firstWhere(
      (s) => s.id == id,
      orElse: () => systems.first,
    );
    return '${system.attributes.length} atributos • '
        '${system.skills.length} perícias • '
        '${system.resources.length} recursos';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Minhas Fichas'),
          actions: [
            IconButton(
              tooltip: 'Nova ficha',
              onPressed: () => _newCharacter(context),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: !state.loaded
            ? const Center(child: CircularProgressIndicator())
            : state.characters.isEmpty
                ? _EmptyState(onCreate: () => _newCharacter(context))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: state.characters.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                          child: Text(
                            '${state.characters.length} ficha${state.characters.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final character = state.characters[index - 1];
                      return _CharacterCard(character: character);
                    },
                  ),
      ),
    );
  }
}

class _NewCharacterData {
  final String name;
  final String systemId;

  const _NewCharacterData({
    required this.name,
    required this.systemId,
  });
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 72),
            const SizedBox(height: 18),
            Text(
              'Sua aventura começa aqui',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie sua primeira ficha e organize personagens, atributos, inventário e habilidades.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Criar primeira ficha'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final Character character;

  const _CharacterCard({required this.character});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final system = state.systems.firstWhere(
      (s) => s.id == character.systemId,
      orElse: () => state.systems.first,
    );

    return Card(
      margin: cardSpacingMargin,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          radius: 27,
          child: Text(
            character.name.isEmpty ? '?' : character.name[0].toUpperCase(),
          ),
        ),
        title: Text(
          character.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${character.className.isEmpty ? 'Sem classe' : character.className} • ${system.name}\n'
          'Nível ${character.level} • HP ${character.hp}/${character.maxHp}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Excluir ficha',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, character),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CharacterScreen(characterId: character.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Character character,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir ficha?'),
        content: Text(
          'A ficha de ${character.name} será removida deste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (delete == true && context.mounted) {
      await context.read<AppState>().deleteCharacter(character.id);
    }
  }
}
