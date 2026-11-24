// Ícones ilustrados das abas da ficha e dos títulos dos cards — SOMENTE no tema
// Abissal ('abyss'). Teste visual fácil de reverter: toda a lógica fica aqui;
// nos outros arquivos há só chamadas curtas.
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
/// arte). A aba selecionada recebe a cor dourada clara do [AbyssTabCell]; as
/// outras ficam com opacidade [abyssTabArtUnselectedOpacity].
Widget? abyssCharacterTabArt(String role, {required double size, Color? color, required Widget fallback}) {
  final path = abyssTabArt(role);
  if (path == null) return null;
  final selected = color == null || color == AbyssColors.goldLight;
  return Builder(builder: (context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final artSize = textScale <= abyssTabArtMaxTextScale ? size * abyssTabArtScale : size;
    return Opacity(
      key: ValueKey('abyss-tab-art-$role'),
      opacity: selected ? 1.0 : abyssTabArtUnselectedOpacity,
      child: _artImage(path, artSize, fallback),
    );
  });
}

/// Ícone do título de um card. Fora do Abissal (ou sem arte para o papel),
/// devolve exatamente o `Icon(themedIcon(themeId, role), size: size)` de hoje.
class ThemedSectionIcon extends StatelessWidget {
  final String themeId;
  final String role;
  final double? size;

  const ThemedSectionIcon(this.themeId, this.role, {super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(themedIcon(themeId, role), size: size);
    final path = abyssTabArt(role);
    if (themeId != 'abyss' || path == null) return fallback;
    final base = size ?? IconTheme.of(context).size ?? 24;
    return _artImage(path, math.max(26.0, base * abyssTabArtScale), fallback);
  }
}
