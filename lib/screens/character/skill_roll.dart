import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';

/// Atributo vinculado à perícia, se ele ainda existir no sistema; senão null.
String? resolveSkillRoll(RpgSystem system, Character character, String skillName) {
  final attribute = system.skillAttributes[skillName];
  if (attribute == null || !system.attributes.contains(attribute)) return null;
  return attribute;
}

/// Texto do resultado, ex.: "d20 (14) + Destreza (3) = 17".
/// Com vantagem/desvantagem mostra os dois dados: "d20 (14, 9 · vantagem) + …".
String skillRollDetail({
  required String? attribute,
  required int attributeValue,
  required List<int> rolls,
  required String mode,
  required int total,
}) {
  final modeLabel = switch (mode) {
    'advantage' => 'vantagem',
    'disadvantage' => 'desvantagem',
    _ => '',
  };
  final dice = modeLabel.isEmpty ? rolls.join(', ') : '${rolls.join(', ')} · $modeLabel';
  final bonus = attribute == null ? '' : ' + $attribute ($attributeValue)';
  return 'd20 ($dice)$bonus = $total';
}

/// Escolha feita na folha de rolagem: atributo (null = sem atributo) e modo.
class SkillRollChoice {
  final String? attribute;
  final String mode;

  const SkillRollChoice({required this.attribute, required this.mode});
}

/// Folha para escolher o atributo e o modo da rolagem de uma perícia.
Future<SkillRollChoice?> showSkillRollSheet(
  BuildContext context, {
  required RpgSystem system,
  required Character character,
  required String skillName,
}) {
  return showModalBottomSheet<SkillRollChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SkillRollSheet(
      system: system,
      character: character,
      skillName: skillName,
      initialAttribute: resolveSkillRoll(system, character, skillName),
    ),
  );
}

/// Rola d20 + valor do atributo (o valor entra direto como modificador, como em
/// "Rolar com ficha"), grava no histórico com o nome da perícia e mostra o
/// resultado numa SnackBar.
Map<String, dynamic> rollSkill(
  BuildContext context, {
  required Character character,
  required String skillName,
  String? attribute,
  String mode = 'normal',
}) {
  final value = attribute == null ? 0 : (character.attributes[attribute] ?? 0);
  final entry = context.read<AppState>().rollAdvanced(sides: 20, modifier: value, mode: mode, label: skillName);
  final detail = skillRollDetail(
    attribute: attribute,
    attributeValue: value,
    rolls: List<int>.from(entry['rolls'] as List),
    mode: mode,
    total: entry['result'] as int,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$skillName: $detail')));
  return entry;
}

class _SkillRollSheet extends StatefulWidget {
  final RpgSystem system;
  final Character character;
  final String skillName;
  final String? initialAttribute;

  const _SkillRollSheet({
    required this.system,
    required this.character,
    required this.skillName,
    required this.initialAttribute,
  });

  @override
  State<_SkillRollSheet> createState() => _SkillRollSheetState();
}

class _SkillRollSheetState extends State<_SkillRollSheet> {
  late String? _attribute = widget.initialAttribute;
  String _mode = 'normal';

  Widget _option(String? attribute) {
    final selected = _attribute == attribute;
    final value = attribute == null ? null : widget.character.attributes[attribute] ?? 0;
    return ListTile(
      dense: true,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
      title: Text(attribute ?? 'Sem atributo'),
      trailing: value == null ? null : Text('$value'),
      selected: selected,
      onTap: () => setState(() => _attribute = attribute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rolar ${widget.skillName}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'normal', label: Text('Normal')),
                  ButtonSegment(value: 'advantage', label: Text('Vantagem')),
                  ButtonSegment(value: 'disadvantage', label: Text('Desvantagem')),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() => _mode = value.first),
              ),
              const SizedBox(height: 8),
              Text('Atributo', style: Theme.of(context).textTheme.labelLarge),
              _option(null),
              for (final attribute in widget.system.attributes) _option(attribute),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Rolar'),
                onPressed: () => Navigator.pop(context, SkillRollChoice(attribute: _attribute, mode: _mode)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
