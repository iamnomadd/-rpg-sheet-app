from pathlib import Path

SPELL_ICON = r'''import 'package:flutter/material.dart';

/// Escolhe um ícone de magia pelo nome e, como fallback, pela descrição.
/// Funciona totalmente offline para manter a seleção instantânea no PWA.
class SpellIconResolver {
  const SpellIconResolver._();

  static IconData resolve(String name, {String description = ''}) {
    final title = _normalize(name);
    final body = _normalize(description);
    return _match(title) ?? _match(body) ?? Icons.auto_awesome_outlined;
  }

  static IconData? _match(String text) {
    if (text.isEmpty) return null;
    if (_has(text, const ['fogo','chama','incend','inferno','bras','combust','flame','fire'])) return Icons.local_fire_department_outlined;
    if (_has(text, const ['raio','relamp','trovao','choque','eletric','lightning','thunder'])) return Icons.bolt;
    if (_has(text, const ['gelo','congel','neve','nevasca','geada','frio','glacial','ice','frost'])) return Icons.ac_unit;
    if (_has(text, const ['veneno','tox','acido','corros','poison','toxic'])) return Icons.science_outlined;
    if (_has(text, const ['cura','curar','regenera','restaura','recupera vida','heal','healing'])) return Icons.healing;
    if (_has(text, const ['escudo','barreira','protec','armadura magica','ward','shield'])) return Icons.shield_outlined;
    if (_has(text, const ['sangue','hemorrag','blood','sangu'])) return Icons.bloodtype_outlined;
    if (_has(text, const ['morte','necrom','cadaver','morto','esqueleto','zumbi','death','undead'])) return Icons.dangerous_outlined;
    if (_has(text, const ['sombra','treva','escurid','noturno','shadow','darkness'])) return Icons.nights_stay_outlined;
    if (_has(text, const ['luz','solar','sagrado','divino','radiante','holy','light','radiant'])) return Icons.wb_sunny_outlined;
    if (_has(text, const ['agua','onda','mare','oceano','chuva','water','wave'])) return Icons.water_drop_outlined;
    if (_has(text, const ['vento','tornado','furacao','rajada','air','wind'])) return Icons.air;
    if (_has(text, const ['terra','pedra','rocha','terremoto','montanha','earth','stone'])) return Icons.landscape_outlined;
    if (_has(text, const ['natureza','planta','raiz','espinho','vinha','floresta','nature','plant'])) return Icons.eco_outlined;
    if (_has(text, const ['portal','teleport','teleporte','dimens','transloc','blink'])) return Icons.blur_circular;
    if (_has(text, const ['sono','dorm','sonho','dream','sleep'])) return Icons.bedtime_outlined;
    if (_has(text, const ['medo','terror','panico','horror','fear'])) return Icons.warning_amber_rounded;
    if (_has(text, const ['mente','mental','psiqu','ilus','encant','telepat','mind','psychic','illusion'])) return Icons.psychology_outlined;
    if (_has(text, const ['som','grito','musica','voz','silencio','sound','sonic'])) return Icons.graphic_eq;
    if (_has(text, const ['tempo','cron','acelera','lentidao','parar o tempo','time'])) return Icons.schedule_outlined;
    if (_has(text, const ['gravidade','gravit','peso','gravity'])) return Icons.public;
    return null;
  }

  static bool _has(String text, List<String> terms) => terms.any(text.contains);

  static String _normalize(String value) {
    var text = value.trim().toLowerCase();
    const replacements = {
      'á':'a','à':'a','â':'a','ã':'a','ä':'a','é':'e','è':'e','ê':'e','ë':'e',
      'í':'i','ì':'i','î':'i','ï':'i','ó':'o','ò':'o','ô':'o','õ':'o','ö':'o',
      'ú':'u','ù':'u','û':'u','ü':'u','ç':'c',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }
}
'''

root = Path(__file__).resolve().parents[1]
(root / 'lib/utils/spell_icon.dart').write_text(SPELL_ICON, encoding='utf-8')

p = root / 'lib/screens/character/character_screen.dart'
s = p.read_text(encoding='utf-8')
if "import '../../utils/spell_icon.dart';" not in s:
    s = s.replace("import '../../utils/resource_math.dart';", "import '../../utils/resource_math.dart';\nimport '../../utils/spell_icon.dart';")

s = s.replace(
    "              Icon(groupIcon, size: 20, color: Theme.of(context).colorScheme.primary),",
    "              Icon(\n                id == 'spells'\n                    ? SpellIconResolver.resolve(name, description: c.abilityDescriptions[name] ?? '')\n                    : groupIcon,\n                size: 20,\n                color: Theme.of(context).colorScheme.primary,\n              ),",
)
s = s.replace(
    "                icon: Icon(id == 'weapons' ? Icons.gps_fixed : id == 'spells' ? Icons.auto_awesome : Icons.play_arrow, size: 17),",
    "                icon: Icon(\n                  id == 'weapons'\n                      ? Icons.gps_fixed\n                      : id == 'spells'\n                          ? SpellIconResolver.resolve(name, description: c.abilityDescriptions[name] ?? '')\n                          : Icons.play_arrow,\n                  size: 17,\n                ),",
)
old_item = "  IconData _itemIcon(String category){if(widget.isAbility)return category=='Magia'?Icons.auto_awesome_outlined:category=='Técnica'?Icons.sports_martial_arts:Icons.bolt_outlined;return switch(category){'Arma'=>Icons.gps_fixed,'Armadura'=>Icons.shield_outlined,'Consumível'=>Icons.local_drink_outlined,'Munição'=>Icons.more_horiz,'Acessório'=>Icons.diamond_outlined,'Ferramenta'=>Icons.build_outlined,_=>Icons.inventory_2_outlined};}"
new_item = """  IconData _itemIcon(String category, {String name = '', String description = ''}) {
    if (widget.isAbility) {
      if (category == 'Magia') return SpellIconResolver.resolve(name, description: description);
      return category == 'Técnica' ? Icons.sports_martial_arts : Icons.bolt_outlined;
    }
    return switch (category) {
      'Arma' => Icons.gps_fixed,
      'Armadura' => Icons.shield_outlined,
      'Consumível' => Icons.local_drink_outlined,
      'Munição' => Icons.more_horiz,
      'Acessório' => Icons.diamond_outlined,
      'Ferramenta' => Icons.build_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }"""
s = s.replace(old_item, new_item)
s = s.replace(
    "child: Icon(_itemIcon(category), size: compact ? 19 : 21, color: scheme.primary),",
    "child: Icon(\n                        _itemIcon(category, name: name, description: widget.descriptions[name] ?? ''),\n                        size: compact ? 19 : 21,\n                        color: scheme.primary,\n                      ),",
)
p.write_text(s, encoding='utf-8')

p = root / 'lib/screens/character/combat_tab.dart'
s = p.read_text(encoding='utf-8')
if "import '../../utils/spell_icon.dart';" not in s:
    s = s.replace("import '../../services/local_image_provider.dart';", "import '../../services/local_image_provider.dart';\nimport '../../utils/spell_icon.dart';")
s = s.replace(
    "                leading: const Icon(Icons.auto_awesome),",
    "                leading: Icon(\n                  SpellIconResolver.resolve(spell, description: widget.character.abilityDescriptions[spell] ?? ''),\n                  color: Theme.of(context).colorScheme.primary,\n                ),",
)
p.write_text(s, encoding='utf-8')

p = root / 'lib/screens/campaigns/npc_sheet_screen.dart'
s = p.read_text(encoding='utf-8')
if "import '../../utils/spell_icon.dart';" not in s:
    s = s.replace("import '../../utils/resource_math.dart';", "import '../../utils/resource_math.dart';\nimport '../../utils/spell_icon.dart';")
s = s.replace(
    "      ...sheet.abilities.map((name) { final d = sheet.abilityDetails[name] ?? {}; return Card(child: ListTile(\n        leading: const Icon(Icons.auto_awesome),",
    "      ...sheet.abilities.map((name) { final d = sheet.abilityDetails[name] ?? {}; final isSpell = d['category'] == 'Magia'; return Card(child: ListTile(\n        leading: Icon(\n          isSpell ? SpellIconResolver.resolve(name, description: sheet.abilityDescriptions[name] ?? '') : Icons.auto_awesome,\n          color: Theme.of(context).colorScheme.primary,\n        ),",
)
p.write_text(s, encoding='utf-8')

p = root / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.16+116', 'version: 1.3.17+117')
p.write_text(s, encoding='utf-8')

p = root / 'lib/core/app_version.dart'
s = p.read_text(encoding='utf-8').replace("appVersion = '1.3.16'", "appVersion = '1.3.17'").replace('appBuildNumber = 115', 'appBuildNumber = 117').replace('appBuildNumber = 116', 'appBuildNumber = 117')
p.write_text(s, encoding='utf-8')

p = root / 'web/rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("VERSION='1.3.16+116'", "VERSION='1.3.17+117'")
p.write_text(s, encoding='utf-8')

p = root / 'README.md'
s = p.read_text(encoding='utf-8').replace('V1.3.16 (Web/PWA)', 'V1.3.17 (Web/PWA)').replace('**1.3.16+116**', '**1.3.17+117**').replace('`RELEASE_NOTES_1.3.16.md`', '`RELEASE_NOTES_1.3.17.md`')
p.write_text(s, encoding='utf-8')

(root / 'RELEASE_NOTES_1.3.17.md').write_text('''# RPG Sheet 1.3.17+117 — Ícones automáticos de magias\n\n- Magias escolhem ícones automaticamente pelo nome e, como fallback, pela descrição.\n- Inclui fogo, eletricidade, gelo, veneno/ácido, cura, proteção, sangue, morte/necromancia, sombras, luz/sagrado, água, vento, terra, natureza, portal/teleporte, sono, medo, mente/ilusão, som, tempo e gravidade.\n- Se nenhuma categoria for reconhecida, permanece o ícone genérico de magia.\n- A cor continua vindo do tema ativo.\n- Aplicado na ficha do jogador, combate e fichas de NPC do Mestre.\n''', encoding='utf-8')
