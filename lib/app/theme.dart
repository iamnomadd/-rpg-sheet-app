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
  // Experimental e isolado (lib/app/abyss_theme.dart); fácil de remover.
  AppThemePreset(id: 'abyss', name: 'Abissal (experimental)', description: 'Ardósia escura, molduras douradas e fumaça roxa. Tema experimental.', icon: Icons.diamond_outlined, seed: Color(0xFFC9A24A), background: Color(0xFF05080D), card: Color(0xFF10171C)),
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


List<Color> themedResourceBarColors(String themeId, {bool secondary = false}) {
  switch (themeId) {
    case 'cyberpunk':
      return secondary ? [const Color(0xFF0E36B8), const Color(0xFF1755FF), const Color(0xFF8BB4E0)] : [const Color(0xFF0E36B8), const Color(0xFF1755FF), const Color(0xFF8BB4E0)];
    case 'arcane':
      return secondary ? [const Color(0xFF6A1B9A), const Color(0xFFB388FF)] : [const Color(0xFF8E24AA), const Color(0xFFD1C4E9)];
    case 'parchment':
      return secondary ? [const Color(0xFF263B4A), const Color(0xFF667785)] : [const Color(0xFF6D542F), const Color(0xFFB08A4B)];
    case 'medieval':
      return secondary ? [const Color(0xFF8D6E63), const Color(0xFFFFCC80)] : [const Color(0xFFB87333), const Color(0xFFFFD54F)];
    case 'vampire':
      return secondary ? [const Color(0xFF650900), const Color(0xFFB70F00)] : [const Color(0xFF7D0A00), const Color(0xFFB70F00)];
    case 'forest':
      return secondary ? [const Color(0xFF6D4C41), const Color(0xFFBCAAA4)] : [const Color(0xFF8D6E63), const Color(0xFFD7B899)];
    case 'ocean':
      return secondary ? [const Color(0xFF90A4AE), const Color(0xFFECEFF1)] : [const Color(0xFFB0BEC5), const Color(0xFFFFFFFF)];
    case 'infernal':
      return secondary ? [const Color(0xFFFF6D00), const Color(0xFFFFAB40)] : [const Color(0xFFFF3D00), const Color(0xFFFF8A65)];
    case 'ice':
      return secondary ? [const Color(0xFF00B8D4), const Color(0xFFB2EBF2)] : [const Color(0xFF00E5FF), const Color(0xFFE1F5FE)];
    case 'abyss':
      return secondary ? AbyssColors.energy : AbyssColors.life;
    default:
      return secondary ? [const Color(0xFF7E57C2), const Color(0xFFD1C4E9)] : [const Color(0xFFB39DDB), const Color(0xFFEDE7F6)];
  }
}

Color themedResourceTrackColor(String themeId) {
  switch (themeId) {
    case 'cyberpunk':
      return const Color(0xFF101A28);
    case 'arcane':
      return const Color(0xFF1D1630);
    case 'parchment':
      return const Color(0xFF111820);
    case 'medieval':
      return const Color(0xFF241B10);
    case 'vampire':
      return const Color(0xFF161616);
    case 'forest':
      return const Color(0xFF24160E);
    case 'ocean':
      return const Color(0xFF1A1E24);
    case 'infernal':
      return const Color(0xFF2A0B05);
    case 'ice':
      return const Color(0xFF07202A);
    case 'abyss':
      return AbyssColors.track;
    default:
      return const Color(0xFF181824);
  }
}

ShapeBorder themedNavigationIndicatorShape(String themeId, double radius) {
  if (themeId == 'abyss') return abyssIndicatorShape();
  return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.clamp(10, 22)));
}

Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color, bool? selected}) {
  if (themeId == 'abyss') {
    final fallback = Icon(themedIcon(themeId, role), size: size, color: color ?? AbyssColors.gold);
    return abyssCharacterTabArt(role, size: size, color: color, selected: selected, fallback: fallback) ?? fallback;
  }
  if (themeId == 'cyberpunk') {
    final iconColor = color ?? const Color(0xFF1755FF);
    if (role == 'general') {
      return ImageIcon(const AssetImage('assets/cyberpunk/skull.png'), size: size * 1.12, color: iconColor);
    }
    if (role == 'abilities') {
      return Icon(Icons.precision_manufacturing_outlined, size: size * 1.12, color: iconColor);
    }
    if (role == 'skills') {
      return ImageIcon(const AssetImage('assets/cyberpunk/chip.png'), size: size * 1.12, color: iconColor);
    }
    return Icon(themedIcon(themeId, role), size: size, color: iconColor);
  }
  if (themeId != 'vampire') return Icon(themedIcon(themeId, role), size: size, color: color);
  final iconColor = color ?? const Color(0xFFB70F00);
  if (role == 'general') return Icon(Icons.circle, size: size, color: iconColor);
  if (role == 'skillTree') return CustomPaint(size: Size.square(size), painter: _AnatomicalHeartPainter(iconColor));
  if (role == 'abilities') return CustomPaint(size: Size.square(size), painter: _BatPainter(iconColor));
  return Icon(themedIcon(themeId, role), size: size, color: iconColor);
}

class _BatPainter extends CustomPainter {
  final Color color;
  const _BatPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    p.moveTo(size.width * .50, size.height * .45);
    p.cubicTo(size.width * .42, size.height * .30, size.width * .32, size.height * .27, size.width * .24, size.height * .35);
    p.cubicTo(size.width * .15, size.height * .23, size.width * .05, size.height * .24, 0, size.height * .31);
    p.cubicTo(size.width * .10, size.height * .45, size.width * .10, size.height * .58, size.width * .18, size.height * .70);
    p.cubicTo(size.width * .25, size.height * .61, size.width * .31, size.height * .64, size.width * .37, size.height * .76);
    p.cubicTo(size.width * .42, size.height * .66, size.width * .46, size.height * .62, size.width * .50, size.height * .72);
    p.cubicTo(size.width * .54, size.height * .62, size.width * .58, size.height * .66, size.width * .63, size.height * .76);
    p.cubicTo(size.width * .69, size.height * .64, size.width * .75, size.height * .61, size.width * .82, size.height * .70);
    p.cubicTo(size.width * .90, size.height * .58, size.width * .90, size.height * .45, size.width, size.height * .31);
    p.cubicTo(size.width * .95, size.height * .24, size.width * .85, size.height * .23, size.width * .76, size.height * .35);
    p.cubicTo(size.width * .68, size.height * .27, size.width * .58, size.height * .30, size.width * .50, size.height * .45);
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }
  @override bool shouldRepaint(covariant _BatPainter oldDelegate) => oldDelegate.color != color;
}

class _AnatomicalHeartPainter extends CustomPainter {
  final Color color;
  const _AnatomicalHeartPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final heart = Path();
    heart.moveTo(size.width * .53, size.height * .90);
    heart.cubicTo(size.width * .43, size.height * .78, size.width * .25, size.height * .63, size.width * .24, size.height * .44);
    heart.cubicTo(size.width * .23, size.height * .28, size.width * .34, size.height * .20, size.width * .45, size.height * .26);
    heart.cubicTo(size.width * .51, size.height * .13, size.width * .66, size.height * .12, size.width * .73, size.height * .23);
    heart.cubicTo(size.width * .84, size.height * .31, size.width * .82, size.height * .48, size.width * .73, size.height * .58);
    heart.cubicTo(size.width * .68, size.height * .69, size.width * .61, size.height * .82, size.width * .53, size.height * .90);
    heart.close();
    canvas.drawPath(heart, paint);
    final vessel = Paint()..color = color..strokeWidth = size.width * .10..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .48, size.height * .28), Offset(size.width * .43, size.height * .06), vessel);
    canvas.drawLine(Offset(size.width * .59, size.height * .23), Offset(size.width * .62, size.height * .04), vessel);
    canvas.drawLine(Offset(size.width * .68, size.height * .28), Offset(size.width * .78, size.height * .12), vessel);
  }
  @override bool shouldRepaint(covariant _AnatomicalHeartPainter oldDelegate) => oldDelegate.color != color;
}

ThemeData buildTheme([String themeId = 'classic']) {
  if (themeId == 'abyss') return buildAbyssTheme();
  final preset = themePreset(themeId);
  final pirate = themeId == 'parchment';
  final vampire = themeId == 'vampire';
  final cyberpunk = themeId == 'cyberpunk';
  final baseScheme = ColorScheme.fromSeed(seedColor: preset.seed, brightness: preset.brightness);
  final scheme = pirate
      ? baseScheme.copyWith(
          primary: const Color(0xFFB08A4B),
          onPrimary: const Color(0xFF090C10),
          primaryContainer: const Color(0xFF171D24),
          onPrimaryContainer: const Color(0xFFE2C98F),
          secondary: const Color(0xFF65798A),
          onSecondary: const Color(0xFF071018),
          secondaryContainer: const Color(0xFF101C28),
          onSecondaryContainer: const Color(0xFFC7D0D8),
          surface: const Color(0xFF151A20),
          onSurface: const Color(0xFFD9DDE1),
          outline: const Color(0xFF8A6C3E),
          outlineVariant: const Color(0xFF50452F),
        )
      : vampire
          ? baseScheme.copyWith(
              primary: const Color(0xFFB70F00),
              onPrimary: const Color(0xFFFFFFFF),
              primaryContainer: const Color(0xFF2A2A2D),
              onPrimaryContainer: const Color(0xFFFFFFFF),
              secondary: const Color(0xFFB70F00),
              onSecondary: const Color(0xFFFFFFFF),
              secondaryContainer: const Color(0xFF242426),
              onSecondaryContainer: const Color(0xFFB70F00),
              surface: const Color(0xFF1A1A1D),
              onSurface: const Color(0xFFF1F1F1),
              surfaceContainerHighest: const Color(0xFF242426),
              onSurfaceVariant: const Color(0xFFD2D2D2),
              outline: const Color(0xFFFF5C5C),
              outlineVariant: const Color(0xFFFF5C5C),
            )
          : cyberpunk
              ? baseScheme.copyWith(
                  primary: const Color(0xFF1755FF),
                  onPrimary: const Color(0xFFFFFFFF),
                  primaryContainer: const Color(0xFF10265E),
                  onPrimaryContainer: const Color(0xFFEAF0FF),
                  secondary: const Color(0xFF1755FF),
                  onSecondary: const Color(0xFFFFFFFF),
                )
              : baseScheme;
  final radius = preset.radius;
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius.clamp(12, 18)),
    side: BorderSide(color: scheme.outlineVariant.withOpacity(.18), width: 1),
  );
  final fieldShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: pirate ? Colors.transparent : (vampire ? Colors.black : preset.background),
    iconTheme: IconThemeData(color: pirate ? const Color(0xFFBFA66F) : (vampire ? const Color(0xFFB70F00) : scheme.onSurfaceVariant)),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: pirate ? const Color(0xFF080F18) : (vampire ? Colors.black : Colors.transparent),
      foregroundColor: pirate ? const Color(0xFFD9DDE1) : (vampire ? const Color(0xFFB70F00) : null),
      iconTheme: vampire ? const IconThemeData(color: Color(0xFFB70F00)) : null,
      actionsIconTheme: vampire ? const IconThemeData(color: Color(0xFFB70F00)) : null,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant.withOpacity(.32),
      dividerHeight: 1,
      overlayColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.pressed) ? scheme.primary.withOpacity(.10) : Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: pirate ? const Color(0xFF09111B) : (vampire ? const Color(0xFF1A1A1D) : preset.card),
      indicatorColor: pirate ? const Color(0xFF171D24) : (vampire ? const Color(0xFF2A2A2D) : scheme.primaryContainer),
      indicatorShape: themedNavigationIndicatorShape(themeId, radius),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected
              ? (pirate ? const Color(0xFFC7A45B) : (vampire ? const Color(0xFFB70F00) : scheme.onPrimaryContainer))
              : (pirate ? const Color(0xFF7E8994) : scheme.onSurfaceVariant),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: states.contains(WidgetState.selected) ? 11 : 10.5,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: 0,
        color: pirate && states.contains(WidgetState.selected) ? const Color(0xFFC7A45B) : (vampire && states.contains(WidgetState.selected) ? const Color(0xFFB70F00) : null),
      )),
    ),
    cardTheme: CardThemeData(
      color: pirate
          ? Color.alphaBlend(const Color(0xFFB08A4B).withOpacity(.07), preset.card)
          : (vampire ? const Color(0xFF1A1A1D) : Color.alphaBlend(scheme.primary.withOpacity(.025), preset.card)),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pirate
          ? const Color(0xFF111820)
          : (vampire ? const Color(0xFF202023) : Color.alphaBlend(scheme.primary.withOpacity(.018), preset.card)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.28), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.28), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary.withOpacity(.85), width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: pirate ? const Color(0xFF151A20) : (vampire ? const Color(0xFFB70F00) : null),
        foregroundColor: pirate ? const Color(0xFFE2C98F) : (vampire ? Colors.white : null),
        shape: fieldShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(.55), width: 1),
        shape: fieldShape,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pirate
          ? const Color(0xFF121820)
          : (vampire ? const Color(0xFF1A1A1D) : Color.alphaBlend(scheme.primary.withOpacity(.02), preset.card)),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(.18), width: 1),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pirate
          ? const Color(0xFF121820)
          : (vampire ? const Color(0xFF1A1A1D) : Color.alphaBlend(scheme.primary.withOpacity(.018), preset.card)),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide.none,
      ),
      showDragHandle: true,
      dragHandleColor: pirate ? scheme.primary.withOpacity(.7) : (vampire ? const Color(0xFFB70F00) : null),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: pirate
          ? const Color(0xFF121820)
          : (vampire ? const Color(0xFF1A1A1D) : Color.alphaBlend(scheme.primary.withOpacity(.018), preset.card)),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(.18), width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: pirate ? const Color(0xFF171D24) : (vampire ? const Color(0xFF242426) : scheme.surfaceContainerHighest.withOpacity(.34)),
      selectedColor: pirate ? const Color(0xFF171D24) : (vampire ? const Color(0xFF2A2A2D) : scheme.primary.withOpacity(.18)),
      side: BorderSide(color: scheme.outlineVariant.withOpacity(.22), width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: pirate ? const Color(0xFF151A20) : (vampire ? const Color(0xFF1A1A1D) : null),
      foregroundColor: pirate ? const Color(0xFFE2C98F) : (vampire ? const Color(0xFFB70F00) : null),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: pirate ? const Color(0xFF171D24) : (vampire ? const Color(0xFF1A1A1D) : null),
      contentTextStyle: pirate ? const TextStyle(color: Color(0xFFD9DDE1)) : (vampire ? const TextStyle(color: Color(0xFFF1F1F1)) : null),
    ),
    dividerTheme: DividerThemeData(
      space: 20,
      thickness: 1,
      color: scheme.outlineVariant.withOpacity(.18),
    ),
  );
}
