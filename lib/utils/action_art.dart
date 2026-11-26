import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/abyss_art_size.dart';

/// Tipo de ação para escolher a ilustração.
enum ActionArtKind { spell, ability, weapon, item }

/// Escolhe uma das 60 ilustrações de `assets/icons/action/` (só usadas no tema
/// Abissal) pelo nome, depois pela descrição e por fim pela categoria.
///
/// Um termo só casa no INÍCIO de uma palavra: 'arco' casa "arco longo" e "arcos", mas não "barco"; 'mente' não
/// casa "rapidamente". Nada é salvo: a arte é calculada na hora de exibir.
class ActionArtResolver {
  const ActionArtResolver._();

  static const folder = 'assets/icons/action/';

  /// Os 60 arquivos de arte (sem a pasta): os 36 originais + 24 novos.
  static const files = <String>[
    'spell_fire', 'spell_lightning', 'spell_ice', 'spell_poison', 'spell_heal', 'spell_shield',
    'spell_blood', 'spell_death', 'spell_shadow', 'spell_light', 'spell_water', 'spell_wind',
    'spell_earth', 'spell_nature', 'spell_portal', 'spell_sleep', 'spell_fear', 'spell_mind',
    'spell_sound', 'spell_time', 'spell_gravity', 'spell_magic_generic', 'ability_technique',
    'ability_passive', 'item_pistol', 'item_shotgun', 'item_sword', 'item_dagger', 'item_bow',
    'item_axe', 'item_staff', 'item_armor', 'item_potion', 'item_ammo', 'item_accessory', 'item_tool',
    // 24 novos
    'spell_arcane', 'spell_curse', 'spell_blessing', 'spell_bind', 'spell_invisibility', 'spell_summon',
    'spell_transform', 'spell_flight', 'spell_vision', 'spell_enchanted_weapon', 'spell_dispel', 'spell_cloud',
    'item_club', 'item_mace', 'item_hammer', 'item_spear', 'item_trident', 'item_grenade',
    'item_scroll', 'item_book', 'item_food', 'item_map', 'item_coins', 'item_torch',
  ];

  static String path(String file) => '$folder$file.webp';

  /// As 21 categorias de magia, na ordem do antigo detector de ícones
  /// (removido na 1.3.69; 'bras' trocado por 'brasa'/'brasas').
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

  /// Termos fracos no NOME: só valem se nenhuma outra categoria casar
  /// ("Raio de Gelo" é gelo; "Raio" sozinho é raio).
  static const weakNameTerms = <(String, List<String>)>[
    ('spell_lightning', ['raio']),
    ('spell_water', ['onda', 'chuva']),
    ('spell_wind', ['rajada']),
  ];

  /// Radicais a mais por categoria, só para o NOME (nunca a descrição).
  static const nameOnlyExtra = <String, List<String>>{
    'spell_fire': ['infern', 'abras', 'ardent', 'esquent', 'calor'],
    'spell_lightning': ['choc'],
    'spell_ice': ['granizo', 'gelad'],
    'spell_poison': ['fetid', 'doenc', 'contag', 'pestil', 'acid'],
    'spell_heal': ['reviv', 'ressusc'],
    'spell_shield': ['protet', 'proteg', 'invulner'],
    'spell_death': ['mort', 'necrot'],
    'spell_shadow': ['escur'],
    'spell_light': ['sagrad', 'divin', 'lunar', 'radian'],
    'spell_sound': ['trovej', 'estrond', 'despedac'],
    'spell_mind': ['enfeit', 'hipno', 'loucur', 'confus', 'domin', 'pensament', 'telecin'],
    'spell_nature': ['inset', 'arvore', 'fruto'],
    'spell_time': ['velocid'],
    'spell_fear': ['pavor', 'assust'],
  };

  /// Categorias novas de magia: só pelo NOME, depois das de elemento.
  static const newSpellTerms = <(String, List<String>)>[
    ('spell_arcane', ['arcan', 'missil', 'misseis', 'runa', 'sigilo']),
    ('spell_curse', ['maldi', 'maleficio', 'praga', 'bruxar', 'vodu']),
    ('spell_blessing', ['bencao', 'abenco', 'bendi', 'benzer', 'inspir']),
    ('spell_bind', ['prend', 'algema', 'enred', 'amarr', 'imobiliz', 'teia', 'corrent']),
    ('spell_invisibility', ['invisi', 'camufl', 'furtiv']),
    ('spell_summon', ['invoc', 'conjur', 'convoc', 'familiar']),
    ('spell_transform', ['transform', 'metamorf', 'polimorf', 'disfarc', 'encolh', 'agigant']),
    ('spell_flight', ['voo', 'voar', 'voand', 'flutu', 'levit', 'salto', 'pulo']),
    ('spell_vision', ['visao', 'enxerg', 'olho', 'clarivid', 'detect', 'revel', 'adivinh', 'vidente', 'visao no escuro']),
    ('spell_enchanted_weapon', ['arma magica', 'arma sagrada', 'arma espiritual', 'arma elemental', 'lamina']),
    ('spell_dispel', ['dissip', 'anul', 'contrafeit', 'neutraliz', 'banir', 'banim', 'purific', 'exorc', 'desfaz']),
    ('spell_cloud', ['nuvem', 'nevoa', 'neblina', 'fumaca', 'bruma', 'miasma']),
  ];

  /// Elementos para o NOME: os termos de sempre (sem os fracos) + os radicais
  /// só de nome.
  static final List<(String, List<String>)> _spellTermsForName = [
    for (final (file, terms) in spellTerms)
      (file, [
        for (final t in terms)
          if (!weakNameTerms.any((weak) => weak.$2.contains(t))) t,
        ...?nameOnlyExtra[file],
      ]),
  ];

  /// Expressões (termos com espaço) das categorias novas: avaliadas ANTES dos
  /// elementos ("Arma Sagrada" é arma encantada, não luz).
  static final List<(String, List<String>)> _newSpellPhrases = [
    for (final (file, terms) in newSpellTerms) (file, [for (final t in terms) if (t.contains(' ')) t]),
  ];

  /// Elementos no nome de HABILIDADES: sem o radical 'mort' ("Golpe Mortal"
  /// não é magia de morte).
  static final List<(String, List<String>)> _abilityTermsForName = [
    for (final (file, terms) in _spellTermsForName) (file, [for (final t in terms) if (t != 'mort') t]),
  ];

  static const weaponTerms = <(String, List<String>)>[
    ('item_pistol', ['pistola', 'revolver', 'garrucha', 'pederneira', 'flintlock', 'pistol']),
    ('item_shotgun', ['escopeta', 'espingarda', 'mosquete', 'arcabuz', 'bacamarte', 'trabuco', 'carabina', 'rifle', 'fuzil', 'musket', 'shotgun']),
    ('item_sword', ['espada', 'sabre', 'cutelo', 'machete', 'alfange', 'florete', 'rapieira', 'cimitarra', 'katana', 'cutlass', 'sword', 'saber']),
    ('item_dagger', ['faca', 'adaga', 'punhal', 'estilete', 'canivete', 'dagger', 'knife']),
    ('item_bow', ['arco', 'besta', 'bow', 'crossbow']),
    ('item_axe', ['machado', 'machadinha', 'tomahawk', 'alabarda', 'axe']),
    ('item_staff', ['cajado', 'bastao', 'varinha', 'cetro', 'staff', 'wand', 'bordao']),
    // Novas (depois das que já existiam).
    ('item_club', ['clava', 'porrete', 'cacete']),
    ('item_mace', ['maca']),
    ('item_hammer', ['martelo', 'marreta', 'malho']),
    ('item_spear', ['lanca', 'pique']),
    ('item_trident', ['tridente']),
    ('item_grenade', ['granada', 'bomba']),
  ];

  /// Na descrição de armas, 'lanca' não vale ("lança uma rajada"...).
  static final List<(String, List<String>)> _weaponTermsForDescription = [
    for (final (file, terms) in weaponTerms) (file, [for (final t in terms) if (t != 'lanca') t]),
  ];

  /// Itens novos de "Outro", só pelo NOME.
  static const newItemTerms = <(String, List<String>)>[
    ('item_scroll', ['pergaminho']),
    ('item_book', ['livro', 'grimorio', 'tomo', 'diario']),
    ('item_food', ['comida', 'racao', 'pao', 'fruta', 'carne', 'banquete']),
    ('item_map', ['mapa']),
    ('item_torch', ['tocha', 'lanterna', 'lampiao']),
    ('item_coins', ['moeda', 'ouro']),
  ];

  /// Consumíveis: checados pelo NOME antes do ícone genérico de poção.
  static const consumableTerms = <(String, List<String>)>[
    ('item_grenade', ['granada', 'bomba']),
    ('item_scroll', ['pergaminho']),
    ('item_food', ['comida', 'racao', 'pao', 'fruta', 'carne', 'banquete']),
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
        return _first(_newSpellPhrases, name) ??
            _first(kind == ActionArtKind.ability ? _abilityTermsForName : _spellTermsForName, name) ??
            _first(newSpellTerms, name) ??
            _first(weakNameTerms, name) ??
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
            return _first(consumableTerms, name) ?? 'item_potion';
          case 'Munição':
            return 'item_ammo';
          case 'Acessório':
            return 'item_accessory';
          case 'Ferramenta':
            return 'item_tool';
          default:
            return _otherItem(name, isName: true) ?? _otherItem(description, isName: false);
        }
    }
  }

  static String? _weapon(String name, String description) => _first(weaponTerms, name) ?? _first(_weaponTermsForDescription, description);

  static String? _otherItem(String text, {required bool isName}) {
    final weapon = _first(isName ? weaponTerms : _weaponTermsForDescription, text);
    if (weapon != null) return weapon;
    if (_has(text, shieldTerms)) return 'spell_shield';
    if (_has(text, armorTerms)) return 'item_armor';
    return _first(itemTerms, text) ?? (isName ? _first(newItemTerms, text) : null);
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

  // Normalização: minúsculas, sem acentos/cedilha.
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
double actionArtSize(bool compact) => abyssArtIconSize(compact);

/// Mostra a ilustração (design do Abissal, em todos os temas); sem arte, devolve exatamente [fallback], sem envolver
/// em nada.
class ActionIconSlot extends StatelessWidget {
  final String themeId;
  final String? artPath;
  final Widget fallback;

  /// Lado da arte; os chamadores passam [actionArtSize] (compacto ou não).
  final double size;

  const ActionIconSlot({super.key, required this.themeId, required this.artPath, required this.fallback, required this.size});

  @override
  Widget build(BuildContext context) {
    final art = artPath;
    if (art == null) return fallback;
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
