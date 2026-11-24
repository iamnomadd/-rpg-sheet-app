import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/utils/action_art.dart';

String? art(ActionArtKind kind, String name, {String description = '', String category = ''}) {
  final path = ActionArtResolver.resolve(kind: kind, name: name, description: description, category: category);
  return path?.replaceFirst(ActionArtResolver.folder, '').replaceFirst('.webp', '');
}

String? spell(String name, {String description = ''}) => art(ActionArtKind.spell, name, description: description, category: 'Magia');

const _new24 = [
  'spell_arcane', 'spell_curse', 'spell_blessing', 'spell_bind', 'spell_invisibility', 'spell_summon',
  'spell_transform', 'spell_flight', 'spell_vision', 'spell_enchanted_weapon', 'spell_dispel', 'spell_cloud',
  'item_club', 'item_mace', 'item_hammer', 'item_spear', 'item_trident', 'item_grenade',
  'item_scroll', 'item_book', 'item_food', 'item_map', 'item_coins', 'item_torch',
];

void main() {
  group('24 ícones novos (2+ nomes cada)', () {
    final spells = <String, String>{
      'Míssil Arcano': 'spell_arcane', 'Runa Explosiva': 'spell_arcane', 'Sigilo Antigo': 'spell_arcane',
      'Maldição do Pirata': 'spell_curse', 'Praga Negra': 'spell_curse', 'Vodu': 'spell_curse',
      'Bênção': 'spell_blessing', 'Inspiração Heroica': 'spell_blessing', 'Abençoar Aliado': 'spell_blessing',
      'Prender Pessoa': 'spell_bind', 'Teia': 'spell_bind', 'Enredar': 'spell_bind', 'Correntes Espectrais': 'spell_bind',
      'Invisibilidade': 'spell_invisibility', 'Camuflagem': 'spell_invisibility', 'Passo Furtivo': 'spell_invisibility',
      'Invocar Familiar': 'spell_summon', 'Conjurar Elemental': 'spell_summon', 'Convocação': 'spell_summon',
      'Transformação': 'spell_transform', 'Polimorfia': 'spell_transform', 'Disfarçar-se': 'spell_transform', 'Agigantar': 'spell_transform',
      'Voo': 'spell_flight', 'Levitação': 'spell_flight', 'Salto Longo': 'spell_flight',
      'Visão Verdadeira': 'spell_vision', 'Clarividência': 'spell_vision', 'Detectar Magia': 'spell_vision', 'Olho de Águia': 'spell_vision', 'Revelar': 'spell_vision',
      'Arma Mágica': 'spell_enchanted_weapon', 'Arma Espiritual': 'spell_enchanted_weapon', 'Lâmina Fantasma': 'spell_enchanted_weapon',
      'Dissipar Magia': 'spell_dispel', 'Contrafeitiço': 'spell_dispel', 'Banir': 'spell_dispel', 'Exorcismo': 'spell_dispel',
      'Nuvem Mortal': 'spell_death', 'Névoa Obscurecente': 'spell_cloud', 'Neblina': 'spell_cloud', 'Fumaça': 'spell_cloud', 'Miasma': 'spell_cloud',
    };
    for (final e in spells.entries) {
      test('${e.key} → ${e.value}', () => expect(spell(e.key), e.value));
    }

    final weapons = <String, String>{
      'Clava': 'item_club', 'Porrete Pesado': 'item_club',
      'Maça': 'item_mace', 'Maça Estrela': 'item_mace',
      'Martelo de Guerra': 'item_hammer', 'Marreta': 'item_hammer', 'Malho': 'item_hammer',
      'Lança': 'item_spear', 'Pique Longo': 'item_spear',
      'Tridente': 'item_trident', 'Tridente do Mar': 'item_trident',
      'Granada': 'item_grenade', 'Bomba de Pólvora': 'item_grenade',
      'Bordão': 'item_staff',
      'Alabarda': 'item_axe',
    };
    for (final e in weapons.entries) {
      test('arma ${e.key} → ${e.value}', () {
        expect(art(ActionArtKind.weapon, e.key), e.value);
        expect(art(ActionArtKind.item, e.key, category: 'Arma'), e.value);
      });
    }

    final others = <String, String>{
      'Pergaminho Antigo': 'item_scroll', 'Pergaminho de Fogo': 'item_scroll',
      'Livro de Receitas': 'item_book', 'Grimório': 'item_book', 'Tomo Proibido': 'item_book', 'Diário do Capitão': 'item_book',
      'Comida Seca': 'item_food', 'Ração de Viagem': 'item_food', 'Pão': 'item_food', 'Banquete': 'item_food',
      'Mapa do Tesouro': 'item_map', 'Mapa': 'item_map',
      'Moedas de Ouro': 'item_coins', 'Ouro': 'item_coins',
      'Tocha': 'item_torch', 'Lanterna': 'item_torch', 'Lampião': 'item_torch',
      'Bomba': 'item_grenade',
    };
    for (final e in others.entries) {
      test('Outro ${e.key} → ${e.value}', () => expect(art(ActionArtKind.item, e.key, category: 'Outro'), e.value));
    }

    test('itens novos de "Outro" só pelo nome', () {
      expect(art(ActionArtKind.item, 'Estatueta', description: 'Um mapa gravado', category: 'Outro'), isNull);
      expect(art(ActionArtKind.item, 'Estatueta', description: 'Feita de ouro', category: 'Outro'), isNull);
    });
  });

  group('Consumível: granada, pergaminho e comida antes da poção', () {
    final cases = <String, String>{
      'Granada': 'item_grenade', 'Bomba de Fumaça': 'item_grenade',
      'Pergaminho de Cura': 'item_scroll',
      'Comida': 'item_food', 'Fruta Seca': 'item_food', 'Carne Defumada': 'item_food', 'Ração': 'item_food',
      'Poção de Cura': 'item_potion', 'Elixir': 'item_potion', 'Qualquer Coisa': 'item_potion',
    };
    for (final e in cases.entries) {
      test('${e.key} → ${e.value}', () => expect(art(ActionArtKind.item, e.key, category: 'Consumível'), e.value));
    }
  });

  group('radicais novos (só nome)', () {
    final cases = <String, String>{
      'Inferno Ardente': 'spell_fire', 'Infernal': 'spell_fire', 'Abrasar': 'spell_fire', 'Calor Intenso': 'spell_fire', 'Esquentar Metal': 'spell_fire',
      'Choque': 'spell_lightning', 'Chocar': 'spell_lightning',
      'Granizo': 'spell_ice', 'Gelada': 'spell_ice',
      'Nuvem Fétida': 'spell_poison', 'Doença': 'spell_poison', 'Contágio': 'spell_poison', 'Pestilência': 'spell_poison',
      'Reviver': 'spell_heal', 'Ressuscitar': 'spell_heal',
      'Aura Protetora': 'spell_shield', 'Proteger': 'spell_shield', 'Invulnerabilidade': 'spell_shield',
      'Mortalha': 'spell_death', 'Necrótico': 'spell_death',
      'Escuridão Total': 'spell_shadow', 'Escurecer': 'spell_shadow',
      'Chama Sagrada': 'spell_fire', 'Palavra Divina': 'spell_light', 'Feixe Lunar': 'spell_light', 'Radiância': 'spell_light', 'Sagrado': 'spell_light',
      'Onda Trovejante': 'spell_sound', 'Estrondo': 'spell_sound', 'Despedaçar': 'spell_sound',
      'Enfeitiçar': 'spell_mind', 'Hipnose': 'spell_mind', 'Loucura': 'spell_mind', 'Confusão': 'spell_mind', 'Dominar Pessoa': 'spell_mind', 'Pensamento': 'spell_mind', 'Telecinese': 'spell_mind',
      'Praga de Insetos': 'spell_nature', 'Enxame de Insetos': 'spell_nature', 'Árvore Viva': 'spell_nature', 'Fruto Bom': 'spell_nature',
      'Velocidade': 'spell_time',
      'Pavor': 'spell_fear', 'Assustar': 'spell_fear',
    };
    for (final e in cases.entries) {
      test('${e.key} → ${e.value}', () => expect(spell(e.key), e.value));
    }

    test('radicais novos não valem na descrição', () {
      expect(spell('Golpe', description: 'Causa doença no alvo'), 'spell_magic_generic');
      expect(spell('Golpe', description: 'Deixa o alvo em confusão'), 'spell_magic_generic');
      expect(spell('Golpe', description: 'Invoca um aliado'), 'spell_magic_generic');
      expect(spell('Golpe', description: 'Uma nuvem cobre a área'), 'spell_magic_generic');
    });
  });

  group('prioridade e termos fracos', () {
    final cases = <String, String>{
      'Raio de Gelo': 'spell_ice',
      'Raio': 'spell_lightning',
      'Raio Arcano': 'spell_arcane',
      'Onda de Choque': 'spell_lightning',
      'Onda': 'spell_water',
      // 'acido' não casa "ácida" (outra terminação): só o termo fraco 'chuva' casa.
      'Chuva Ácida': 'spell_water',
      'Chuva de Ácido': 'spell_poison',
      'Visão no Escuro': 'spell_shadow',
      'Olho Arcano': 'spell_arcane',
      'Chuva': 'spell_water',
      'Rajada de Vento': 'spell_wind',
      'Rajada': 'spell_wind',
      'Rajada de Fogo': 'spell_fire',
      'Bola de Fogo Arcana': 'spell_fire',
      'Arma Sagrada': 'spell_light',
      'Névoa Tóxica': 'spell_poison',
      'Visão da Morte': 'spell_death',
    };
    for (final e in cases.entries) {
      test('${e.key} → ${e.value}', () => expect(spell(e.key), e.value));
    }

    test('descrição continua como antes (inclui raio/chuva/rajada)', () {
      expect(spell('Golpe', description: 'Dispara um raio'), 'spell_lightning');
      expect(spell('Golpe', description: 'Uma rajada forte'), 'spell_wind');
    });
  });

  group('negativos', () {
    test('nomes comuns sem relação ficam no genérico', () {
      for (final name in ['Rapidamente', 'Golpe Rápido', 'Truque Simples', 'Agarrar', 'Correr']) {
        expect(spell(name), 'spell_magic_generic', reason: name);
      }
      expect(spell('Voz'), 'spell_sound', reason: 'voz continua sendo som pelo nome');
      expect(art(ActionArtKind.item, 'Rapidamente', category: 'Outro'), isNull);
      expect(art(ActionArtKind.item, 'Estatueta velha', category: 'Outro'), isNull);
    });
    test("'lanca' não dispara pela descrição de arma", () {
      expect(art(ActionArtKind.weapon, 'Arma Velha', description: 'Lança o inimigo longe'), 'item_sword');
      expect(art(ActionArtKind.item, 'Arma Velha', description: 'Lança o inimigo longe', category: 'Arma'), 'item_sword');
      expect(art(ActionArtKind.item, 'Coisa', description: 'Lança pedras', category: 'Outro'), isNull);
      expect(art(ActionArtKind.weapon, 'Lança'), 'item_spear');
    });
    test('Passiva e Técnica mantêm o comportamento', () {
      expect(art(ActionArtKind.ability, 'Invocar Familiar', category: 'Passiva'), 'ability_passive');
      expect(art(ActionArtKind.ability, 'Golpe Giratório', category: 'Técnica'), 'ability_technique');
      expect(art(ActionArtKind.ability, 'Passo Furtivo', category: 'Técnica'), 'spell_invisibility');
    });
  });

  test('arquivos: 60 na lista, todos em disco, nenhum sobrando e pending/ removida', () {
    expect(ActionArtResolver.files.length, 60);
    expect(ActionArtResolver.files.toSet().length, 60);
    expect(ActionArtResolver.files, containsAll(_new24));
    final onDisk = Directory('assets/icons/action').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(onDisk, ActionArtResolver.files.map((f) => '$f.webp').toSet());
    for (final file in ActionArtResolver.files) {
      expect(File(ActionArtResolver.path(file)).existsSync(), isTrue, reason: file);
    }
    expect(Directory('assets/icons/pending').existsSync(), isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), contains('    - assets/icons/action/\n'));
  });

  test('todo arquivo que o resolvedor pode devolver está na lista', () {
    final reachable = <String>{
      for (final (f, _) in ActionArtResolver.spellTerms) f,
      for (final (f, _) in ActionArtResolver.newSpellTerms) f,
      for (final (f, _) in ActionArtResolver.weakNameTerms) f,
      for (final (f, _) in ActionArtResolver.weaponTerms) f,
      for (final (f, _) in ActionArtResolver.itemTerms) f,
      for (final (f, _) in ActionArtResolver.newItemTerms) f,
      for (final (f, _) in ActionArtResolver.consumableTerms) f,
      ...ActionArtResolver.nameOnlyExtra.keys,
    };
    expect(ActionArtResolver.files.toSet().containsAll(reachable), isTrue);
    expect(reachable.containsAll(_new24), isTrue, reason: 'todos os 24 novos são alcançáveis');
  });

  group('fora do Abissal o fallback é exato', () {
    const fallback = Icon(Icons.gps_fixed, key: ValueKey('fallback'));
    for (final theme in ['classic', 'parchment', 'vampire', 'cyberpunk', 'ice']) {
      testWidgets(theme, (tester) async {
        await tester.pumpWidget(MaterialApp(home: ActionIconSlot(themeId: theme, artPath: ActionArtResolver.path('spell_arcane'), fallback: fallback)));
        expect(find.byType(Image), findsNothing);
        expect(tester.widget(find.byKey(const ValueKey('fallback'))), same(fallback));
      });
    }
    testWidgets('abyss mostra a arte nova', (tester) async {
      await tester.pumpWidget(MaterialApp(home: ActionIconSlot(themeId: 'abyss', artPath: ActionArtResolver.path('spell_arcane'), fallback: fallback)));
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
