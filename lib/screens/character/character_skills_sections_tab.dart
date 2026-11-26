part of 'character_screen.dart';

class _SkillsTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, String) onToggle;
  const _SkillsTab({required this.character, required this.system, required this.onToggle});

  Future<void> _rollFromSheet(BuildContext context, String skill) async {
    final choice = await showSkillRollSheet(context, system: system, character: character, skillName: skill);
    if (choice == null || !context.mounted) return;
    rollSkill(context, character: character, skillName: skill, attribute: choice.attribute, mode: choice.mode);
  }

  void _tapSkill(BuildContext context, String skill) {
    final attribute = resolveSkillRoll(system, character, skill);
    if (attribute == null) {
      _rollFromSheet(context, skill);
      return;
    }
    rollSkill(context, character: character, skillName: skill, attribute: attribute);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Perícias do sistema', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (system.skills.isNotEmpty) ...[
        Text(
          'Toque para rolar · segure para escolher atributo e modo',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
      ],
      if (system.skills.isEmpty) const Text('Este sistema não possui perícias configuradas.')
      else ...[
        // Treinadas (marcadas) e Outras, cada bloco na ordem do sistema.
        for (final (title, trained) in [('Treinadas', true), ('Outras', false)])
          if (system.skills.any((skill) => character.skills.contains(skill) == trained)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ...system.skills.where((skill) => character.skills.contains(skill) == trained).map((skill) => _skillTile(context, skill)),
          ],
      ],
    ]);
  }

  Widget _skillTile(BuildContext context, String skill) {
    final attribute = resolveSkillRoll(system, character, skill);
    return Card(margin: cardSpacingMargin, child: ListTile(
      leading: const Icon(Icons.psychology),
      title: Text(skill),
      subtitle: Text(
        attribute == null ? 'Segure para escolher o atributo' : 'Rola com $attribute',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Checkbox(
        value: character.skills.contains(skill),
        onChanged: (_) => onToggle(character, skill),
        semanticLabel: 'Treinada em $skill',
      ),
      onTap: () => _tapSkill(context, skill),
      onLongPress: () => _rollFromSheet(context, skill),
    ));
  }
}

class _SectionsTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, String) onEdit;
  const _SectionsTab({required this.character, required this.system, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Texto 1.0: a linha de sempre. Texto maior: o chip desce de linha em vez
      // de passar da tela.
      if (MediaQuery.textScalerOf(context).scale(1) <= 1)
        Row(children: [
          Expanded(child: Text('Seções da ficha', style: Theme.of(context).textTheme.titleLarge)),
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.tune, size: 15),
            label: Text(system.name),
          ),
        ])
      else
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
          Text('Seções da ficha', style: Theme.of(context).textTheme.titleLarge),
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.tune, size: 15),
            label: Text(system.name),
          ),
        ]),
      const SizedBox(height: 10),
      if (system.sections.isEmpty) const Text('Este sistema não possui seções configuradas.'),
      ...system.sections.map((section) => Card(
        margin: cardSpacingMargin,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          title: Text(section, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            (character.sectionNotes[section] ?? '').isEmpty ? 'Toque para preencher.' : character.sectionNotes[section]!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.edit),
          onTap: () => onEdit(character, section),
        ),
      )),
    ]);
  }
}
