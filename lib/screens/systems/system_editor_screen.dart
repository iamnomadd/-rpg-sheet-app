import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rpg_system.dart';
import '../../services/app_state.dart';

class SystemEditorScreen extends StatefulWidget {
  final RpgSystem system;

  const SystemEditorScreen({super.key, required this.system});

  @override
  State<SystemEditorScreen> createState() => _SystemEditorScreenState();
}

class _SystemEditorScreenState extends State<SystemEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController description;
  late List<String> attributes;
  late List<String> skills;
  late List<String> resources;
  late List<String> sections;
  late List<int> dice;
  late Map<String, String> skillAttributes;

  final Map<String, String> _attributeRenames = {};
  final Map<String, String> _skillRenames = {};
  final Map<String, String> _resourceRenames = {};
  final Map<String, String> _sectionRenames = {};

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.system.name);
    description = TextEditingController(text: widget.system.description);
    attributes = [...widget.system.attributes];
    skills = [...widget.system.skills];
    resources = [...widget.system.resources];
    sections = [...widget.system.sections];
    dice = [...widget.system.dice];
    skillAttributes = {...widget.system.skillAttributes};
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  bool _alreadyExists(List<String> list, String value, {int? ignoreIndex}) {
    final normalized = value.trim().toLowerCase();
    for (var i = 0; i < list.length; i++) {
      if (i == ignoreIndex) continue;
      if (list[i].trim().toLowerCase() == normalized) return true;
    }
    return false;
  }

  Future<String?> _askText({
    required String title,
    required String label,
    String initial = '',
    String action = 'Salvar',
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (text) => Navigator.pop(context, text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _addTo(List<String> list, String title, String hint) async {
    final value = await _askText(
      title: title,
      label: hint,
      action: 'Adicionar',
    );
    if (value == null || value.isEmpty) return;

    if (_alreadyExists(list, value)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$value" já existe nesta categoria.')),
      );
      return;
    }

    setState(() => list.add(value));
  }

  Future<void> _editItem(
    List<String> list,
    int index,
    String title,
    String hint,
    Map<String, String> renameMap,
  ) async {
    final oldValue = list[index];
    final value = await _askText(
      title: title,
      label: hint,
      initial: oldValue,
    );
    if (value == null || value.isEmpty || value == oldValue) return;

    if (_alreadyExists(list, value, ignoreIndex: index)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$value" já existe nesta categoria.')),
      );
      return;
    }

    String originalValue = oldValue;
    for (final entry in renameMap.entries) {
      if (entry.value == oldValue) {
        originalValue = entry.key;
        break;
      }
    }
    renameMap.removeWhere((key, current) => current == oldValue && key != originalValue);
    renameMap[originalValue] = value;

    setState(() {
      list[index] = value;
      if (identical(list, skills)) skillAttributes = renameSkillInLinks(skillAttributes, oldValue, value);
      if (identical(list, attributes)) skillAttributes = renameAttributeInLinks(skillAttributes, oldValue, value);
    });
  }

  Future<void> _confirmDelete(List<String> list, int index, String type) async {
    final item = list[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Excluir $type?'),
        content: Text('"$item" será removido da estrutura do sistema. Dados já preenchidos em fichas antigas serão preservados internamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      list.removeAt(index);
      if (identical(list, skills)) skillAttributes = removeSkillFromLinks(skillAttributes, item);
      if (identical(list, attributes)) skillAttributes = removeAttributeFromLinks(skillAttributes, item);
    });
  }

  String? _skillAttributeSubtitle(String skill) {
    if (attributes.isEmpty) return null;
    final attribute = skillAttributes[skill];
    return attribute != null && attributes.contains(attribute) ? 'Atributo: $attribute' : 'Sem atributo';
  }

  Future<void> _pickSkillAttribute(int index) async {
    if (attributes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione atributos ao sistema para vincular perícias.')),
      );
      return;
    }
    final skill = skills[index];
    final current = skillAttributes[skill];
    // '' representa "Sem atributo"; null significa que a janela foi fechada.
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Atributo base de $skill'),
        children: [
          for (final option in ['', ...attributes])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option),
              child: Row(children: [
                Icon(
                  (option.isEmpty ? current == null || !attributes.contains(current) : current == option)
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(option.isEmpty ? 'Sem atributo' : option)),
              ]),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice.isEmpty) {
        skillAttributes = removeSkillFromLinks(skillAttributes, skill);
      } else {
        skillAttributes = {...skillAttributes, skill: choice};
      }
    });
  }

  void _reorder(List<String> list, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  Future<void> _applyStarterStructure(String type) async {
    final preset = switch (type) {
      'narrative' => <String, List<String>>{
          'attributes': ['Corpo', 'Mente', 'Presença'],
          'skills': ['Ação', 'Conhecimento', 'Influência', 'Percepção'],
          'resources': ['Vida', 'Energia'],
          'sections': ['História', 'Relações', 'Anotações'],
        },
      'd20' => <String, List<String>>{
          'attributes': ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'],
          'skills': ['Atletismo', 'Furtividade', 'Investigação', 'Percepção', 'Persuasão', 'Sobrevivência'],
          'resources': ['Vida', 'Energia'],
          'sections': ['Defesa', 'Proficiências', 'Traços', 'Anotações'],
        },
      _ => <String, List<String>>{
          'attributes': ['FOR', 'DES', 'CON', 'INT', 'SAB', 'CAR'],
          'skills': [],
          'resources': ['Vida', 'Energia'],
          'sections': ['História', 'Traços', 'Anotações'],
        },
    };
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aplicar estrutura inicial?'),
        content: const Text('Isso substitui atributos, perícias, recursos e seções que estão no editor. Nada é salvo até você tocar em Salvar sistema.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (replace != true) return;
    setState(() {
      attributes = [...preset['attributes']!];
      skills = [...preset['skills']!];
      resources = [...preset['resources']!];
      sections = [...preset['sections']!];
      skillAttributes = pruneSkillAttributes(skills: skills, attributes: attributes, links: skillAttributes);
      _attributeRenames.clear();
      _skillRenames.clear();
      _resourceRenames.clear();
      _sectionRenames.clear();
    });
  }

  Future<void> _showStructurePresets() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Estruturas iniciais', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Comece com uma base e personalize cada parte depois.'),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.public), title: const Text('Padrão flexível'), subtitle: const Text('6 atributos • Vida e Energia • estrutura genérica'), onTap: () => Navigator.pop(sheetContext, 'standard')),
            ListTile(leading: const Icon(Icons.casino_outlined), title: const Text('Base d20'), subtitle: const Text('6 atributos clássicos • perícias essenciais • defesa e traços'), onTap: () => Navigator.pop(sheetContext, 'd20')),
            ListTile(leading: const Icon(Icons.menu_book_outlined), title: const Text('Narrativo'), subtitle: const Text('3 atributos • poucas perícias • foco em história e relações'), onTap: () => Navigator.pop(sheetContext, 'narrative')),
          ]),
        ),
      ),
    );
    if (selected != null && mounted) await _applyStarterStructure(selected);
  }

  Future<void> _save() async {
    final cleanName = name.text.trim();
    if (cleanName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para o sistema.')),
      );
      return;
    }

    final updated = RpgSystem(
      id: widget.system.id,
      name: cleanName,
      description: description.text.trim(),
      attributes: attributes,
      skills: skills,
      resources: resources,
      sections: sections,
      dice: dice,
      skillAttributes: pruneSkillAttributes(skills: skills, attributes: attributes, links: skillAttributes),
    );

    await context.read<AppState>().updateSystem(
          updated,
          attributeRenames: _attributeRenames,
          skillRenames: _skillRenames,
          resourceRenames: _resourceRenames,
          sectionRenames: _sectionRenames,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sistema salvo. Fichas vinculadas foram atualizadas.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = attributes.length + skills.length + resources.length + sections.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.system.id == 'generic' ? 'Sistema Padrão' : 'Editar sistema'),
        actions: [
          IconButton(
            onPressed: _save,
            tooltip: 'Salvar',
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_tree_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Estrutura do sistema', style: Theme.of(context).textTheme.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CountChip(label: 'Atributos', value: attributes.length),
                      _CountChip(label: 'Perícias', value: skills.length),
                      _CountChip(label: 'Recursos', value: resources.length),
                      _CountChip(label: 'Seções', value: sections.length),
                      _CountChip(label: 'Dados', value: dice.length),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('$totalItems elementos estruturais configurados.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(textCapitalization: TextCapitalization.sentences, 
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Nome do sistema',
              prefixIcon: Icon(Icons.auto_awesome),
            ),
          ),
          const SizedBox(height: 12),
          TextField(textCapitalization: TextCapitalization.sentences, 
            controller: description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          const _BuilderHint(),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Estrutura inicial'),
              subtitle: const Text('Aplicar uma base Padrão, d20 ou Narrativa e continuar personalizando.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showStructurePresets,
            ),
          ),
          const SizedBox(height: 10),
          _EditorSection(
            title: 'Atributos',
            icon: Icons.bar_chart,
            description: 'Características principais do personagem.',
            items: attributes,
            onAdd: () => _addTo(attributes, 'Novo atributo', 'Ex.: Força'),
            onEdit: (i) => _editItem(attributes, i, 'Editar atributo', 'Nome do atributo', _attributeRenames),
            onDelete: (i) => _confirmDelete(attributes, i, 'atributo'),
            onReorder: (a, b) => _reorder(attributes, a, b),
          ),
          _EditorSection(
            title: 'Perícias',
            icon: Icons.psychology,
            description: 'Perícias ou competências que o sistema utiliza.',
            items: skills,
            onAdd: () => _addTo(skills, 'Nova perícia', 'Ex.: Furtividade'),
            onEdit: (i) => _editItem(skills, i, 'Editar perícia', 'Nome da perícia', _skillRenames),
            onDelete: (i) => _confirmDelete(skills, i, 'perícia'),
            onReorder: (a, b) => _reorder(skills, a, b),
            subtitleFor: _skillAttributeSubtitle,
            onTapItem: _pickSkillAttribute,
          ),
          _EditorSection(
            title: 'Recursos',
            icon: Icons.favorite,
            description: 'Recursos como Vida, Mana, Sanidade ou Estamina.',
            items: resources,
            onAdd: () => _addTo(resources, 'Novo recurso', 'Ex.: Sanidade'),
            onEdit: (i) => _editItem(resources, i, 'Editar recurso', 'Nome do recurso', _resourceRenames),
            onDelete: (i) => _confirmDelete(resources, i, 'recurso'),
            onReorder: (a, b) => _reorder(resources, a, b),
          ),
          _EditorSection(
            title: 'Seções da ficha',
            icon: Icons.view_agenda,
            description: 'Áreas personalizadas exibidas na aba Seções.',
            items: sections,
            onAdd: () => _addTo(sections, 'Nova seção', 'Ex.: Magias'),
            onEdit: (i) => _editItem(sections, i, 'Editar seção', 'Nome da seção', _sectionRenames),
            onDelete: (i) => _confirmDelete(sections, i, 'seção'),
            onReorder: (a, b) => _reorder(sections, a, b),
          ),
          _DiceEditorSection(
            dice: dice,
            onDefaults: () => setState(() => dice = [4, 6, 8, 10, 12, 20, 100]),
            onClear: () => setState(dice.clear),
            onAdd: () async {
              final controller = TextEditingController();
              final value = await showDialog<int>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Novo dado'),
                  content: TextField(textCapitalization: TextCapitalization.sentences, 
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Número de faces', hintText: 'Ex.: 20'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('Adicionar')),
                  ],
                ),
              );
              controller.dispose();
              if (value != null && value >= 2 && value <= 1000 && !dice.contains(value)) {
                setState(() {
                  dice.add(value);
                  dice.sort();
                });
              }
            },
            onDelete: (i) => setState(() => dice.removeAt(i)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Salvar sistema'),
          ),
        ],
      ),
    );
  }
}

class _BuilderHint extends StatelessWidget {
  const _BuilderHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_outlined, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text('Use o lápis para renomear. Arraste pelo indicador para reorganizar a ordem exibida na ficha.'),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int value;

  const _CountChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text('$value')),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DiceEditorSection extends StatelessWidget {
  final List<int> dice;
  final VoidCallback onAdd;
  final VoidCallback onDefaults;
  final VoidCallback onClear;
  final ValueChanged<int> onDelete;

  const _DiceEditorSection({required this.dice, required this.onAdd, required this.onDefaults, required this.onClear, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.casino),
            const SizedBox(width: 10),
            Expanded(child: Text('Dados', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(onPressed: onAdd, tooltip: 'Adicionar dado', icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Text('Defina quais dados aparecem para este sistema na tela de rolagem.'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            TextButton.icon(onPressed: onDefaults, icon: const Icon(Icons.restart_alt, size: 18), label: const Text('Dados padrão')),
            TextButton.icon(onPressed: dice.isEmpty ? null : onClear, icon: const Icon(Icons.clear_all, size: 18), label: const Text('Limpar')),
          ]),
          const SizedBox(height: 4),
          if (dice.isEmpty)
            const Text('Nenhum dado configurado. Os dados padrão serão usados.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dice.asMap().entries.map((entry) {
                return InputChip(
                  label: Text('d${entry.value}'),
                  onDeleted: () => onDelete(entry.key),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final String? Function(String item)? subtitleFor;
  final ValueChanged<int>? onTapItem;

  const _EditorSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    this.subtitleFor,
    this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon),
        title: Row(
          children: [
            Expanded(child: Text(title)),
            Badge(label: Text('${items.length}')),
          ],
        ),
        subtitle: Text(description),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum item configurado.'),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final item = items[index];
                final subtitle = subtitleFor?.call(item);
                return ListTile(
                  key: ValueKey('$title-$item-$index'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator, size: 22),
                    ),
                  ),
                  title: Text(item),
                  subtitle: subtitle == null ? null : Text(subtitle),
                  onTap: onTapItem == null ? null : () => onTapItem!(index),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        tooltip: 'Renomear',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEdit(index),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ),
        ],
      ),
    );
  }
}
