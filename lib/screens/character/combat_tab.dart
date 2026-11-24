import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/abyss_theme.dart';
import '../../app/theme.dart';
import '../../models/character.dart';
import '../../models/rpg_system.dart';
import '../../services/app_state.dart';
import '../../services/local_image_provider.dart';
import '../../utils/spell_icon.dart';

class CombatTab extends StatefulWidget {
  final Character character;
  final RpgSystem system;

  const CombatTab({super.key, required this.character, required this.system});

  @override
  State<CombatTab> createState() => _CombatTabState();
}

class _CombatTabState extends State<CombatTab> with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  bool _reaction = false;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  String _lifeResourceName() {
    for (final name in widget.system.resources) {
      if (name.toLowerCase() == 'vida') return name;
    }
    return widget.system.resources.isNotEmpty ? widget.system.resources.first : '';
  }

  String _energyResourceName() {
    for (final name in widget.system.resources) {
      if (name.toLowerCase() == 'energia' || name.toLowerCase() == 'mana') return name;
    }
    for (final name in widget.system.resources) {
      if (name != _lifeResourceName()) return name;
    }
    return '';
  }

  Future<void> _save() => context.read<AppState>().updateCharacter(widget.character);

  Future<void> _changeResource(String name, int delta) async {
    if (name.isEmpty) return;
    final max = widget.character.resourceMaxValues[name] ?? 0;
    final current = widget.character.resourceValues[name] ?? 0;
    widget.character.resourceValues[name] = (current + delta).clamp(0, max);
    if (name.toLowerCase() == 'vida') widget.character.hp = widget.character.resourceValues[name]!;
    if (name.toLowerCase() == 'energia') widget.character.energy = widget.character.resourceValues[name]!;
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _pickFullBody() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image == null) return;
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      // Evita lotar o armazenamento local/nuvem com uma imagem excessivamente grande.
      if (bytes.length > 700000) {
        _feedback('A imagem ficou muito grande. Escolha uma imagem menor.');
        return;
      }
      final mime = image.mimeType?.startsWith('image/') == true ? image.mimeType! : 'image/jpeg';
      widget.character.fullBodyPath = 'data:$mime;base64,${base64Encode(bytes)}';
    } else {
      widget.character.fullBodyPath = image.path;
    }
    await _save();
    if (mounted) setState(() {});
  }

  void _feedback(String text) {
    if (!mounted) return;
    setState(() => _reaction = true);
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _reaction = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _useConsumable(String item) async {
    final detail = widget.character.inventoryDetails[item] ??= <String, dynamic>{};
    final quantity = int.tryParse('${detail['quantity'] ?? 1}') ?? 1;
    if (quantity <= 0) {
      _feedback('$item acabou.');
      return;
    }
    detail['quantity'] = quantity - 1;
    await _save();
    if (mounted) setState(() {});
    _feedback('$item usado • restam ${quantity - 1}.');
  }

  Future<void> _useWeapon(String item) async {
    final detail = widget.character.inventoryDetails[item] ??= <String, dynamic>{};
    final usesAmmo = detail['usesAmmo'] == true;
    if (usesAmmo) {
      final current = int.tryParse('${detail['ammoCurrent'] ?? 0}') ?? 0;
      if (current <= 0) {
        _feedback('$item está sem munição.');
        return;
      }
      detail['ammoCurrent'] = current - 1;
      await _save();
      if (mounted) setState(() {});
      _feedback('$item disparada • munição ${current - 1}/${detail['ammoMax'] ?? 0}.');
      return;
    }
    _feedback('$item usada.');
  }

  Future<void> _reloadWeapon(String item) async {
    final detail = widget.character.inventoryDetails[item] ??= <String, dynamic>{};
    final max = int.tryParse('${detail['ammoMax'] ?? 0}') ?? 0;
    final current = int.tryParse('${detail['ammoCurrent'] ?? 0}') ?? 0;
    if (max <= 0 || current >= max) return;

    final ammoItem = detail['ammoItem']?.toString() ?? '';
    if (ammoItem.isNotEmpty && widget.character.inventoryDetails.containsKey(ammoItem)) {
      final ammoDetail = widget.character.inventoryDetails[ammoItem] ??= <String, dynamic>{};
      final reserve = int.tryParse('${ammoDetail['quantity'] ?? 0}') ?? 0;
      if (reserve <= 0) {
        _feedback('Sem $ammoItem na reserva.');
        return;
      }
      final needed = max - current;
      final loaded = reserve < needed ? reserve : needed;
      detail['ammoCurrent'] = current + loaded;
      ammoDetail['quantity'] = reserve - loaded;
      await _save();
      if (mounted) setState(() {});
      _feedback('$item recarregada • ${current + loaded}/$max • reserva ${reserve - loaded}.');
      return;
    }

    detail['ammoCurrent'] = max;
    await _save();
    if (mounted) setState(() {});
    _feedback('$item recarregada.');
  }

  Future<void> _castSpell(String spell) async {
    final detail = widget.character.abilityDetails[spell] ??= <String, dynamic>{};
    final cost = int.tryParse('${detail['cost'] ?? 0}') ?? 0;
    var resource = detail['resource']?.toString() ?? '';
    if (resource.isEmpty || !widget.character.resourceValues.containsKey(resource)) {
      resource = _energyResourceName();
    }
    if (resource.isEmpty) {
      _feedback('Nenhum recurso foi configurado para lançar $spell.');
      return;
    }
    final current = widget.character.resourceValues[resource] ?? 0;
    if (current < cost) {
      _feedback('$resource insuficiente para lançar $spell.');
      return;
    }
    widget.character.resourceValues[resource] = current - cost;
    if (resource.toLowerCase() == 'energia') widget.character.energy = current - cost;
    if (resource.toLowerCase() == 'vida') widget.character.hp = current - cost;
    await _save();
    if (mounted) setState(() {});
    _feedback('$spell lançada • $resource: ${current - cost}.');
  }

  Widget _resourceCard(BuildContext context, String name, {required bool secondary}) {
    if (name.isEmpty) return const SizedBox.shrink();
    final value = widget.character.resourceValues[name] ?? 0;
    final max = widget.character.resourceMaxValues[name] ?? 0;
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final themeId = context.watch<AppState>().themeId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(secondary ? Icons.bolt : themedIcon(themeId, 'resources'), size: 20),
                const SizedBox(width: 7),
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Diminuir',
                  onPressed: () => _changeResource(name, -1),
                  icon: const Icon(Icons.remove),
                ),
                Text('$value / $max', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Aumentar',
                  onPressed: () => _changeResource(name, 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _CombatResourceBar(value: progress, themeId: themeId, secondary: secondary),
          ],
        ),
      ),
    );
  }

  Widget _characterStage(BuildContext context) {
    final state = context.watch<AppState>();
    final reduce = state.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
    final fullBody = widget.character.fullBodyPath;
    final portrait = widget.character.portraitPath;
    final fullBodyImage=localImageProvider(fullBody);
    final portraitImage=localImageProvider(portrait);
    final image=fullBodyImage ?? portraitImage;
    final primary = Theme.of(context).colorScheme.primary;

    Widget character = SizedBox(
      width: 190,
      height: 255,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (image != null)
            Positioned(
              left: 18,
              right: 18,
              bottom: 4,
              height: 82,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [primary.withOpacity(.18), primary.withOpacity(0)],
                  ),
                ),
              ),
            ),
          if (image == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1_outlined, size: 58, color: primary),
                  const SizedBox(height: 8),
                  const Text('Adicione uma imagem\nde corpo inteiro', textAlign: TextAlign.center),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Image(
                image: image,
                fit: BoxFit.contain,
                width: 182,
                height: 249,
                filterQuality: FilterQuality.none,
              ),
            ),
        ],
      ),
    );

    if (!reduce) {
      character = AnimatedBuilder(
        animation: _idle,
        child: character,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_idle.value);
          return Transform.translate(
            offset: Offset(0, -3 * t),
            child: Transform.scale(scale: .995 + .01 * t, child: child),
          );
        },
      );
    }

    return GestureDetector(
      onTap: image == null ? _pickFullBody : () {
        if (context.read<AppState>().reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true) return;
        setState(() => _reaction = true);
        Future<void>.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _reaction = false);
        });
      },
      child: AnimatedScale(
        scale: _reaction && !reduce ? 1.035 : 1,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            character,
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                tooltip: 'Trocar personagem 2D',
                onPressed: _pickFullBody,
                icon: const Icon(Icons.photo_camera_back_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionSection(BuildContext context) {
    final consumables = widget.character.inventory.where((item) => (widget.character.inventoryDetails[item]?['category'] ?? '') == 'Consumível').toList();
    final weapons = widget.character.inventory.where((item) => (widget.character.inventoryDetails[item]?['category'] ?? '') == 'Arma').toList();
    final spells = widget.character.abilities.where((item) => (widget.character.abilityDetails[item]?['category'] ?? '') == 'Magia').toList();

    if (consumables.isEmpty && weapons.isEmpty && spells.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhuma ação rápida disponível. Cadastre consumíveis, armas ou magias nas abas correspondentes.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (consumables.isNotEmpty) ...[
          _ActionHeading(icon: Icons.local_drink_outlined, label: 'Consumíveis'),
          ...consumables.map((item) {
            final detail = widget.character.inventoryDetails[item] ?? const <String, dynamic>{};
            final quantity = int.tryParse('${detail['quantity'] ?? 1}') ?? 1;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item),
                subtitle: Text('Quantidade: $quantity'),
                trailing: FilledButton.tonalIcon(
                  onPressed: quantity > 0 ? () => _useConsumable(item) : null,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Usar'),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (weapons.isNotEmpty) ...[
          _ActionHeading(icon: Icons.gps_fixed, label: 'Armas'),
          ...weapons.map((item) {
            final detail = widget.character.inventoryDetails[item] ?? const <String, dynamic>{};
            final damage = detail['damage']?.toString() ?? '';
            final usesAmmo = detail['usesAmmo'] == true;
            final ammoCurrent = int.tryParse('${detail['ammoCurrent'] ?? 0}') ?? 0;
            final ammoMax = int.tryParse('${detail['ammoMax'] ?? 0}') ?? 0;
            final ammoItem = detail['ammoItem']?.toString() ?? '';
            final reserve = ammoItem.isEmpty
                ? null
                : int.tryParse('${widget.character.inventoryDetails[ammoItem]?['quantity'] ?? 0}') ?? 0;
            final canReload = usesAmmo && ammoCurrent < ammoMax && (reserve == null || reserve > 0);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text([
                            if (damage.isNotEmpty) 'Dano: $damage',
                            if (usesAmmo) 'Munição: $ammoCurrent/$ammoMax',
                            if (reserve != null) 'Reserva: $reserve',
                          ].join(' • '), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (usesAmmo)
                      IconButton(
                        tooltip: 'Recarregar',
                        onPressed: canReload ? () => _reloadWeapon(item) : null,
                        icon: const Icon(Icons.refresh),
                      ),
                    FilledButton.tonal(
                      onPressed: !usesAmmo || ammoCurrent > 0 ? () => _useWeapon(item) : null,
                      child: Text(usesAmmo ? 'Atirar' : 'Usar'),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (spells.isNotEmpty) ...[
          _ActionHeading(icon: Icons.auto_awesome, label: 'Magias'),
          ...spells.map((spell) {
            final detail = widget.character.abilityDetails[spell] ?? const <String, dynamic>{};
            final damage = detail['damage']?.toString() ?? '';
            final cost = int.tryParse('${detail['cost'] ?? 0}') ?? 0;
            var resource = detail['resource']?.toString() ?? '';
            if (resource.isEmpty) resource = _energyResourceName();
            final available = resource.isNotEmpty && (widget.character.resourceValues[resource] ?? 0) >= cost;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  SpellIconResolver.resolve(spell, description: widget.character.abilityDescriptions[spell] ?? ''),
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(spell),
                subtitle: Text([
                  if (damage.isNotEmpty) 'Dano: $damage',
                  if (resource.isNotEmpty) 'Custo: $cost $resource',
                  if (!available) 'Recurso insuficiente',
                ].join(' • ')),
                trailing: FilledButton.tonal(
                  onPressed: available ? () => _castSpell(spell) : null,
                  child: const Text('Lançar'),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final life = _lifeResourceName();
    final energy = _energyResourceName();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Center(child: _characterStage(context)),
        const SizedBox(height: 12),
        _resourceCard(context, life, secondary: false),
        const SizedBox(height: 8),
        _resourceCard(context, energy, secondary: true),
        const SizedBox(height: 10),
        if (widget.character.conditions.isNotEmpty) ...[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.character.conditions.map((condition) {
              final positive = condition.toLowerCase().contains('proteg') ||
                  condition.toLowerCase().contains('inspir') ||
                  condition.toLowerCase().contains('fortalec') ||
                  condition.toLowerCase().contains('aceler') ||
                  condition.toLowerCase().contains('regener');
              final scheme = Theme.of(context).colorScheme;
              final tone = positive ? scheme.tertiary : scheme.error;
              return Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  positive ? Icons.auto_awesome : Icons.warning_amber_rounded,
                  size: 16,
                  color: tone,
                ),
                side: BorderSide(color: tone.withOpacity(.28)),
                backgroundColor: tone.withOpacity(.07),
                label: Text(condition),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Icon(themedIcon(context.watch<AppState>().themeId, 'combat')),
            const SizedBox(width: 8),
            Text('Ações rápidas', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 10),
        _actionSection(context),
      ],
    );
  }
}

class _ActionHeading extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionHeading({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 7),
            Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _CombatResourceBar extends StatelessWidget {
  final double value;
  final String themeId;
  final bool secondary;
  const _CombatResourceBar({required this.value, required this.themeId, required this.secondary});

  @override
  Widget build(BuildContext context) {
    if (themeId == 'abyss') return AbyssResourceBar(value: value, secondary: secondary);
    final colors = themedResourceBarColors(themeId, secondary: secondary);
    final widthFactor = value.clamp(0.0, 1.0);
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: themedResourceTrackColor(themeId),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.4)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.center,
        widthFactor: widthFactor,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
