import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/example_character.dart';
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

    // "Ficha de exemplo" no próprio fluxo de nova ficha.
    var example = false;
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
            TextButton.icon(
              onPressed: () {
                example = true;
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Ficha de exemplo'),
            ),
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

    if (example && context.mounted) return _newExampleCharacter(context);
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

  /// Cria a ficha de exemplo (uma ficha normal) e abre essa ficha.
  Future<void> _newExampleCharacter(BuildContext context) async {
    final character = await createExampleCharacter(context.read<AppState>());
    if (!context.mounted) return;
    if (character == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O sistema Tormenta20 não está disponível para a ficha de exemplo.')));
      return;
    }
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
                ? _EmptyState(onCreate: () => _newCharacter(context), onCreateExample: () => _newExampleCharacter(context))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    // Contador + fichas + bloco de criação no fim da lista.
                    itemCount: state.characters.length + 2,
                    itemBuilder: (_, index) {
                      if (index == state.characters.length + 1) {
                        return _EmptyState.more(onCreate: () => _newCharacter(context), onCreateExample: () => _newExampleCharacter(context));
                      }
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

/// Bloco de criação: a tela vazia (sem fichas) e, mais compacto, o fim da
/// lista com fichas ([_EmptyState.more]). Mesmo ícone, títulos e botões.
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onCreateExample;
  final double iconSize;
  final String title;
  final String text;
  final String createLabel;
  final String exampleLabel;
  final EdgeInsetsGeometry padding;
  final double iconGap;
  final double buttonsGap;

  const _EmptyState({required this.onCreate, required this.onCreateExample})
      : iconSize = 72,
        title = 'Sua aventura começa aqui',
        text = 'Crie sua primeira ficha e organize personagens, atributos, inventário e habilidades.',
        createLabel = 'Criar primeira ficha',
        exampleLabel = 'Criar ficha de exemplo',
        padding = const EdgeInsets.all(32),
        iconGap = 18,
        buttonsGap = 24;

  /// Fim da lista quando já há fichas (1.3.75): ~48 px e menos espaço,
  /// com folga embaixo para não encostar na barra de navegação.
  const _EmptyState.more({required this.onCreate, required this.onCreateExample})
      : iconSize = 48,
        title = 'Sua aventura continua',
        text = 'Crie outra ficha ou explore uma ficha de exemplo.',
        createLabel = 'Criar uma nova ficha',
        exampleLabel = 'Criar uma nova ficha de exemplo',
        padding = const EdgeInsets.fromLTRB(16, 20, 16, 32),
        iconGap = 12,
        buttonsGap = 18;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: ValueKey('create-block-$title'),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: iconSize),
            SizedBox(height: iconGap),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: buttonsGap),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(createLabel, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCreateExample,
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(exampleLabel, textAlign: TextAlign.center),
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
