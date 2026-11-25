// Paletas do design do Abissal por tema (1.3.62): a tabela, o Abissal
// idêntico ao AbyssColors, o contraste mínimo, o id desconhecido e a extensão
// em cada ThemeData.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/abyss_theme.dart';
import 'package:rpg_sheet_app/app/app.dart';
import 'package:rpg_sheet_app/app/theme.dart';

// gold | goldLight | goldDim | cream | creamMuted | bgTop | bgMiddle | bgBottom | bar | card | raised | track | smoke
const _table = <String, List<int>>{
  'classic': [0x9C7CFF, 0xC8B6FF, 0x3E2A7A, 0xECE8F5, 0xA9A3B8, 0x0C0C10, 0x111118, 0x15151D, 0x09090C, 0x17171D, 0x1E1E26, 0x0B0B0F, 0x5A3FA0],
  'parchment': [0xB08A4B, 0xE3C68A, 0x4F3E22, 0xF1E6C8, 0xB5AE9A, 0x050A12, 0x0A1220, 0x0E1826, 0x04080E, 0x151A20, 0x1B222A, 0x070C12, 0x2E4A66],
  'medieval': [0xD9A441, 0xF0CD82, 0x5E4620, 0xF2E8D2, 0xB8AC92, 0x0F0E0B, 0x15130F, 0x1A1813, 0x0B0A08, 0x1C1912, 0x241F17, 0x0D0C09, 0x5A4630],
  'arcane': [0x9C6CFF, 0xCDB3FF, 0x43307A, 0xEEE6FF, 0xACA3C2, 0x0E0B14, 0x130F1B, 0x181322, 0x0A0810, 0x1A1523, 0x221C2D, 0x0C0A11, 0x6B3FA0],
  'vampire': [0xD4231A, 0xFF5C5C, 0x4A0A06, 0xF2E6E6, 0xB3A3A3, 0x000000, 0x07070A, 0x0C0C10, 0x000000, 0x1A1A1D, 0x222226, 0x08080A, 0x5A0A10],
  'forest': [0xB97945, 0xE0AE80, 0x4F3320, 0xF0E4D6, 0xB3A594, 0x0F0B08, 0x15100C, 0x1A1410, 0x0B0806, 0x1B1511, 0x231C16, 0x0D0A07, 0x4A3A22],
  'ocean': [0xDDE6F0, 0xF5F9FC, 0x4A5560, 0xF2F5F8, 0xA9B2BC, 0x0C0E11, 0x111418, 0x161A1F, 0x090B0D, 0x171A1D, 0x1E2226, 0x0B0D0F, 0x5A6B80],
  'cyberpunk': [0x1755FF, 0x6E93FF, 0x0E2A70, 0xE6ECFF, 0x9EA8C2, 0x08090E, 0x0C0E15, 0x10131C, 0x06070B, 0x12141B, 0x191C25, 0x090A0F, 0x1A3A8F],
  'infernal': [0xFD0F04, 0xFF7A4D, 0x5E1008, 0xF5E6DE, 0xB8A39A, 0x100605, 0x160907, 0x1C0C09, 0x0C0504, 0x1D0D0A, 0x26120E, 0x0E0605, 0x7A1A0A],
  'ice': [0x62D8F2, 0xB3EEFA, 0x1E5260, 0xE8F7FB, 0x9FB6BD, 0x071014, 0x0B171C, 0x0F1D23, 0x050C0F, 0x0E1B20, 0x142429, 0x081115, 0x2A6A80],
};

Color _c(int rgb) => Color(0xFF000000 | rgb);

double _luminance(Color c) {
  double channel(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

List<Color> _fields(AbyssPalette p) => [p.gold, p.goldLight, p.goldDim, p.cream, p.creamMuted, p.backgroundTop, p.backgroundMiddle, p.backgroundBottom, p.bar, p.card, p.raised, p.track, p.smoke];

void main() {
  test('há paleta para cada um dos 11 temas', () {
    expect(abyssPalettes.keys.toSet(), appThemes.map((t) => t.id).toSet());
    expect(appThemes, hasLength(11));
  });

  test('tabela A3: cores de cada tema, goldLine (gold a 0xB3), outline preto, vida e energia do Abissal', () {
    for (final e in _table.entries) {
      final p = abyssPaletteFor(e.key);
      expect(_fields(p), e.value.map(_c).toList(), reason: e.key);
      expect(p.goldLine, _c(e.value[0]).withAlpha(0xB3), reason: e.key);
      expect(p.outline, const Color(0xFF000000), reason: e.key);
      expect(p.life, AbyssColors.life, reason: e.key);
      expect(p.energy, AbyssColors.energy, reason: e.key);
    }
  });

  test('a paleta do Abissal é idêntica ao AbyssColors', () {
    final p = abyssPaletteFor('abyss');
    expect(identical(p, AbyssPalette.abyss), isTrue);
    expect(p.backgroundTop, AbyssColors.backgroundTop);
    expect(p.backgroundMiddle, AbyssColors.backgroundMiddle);
    expect(p.backgroundBottom, AbyssColors.backgroundBottom);
    expect(p.bar, AbyssColors.bar);
    expect(p.card, AbyssColors.card);
    expect(p.raised, AbyssColors.raised);
    expect(p.gold, AbyssColors.gold);
    expect(p.goldLight, AbyssColors.goldLight);
    expect(p.goldDim, AbyssColors.goldDim);
    expect(p.goldLine, AbyssColors.goldLine);
    expect(p.cream, AbyssColors.cream);
    expect(p.creamMuted, AbyssColors.creamMuted);
    expect(p.outline, AbyssColors.outline);
    expect(p.track, AbyssColors.track);
    expect(p.smoke, AbyssColors.smoke);
    expect(p.life, AbyssColors.life);
    expect(p.energy, AbyssColors.energy);
  });

  test('contraste mínimo sobre o card: cream ≥ 4,5, gold ≥ 3, creamMuted ≥ 3', () {
    for (final id in abyssPalettes.keys) {
      final p = abyssPaletteFor(id);
      expect(_contrast(p.cream, p.card), greaterThanOrEqualTo(4.5), reason: '$id cream');
      expect(_contrast(p.gold, p.card), greaterThanOrEqualTo(3), reason: '$id gold');
      expect(_contrast(p.creamMuted, p.card), greaterThanOrEqualTo(3), reason: '$id creamMuted');
    }
  });

  test('id desconhecido cai na paleta do Clássico', () {
    expect(abyssPaletteFor('tema-que-nao-existe'), same(abyssPaletteFor('classic')));
    expect(abyssPaletteFor(''), same(abyssPaletteFor('classic')));
    expect(buildTheme('tema-que-nao-existe').extension<AbyssPalette>(), abyssPaletteFor('classic'));
  });

  test('cada ThemeData (buildTheme e buildAppTheme) leva a extensão certa e o ColorScheme da paleta', () {
    for (final preset in appThemes) {
      final p = abyssPaletteFor(preset.id);
      for (final theme in [buildTheme(preset.id), buildAppTheme(preset.id, false), buildAppTheme(preset.id, true)]) {
        expect(theme.extension<AbyssPalette>(), p, reason: preset.id);
        expect(theme.colorScheme.primary, p.gold, reason: preset.id);
        expect(theme.colorScheme.surface, p.card, reason: preset.id);
        expect(theme.colorScheme.onSurface, p.cream, reason: preset.id);
        expect(theme.cardTheme.color, p.card, reason: preset.id);
        expect((theme.cardTheme.shape! as AbyssFrameBorder).innerColor, p.goldLine, reason: preset.id);
      }
    }
  });

  testWidgets('AbyssPalette.of: a extensão do tema, ou a do Abissal sem extensão', (tester) async {
    late AbyssPalette fromTheme;
    late AbyssPalette withoutExtension;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme('ice'),
      home: Builder(builder: (context) {
        fromTheme = AbyssPalette.of(context);
        return Theme(
          data: ThemeData(),
          child: Builder(builder: (context) {
            withoutExtension = AbyssPalette.of(context);
            return const SizedBox();
          }),
        );
      }),
    ));
    expect(fromTheme, abyssPaletteFor('ice'));
    expect(withoutExtension, same(AbyssPalette.abyss));
  });

  test('copyWith e lerp', () {
    final classic = abyssPaletteFor('classic');
    expect(classic.copyWith(), classic);
    expect(classic.copyWith(gold: const Color(0xFF123456)).gold, const Color(0xFF123456));
    expect(classic.lerp(AbyssPalette.abyss, 0), classic);
    expect(classic.lerp(AbyssPalette.abyss, 1), AbyssPalette.abyss);
    expect(classic.lerp(null, .5), same(classic));
  });
}
