import 'package:flutter/material.dart';

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
