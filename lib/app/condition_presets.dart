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
