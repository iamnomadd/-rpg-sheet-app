import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/screens/character/character_sprites.dart';

const _poses = ['incapacitated', 'critical', 'agony', 'normal'];

const _defaultSprites = {
  'incapacitated': 'assets/character2d/incapacitated.png',
  'critical': 'assets/character2d/normal.png',
  'agony': 'assets/character2d/agony.png',
  'normal': 'assets/character2d/normal.png',
};

/// Tabela esperada tema × pose → sprite. Deve ficar idêntica entre a lógica
/// antiga (ternários) e a nova (mapa).
const _expected = <String, Map<String, String>>{
  'classic': _defaultSprites,
  'parchment': {
    'incapacitated': 'assets/character2d/pirate_incapacitated.webp',
    'critical': 'assets/character2d/pirate_critical_new.webp',
    'agony': 'assets/character2d/pirate_critical.webp',
    'normal': 'assets/character2d/pirate_normal.webp',
  },
  'medieval': _defaultSprites,
  'arcane': _defaultSprites,
  'vampire': {
    'incapacitated': 'assets/character2d/vampiric_incapacitated.png',
    'critical': 'assets/character2d/vampiric_critical.png',
    'agony': 'assets/character2d/vampiric_agony.png',
    'normal': 'assets/character2d/vampiric_normal.png',
  },
  'forest': _defaultSprites,
  'ocean': _defaultSprites,
  'cyberpunk': {
    'incapacitated': 'assets/character2d/cyberpunk_incapacitated.png',
    'critical': 'assets/character2d/cyberpunk_critical.png',
    'agony': 'assets/character2d/cyberpunk_agony.png',
    'normal': 'assets/character2d/cyberpunk_normal.png',
  },
  'infernal': _defaultSprites,
  'ice': _defaultSprites,
  'tema-desconhecido': _defaultSprites,
};

String _pose(int life, int lifeMax, {bool negative = false}) =>
    characterPoseFor(life: life, lifeMax: lifeMax, hasNegativeStatus: negative);

void main() {
  group('pose por vida', () {
    test('vida <= 0 é incapacitado', () {
      expect(_pose(0, 100), 'incapacitated');
      expect(_pose(0, 100, negative: true), 'incapacitated');
      expect(_pose(-5, 100), 'incapacitated');
      expect(_pose(0, 0), 'incapacitated');
    });

    test('até 30% é crítico', () {
      expect(_pose(1, 100), 'critical');
      expect(_pose(30, 100), 'critical');
      expect(_pose(3, 10), 'critical');
      expect(_pose(30, 100, negative: true), 'critical');
    });

    test('de 31% a 40% é agony', () {
      expect(_pose(31, 100), 'agony');
      expect(_pose(40, 100), 'agony');
      expect(_pose(4, 10), 'agony');
    });

    test('acima de 40% é normal, ou agony com status negativo', () {
      expect(_pose(41, 100), 'normal');
      expect(_pose(41, 100, negative: true), 'agony');
      expect(_pose(100, 100), 'normal');
      expect(_pose(100, 100, negative: true), 'agony');
    });

    test('vida acima do máximo é tratada como 100%', () {
      expect(_pose(150, 100), 'normal');
    });

    test('sem vida máxima a razão é 1.0', () {
      expect(_pose(10, 0), 'normal');
      expect(_pose(10, 0, negative: true), 'agony');
    });
  });

  group('sprite por tema', () {
    test('a tabela cobre os 10 temas e um tema desconhecido', () {
      expect(_expected.keys, hasLength(11));
    });

    for (final theme in _expected.entries) {
      test('tema ${theme.key}', () {
        for (final pose in _poses) {
          expect(characterSpritePath(themeId: theme.key, pose: pose), theme.value[pose], reason: '${theme.key}/$pose');
        }
      });
    }

    test('temas padrão usam normal.png no crítico', () {
      expect(characterSpritePath(themeId: 'classic', pose: 'critical'), 'assets/character2d/normal.png');
    });

    test('todos os sprites esperados existem em disco', () {
      final paths = _expected.values.expand((m) => m.values).toSet();
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('só Pirata, Cyberpunk e Vampírico usam sprite próprio', () {
      final special = _expected.keys.where(characterUsesSpecialSprite).toSet();
      expect(special, {'parchment', 'cyberpunk', 'vampire'});
    });

    test('pubspec.yaml declara assets/character2d/', () {
      final pubspec = File('pubspec.yaml').readAsLinesSync().map((l) => l.trim());
      expect(pubspec, contains('- assets/character2d/'));
    });
  });
}
