// Ícones ilustrados das barras de recurso (Vida, Energia, Mana...) — SOMENTE
// no tema Abissal ('abyss'). Teste visual fácil de reverter: toda a lógica
// fica aqui; nas telas há só a troca do Icon por ThemedResourceIcon.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'abyss_art_size.dart';

/// Pasta das 24 ilustrações de recurso.
const abyssResourceArtFolder = 'assets/icons/resources/';

/// Arquivo usado quando nenhuma regra casa.
const abyssResourceGeneric = 'res_generic';

/// Regras em ordem: a PRIMEIRA que casar vence. Termos com 4+ letras casam no
/// início de uma palavra; termos com 3 letras ou menos só como palavra
/// inteira ("Pedra" não é 'pe'); expressões com espaço casam como frase a
/// partir do início de uma palavra.
const abyssResourceRules = <(String, List<String>)>[
  ('res_temp_hp', ['pv temp', 'hp temp', 'temp hp', 'vida temp', 'vida extra', 'temporari']),
  ('res_blood', ['sangue', 'vitae', 'blood']),
  // "Saúde Mental" é sanidade, não vida (antes da regra de vida).
  ('res_sanity', ['saude mental']),
  ('res_life', ['vida', 'pv', 'hp', 'saude', 'ferimento', 'life', 'health']),
  ('res_energy', ['energia', 'pe', 'ep', 'eletric', 'bateria', 'energy', 'esforc']),
  ('res_mana', ['mana', 'pm', 'mp', 'magia', 'arcan', 'eter']),
  ('res_sanity', ['sanidade', 'san', 'mente', 'mental', 'psiqu', 'razao', 'sanity']),
  ('res_willpower', ['forca de vontade', 'vontade', 'determinac', 'willpower']),
  ('res_exhaustion', ['exaust', 'cansaco', 'fadiga']),
  ('res_breath', ['folego', 'oxigenio', 'respir', 'ar', 'breath']),
  ('res_stamina', ['estamina', 'stamina', 'vigor', 'resistencia']),
  ('res_defense', ['escudo', 'defesa', 'armadura', 'ca', 'blindag', 'protec', 'shield', 'armor']),
  ('res_faith', ['fe', 'divin', 'sagrad', 'devoc', 'oracao', 'graca', 'faith']),
  ('res_fury', ['furia', 'raiva', 'ira', 'colera', 'berserk', 'rage']),
  ('res_ecstasy', ['extase', 'euforia', 'prazer', 'paixao', 'desejo']),
  ('res_ki', ['ki', 'chi', 'qi', 'espirito', 'alma', 'aura', 'chakra']),
  ('res_humanity', ['humanidade', 'humanity']),
  ('res_hunger', ['fome', 'aliment', 'comida', 'hunger']),
  ('res_thirst', ['sede', 'hidrat', 'agua', 'thirst']),
  ('res_luck', ['sorte', 'fortuna', 'destino', 'luck']),
  ('res_xp', ['experiencia', 'xp', 'exp', 'nivel', 'level']),
  ('res_corruption', ['corrup', 'corromp', 'macula']),
  ('res_temperature', ['temperatura', 'calor', 'frio', 'termic']),
  ('res_morale', ['moral', 'animo', 'coragem', 'morale']),
];

/// Caminho da ilustração do recurso pelo nome; `res_generic` se nenhuma regra
/// casar; null para nome vazio.
String? abyssResourceArt(String resourceName) {
  final kind = abyssResourceKind(resourceName);
  return kind == null ? null : '$abyssResourceArtFolder$kind.webp';
}

/// Tipo do recurso pelo nome (ex.: 'res_life'); `res_generic` se nenhuma regra
/// casar; null para nome vazio.
String? abyssResourceKind(String resourceName) {
  final words = _normalize(resourceName).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return null;
  for (final (file, terms) in abyssResourceRules) {
    if (terms.any((term) => _matches(words, term))) return file;
  }
  return abyssResourceGeneric;
}

/// Gradiente [escura, clara] da barra de recurso no Abissal, pelo tipo.
const abyssResourceBarColorTable = <String, List<Color>>{
  'res_life': [Color(0xFF8F1B1B), Color(0xFFD93A3A)],
  'res_temp_hp': [Color(0xFFA0581A), Color(0xFFF0A040)],
  'res_blood': [Color(0xFF5E0B14), Color(0xFFA3192B)],
  'res_energy': [Color(0xFF2D5F96), Color(0xFF5A9BDA)],
  'res_mana': [Color(0xFF2B3A8F), Color(0xFF5B6FE0)],
  'res_sanity': [Color(0xFF5B4A8F), Color(0xFFA899E0)],
  'res_willpower': [Color(0xFF8C7A4A), Color(0xFFF2E3B0)],
  'res_exhaustion': [Color(0xFF4A3F36), Color(0xFF8C7A68)],
  'res_breath': [Color(0xFF2A7F8F), Color(0xFF6FD0DE)],
  'res_stamina': [Color(0xFF2F6B2A), Color(0xFF6DBA4F)],
  'res_defense': [Color(0xFF4A5560), Color(0xFF9AA6B2)],
  'res_faith': [Color(0xFF8A6A1E), Color(0xFFE6C25A)],
  'res_fury': [Color(0xFF8A2A0E), Color(0xFFE5532A)],
  'res_ecstasy': [Color(0xFF7A1F6B), Color(0xFFE04FB8)],
  'res_ki': [Color(0xFF3E6E9E), Color(0xFFB8DDF5)],
  'res_humanity': [Color(0xFF7A6A58), Color(0xFFD6C6A8)],
  'res_hunger': [Color(0xFF7A4A1E), Color(0xFFC9863E)],
  'res_thirst': [Color(0xFF1E5A8A), Color(0xFF4FA8E0)],
  'res_luck': [Color(0xFF1E7A4A), Color(0xFF4FD68A)],
  'res_xp': [Color(0xFF9A7A1A), Color(0xFFF5D55A)],
  'res_corruption': [Color(0xFF2A3A1A), Color(0xFF7FA83A)],
  'res_temperature': [Color(0xFFE0642A), Color(0xFF6FC8F0)],
  'res_morale': [Color(0xFF8A1F2A), Color(0xFFD6A030)],
};

/// Cores da barra de recurso no Abissal; null para nome vazio ou genérico (a
/// barra mantém a lógica de hoje).
List<Color>? abyssResourceBarColors(String resourceName) {
  final kind = abyssResourceKind(resourceName);
  return kind == null ? null : abyssResourceBarColorTable[kind];
}

bool _matches(List<String> words, String term) {
  final parts = term.split(' ');
  if (parts.length == 1) {
    return term.length <= 3 ? words.contains(term) : words.any((w) => w.startsWith(term));
  }
  // Frase: palavras consecutivas; a última parte pode ser início de palavra.
  for (var i = 0; i + parts.length <= words.length; i++) {
    var ok = true;
    for (var j = 0; j < parts.length && ok; j++) {
      final word = words[i + j];
      final part = parts[j];
      final last = j == parts.length - 1;
      ok = last ? word.startsWith(part) : word == part;
    }
    if (ok) return true;
  }
  return false;
}

String _normalize(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
  };
  replacements.forEach((from, to) => text = text.replaceAll(from, to));
  return text;
}

/// Ícone de uma barra de recurso. Fora do Abissal (ou sem nome) devolve
/// exatamente `Icon(fallbackIcon, size: size)`, o mesmo de hoje.
class ThemedResourceIcon extends StatelessWidget {
  final String themeId;
  final String resourceName;
  final IconData fallbackIcon;
  final double? size;

  const ThemedResourceIcon(this.themeId, this.resourceName, {super.key, required this.fallbackIcon, this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(fallbackIcon, size: size);
    final path = abyssResourceArt(resourceName);
    if (path == null) return fallback;
    final side = abyssArtIconSize(context.watch<AppState?>()?.compactMode ?? false);
    return Image.asset(
      path,
      width: side,
      height: side,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
