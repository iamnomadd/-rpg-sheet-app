import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Tipo de ação para escolher a ilustração.
enum ActionArtKind { spell, ability, weapon, item }

/// Escolhe uma das 36 ilustrações de `assets/icons/action/` (só usadas no tema
/// Abissal) pelo nome, depois pela descrição e por fim pela categoria.
///
/// Diferente do [SpellIconResolver], um termo só casa no INÍCIO de uma
/// palavra: 'arco' casa "arco longo" e "arcos", mas não "barco"; 'mente' não
/// casa "rapidamente". Nada é salvo: a arte é calculada na hora de exibir.
class ActionArtResolver {
  const ActionArtResolver._();

  static const folder = 'assets/icons/action/';

  /// Os 36 arquivos de arte (sem a pasta).
  static const files = <String>[
    'spell_fire', 'spell_lightning', 'spell_ice', 'spell_poison', 'spell_heal', 'spell_shield',
    'spell_blood', 'spell_death', 'spell_shadow', 'spell_light', 'spell_water', 'spell_wind',
    'spell_earth', 'spell_nature', 'spell_portal', 'spell_sleep', 'spell_fear', 'spell_mind',
    'spell_sound', 'spell_time', 'spell_gravity', 'spell_magic_generic', 'ability_technique',
    'ability_passive', 'item_pistol', 'item_shotgun', 'item_sword', 'item_dagger', 'item_bow',
    'item_axe', 'item_staff', 'item_armor', 'item_potion', 'item_ammo', 'item_accessory', 'item_tool',
  ];

  static String path(String file) => '$folder$file.webp';

  /// Mesmas 21 categorias e na mesma ordem do [SpellIconResolver] ('bras'
  /// trocado por 'brasa'/'brasas').
  static const spellTerms = <(String, List<String>)>[
    ('spell_fire', ['fogo', 'chama', 'incend', 'inferno', 'brasa', 'brasas', 'combust', 'flame', 'fire']),
    ('spell_lightning', ['raio', 'relamp', 'trovao', 'choque', 'eletric', 'lightning', 'thunder']),
    ('spell_ice', ['gelo', 'congel', 'neve', 'nevasca', 'geada', 'frio', 'glacial', 'ice', 'frost']),
    ('spell_poison', ['veneno', 'tox', 'acido', 'corros', 'poison', 'toxic']),
    ('spell_heal', ['cura', 'curar', 'regenera', 'restaura', 'recupera vida', 'heal', 'healing']),
    ('spell_shield', ['escudo', 'barreira', 'protec', 'armadura magica', 'ward', 'shield']),
    ('spell_blood', ['sangue', 'hemorrag', 'blood', 'sangu']),
    ('spell_death', ['morte', 'necrom', 'cadaver', 'morto', 'esqueleto', 'zumbi', 'death', 'undead']),
    ('spell_shadow', ['sombra', 'treva', 'escurid', 'noturno', 'shadow', 'darkness']),
    ('spell_light', ['luz', 'solar', 'sagrado', 'divino', 'radiante', 'holy', 'light', 'radiant']),
    ('spell_water', ['agua', 'onda', 'mare', 'oceano', 'chuva', 'water', 'wave']),
    ('spell_wind', ['vento', 'tornado', 'furacao', 'rajada', 'air', 'wind']),
    ('spell_earth', ['terra', 'pedra', 'rocha', 'terremoto', 'montanha', 'earth', 'stone']),
    ('spell_nature', ['natureza', 'planta', 'raiz', 'espinho', 'vinha', 'floresta', 'nature', 'plant']),
    ('spell_portal', ['portal', 'teleport', 'teleporte', 'dimens', 'transloc', 'blink']),
    ('spell_sleep', ['sono', 'dorm', 'sonho', 'dream', 'sleep']),
    ('spell_fear', ['medo', 'terror', 'panico', 'horror', 'fear']),
    ('spell_mind', ['mente', 'mental', 'psiqu', 'ilus', 'encant', 'telepat', 'mind', 'psychic', 'illusion']),
    ('spell_sound', ['som', 'grito', 'musica', 'voz', 'silencio', 'sound', 'sonic']),
    ('spell_time', ['tempo', 'cron', 'acelera', 'lentidao', 'parar o tempo', 'time']),
    ('spell_gravity', ['gravidade', 'gravit', 'peso', 'gravity']),
  ];

  /// Termos comuns em texto de regra ("Soma 2 ao dano", "somente", "no mesmo
  /// tempo"...) que só valem no NOME, nunca na descrição. Todos os outros
  /// termos (inclusive curtos, como gelo, fogo, raio) valem nos dois.
  static const descriptionExcluded = {'som', 'voz', 'luz', 'tempo', 'peso', 'vinha', 'terra', 'cura', 'curar', 'onda', 'agua', 'mare'};

  static final List<(String, List<String>)> _spellTermsForDescription = [
    for (final (file, terms) in spellTerms) (file, [for (final t in terms) if (!descriptionExcluded.contains(t)) t]),
  ];

  static const weaponTerms = <(String, List<String>)>[
    ('item_pistol', ['pistola', 'revolver', 'garrucha', 'pederneira', 'flintlock', 'pistol']),
    ('item_shotgun', ['escopeta', 'espingarda', 'mosquete', 'arcabuz', 'bacamarte', 'trabuco', 'carabina', 'rifle', 'fuzil', 'musket', 'shotgun']),
    ('item_sword', ['espada', 'sabre', 'cutelo', 'machete', 'alfange', 'florete', 'rapieira', 'cimitarra', 'katana', 'cutlass', 'sword', 'saber']),
    ('item_dagger', ['faca', 'adaga', 'punhal', 'estilete', 'canivete', 'dagger', 'knife']),
    ('item_bow', ['arco', 'besta', 'bow', 'crossbow']),
    ('item_axe', ['machado', 'machadinha', 'tomahawk', 'alabarda', 'axe']),
    ('item_staff', ['cajado', 'bastao', 'varinha', 'cetro', 'staff', 'wand']),
  ];

  static const shieldTerms = ['escudo', 'broquel', 'shield'];
  static const armorTerms = ['armadura', 'couraca', 'peitoral', 'elmo', 'capacete', 'cota de malha', 'armor', 'helmet'];

  static const itemTerms = <(String, List<String>)>[
    ('item_potion', ['pocao', 'elixir', 'frasco', 'tonico', 'antidoto', 'potion']),
    ('item_ammo', ['municao', 'bala', 'balas', 'polvora', 'cartucho', 'projetil']),
    ('item_accessory', ['amuleto', 'anel', 'colar', 'medalhao', 'talisma', 'pingente', 'joia', 'amulet', 'ring']),
    ('item_tool', ['martelo', 'chave', 'ferramenta', 'picareta', 'alicate', 'tool']),
  ];

  /// Caminho do asset ou null (o chamador usa o ícone Material de hoje).
  static String? resolve({required ActionArtKind kind, required String name, String description = '', String category = ''}) {
    final file = _resolveFile(kind, _normalize(name), _normalize(description), category);
    return file == null ? null : path(file);
  }

  static String? _resolveFile(ActionArtKind kind, String name, String description, String category) {
    switch (kind) {
      case ActionArtKind.spell:
      case ActionArtKind.ability:
        if (category == 'Passiva') return 'ability_passive';
        return _first(spellTerms, name) ??
            _first(_spellTermsForDescription, description) ??
            (category == 'Técnica' ? 'ability_technique' : 'spell_magic_generic');
      case ActionArtKind.weapon:
        return _weapon(name, description) ?? 'item_sword';
      case ActionArtKind.item:
        switch (category) {
          case 'Arma':
            return _weapon(name, description) ?? 'item_sword';
          case 'Armadura':
            return _has(name, shieldTerms) || (!_hasAny(name) && _has(description, shieldTerms)) ? 'spell_shield' : 'item_armor';
          case 'Consumível':
            return 'item_potion';
          case 'Munição':
            return 'item_ammo';
          case 'Acessório':
            return 'item_accessory';
          case 'Ferramenta':
            return 'item_tool';
          default:
            return _otherItem(name) ?? _otherItem(description);
        }
    }
  }

  static String? _weapon(String name, String description) => _first(weaponTerms, name) ?? _first(weaponTerms, description);

  static String? _otherItem(String text) {
    final weapon = _first(weaponTerms, text);
    if (weapon != null) return weapon;
    if (_has(text, shieldTerms)) return 'spell_shield';
    if (_has(text, armorTerms)) return 'item_armor';
    return _first(itemTerms, text);
  }

  // Nome "com conteúdo" (qualquer palavra-chave de armadura) decide antes da descrição.
  static bool _hasAny(String name) => _has(name, shieldTerms) || _has(name, armorTerms);

  static String? _first(List<(String, List<String>)> table, String text) {
    if (text.isEmpty) return null;
    for (final (file, terms) in table) {
      if (_has(text, terms)) return file;
    }
    return null;
  }

  /// Casa só no início de palavra (inclusive frases com espaço).
  static bool _has(String text, List<String> terms) {
    for (final term in terms) {
      var index = text.indexOf(term);
      while (index >= 0) {
        if (index == 0 || !_isWordChar(text.codeUnitAt(index - 1))) return true;
        index = text.indexOf(term, index + 1);
      }
    }
    return false;
  }

  static bool _isWordChar(int c) => (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39);

  // Cópia da normalização do SpellIconResolver (minúsculas, sem acentos/cedilha).
  static String _normalize(String value) {
    var text = value.trim().toLowerCase();
    const replacements = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }
}

/// Tamanho da arte: 52 dp no modo normal e 44 dp no compacto.
double actionArtSize(bool compact) => compact ? 44 : 52;

/// No tema Abissal, mostra a ilustração; nos outros temas (ou sem arte),
/// devolve exatamente [fallback], sem envolver em nada.
class ActionIconSlot extends StatelessWidget {
  final String themeId;
  final String? artPath;
  final Widget fallback;
  final double size;

  const ActionIconSlot({super.key, required this.themeId, required this.artPath, required this.fallback, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final art = artPath;
    if (themeId != 'abyss' || art == null) return fallback;
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return Image.asset(
      art,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      cacheWidth: math.min(256, (size * ratio).ceil()),
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
