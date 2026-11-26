import 'package:flutter/material.dart';

class ConditionPreset {
  final String name;
  final IconData icon;
  final bool positive;

  const ConditionPreset(this.name, this.icon, {this.positive = false});
}

const conditionPresets = <ConditionPreset>[
  ConditionPreset('Envenenado', Icons.coronavirus),
  ConditionPreset('Queimando', Icons.local_fire_department),
  ConditionPreset('Congelado', Icons.ac_unit),
  ConditionPreset('Sangrando', Icons.water_drop),
  ConditionPreset('Atordoado', Icons.flash_on),
  ConditionPreset('Caído', Icons.airline_seat_flat),
  ConditionPreset('Cego', Icons.visibility_off),
  ConditionPreset('Surdo', Icons.hearing_disabled),
  ConditionPreset('Imobilizado', Icons.link),
  ConditionPreset('Assustado', Icons.sentiment_very_dissatisfied),
  ConditionPreset('Confuso', Icons.psychology_alt),
  ConditionPreset('Inconsciente', Icons.bedtime),
  ConditionPreset('Doente', Icons.sick),
  ConditionPreset('Exausto', Icons.battery_0_bar),
  ConditionPreset('Silenciado', Icons.volume_off),
  ConditionPreset('Protegido', Icons.shield, positive: true),
  ConditionPreset('Inspirado', Icons.auto_awesome, positive: true),
  ConditionPreset('Fortalecido', Icons.fitness_center, positive: true),
  ConditionPreset('Acelerado', Icons.speed, positive: true),
  ConditionPreset('Regenerando', Icons.favorite_border, positive: true),
];

ConditionPreset? conditionPresetFor(String name) {
  final normalized = name.trim().toLowerCase();
  for (final preset in conditionPresets) {
    if (preset.name.toLowerCase() == normalized) return preset;
  }
  return null;
}

IconData conditionIcon(String name) => conditionPresetFor(name)?.icon ?? Icons.flag_outlined;

/// Arte de cada condição pré-definida (nome do preset → asset). Único lugar
/// do mapeamento; o [ConditionPreset.icon] continua como reserva.
const conditionArt = <String, String>{
  'Envenenado': 'assets/icons/conditions/cond_poisoned.webp',
  'Queimando': 'assets/icons/conditions/cond_burning.webp',
  'Congelado': 'assets/icons/conditions/cond_frozen.webp',
  'Sangrando': 'assets/icons/conditions/cond_bleeding.webp',
  'Atordoado': 'assets/icons/conditions/cond_stunned.webp',
  'Caído': 'assets/icons/conditions/cond_prone.webp',
  'Cego': 'assets/icons/conditions/cond_blinded.webp',
  'Surdo': 'assets/icons/conditions/cond_deafened.webp',
  'Imobilizado': 'assets/icons/conditions/cond_restrained.webp',
  'Assustado': 'assets/icons/conditions/cond_frightened.webp',
  'Confuso': 'assets/icons/conditions/cond_confused.webp',
  'Inconsciente': 'assets/icons/conditions/cond_unconscious.webp',
  'Doente': 'assets/icons/conditions/cond_sick.webp',
  'Exausto': 'assets/icons/conditions/cond_exhausted.webp',
  'Silenciado': 'assets/icons/conditions/cond_silenced.webp',
  'Protegido': 'assets/icons/conditions/cond_protected.webp',
  'Inspirado': 'assets/icons/conditions/cond_inspired.webp',
  'Fortalecido': 'assets/icons/conditions/cond_strengthened.webp',
  'Acelerado': 'assets/icons/conditions/cond_hasted.webp',
  'Regenerando': 'assets/icons/conditions/cond_regenerating.webp',
};

/// Tamanho da arte da condição (no lugar do ícone de 18 px).
const conditionArtSize = 22.0;

/// Asset da arte da condição [name], ou null (condição personalizada).
String? conditionArtFor(String name) {
  final preset = conditionPresetFor(name);
  return preset == null ? null : conditionArt[preset.name];
}

/// Ícone de uma condição: a arte do preset (sem tint, a arte já tem cor) ou,
/// em condição personalizada ou falha ao carregar a imagem, o ícone reserva
/// ([fallback], senão o do preset ou [Icons.flag_outlined]) com [size] e
/// [color].
class ConditionIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final IconData? fallback;

  /// Tamanho da arte; por padrão [conditionArtSize] (22 px). Menor só onde
  /// o espaço é menor (chips do card do personagem 2D, 1.3.73).
  final double artSize;

  const ConditionIcon(this.name, {super.key, this.size = 18, this.color, this.fallback, this.artSize = conditionArtSize});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(fallback ?? conditionIcon(name), size: size, color: color);
    final art = conditionArtFor(name);
    if (art == null) return icon;
    final box = size > artSize ? size : artSize;
    // Caixa externa do tamanho do ícone/arte. Dentro de um chip (que força o
    // avatar a ~20 px), a arte continua com 22 px, centralizada, sem mudar a
    // altura do chip (o excedente fica no respiro do avatar).
    return SizedBox.square(
      dimension: box,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: artSize,
        maxHeight: artSize,
        child: SizedBox.square(
          dimension: artSize,
          child: Image.asset(
            art,
            key: ValueKey('condition-art-$name'),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => icon,
          ),
        ),
      ),
    );
  }
}
