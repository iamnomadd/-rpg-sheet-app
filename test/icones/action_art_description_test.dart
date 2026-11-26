import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/utils/action_art.dart';

String? art(ActionArtKind kind, String name, {String description = '', String category = ''}) {
  final path = ActionArtResolver.resolve(kind: kind, name: name, description: description, category: category);
  return path?.replaceFirst(ActionArtResolver.folder, '').replaceFirst('.webp', '');
}

void main() {
  group('descrição: termos comuns de texto de regra não escolhem a arte', () {
    final cases = <(String, String, String, String)>[
      ('Golpe Furioso', 'Soma 2 ao dano', 'Habilidade', 'spell_magic_generic'),
      ('Golpe Furioso', 'Ataca somente uma vez', 'Habilidade', 'spell_magic_generic'),
      ('Golpe Furioso', 'Ataca somente uma vez', 'Técnica', 'ability_technique'),
      ('Golpe Furioso', 'Dura um tempo curto', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'Ignora o peso da armadura', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'Os inimigos que vinham atrás recuam', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'Com a voz firme', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'À luz do dia', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'Cura 2 pontos', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'Na terra firme', 'Magia', 'spell_magic_generic'),
      ('Golpe Furioso', 'Uma onda de choque', 'Magia', 'spell_lightning'),
    ];
    for (final (name, description, category, expected) in cases) {
      test('"$name" + "$description" ($category) → $expected', () {
        expect(art(ActionArtKind.ability, name, description: description, category: category), expected);
      });
    }
  });

  group('termos específicos continuam valendo na descrição', () {
    test('"Causa hemorragia" → spell_blood', () => expect(art(ActionArtKind.spell, 'Golpe Furioso', description: 'Causa hemorragia', category: 'Magia'), 'spell_blood'));
    test('"Lança uma rajada incendiária" → spell_fire', () => expect(art(ActionArtKind.spell, 'Golpe Furioso', description: 'Lança uma rajada incendiária', category: 'Magia'), 'spell_fire'));
    test('"Um golpe de fogo" → spell_fire', () => expect(art(ActionArtKind.ability, 'Golpe Furioso', description: 'Um golpe de fogo', category: 'Habilidade'), 'spell_fire'));
    test('termos curtos fora da lista (gelo, raio, frio) seguem valendo', () {
      expect(art(ActionArtKind.spell, 'Toque', description: 'Um toque de gelo puro.', category: 'Magia'), 'spell_ice');
      expect(art(ActionArtKind.spell, 'Toque', description: 'Dispara um raio', category: 'Magia'), 'spell_lightning');
      expect(art(ActionArtKind.spell, 'Toque', description: 'Um frio cortante', category: 'Magia'), 'spell_ice');
    });
  });

  group('o NOME continua usando a lista completa', () {
    test('"Som Ensurdecedor" → spell_sound', () => expect(art(ActionArtKind.spell, 'Som Ensurdecedor', category: 'Magia'), 'spell_sound'));
    test('excluídos da descrição valem no nome', () {
      expect(art(ActionArtKind.spell, 'Parar o Tempo', category: 'Magia'), 'spell_time');
      expect(art(ActionArtKind.spell, 'Luz Sagrada', category: 'Magia'), 'spell_light');
      expect(art(ActionArtKind.spell, 'Cura Maior', category: 'Magia'), 'spell_heal');
      expect(art(ActionArtKind.spell, 'Onda Gigante', category: 'Magia'), 'spell_water');
      expect(art(ActionArtKind.spell, 'Peso Esmagador', category: 'Magia'), 'spell_gravity');
      expect(art(ActionArtKind.spell, 'Voz de Comando', category: 'Magia'), 'spell_sound');
      expect(art(ActionArtKind.spell, 'Terra Tremida', category: 'Magia'), 'spell_earth');
    });
    test('a lista de exclusão é exatamente a combinada', () {
      expect(ActionArtResolver.descriptionExcluded, {'som', 'voz', 'luz', 'tempo', 'peso', 'vinha', 'terra', 'cura', 'curar', 'onda', 'agua', 'mare'});
    });
  });
}
