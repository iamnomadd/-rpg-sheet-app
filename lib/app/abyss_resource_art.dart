// Ícones ilustrados das barras de recurso (Vida, Energia, Mana...) — SOMENTE
// no tema Abissal ('abyss'). Teste visual fácil de reverter: toda a lógica
// fica aqui; nas telas há só a troca do Icon por ThemedResourceIcon.
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  ('res_life', ['vida', 'pv', 'hp', 'saude', 'ferimento', 'life', 'health']),
  ('res_energy', ['energia', 'pe', 'ep', 'eletric', 'bateria', 'energy']),
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
  final words = _normalize(resourceName).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return null;
  for (final (file, terms) in abyssResourceRules) {
    if (terms.any((term) => _matches(words, term))) return '$abyssResourceArtFolder$file.webp';
  }
  return '$abyssResourceArtFolder$abyssResourceGeneric.webp';
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
    final path = themeId == 'abyss' ? abyssResourceArt(resourceName) : null;
    if (path == null) return fallback;
    final side = math.max(26.0, (size ?? IconTheme.of(context).size ?? 24) * 1.35);
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
