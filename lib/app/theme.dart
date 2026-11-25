import 'package:flutter/material.dart';

import 'abyss_tab_art.dart';
import 'abyss_theme.dart';

class AppThemePreset {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color seed;
  final Color background;
  final Color card;
  final Brightness brightness;
  final double radius;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.seed,
    required this.background,
    required this.card,
    this.brightness = Brightness.dark,
    this.radius = 20,
  });
}

const appThemes = <AppThemePreset>[
  AppThemePreset(id: 'classic', name: 'Clássico Escuro', description: 'Roxo discreto, preto e superfícies neutras.', icon: Icons.dark_mode, seed: Color(0xFF7C4DFF), background: Color(0xFF0C0C10), card: Color(0xFF17171D)),
  AppThemePreset(id: 'parchment', name: 'Sombrio Pirata', description: 'Azul-marinho, preto azulado e cinza escuro com detalhes em ouro envelhecido.', icon: Icons.anchor, seed: Color(0xFFB08A4B), background: Color(0xFF050A12), card: Color(0xFF151A20)),
  AppThemePreset(id: 'medieval', name: 'Medieval', description: 'Bronze e ferro em superfícies escuras e sóbrias.', icon: Icons.shield, seed: Color(0xFFD9A441), background: Color(0xFF0F0E0B), card: Color(0xFF1C1912)),
  AppThemePreset(id: 'arcane', name: 'Arcano', description: 'Violeta místico com profundidade sem excesso de brilho.', icon: Icons.auto_awesome, seed: Color(0xFF9C6CFF), background: Color(0xFF0E0B14), card: Color(0xFF1A1523)),
  AppThemePreset(id: 'vampire', name: 'Vampírico', description: 'Preto absoluto, cinza escuro e vermelho sangue intenso como identidade visual.', icon: Icons.nightlight_round, seed: Color(0xFFB70F00), background: Color(0xFF000000), card: Color(0xFF1A1A1D)),
  AppThemePreset(id: 'forest', name: 'Elemento Terra', description: 'Terra, pedra e cobre em uma base escura natural.', icon: Icons.landscape, seed: Color(0xFFB97945), background: Color(0xFF0F0B08), card: Color(0xFF1B1511)),
  AppThemePreset(id: 'ocean', name: 'Elemento Ar', description: 'Cinza frio e branco suave com sensação leve.', icon: Icons.air, seed: Color(0xFFDDE6F0), background: Color(0xFF0C0E11), card: Color(0xFF171A1D)),
  AppThemePreset(id: 'cyberpunk', name: 'Cyberpunk', description: 'Azul elétrico pontual sobre superfícies tecnológicas escuras.', icon: Icons.memory, seed: Color(0xFF1755FF), background: Color(0xFF08090E), card: Color(0xFF12141B)),
  AppThemePreset(id: 'infernal', name: 'Infernal', description: 'Vermelho e brasa usados como acento em uma base carbonizada.', icon: Icons.local_fire_department, seed: Color(0xFFFD0F04), background: Color(0xFF100605), card: Color(0xFF1D0D0A)),
  AppThemePreset(id: 'ice', name: 'Gelo', description: 'Azul glacial em superfícies frias e minimalistas.', icon: Icons.ac_unit, seed: Color(0xFF62D8F2), background: Color(0xFF071014), card: Color(0xFF0E1B20)),
  // Paleta do design do Abissal (lib/app/abyss_theme.dart), que desde a 1.3.62 é o design de todos os temas.
  AppThemePreset(id: 'abyss', name: 'Abissal', description: 'Ardósia escura, molduras douradas e fumaça roxa.', icon: Icons.diamond_outlined, seed: Color(0xFFC9A24A), background: Color(0xFF05080D), card: Color(0xFF10171C)),
];

AppThemePreset themePreset(String id) => appThemes.firstWhere(
  (theme) => theme.id == id,
  orElse: () => appThemes.first,
);

IconData themedIcon(String themeId, String role) {
  const sets = <String, Map<String, IconData>>{
    'classic': {'general': Icons.dashboard, 'attributes': Icons.bar_chart, 'attributesResources': Icons.dashboard_customize, 'actions': Icons.sports_martial_arts, 'skills': Icons.psychology, 'resources': Icons.favorite, 'sections': Icons.menu_book, 'extras': Icons.backpack, 'inventory': Icons.backpack, 'abilities': Icons.auto_awesome, 'skillTree': Icons.account_tree_outlined},
    'cyberpunk': {'general': Icons.grid_view_rounded, 'attributes': Icons.monitor_heart_outlined, 'attributesResources': Icons.monitor_heart_outlined, 'actions': Icons.flash_on, 'skills': Icons.hub_outlined, 'resources': Icons.battery_charging_full, 'sections': Icons.terminal, 'extras': Icons.inventory_2_outlined, 'inventory': Icons.inventory_2_outlined, 'abilities': Icons.bolt, 'skillTree': Icons.hub_outlined},
    'arcane': {'general': Icons.blur_circular, 'attributes': Icons.auto_graph, 'attributesResources': Icons.auto_graph, 'actions': Icons.auto_fix_high, 'skills': Icons.psychology_alt, 'resources': Icons.favorite_border, 'sections': Icons.auto_stories, 'extras': Icons.all_inclusive, 'inventory': Icons.shopping_bag_outlined, 'abilities': Icons.auto_awesome, 'skillTree': Icons.device_hub},
    'parchment': {'general': Icons.explore_outlined, 'attributes': Icons.anchor, 'attributesResources': Icons.anchor, 'actions': Icons.sailing, 'combat': Icons.directions_boat_filled, 'skills': Icons.map_outlined, 'resources': Icons.water_drop_outlined, 'sections': Icons.menu_book_outlined, 'extras': Icons.inventory_2_outlined, 'inventory': Icons.inventory_2_outlined, 'abilities': Icons.flash_on, 'skillTree': Icons.alt_route},
    'medieval': {'general': Icons.shield_outlined, 'attributes': Icons.fitness_center, 'attributesResources': Icons.shield_outlined, 'actions': Icons.sports_martial_arts, 'skills': Icons.military_tech, 'resources': Icons.favorite, 'sections': Icons.menu_book, 'extras': Icons.backpack, 'inventory': Icons.backpack, 'abilities': Icons.flash_on, 'skillTree': Icons.account_tree_outlined},
    'vampire': {'general': Icons.circle, 'attributes': Icons.bloodtype_outlined, 'attributesResources': Icons.bloodtype_outlined, 'actions': Icons.flash_on, 'skills': Icons.visibility_outlined, 'resources': Icons.favorite, 'sections': Icons.menu_book, 'extras': Icons.inventory_2, 'inventory': Icons.inventory_2, 'abilities': Icons.dark_mode, 'skillTree': Icons.favorite_border},
    'forest': {'general': Icons.landscape, 'attributes': Icons.fitness_center, 'attributesResources': Icons.landscape, 'actions': Icons.sports_martial_arts, 'skills': Icons.psychology, 'resources': Icons.eco, 'sections': Icons.menu_book, 'extras': Icons.backpack, 'inventory': Icons.backpack, 'abilities': Icons.bolt, 'skillTree': Icons.terrain},
    'ocean': {'general': Icons.air, 'attributes': Icons.speed, 'attributesResources': Icons.air, 'actions': Icons.air, 'skills': Icons.explore_outlined, 'resources': Icons.cloud_outlined, 'sections': Icons.menu_book, 'extras': Icons.inventory_2, 'inventory': Icons.inventory_2, 'abilities': Icons.bolt, 'skillTree': Icons.alt_route},
    'infernal': {'general': Icons.local_fire_department, 'attributes': Icons.whatshot, 'attributesResources': Icons.whatshot, 'actions': Icons.local_fire_department, 'skills': Icons.psychology_alt, 'resources': Icons.favorite, 'sections': Icons.menu_book, 'extras': Icons.inventory_2, 'inventory': Icons.inventory_2, 'abilities': Icons.bolt, 'skillTree': Icons.call_split},
    'ice': {'general': Icons.ac_unit, 'attributes': Icons.stacked_line_chart, 'attributesResources': Icons.ac_unit, 'actions': Icons.ac_unit, 'skills': Icons.diamond_outlined, 'resources': Icons.severe_cold, 'sections': Icons.menu_book, 'extras': Icons.inventory_2, 'inventory': Icons.inventory_2, 'abilities': Icons.auto_awesome, 'skillTree': Icons.hub_outlined},
    'abyss': {'general': Icons.explore, 'attributes': Icons.anchor, 'attributesResources': Icons.anchor, 'actions': Icons.gps_fixed, 'combat': Icons.shield_outlined, 'skills': Icons.menu_book_outlined, 'resources': Icons.water_drop_outlined, 'sections': Icons.auto_stories_outlined, 'extras': Icons.inventory_2_outlined, 'inventory': Icons.inventory_2_outlined, 'abilities': Icons.flash_on, 'skillTree': Icons.alt_route},
  };
  return sets[themeId]?[role] ?? sets['classic']![role] ?? Icons.circle;
}


IconData themedMainIcon(String themeId, String role) {
  const sets = <String, Map<String, IconData>>{
    'classic': {
      'characters': Icons.people_alt_outlined, 'systems': Icons.auto_awesome, 'tree': Icons.account_tree_outlined,
      'dice': Icons.casino_outlined, 'campaigns': Icons.groups_outlined, 'settings': Icons.settings_outlined,
    },
    'cyberpunk': {
      'characters': Icons.badge_outlined, 'systems': Icons.memory, 'tree': Icons.hub_outlined,
      'dice': Icons.casino_outlined, 'campaigns': Icons.wifi_tethering, 'settings': Icons.tune,
    },
    'arcane': {
      'characters': Icons.person_outline, 'systems': Icons.auto_awesome, 'tree': Icons.device_hub,
      'dice': Icons.casino, 'campaigns': Icons.groups_outlined, 'settings': Icons.tune,
    },
    'parchment': {
      'characters': Icons.groups_2_outlined, 'systems': Icons.map_outlined, 'tree': Icons.alt_route,
      'dice': Icons.casino_outlined, 'campaigns': Icons.directions_boat_filled, 'settings': Icons.explore_outlined,
    },
    'medieval': {
      'characters': Icons.shield_outlined, 'systems': Icons.menu_book, 'tree': Icons.account_tree_outlined,
      'dice': Icons.casino, 'campaigns': Icons.groups, 'settings': Icons.settings,
    },
    'vampire': {
      'characters': Icons.nightlight_round, 'systems': Icons.bloodtype_outlined, 'tree': Icons.account_tree,
      'dice': Icons.casino_outlined, 'campaigns': Icons.groups_outlined, 'settings': Icons.settings_outlined,
    },
    'forest': {
      'characters': Icons.landscape, 'systems': Icons.eco, 'tree': Icons.terrain,
      'dice': Icons.casino_outlined, 'campaigns': Icons.groups_outlined, 'settings': Icons.tune,
    },
    'ocean': {
      'characters': Icons.air, 'systems': Icons.cloud_outlined, 'tree': Icons.alt_route,
      'dice': Icons.casino_outlined, 'campaigns': Icons.groups_outlined, 'settings': Icons.tune,
    },
    'infernal': {
      'characters': Icons.local_fire_department, 'systems': Icons.whatshot, 'tree': Icons.call_split,
      'dice': Icons.casino, 'campaigns': Icons.groups, 'settings': Icons.settings,
    },
    'ice': {
      'characters': Icons.ac_unit, 'systems': Icons.severe_cold, 'tree': Icons.hub_outlined,
      'dice': Icons.casino_outlined, 'campaigns': Icons.groups_outlined, 'settings': Icons.settings_outlined,
    },
    'abyss': {
      'characters': Icons.people_outline, 'systems': Icons.menu_book_outlined, 'tree': Icons.alt_route,
      'dice': Icons.casino_outlined, 'campaigns': Icons.shield_outlined, 'settings': Icons.explore_outlined,
    },
  };
  return sets[themeId]?[role] ?? sets['classic']![role] ?? Icons.circle;
}


/// Indicador da navegação: a moldura do Abissal na paleta do tema.
ShapeBorder themedNavigationIndicatorShape(String themeId) => abyssIndicatorShape(abyssPaletteFor(themeId));

/// Ícone da aba da ficha: a arte do Abissal (ou o ícone de fallback do tema).
Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color, bool? selected}) {
  final fallback = Icon(themedIcon(themeId, role), size: size, color: color ?? abyssPaletteFor(themeId).gold);
  return abyssCharacterTabArt(role, size: size, color: color, selected: selected, fallback: fallback) ?? fallback;
}

/// ThemeData do tema: o design do Abissal com a paleta do tema.
ThemeData buildTheme([String themeId = 'classic']) => buildAbyssTheme(abyssPaletteFor(themeId));
