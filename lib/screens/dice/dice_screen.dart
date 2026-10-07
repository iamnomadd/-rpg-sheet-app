import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/character.dart';
import '../../services/app_state.dart';

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen> {
  int sides = 20;
  int count = 1;
  int modifier = 0;
  String mode = 'normal';
  String? selectedSystemId;
  String? selectedCharacterId;
  String? selectedAttribute;
  late TextEditingController expressionController;
  late TextEditingController modifierController;
  Map<String, dynamic>? lastRoll;
  bool historyCompact = true;

  @override
  void initState() {
    super.initState();
    expressionController = TextEditingController(text: '1d20');
    modifierController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    expressionController.dispose();
    modifierController.dispose();
    super.dispose();
  }

  List<int> _availableDice(AppState state) {
    if (selectedSystemId == null) return [4, 6, 8, 10, 12, 20, 100];
    final matches = state.systems.where((s) => s.id == selectedSystemId);
    final system = matches.isEmpty ? null : matches.first;
    return system != null && system.dice.isNotEmpty
        ? system.dice
        : [4, 6, 8, 10, 12, 20, 100];
  }

  Character? _selectedCharacter(AppState state) {
    final matches = state.characters.where((c) => c.id == selectedCharacterId);
    return matches.isEmpty ? null : matches.first;
  }

  int get _effectiveModifier => modifier;

  void _syncExpression() {
    expressionController.text =
        '${count}d$sides${modifier == 0 ? '' : modifier > 0 ? '+$modifier' : '$modifier'}';
  }

  void _setRoll({
    required int newSides,
    required int newCount,
    required int newModifier,
    required String newMode,
  }) {
    setState(() {
      sides = newSides;
      count = newCount.clamp(1, 100);
      modifier = newModifier;
      mode = ['normal', 'advantage', 'disadvantage'].contains(newMode)
          ? newMode
          : 'normal';
      modifierController.text = '$modifier';
      _syncExpression();
    });
  }

  void _parseExpression() {
    final value = expressionController.text.trim().toLowerCase().replaceAll(' ', '');
    final match = RegExp(r'^(\d*)d(\d+)([+-]\d+)?$').firstMatch(value);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use uma expressão como 2d6+3.')),
      );
      return;
    }
    final parsedCount =
        int.tryParse(match.group(1)?.isEmpty == true ? '1' : match.group(1)!) ?? 1;
    final parsedSides = int.tryParse(match.group(2)!) ?? 20;
    final parsedModifier = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (parsedCount < 1 || parsedCount > 100 || parsedSides < 2 || parsedSides > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade: 1–100. Faces: 2–1000.')),
      );
      return;
    }
    _setRoll(
      newSides: parsedSides,
      newCount: parsedCount,
      newModifier: parsedModifier,
      newMode: mode,
    );
    _roll();
  }

  void _roll() {
    final result = context.read<AppState>().rollAdvanced(
          sides: sides,
          count: count,
          modifier: _effectiveModifier,
          mode: mode,
        );
    setState(() => lastRoll = result);
  }

  String _modeLabel([String? value]) {
    switch (value ?? mode) {
      case 'advantage':
        return 'Vantagem';
      case 'disadvantage':
        return 'Desvantagem';
      default:
        return 'Normal';
    }
  }

  Future<void> _savePreset() async {
    final controller = TextEditingController(text: expressionController.text);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar rolagem'),
        content: TextField(textCapitalization: TextCapitalization.sentences, 
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do atalho',
            hintText: 'Ex.: Ataque, Dano, Teste de força',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<AppState>().saveRollPreset(
          name: name,
          sides: sides,
          count: count,
          modifier: modifier,
          mode: mode,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rolagem salva nos favoritos.')),
      );
    }
  }

  void _applyAttribute(AppState state, String? attribute) {
    final character = _selectedCharacter(state);
    if (character == null || attribute == null) return;
    final value = character.attributes[attribute] ?? 0;
    setState(() {
      selectedAttribute = attribute;
      modifier = value;
      modifierController.text = '$value';
      _syncExpression();
    });
  }

  void _applyDamageExpression(String damage) {
    final value = damage.trim().toLowerCase().replaceAll(' ', '');
    final match = RegExp(r'^(\d*)d(\d+)([+-]\d+)?$').firstMatch(value);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O dano precisa estar no formato 1d8, 2d6+3, etc.')));
      return;
    }
    _setRoll(
      newSides: int.tryParse(match.group(2)!) ?? 20,
      newCount: int.tryParse(match.group(1)?.isEmpty == true ? '1' : match.group(1)!) ?? 1,
      newModifier: int.tryParse(match.group(3) ?? '0') ?? 0,
      newMode: 'normal',
    );
    _roll();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dice = _availableDice(state);
    if (!dice.contains(sides) && sides <= 1000) {
      sides = dice.isNotEmpty ? dice.first : 20;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncExpression();
      });
    }
    final selectedCharacter = _selectedCharacter(state);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Dados e Rolagens')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withOpacity(.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${lastRoll?['result'] ?? '—'}',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Último resultado', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          if (lastRoll == null)
                            const Text('Faça uma rolagem para começar.')
                          else ...[
                            Text('${lastRoll!['expression']} • ${_modeLabel(lastRoll!['mode']?.toString())}'),
                            Text(
                              'Dados: ${(lastRoll!['rolls'] as List).join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Atalhos rápidos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                if (state.savedRolls.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_outline, size: 17),
                      const SizedBox(width: 4),
                      Text('${state.savedRolls.length} favorito(s)', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final preset in const [
                    [20, 1, 0, '1d20'],
                    [6, 2, 0, '2d6'],
                    [8, 1, 0, '1d8'],
                    [10, 1, 0, '1d10'],
                    [100, 1, 0, '1d100'],
                  ]) ...[
                    ActionChip(
                      avatar: const Icon(Icons.casino_outlined, size: 17),
                      label: Text(preset[3] as String),
                      onPressed: () {
                        _setRoll(
                          newSides: preset[0] as int,
                          newCount: preset[1] as int,
                          newModifier: preset[2] as int,
                          newMode: 'normal',
                        );
                        _roll();
                      },
                    ),
                    const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Rolagem personalizada', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                        Text(expressionController.text, style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: selectedSystemId,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Sistema de RPG',
                        prefixIcon: Icon(Icons.auto_awesome, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Dados padrão')),
                        ...state.systems.map(
                          (system) => DropdownMenuItem<String?>(value: system.id, child: Text(system.name)),
                        ),
                      ],
                      onChanged: (value) => setState(() => selectedSystemId = value),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final d in dice) ...[
                            ChoiceChip(
                              label: Text('d$d'),
                              selected: sides == d,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {
                                setState(() => sides = d);
                                _syncExpression();
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: count.clamp(1, 100) as int,
                            isDense: true,
                            decoration: const InputDecoration(labelText: 'Quantidade'),
                            items: List.generate(100, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                            onChanged: (value) {
                              setState(() => count = value ?? 1);
                              _syncExpression();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(textCapitalization: TextCapitalization.sentences, 
                            controller: modifierController,
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            decoration: const InputDecoration(labelText: 'Modificador'),
                            onChanged: (value) {
                              modifier = int.tryParse(value) ?? 0;
                              _syncExpression();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'normal', label: Text('Normal')),
                        ButtonSegment(value: 'advantage', label: Text('Vant.')),
                        ButtonSegment(value: 'disadvantage', label: Text('Desvant.')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (value) => setState(() => mode = value.first),
                    ),
                    const SizedBox(height: 8),
                    TextField(textCapitalization: TextCapitalization.sentences, 
                      controller: expressionController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _parseExpression(),
                      decoration: InputDecoration(
                        labelText: 'Expressão',
                        hintText: '2d6+3',
                        suffixIcon: IconButton(icon: const Icon(Icons.play_arrow), onPressed: _parseExpression),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _roll,
                            icon: const Icon(Icons.casino),
                            label: const Text('Rolar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _savePreset,
                          icon: const Icon(Icons.star_border),
                          label: const Text('Salvar'),
                        ),
                      ],
                    ),
                    if (lastRoll != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withOpacity(.38),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.primary.withOpacity(.22)),
                        ),
                        child: Row(
                          children: [
                            Text('Resultado', style: Theme.of(context).textTheme.labelLarge),
                            const Spacer(),
                            Text('${lastRoll!['result']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                (lastRoll!['rolls'] as List).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Rolar com ficha'),
                subtitle: selectedCharacter == null
                    ? const Text('Opcional: use um atributo como modificador.')
                    : Text(selectedCharacter.name),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  DropdownButtonFormField<String?>(
                    value: selectedCharacterId,
                    decoration: const InputDecoration(labelText: 'Personagem'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Nenhum personagem')),
                      ...state.characters.map(
                        (character) => DropdownMenuItem<String?>(value: character.id, child: Text(character.name)),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCharacterId = value;
                        selectedAttribute = null;
                      });
                    },
                  ),
                  if (selectedCharacter != null && selectedCharacter.attributes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedAttribute,
                      decoration: const InputDecoration(labelText: 'Atributo como modificador'),
                      items: selectedCharacter.attributes.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text('${entry.key} (${entry.value >= 0 ? '+' : ''}${entry.value})'),
                              ))
                          .toList(),
                      onChanged: (value) => _applyAttribute(state, value),
                    ),
                  ],
                  if (selectedCharacter != null) ...[
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: Text('Atalhos da ficha', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ...selectedCharacter.inventory.where((name) {
                          final d = selectedCharacter.inventoryDetails[name] ?? const <String, dynamic>{};
                          return d['category'] == 'Arma' && d['damage']?.toString().trim().isNotEmpty == true;
                        }).map((name) => ActionChip(
                          avatar: const Icon(Icons.gps_fixed, size: 16),
                          label: Text(name),
                          tooltip: 'Rolar dano da arma',
                          onPressed: () => _applyDamageExpression(selectedCharacter.inventoryDetails[name]?['damage']?.toString() ?? ''),
                        )),
                        ...selectedCharacter.abilities.where((name) {
                          final d = selectedCharacter.abilityDetails[name] ?? const <String, dynamic>{};
                          return d['damage']?.toString().trim().isNotEmpty == true;
                        }).map((name) => ActionChip(
                          avatar: const Icon(Icons.bolt_outlined, size: 16),
                          label: Text(name),
                          tooltip: 'Rolar dano da habilidade',
                          onPressed: () => _applyDamageExpression(selectedCharacter.abilityDetails[name]?['damage']?.toString() ?? ''),
                        )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (state.savedRolls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Favoritos'),
                  subtitle: Text('${state.savedRolls.length} rolagem(ns) salva(s)'),
                  children: [
                    ...state.savedRolls.map(
                      (preset) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.star, size: 20),
                        title: Text(preset['name']?.toString() ?? 'Rolagem salva'),
                        subtitle: Text(
                          '${preset['count']}d${preset['sides']}${(preset['modifier'] as int? ?? 0) == 0 ? '' : (preset['modifier'] as int) > 0 ? ' + ${preset['modifier']}' : ' - ${(preset['modifier'] as int).abs()}'} • ${_modeLabel(preset['mode']?.toString())}',
                        ),
                        onTap: () {
                          _setRoll(
                            newSides: preset['sides'] as int? ?? 20,
                            newCount: preset['count'] as int? ?? 1,
                            newModifier: preset['modifier'] as int? ?? 0,
                            newMode: preset['mode']?.toString() ?? 'normal',
                          );
                          _roll();
                        },
                        trailing: IconButton(
                          tooltip: 'Excluir favorito',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => state.deleteRollPreset(preset['id']?.toString() ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text('Histórico', style: Theme.of(context).textTheme.titleLarge)),
                if (state.diceHistory.isNotEmpty) ...[
                  IconButton(
                    tooltip: historyCompact ? 'Mostrar mais' : 'Mostrar menos',
                    onPressed: () => setState(() => historyCompact = !historyCompact),
                    icon: Icon(historyCompact ? Icons.unfold_more : Icons.unfold_less),
                  ),
                  TextButton(onPressed: state.clearDiceHistory, child: const Text('Limpar')),
                ],
              ],
            ),
            if (state.diceHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhuma rolagem registrada.'),
              )
            else
              ...state.diceHistory.take(historyCompact ? 10 : 30).map(
                (entry) => Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 20),
                    title: Text('${entry['expression']} = ${entry['result']}'),
                    subtitle: Text(
                      'Dados: ${(entry['rolls'] as List).join(', ')}${entry['mode'] == 'normal' ? '' : ' • ${_modeLabel(entry['mode']?.toString())}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Repetir rolagem',
                      icon: const Icon(Icons.replay),
                      onPressed: () {
                        _setRoll(
                          newSides: entry['sides'] as int? ?? 20,
                          newCount: entry['count'] as int? ?? 1,
                          newModifier: entry['modifier'] as int? ?? 0,
                          newMode: entry['mode']?.toString() ?? 'normal',
                        );
                        _roll();
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
