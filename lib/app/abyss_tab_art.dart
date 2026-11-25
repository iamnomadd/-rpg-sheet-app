// Ícones ilustrados das abas da ficha e dos títulos dos cards — SOMENTE no tema
// Abissal ('abyss'). Teste visual fácil de reverter: toda a lógica fica aqui;
// nos outros arquivos há só chamadas curtas.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'abyss_art_size.dart';
import 'abyss_theme.dart';
import 'theme.dart';

/// Pasta das 8 ilustrações das abas.
const abyssTabArtFolder = 'assets/icons/tabs/';

/// Papel (o mesmo de `themedIcon`) → arquivo da ilustração.
const abyssTabArtFiles = <String, String>{
  'general': 'tab_scene',
  'attributesResources': 'tab_status',
  'attributes': 'tab_status',
  'abilities': 'tab_abilities',
  'actions': 'tab_actions',
  'skillTree': 'tab_tree',
  'skills': 'tab_skills',
  'inventory': 'tab_inventory',
  'sections': 'tab_sections',
};

/// Pasta das 8 ilustrações SEM moldura dos títulos dos cards.
const abyssSectionArtFolder = 'assets/icons/sections/';

/// Papel → arquivo da ilustração sem moldura dos títulos dos cards.
const abyssSectionArtFiles = <String, String>{
  'general': 'section_scene',
  'attributesResources': 'section_status',
  'attributes': 'section_status',
  'abilities': 'section_abilities',
  'actions': 'section_actions',
  'skillTree': 'section_tree',
  'skills': 'section_skills',
  'inventory': 'section_inventory',
  'sections': 'section_sections',
  'session': 'section_actions',
};

/// Caminho da arte sem moldura do título do card ou null.
String? abyssSectionArt(String role) {
  final file = abyssSectionArtFiles[role];
  return file == null ? null : '$abyssSectionArtFolder$file.webp';
}

/// Fator de tamanho da arte em relação ao ícone de hoje.
const abyssTabArtScale = 1.35;

/// Acima desta escala de texto, a arte das abas usa o tamanho do ícone de
/// hoje: a barra tem altura fixa (72) e o rótulo maior não deixa espaço.
const abyssTabArtMaxTextScale = 1.2;

/// Opacidade da arte nas abas não selecionadas.
const abyssTabArtUnselectedOpacity = .55;

/// Caminho do asset do papel ou null (o papel não tem arte).
String? abyssTabArt(String role) {
  final file = abyssTabArtFiles[role];
  return file == null ? null : '$abyssTabArtFolder$file.webp';
}

Widget _artImage(String path, double size, Widget fallback) => Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback,
    );

/// Ícone da aba da ficha no Abissal: a ilustração (ou null se o papel não tem
/// arte). A aba selecionada fica opaca e as outras com opacidade
/// [abyssTabArtUnselectedOpacity]. [selected] decide; se vier null, a seleção é
/// deduzida pela cor dourada clara que o [AbyssTabCell] passa.
Widget? abyssCharacterTabArt(String role, {required double size, Color? color, bool? selected, required Widget fallback}) {
  final path = abyssTabArt(role);
  if (path == null) return null;
  return Builder(builder: (context) {
    final isSelected = selected ?? (color == null || color == AbyssPalette.of(context).goldLight);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final artSize = textScale <= abyssTabArtMaxTextScale ? size * abyssTabArtScale : size;
    return Opacity(
      key: ValueKey('abyss-tab-art-$role'),
      opacity: isSelected ? 1.0 : abyssTabArtUnselectedOpacity,
      child: _artImage(path, artSize, fallback),
    );
  });
}

/// Ícone do título de um card (e do card Sessão). Fora do Abissal (ou sem
/// arte para o papel), devolve exatamente o
/// `Icon(fallbackIcon ?? themedIcon(themeId, role), size: size, color: color)`
/// de hoje. No Abissal, a arte SEM moldura de `assets/icons/sections/`, no
/// tamanho padrão [abyssArtIconSize].
class ThemedSectionIcon extends StatelessWidget {
  final String themeId;
  final String role;
  final double? size;
  final IconData? fallbackIcon;
  final Color? color;

  const ThemedSectionIcon(this.themeId, this.role, {super.key, this.size, this.fallbackIcon, this.color});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(fallbackIcon ?? themedIcon(themeId, role), size: size, color: color);
    final path = abyssSectionArt(role);
    if (!usesAbyssDesign(themeId) || path == null) return fallback;
    return _artImage(path, abyssArtIconSize(context.watch<AppState?>()?.compactMode ?? false), fallback);
  }
}
