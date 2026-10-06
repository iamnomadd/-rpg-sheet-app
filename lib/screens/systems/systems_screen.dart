import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/rpg_file_service.dart';
import 'system_editor_screen.dart';

class SystemsScreen extends StatefulWidget {
  const SystemsScreen({super.key});

  @override
  State<SystemsScreen> createState() => _SystemsScreenState();
}

class _SystemsScreenState extends State<SystemsScreen> {
  bool _busy = false;

  Future<void> _addSystem(BuildContext context) async {
    final system = RpgSystem(
      id: const Uuid().v4(),
      name: 'Novo Sistema',
      description: 'Sistema personalizado.',
      attributes: ['FOR', 'DES', 'CON'],
      skills: [],
      resources: ['Vida'],
      sections: ['Resumo', 'História'],
    );

    await context.read<AppState>().addSystem(system);

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SystemEditorScreen(system: system)),
    );
  }

  Future<void> _createFromTemplate(
    BuildContext context,
    _SystemTemplate template,
  ) async {
    final state = context.read<AppState>();
    var name = template.name;
    var counter = 2;
    while (state.systems.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      name = '${template.name} ($counter)';
      counter++;
    }

    final system = RpgSystem(
      id: const Uuid().v4(),
      name: name,
      description: template.description,
      attributes: List<String>.from(template.attributes),
      skills: List<String>.from(template.skills),
      resources: List<String>.from(template.resources),
      sections: List<String>.from(template.sections),
      dice: List<int>.from(template.dice),
    );

    await state.addSystem(system);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SystemEditorScreen(system: system)),
    );
  }

  Future<void> _showTemplates(BuildContext context) async {
    final selected = await showModalBottomSheet<_SystemTemplate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Biblioteca de modelos',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Use um modelo como ponto de partida e altere tudo depois no construtor.',
              ),
              const SizedBox(height: 16),
              ..._templates.map(
                (template) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(template.icon)),
                    title: Text(template.name),
                    subtitle: Text(
                      '${template.description}\n'
                      '${template.attributes.length} atributos • '
                      '${template.skills.length} perícias • '
                      '${template.resources.length} recursos',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => Navigator.pop(sheetContext, template),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && context.mounted) {
      await _createFromTemplate(context, selected);
    }
  }

  Future<void> _importSystem(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final imported = await RpgFileService.importSystemOnly(context.read<AppState>());
      if (!mounted || imported == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sistema "${imported.name}" importado.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível importar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSystem(BuildContext context, RpgSystem system) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await RpgFileService.exportSystem(system);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _duplicate(BuildContext context, RpgSystem system) async {
    final copy = await context.read<AppState>().duplicateSystem(system.id);
    if (!context.mounted || copy == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${copy.name}" criado.')),
    );
  }

  void _openEditor(BuildContext context, RpgSystem system) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SystemEditorScreen(system: system)),
    );
  }

  bool _isBuiltIn(String id) => const {'generic', 'dnd5e', 'tormenta20', 'ordem_paranormal', 'shadowdark'}.contains(id);

  String _systemFocus(String id) => switch (id) {
    'dnd5e' => 'D20 • perícias • PV temporários • inspiração',
    'tormenta20' => 'PV e PM • perícias • poderes e magias',
    'ordem_paranormal' => 'PV, PE e Sanidade • NEX • rituais',
    'shadowdark' => 'Ficha enxuta • PV • talentos • luz',
    'generic' => 'Estrutura livre • Vida e Energia',
    _ => 'Sistema personalizado',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sistemas de RPG'),
          actions: [
            IconButton(
              onPressed: () => _addSystem(context),
              icon: const Icon(Icons.add),
              tooltip: 'Criar sistema',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tune, size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Construtor de sistemas',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Crie do zero, use um modelo pronto, duplique um sistema ou importe um arquivo .rpg.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _showTemplates(context),
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('Modelos'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _importSystem(context),
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Importar .rpg'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Meus sistemas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...state.systems.map(
              (system) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      system.id == 'generic' ? Icons.public : Icons.auto_awesome,
                    ),
                  ),
                  title: Text(system.name),
                  subtitle: Text(
                    '${_isBuiltIn(system.id) ? 'Preset oficial do app' : 'Sistema personalizado'}\n'
                    '${_systemFocus(system.id)}\n'
                    '${system.attributes.length} atributos • ${system.skills.length} perícias • ${system.resources.length} recursos',
                  ),
                  isThreeLine: true,
                  onTap: () => _openEditor(context, system),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opções do sistema',
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          _openEditor(context, system);
                          break;
                        case 'duplicate':
                          await _duplicate(context, system);
                          break;
                        case 'export':
                          await _exportSystem(context, system);
                          break;
                        case 'delete':
                          await _confirmDelete(context, system);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplicar'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.ios_share_outlined),
                          title: Text('Exportar .rpg'),
                        ),
                      ),
                      if (system.id != 'generic')
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Excluir'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RpgSystem system) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir sistema?'),
        content: Text(
          'O sistema "${system.name}" será removido. Personagens existentes não serão apagados.',
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

    if (confirmed == true && context.mounted) {
      final deleted = await context.read<AppState>().deleteSystem(system.id);
      if (!deleted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este sistema está sendo usado por uma ou mais fichas e não pode ser excluído.'),
          ),
        );
      }
    }
  }
}

class _SystemTemplate {
  final String name;
  final String description;
  final IconData icon;
  final List<String> attributes;
  final List<String> skills;
  final List<String> resources;
  final List<String> sections;
  final List<int> dice;

  const _SystemTemplate({
    required this.name,
    required this.description,
    required this.icon,
    required this.attributes,
    required this.skills,
    required this.resources,
    required this.sections,
    this.dice = const [4, 6, 8, 10, 12, 20, 100],
  });
}

const _templates = <_SystemTemplate>[
  _SystemTemplate(
    name: 'D&D 5e',
    description: 'Atributos, perícias e áreas de ficha estruturadas para D&D 5e.',
    icon: Icons.shield_outlined,
    attributes: ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'],
    skills: ['Acrobacia', 'Arcanismo', 'Atletismo', 'Atuação', 'Enganação', 'Furtividade', 'História', 'Intimidação', 'Intuição', 'Investigação', 'Lidar com Animais', 'Medicina', 'Natureza', 'Percepção', 'Persuasão', 'Prestidigitação', 'Religião', 'Sobrevivência'],
    resources: ['Vida', 'PV Temporários', 'Inspiração'],
    sections: ['Classe e Subclasse', 'Antecedente', 'CA e Iniciativa', 'Salvaguardas', 'Dados de Vida', 'Testes contra Morte', 'Proficiências e Idiomas', 'Magias', 'Traços', 'Anotações'],
  ),
  _SystemTemplate(
    name: 'Tormenta20',
    description: 'PV, PM, seis atributos, perícias e áreas características de Tormenta20.',
    icon: Icons.auto_awesome,
    attributes: ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'],
    skills: ['Acrobacia', 'Adestramento', 'Atletismo', 'Atuação', 'Cavalgar', 'Conhecimento', 'Cura', 'Diplomacia', 'Enganação', 'Fortitude', 'Furtividade', 'Guerra', 'Iniciativa', 'Intimidação', 'Intuição', 'Investigação', 'Jogatina', 'Ladinagem', 'Luta', 'Misticismo', 'Nobreza', 'Ofício', 'Percepção', 'Pilotagem', 'Pontaria', 'Reflexos', 'Religião', 'Sobrevivência', 'Vontade'],
    resources: ['PV', 'PM'],
    sections: ['Origem', 'Raça', 'Classe', 'Defesa', 'Deslocamento', 'Proficiências', 'Poderes', 'Magias', 'Anotações'],
  ),
  _SystemTemplate(
    name: 'Ordem Paranormal',
    description: 'Ficha de agente com cinco atributos, PV, PE, Sanidade e perícias.',
    icon: Icons.visibility_outlined,
    attributes: ['Agilidade', 'Intelecto', 'Vigor', 'Presença', 'Força'],
    skills: ['Acrobacia', 'Adestramento', 'Artes', 'Atletismo', 'Atualidades', 'Ciências', 'Crime', 'Diplomacia', 'Enganação', 'Fortitude', 'Furtividade', 'Iniciativa', 'Intimidação', 'Intuição', 'Investigação', 'Luta', 'Medicina', 'Ocultismo', 'Percepção', 'Pilotagem', 'Pontaria', 'Profissão', 'Reflexos', 'Religião', 'Sobrevivência', 'Tática', 'Tecnologia', 'Vontade'],
    resources: ['PV', 'PE', 'Sanidade'],
    sections: ['Origem', 'Classe e Trilha', 'NEX', 'Defesa', 'Deslocamento', 'Proteção e Resistências', 'Rituais', 'Poderes', 'Anotações'],
  ),
  _SystemTemplate(
    name: 'Shadowdark',
    description: 'Estrutura enxuta com seis atributos, PV, CA, talentos, magia e controle de luz.',
    icon: Icons.dark_mode_outlined,
    attributes: ['FOR', 'DES', 'CON', 'INT', 'SAB', 'CAR'],
    skills: [],
    resources: ['PV'],
    sections: ['Classe', 'Ancestralidade', 'CA', 'Iniciativa', 'Talentos', 'Magias', 'Equipamento', 'Tochas e Luz', 'Anotações'],
  ),
  _SystemTemplate(
    name: 'Sistema Padrão',
    description: 'Modelo genérico e flexível do RPG Sheet.',
    icon: Icons.public,
    attributes: ['FOR', 'DES', 'CON', 'INT', 'SAB', 'CAR'],
    skills: [],
    resources: ['Vida', 'Energia'],
    sections: ['História', 'Traços', 'Anotações'],
  ),
];

