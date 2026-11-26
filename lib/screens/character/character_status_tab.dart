part of 'character_screen.dart';

/// Aplica os valores da folha do recurso na ficha, com o máximo em [0, 999999]
/// e o atual em [0, máximo]. Vida e Energia também atualizam hp/maxHp e
/// energy/maxEnergy.
void _applyResourceValues(Character c, String name, ResourceValues values) {
  final newMax = values.max.clamp(0, 999999);
  c.resourceMaxValues[name] = newMax;
  c.resourceValues[name] = values.current.clamp(0, newMax);
  if (name.toLowerCase() == 'vida') { c.maxHp = newMax; c.hp = c.resourceValues[name]!; }
  if (name.toLowerCase() == 'energia') { c.maxEnergy = newMax; c.energy = c.resourceValues[name]!; }
}

class _AttributesResourcesTab extends StatelessWidget {
  final Character character;
  final RpgSystem system;
  final Future<void> Function(Character, String) onEditAttribute;
  final Future<void> Function(Character, String, int) onChangeResource;
  final Future<void> Function(Character, String) onEditResource;

  const _AttributesResourcesTab({
    required this.character,
    required this.system,
    required this.onEditAttribute,
    required this.onChangeResource,
    required this.onEditResource,
  });

  @override
  Widget build(BuildContext context) {
    final themeId = context.watch<AppState>().themeId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            ThemedSectionIcon(themeId, 'attributes', size: 22),
            const SizedBox(width: 8),
            Text('Atributos', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 10),
        if (system.attributes.isEmpty)
          const Text('Este sistema não possui atributos configurados.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: system.attributes.length,
            gridDelegate: abyssAttributeGridDelegate(context),
            itemBuilder: (_, index) {
              final name = system.attributes[index];
              final value = character.attributes[name] ?? 0;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onEditAttribute(character, name),
                  child: Padding(
                    padding: abyssCardInset,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 0),
                        Text(
                          '$value',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(themedIcon(themeId, 'resources')),
            const SizedBox(width: 8),
            Text('Recursos', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 10),
        if (system.resources.isEmpty)
          const Text('Este sistema não possui recursos configurados.'),
        ...system.resources.map((name) {
          final value = character.resourceValues[name] ?? 0;
          final max = character.resourceMaxValues[name] ?? 0;
          final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
          return Card(
            margin: cardSpacingMargin,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      ThemedResourceIcon(themeId, name, fallbackIcon: name.toLowerCase() == 'vida'
                          ? themedIcon(themeId, 'resources')
                          : Icons.bolt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () => onChangeResource(character, name, -1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$value / $max'),
                      IconButton(
                        onPressed: () => onChangeResource(character, name, 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  ResourceBarTapTarget(
                    label: name,
                    onTap: () => onEditResource(character, name),
                    child: _ThemedResourceBar(
                      value: progress,
                      themeId: themeId,
                      secondary: name.toLowerCase() != 'vida',
                      resourceName: name,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ThemedResourceBar extends StatelessWidget {
  final double value;
  final String themeId;
  final bool secondary;

  /// Nome do recurso (só para a cor da barra no Abissal).
  final String resourceName;

  const _ThemedResourceBar({
    required this.value,
    required this.themeId,
    this.secondary = false,
    this.resourceName = '',
  });

  @override
  Widget build(BuildContext context) {
    return AbyssResourceBar(value: value, secondary: secondary, colors: abyssResourceBarColors(resourceName));
  }
}
