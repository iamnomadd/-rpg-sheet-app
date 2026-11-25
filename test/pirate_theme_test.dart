import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/theme.dart';

void main() {
  test('tema sombrio usa identidade pirata sem trocar o id persistido', () {
    final preset = themePreset('parchment');
    expect(preset.id, 'parchment');
    expect(preset.name, 'Sombrio Pirata');
    expect(preset.icon, Icons.anchor);
    expect(themedMainIcon('parchment', 'campaigns'), Icons.directions_boat_filled);
    expect(themedMainIcon('parchment', 'settings'), Icons.explore_outlined);
    expect(themedMainIcon('parchment', 'systems'), Icons.map_outlined);
    expect(themedIcon('parchment', 'resources'), Icons.water_drop_outlined);
  });

  test('tema pirata segue paleta sombria oficial', () {
    final preset = themePreset('parchment');
    final theme = buildTheme('parchment');
    expect(preset.background, const Color(0xFF050A12));
    expect(preset.card, const Color(0xFF151A20));
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    // Design do Abissal (padrão desde a 1.3.62) com a paleta do Pirata.
    expect(theme.navigationBarTheme.indicatorShape, isA<AbyssFrameBorder>());
    expect(theme.cardTheme.shape, isA<AbyssFrameBorder>());
    expect(theme.colorScheme.primary, const Color(0xFFB08A4B));
    expect(theme.colorScheme.surface, const Color(0xFF151A20));
    expect(theme.colorScheme.outline, const Color(0xFFB08A4B));
  });
}
