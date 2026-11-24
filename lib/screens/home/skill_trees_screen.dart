import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/app_state.dart';
import '../character/skill_tree_screen.dart';
import '../../widgets/card_spacing.dart';

class SkillTreesScreen extends StatelessWidget {
  const SkillTreesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Árvores de Habilidades')),
        body: state.characters.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Crie uma ficha primeiro para montar sua árvore de habilidades.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.characters.length,
                itemBuilder: (ctx, i) {
                  final c = state.characters[i];
                  final unlocked = c.skillTree.where((n) => n['unlocked'] == true).length;
                  return Card(
                    margin: cardSpacingMargin,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: CircleAvatar(child: Icon(themedMainIcon(state.themeId, 'tree'))),
                      title: Text(c.name),
                      subtitle: Text('${c.skillTree.length} habilidade(s) • $unlocked desbloqueada(s)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SkillTreeScreen(characterId: c.id)),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
