// Design do tema Abissal (id 'abyss') — desde a 1.3.62 é o design PADRÃO de
// todos os temas: cada tema muda só a paleta ([AbyssPalette],
// [abyssPaletteFor]); o design antigo dos outros temas foi removido na
// 1.3.63. Os ornamentos são originais,
// desenhados em código (Path/CustomPainter/ShapeBorder); sem imagens nem
// fontes novas.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paleta do tema Abissal.
abstract final class AbyssColors {
  static const backgroundTop = Color(0xFF05080D);
  static const backgroundMiddle = Color(0xFF0A1118);
  static const backgroundBottom = Color(0xFF0E161C);
  static const bar = Color(0xFF080D12);
  static const card = Color(0xFF10171C);
  static const raised = Color(0xFF151E24);
  static const gold = Color(0xFFC9A24A);
  static const goldLight = Color(0xFFE9CF86);
  static const goldDim = Color(0xFF5E4D2A);

  /// Dourado a 70%: borda de campo e divisores (>= 3:1 contra o fundo).
  static const goldLine = Color(0xB3C9A24A);
  static const cream = Color(0xFFF1E6C8);
  static const creamMuted = Color(0xFFB5AE9A);
  static const outline = Color(0xFF000000);
  static const life = [Color(0xFF8F1B1B), Color(0xFFD93A3A)];
  static const energy = [Color(0xFF2D5F96), Color(0xFF5A9BDA)];
  static const track = Color(0xFF0A1015);
  static const smoke = Color(0xFF6B3FA0);
}

/// Paleta do design do Abissal para um tema (os mesmos campos de
/// [AbyssColors]). Fica no `ThemeData` como extensão; os widgets e pintores do
/// design leem com [AbyssPalette.of].
@immutable
class AbyssPalette extends ThemeExtension<AbyssPalette> {
  final Color backgroundTop;
  final Color backgroundMiddle;
  final Color backgroundBottom;
  final Color bar;
  final Color card;
  final Color raised;

  /// Destaque e moldura.
  final Color gold;
  final Color goldLight;
  final Color goldDim;

  /// [gold] a 70% (borda de campo e divisores).
  final Color goldLine;

  /// Texto.
  final Color cream;
  final Color creamMuted;
  final Color outline;
  final Color track;
  final Color smoke;
  final List<Color> life;
  final List<Color> energy;

  const AbyssPalette({
    required this.backgroundTop,
    required this.backgroundMiddle,
    required this.backgroundBottom,
    required this.bar,
    required this.card,
    required this.raised,
    required this.gold,
    required this.goldLight,
    required this.goldDim,
    required this.goldLine,
    required this.cream,
    required this.creamMuted,
    required this.outline,
    required this.track,
    required this.smoke,
    required this.life,
    required this.energy,
  });

  /// A paleta do Abissal: exatamente os valores de [AbyssColors].
  static const abyss = AbyssPalette(
    backgroundTop: AbyssColors.backgroundTop,
    backgroundMiddle: AbyssColors.backgroundMiddle,
    backgroundBottom: AbyssColors.backgroundBottom,
    bar: AbyssColors.bar,
    card: AbyssColors.card,
    raised: AbyssColors.raised,
    gold: AbyssColors.gold,
    goldLight: AbyssColors.goldLight,
    goldDim: AbyssColors.goldDim,
    goldLine: AbyssColors.goldLine,
    cream: AbyssColors.cream,
    creamMuted: AbyssColors.creamMuted,
    outline: AbyssColors.outline,
    track: AbyssColors.track,
    smoke: AbyssColors.smoke,
    life: AbyssColors.life,
    energy: AbyssColors.energy,
  );

  /// A paleta do tema atual; sem a extensão no tema, a do Abissal.
  static AbyssPalette of(BuildContext context) => Theme.of(context).extension<AbyssPalette>() ?? abyss;

  @override
  AbyssPalette copyWith({
    Color? backgroundTop,
    Color? backgroundMiddle,
    Color? backgroundBottom,
    Color? bar,
    Color? card,
    Color? raised,
    Color? gold,
    Color? goldLight,
    Color? goldDim,
    Color? goldLine,
    Color? cream,
    Color? creamMuted,
    Color? outline,
    Color? track,
    Color? smoke,
    List<Color>? life,
    List<Color>? energy,
  }) =>
      AbyssPalette(
        backgroundTop: backgroundTop ?? this.backgroundTop,
        backgroundMiddle: backgroundMiddle ?? this.backgroundMiddle,
        backgroundBottom: backgroundBottom ?? this.backgroundBottom,
        bar: bar ?? this.bar,
        card: card ?? this.card,
        raised: raised ?? this.raised,
        gold: gold ?? this.gold,
        goldLight: goldLight ?? this.goldLight,
        goldDim: goldDim ?? this.goldDim,
        goldLine: goldLine ?? this.goldLine,
        cream: cream ?? this.cream,
        creamMuted: creamMuted ?? this.creamMuted,
        outline: outline ?? this.outline,
        track: track ?? this.track,
        smoke: smoke ?? this.smoke,
        life: life ?? this.life,
        energy: energy ?? this.energy,
      );

  @override
  AbyssPalette lerp(covariant ThemeExtension<AbyssPalette>? other, double t) {
    if (other is! AbyssPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => [for (var i = 0; i < a.length && i < b.length; i++) c(a[i], b[i])];
    return AbyssPalette(
      backgroundTop: c(backgroundTop, other.backgroundTop),
      backgroundMiddle: c(backgroundMiddle, other.backgroundMiddle),
      backgroundBottom: c(backgroundBottom, other.backgroundBottom),
      bar: c(bar, other.bar),
      card: c(card, other.card),
      raised: c(raised, other.raised),
      gold: c(gold, other.gold),
      goldLight: c(goldLight, other.goldLight),
      goldDim: c(goldDim, other.goldDim),
      goldLine: c(goldLine, other.goldLine),
      cream: c(cream, other.cream),
      creamMuted: c(creamMuted, other.creamMuted),
      outline: c(outline, other.outline),
      track: c(track, other.track),
      smoke: c(smoke, other.smoke),
      life: l(life, other.life),
      energy: l(energy, other.energy),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AbyssPalette &&
      other.backgroundTop == backgroundTop &&
      other.backgroundMiddle == backgroundMiddle &&
      other.backgroundBottom == backgroundBottom &&
      other.bar == bar &&
      other.card == card &&
      other.raised == raised &&
      other.gold == gold &&
      other.goldLight == goldLight &&
      other.goldDim == goldDim &&
      other.goldLine == goldLine &&
      other.cream == cream &&
      other.creamMuted == creamMuted &&
      other.outline == outline &&
      other.track == track &&
      other.smoke == smoke &&
      listEquals(other.life, life) &&
      listEquals(other.energy, energy);

  @override
  int get hashCode => Object.hashAll([backgroundTop, backgroundMiddle, backgroundBottom, bar, card, raised, gold, goldLight, goldDim, goldLine, cream, creamMuted, outline, track, smoke, ...life, ...energy]);
}

AbyssPalette _palette({
  required int gold,
  required int goldLight,
  required int goldDim,
  required int cream,
  required int creamMuted,
  required int bgTop,
  required int bgMiddle,
  required int bgBottom,
  required int bar,
  required int card,
  required int raised,
  required int track,
  required int smoke,
}) =>
    AbyssPalette(
      backgroundTop: Color(bgTop),
      backgroundMiddle: Color(bgMiddle),
      backgroundBottom: Color(bgBottom),
      bar: Color(bar),
      card: Color(card),
      raised: Color(raised),
      gold: Color(gold),
      goldLight: Color(goldLight),
      goldDim: Color(goldDim),
      goldLine: Color(gold).withAlpha(0xB3),
      cream: Color(cream),
      creamMuted: Color(creamMuted),
      outline: const Color(0xFF000000),
      track: Color(track),
      smoke: Color(smoke),
      life: AbyssColors.life,
      energy: AbyssColors.energy,
    );

/// Paletas dos temas (ids desconhecidos → a do 'classic').
final Map<String, AbyssPalette> abyssPalettes = {
  'abyss': AbyssPalette.abyss,
  'classic': _palette(gold: 0xFF9C7CFF, goldLight: 0xFFC8B6FF, goldDim: 0xFF3E2A7A, cream: 0xFFECE8F5, creamMuted: 0xFFA9A3B8, bgTop: 0xFF0C0C10, bgMiddle: 0xFF111118, bgBottom: 0xFF15151D, bar: 0xFF09090C, card: 0xFF17171D, raised: 0xFF1E1E26, track: 0xFF0B0B0F, smoke: 0xFF5A3FA0),
  'parchment': _palette(gold: 0xFFB08A4B, goldLight: 0xFFE3C68A, goldDim: 0xFF4F3E22, cream: 0xFFF1E6C8, creamMuted: 0xFFB5AE9A, bgTop: 0xFF050A12, bgMiddle: 0xFF0A1220, bgBottom: 0xFF0E1826, bar: 0xFF04080E, card: 0xFF151A20, raised: 0xFF1B222A, track: 0xFF070C12, smoke: 0xFF2E4A66),
  'medieval': _palette(gold: 0xFFD9A441, goldLight: 0xFFF0CD82, goldDim: 0xFF5E4620, cream: 0xFFF2E8D2, creamMuted: 0xFFB8AC92, bgTop: 0xFF0F0E0B, bgMiddle: 0xFF15130F, bgBottom: 0xFF1A1813, bar: 0xFF0B0A08, card: 0xFF1C1912, raised: 0xFF241F17, track: 0xFF0D0C09, smoke: 0xFF5A4630),
  'arcane': _palette(gold: 0xFF9C6CFF, goldLight: 0xFFCDB3FF, goldDim: 0xFF43307A, cream: 0xFFEEE6FF, creamMuted: 0xFFACA3C2, bgTop: 0xFF0E0B14, bgMiddle: 0xFF130F1B, bgBottom: 0xFF181322, bar: 0xFF0A0810, card: 0xFF1A1523, raised: 0xFF221C2D, track: 0xFF0C0A11, smoke: 0xFF6B3FA0),
  'vampire': _palette(gold: 0xFFE84941, goldLight: 0xFFFF5C5C, goldDim: 0xFF4A0A06, cream: 0xFFF2E6E6, creamMuted: 0xFFB3A3A3, bgTop: 0xFF000000, bgMiddle: 0xFF07070A, bgBottom: 0xFF0C0C10, bar: 0xFF000000, card: 0xFF1A1A1D, raised: 0xFF222226, track: 0xFF08080A, smoke: 0xFF5A0A10),
  'forest': _palette(gold: 0xFFB97945, goldLight: 0xFFE0AE80, goldDim: 0xFF4F3320, cream: 0xFFF0E4D6, creamMuted: 0xFFB3A594, bgTop: 0xFF0F0B08, bgMiddle: 0xFF15100C, bgBottom: 0xFF1A1410, bar: 0xFF0B0806, card: 0xFF1B1511, raised: 0xFF231C16, track: 0xFF0D0A07, smoke: 0xFF4A3A22),
  'ocean': _palette(gold: 0xFFDDE6F0, goldLight: 0xFFF5F9FC, goldDim: 0xFF4A5560, cream: 0xFFF2F5F8, creamMuted: 0xFFA9B2BC, bgTop: 0xFF0C0E11, bgMiddle: 0xFF111418, bgBottom: 0xFF161A1F, bar: 0xFF090B0D, card: 0xFF171A1D, raised: 0xFF1E2226, track: 0xFF0B0D0F, smoke: 0xFF5A6B80),
  'cyberpunk': _palette(gold: 0xFF4174FF, goldLight: 0xFF6E93FF, goldDim: 0xFF0E2A70, cream: 0xFFE6ECFF, creamMuted: 0xFF9EA8C2, bgTop: 0xFF08090E, bgMiddle: 0xFF0C0E15, bgBottom: 0xFF10131C, bar: 0xFF06070B, card: 0xFF12141B, raised: 0xFF191C25, track: 0xFF090A0F, smoke: 0xFF1A3A8F),
  'infernal': _palette(gold: 0xFFFD0F04, goldLight: 0xFFFF7A4D, goldDim: 0xFF5E1008, cream: 0xFFF5E6DE, creamMuted: 0xFFB8A39A, bgTop: 0xFF100605, bgMiddle: 0xFF160907, bgBottom: 0xFF1C0C09, bar: 0xFF0C0504, card: 0xFF1D0D0A, raised: 0xFF26120E, track: 0xFF0E0605, smoke: 0xFF7A1A0A),
  'ice': _palette(gold: 0xFF62D8F2, goldLight: 0xFFB3EEFA, goldDim: 0xFF1E5260, cream: 0xFFE8F7FB, creamMuted: 0xFF9FB6BD, bgTop: 0xFF071014, bgMiddle: 0xFF0B171C, bgBottom: 0xFF0F1D23, bar: 0xFF050C0F, card: 0xFF0E1B20, raised: 0xFF142429, track: 0xFF081115, smoke: 0xFF2A6A80),
};

/// Paleta do tema (ids desconhecidos → a do 'classic').
AbyssPalette abyssPaletteFor(String themeId) => abyssPalettes[themeId] ?? abyssPalettes['classic']!;

Path _chamferedPath(Rect rect, double chamfer) {
  final c = math.max(0.0, math.min(chamfer, math.min(rect.width, rect.height) / 2));
  return Path()
    ..moveTo(rect.left + c, rect.top)
    ..lineTo(rect.right - c, rect.top)
    ..lineTo(rect.right, rect.top + c)
    ..lineTo(rect.right, rect.bottom - c)
    ..lineTo(rect.right - c, rect.bottom)
    ..lineTo(rect.left + c, rect.bottom)
    ..lineTo(rect.left, rect.bottom - c)
    ..lineTo(rect.left, rect.top + c)
    ..close();
}

/// Distância entre o contorno preto e o filete dourado.
const double abyssFrameGap = .4;

/// Área ocupada pela moldura a partir da borda (contorno + filete + entalhes).
const double abyssFrameReach = 6;

/// Moldura dupla com cantos chanfrados: contorno externo ([side], preto) +
/// filete interno dourado e, opcionalmente, pequenos entalhes dourados nos
/// cantos. Não muda o tamanho nem o padding do conteúdo.
class AbyssFrameBorder extends OutlinedBorder {
  final double chamfer;
  final Color innerColor;
  final double innerWidth;
  final bool ornaments;

  /// Sombra chapada (sem blur) desenhada logo abaixo da forma, em px.
  final double shadowOffset;

  const AbyssFrameBorder({
    super.side = const BorderSide(color: AbyssColors.outline, width: 2),
    this.chamfer = 11,
    this.innerColor = const Color(0xB3C9A24A),
    this.innerWidth = 1.2,
    this.ornaments = true,
    this.shadowOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset > 0 ? side.strokeInset : 0);

  @override
  AbyssFrameBorder copyWith({BorderSide? side, double? chamfer, Color? innerColor, double? innerWidth, bool? ornaments, double? shadowOffset}) => AbyssFrameBorder(
        side: side ?? this.side,
        chamfer: chamfer ?? this.chamfer,
        innerColor: innerColor ?? this.innerColor,
        innerWidth: innerWidth ?? this.innerWidth,
        ornaments: ornaments ?? this.ornaments,
        shadowOffset: shadowOffset ?? this.shadowOffset,
      );

  @override
  ShapeBorder scale(double t) => AbyssFrameBorder(
        side: side.scale(t),
        chamfer: chamfer * t,
        innerColor: innerColor,
        innerWidth: innerWidth * t,
        ornaments: ornaments,
        shadowOffset: shadowOffset * t,
      );

  AbyssFrameBorder _lerp(AbyssFrameBorder a, AbyssFrameBorder b, double t) => AbyssFrameBorder(
        side: BorderSide.lerp(a.side, b.side, t),
        chamfer: lerpDouble(a.chamfer, b.chamfer, t)!,
        innerColor: Color.lerp(a.innerColor, b.innerColor, t)!,
        innerWidth: lerpDouble(a.innerWidth, b.innerWidth, t)!,
        ornaments: t < .5 ? a.ornaments : b.ornaments,
        shadowOffset: lerpDouble(a.shadowOffset, b.shadowOffset, t)!,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is AbyssFrameBorder) return _lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is AbyssFrameBorder) return _lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _chamferedPath(rect, chamfer);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final inset = math.max(0.0, side.strokeInset);
    final inner = rect.deflate(math.min(inset, math.min(rect.width, rect.height) / 2));
    return _chamferedPath(inner, math.max(0.0, chamfer - inset * .414));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    if (shadowOffset > 0) {
      // Sombra chapada: caminho deslocado em par-ímpar com o original (sem
      // operação booleana). A faixa fina que sobra dentro da forma fica sob o
      // contorno preto desenhado em seguida.
      final outer = _chamferedPath(rect, chamfer);
      final shadow = Path()
        ..fillType = PathFillType.evenOdd
        ..addPath(outer.shift(Offset(0, shadowOffset)), Offset.zero)
        ..addPath(outer, Offset.zero);
      canvas.drawPath(shadow, Paint()..color = const Color(0x99000000));
    }
    if (side.style != BorderStyle.none && side.width > 0) {
      final half = side.width / 2;
      canvas.drawPath(
        _chamferedPath(rect.deflate(math.min(half, rect.shortestSide / 2)), math.max(0.0, chamfer - half * .414)),
        Paint()
          ..color = side.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = side.width,
      );
    }
    if (innerWidth <= 0 || innerColor.a == 0) return;
    // Filete dourado a ~3 px da borda (área ocupada pela moldura: até ~6 px).
    final inset = side.width + abyssFrameGap + innerWidth / 2;
    if (rect.width <= inset * 2 + 4 || rect.height <= inset * 2 + 4) return;
    final innerRect = rect.deflate(inset);
    final innerChamfer = math.max(2.0, chamfer - inset * .414);
    final goldLine = Paint()
      ..color = innerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerWidth;
    canvas.drawPath(_chamferedPath(innerRect, innerChamfer), goldLine);
    if (!ornaments || rect.width < 48 || rect.height < 36) return;
    _paintCornerOrnaments(canvas, innerRect, innerChamfer);
  }

  /// Entalhes em L nos quatro cantos: um traço paralelo ao chanfro e dois
  /// traços curtos ao longo das bordas.
  void _paintCornerOrnaments(Canvas canvas, Rect r, double c) {
    final paint = Paint()
      ..color = innerColor.withValues(alpha: math.min(1.0, innerColor.a + .2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerWidth + .4
      ..strokeCap = StrokeCap.square;
    const arm = 3.5;
    const gap = 2.5;
    // (canto, direção x, direção y)
    final corners = <(Offset, double, double)>[
      (r.topLeft, 1, 1),
      (r.topRight, -1, 1),
      (r.bottomRight, -1, -1),
      (r.bottomLeft, 1, -1),
    ];
    for (final (corner, dx, dy) in corners) {
      // Traço paralelo ao chanfro, um pouco para dentro.
      final a = corner + Offset(dx * (c + gap), dy * gap);
      final b = corner + Offset(dx * gap, dy * (c + gap));
      canvas.drawLine(a, b, paint);
      // Braços do L ao longo das bordas.
      canvas.drawLine(a, a + Offset(dx * arm, 0), paint);
      canvas.drawLine(b, b + Offset(0, dy * arm), paint);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AbyssFrameBorder &&
      other.side == side &&
      other.chamfer == chamfer &&
      other.innerColor == innerColor &&
      other.innerWidth == innerWidth &&
      other.ornaments == ornaments &&
      other.shadowOffset == shadowOffset;

  @override
  int get hashCode => Object.hash(side, chamfer, innerColor, innerWidth, ornaments, shadowOffset);
}

/// Folha inferior: só os cantos de CIMA chanfrados; contorno e filete
/// dourado apenas no topo (laterais e base ficam coladas na borda da tela).
class AbyssSheetBorder extends ShapeBorder {
  final double chamfer;
  final Color outlineColor;
  final Color lineColor;

  const AbyssSheetBorder({this.chamfer = 11, this.outlineColor = AbyssColors.outline, this.lineColor = AbyssColors.goldLine});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  Path _path(Rect rect) {
    final c = math.max(0.0, math.min(chamfer, math.min(rect.width, rect.height) / 2));
    return Path()
      ..moveTo(rect.left, rect.top + c)
      ..lineTo(rect.left + c, rect.top)
      ..lineTo(rect.right - c, rect.top)
      ..lineTo(rect.right, rect.top + c)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  Path _topEdge(Rect rect, double inset) {
    final c = math.max(0.0, math.min(chamfer, math.min(rect.width, rect.height) / 2));
    final k = inset * .414;
    return Path()
      ..moveTo(rect.left, rect.top + c + k)
      ..lineTo(rect.left + c + k, rect.top + inset)
      ..lineTo(rect.right - c - k, rect.top + inset)
      ..lineTo(rect.right, rect.top + c + k);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    canvas.drawPath(_topEdge(rect, 1), Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawPath(_topEdge(rect, 3), Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  ShapeBorder scale(double t) => AbyssSheetBorder(chamfer: chamfer * t, outlineColor: outlineColor, lineColor: lineColor);

  @override
  bool operator ==(Object other) => other is AbyssSheetBorder && other.chamfer == chamfer && other.outlineColor == outlineColor && other.lineColor == lineColor;

  @override
  int get hashCode => Object.hash(chamfer, outlineColor, lineColor);
}

/// Borda chanfrada para campos de texto, com o vão do rótulo flutuante.
class AbyssInputBorder extends InputBorder {
  final double chamfer;
  final double gapPadding;

  const AbyssInputBorder({super.borderSide = const BorderSide(color: AbyssColors.goldLine), this.chamfer = 7, this.gapPadding = 4});

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  AbyssInputBorder copyWith({BorderSide? borderSide, double? chamfer}) =>
      AbyssInputBorder(borderSide: borderSide ?? this.borderSide, chamfer: chamfer ?? this.chamfer, gapPadding: gapPadding);

  @override
  ShapeBorder scale(double t) => AbyssInputBorder(borderSide: borderSide.scale(t), chamfer: chamfer * t, gapPadding: gapPadding * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is AbyssInputBorder) {
      return AbyssInputBorder(borderSide: BorderSide.lerp(a.borderSide, borderSide, t), chamfer: lerpDouble(a.chamfer, chamfer, t)!, gapPadding: gapPadding);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is AbyssInputBorder) {
      return AbyssInputBorder(borderSide: BorderSide.lerp(borderSide, b.borderSide, t), chamfer: lerpDouble(chamfer, b.chamfer, t)!, gapPadding: gapPadding);
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _chamferedPath(rect, chamfer);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _chamferedPath(rect.deflate(math.min(borderSide.width, rect.shortestSide / 2)), math.max(0.0, chamfer - borderSide.width * .414));

  @override
  void paint(Canvas canvas, Rect rect, {double? gapStart, double gapExtent = 0.0, double gapPercentage = 0.0, TextDirection? textDirection}) {
    if (rect.isEmpty || borderSide.style == BorderStyle.none) return;
    final paint = borderSide.toPaint();
    final r = rect.deflate(borderSide.width / 2);
    final c = math.max(0.0, math.min(chamfer, r.shortestSide / 2));
    if (gapStart == null || gapExtent <= 0 || gapPercentage <= 0) {
      canvas.drawPath(_chamferedPath(r, c), paint);
      return;
    }
    // Vão no topo para o rótulo flutuante (como no OutlineInputBorder).
    final extent = lerpDouble(0.0, gapExtent + gapPadding * 2, gapPercentage)!;
    final start = textDirection == TextDirection.rtl ? gapStart + gapPadding - extent : gapStart - gapPadding;
    final gapLeft = (rect.left + start).clamp(r.left + c, r.right - c).toDouble();
    final gapRight = (rect.left + start + extent).clamp(r.left + c, r.right - c).toDouble();
    final path = Path()
      ..moveTo(gapRight, r.top)
      ..lineTo(r.right - c, r.top)
      ..lineTo(r.right, r.top + c)
      ..lineTo(r.right, r.bottom - c)
      ..lineTo(r.right - c, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..lineTo(r.left, r.bottom - c)
      ..lineTo(r.left, r.top + c)
      ..lineTo(r.left + c, r.top)
      ..lineTo(gapLeft, r.top);
    canvas.drawPath(path, paint);
  }

  @override
  bool operator ==(Object other) => other is AbyssInputBorder && other.borderSide == borderSide && other.chamfer == chamfer && other.gapPadding == gapPadding;

  @override
  int get hashCode => Object.hash(borderSide, chamfer, gapPadding);
}

/// Indicador da aba selecionada: chanfrado, borda dourada.
ShapeBorder abyssIndicatorShape([AbyssPalette palette = AbyssPalette.abyss]) => AbyssFrameBorder(
      side: BorderSide(color: palette.gold, width: 1.2),
      chamfer: 7,
      innerWidth: 0,
      ornaments: false,
    );

/// Chanfro dos botões (menor que o dos cards, para o botão não ficar
/// desproporcional com a altura mínima de 40/44 px).
const double abyssButtonChamfer = 6;

/// Folga lateral do conteúdo do botão: chanfro + 10 (normal) / + 8 (compacto).
double abyssButtonPaddingH(bool compact) => compact ? 14 : 16;

/// Folga vertical do conteúdo do botão (a sombra de 2 px fica fora da forma).
double abyssButtonPaddingV(bool compact) => compact ? 8 : 10;

/// Altura mínima do botão: a lateral reta da moldura comporta texto e ícone.
double abyssButtonMinHeight(bool compact) => compact ? 40 : 44;

ButtonStyle _framedButton(AbyssPalette p, {Color? background, TextStyle? label}) => ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: abyssButtonPaddingH(false), vertical: abyssButtonPaddingV(false))),
      minimumSize: WidgetStatePropertyAll(Size(44, abyssButtonMinHeight(false))),
      // Sem a densidade compacta do app: ela tiraria até 16 px da altura e
      // 8 px do padding, jogando texto e ícone nos cantos chanfrados.
      visualDensity: VisualDensity.standard,
      alignment: Alignment.center,
      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? p.card : (background ?? p.raised)),
      foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? p.creamMuted.withValues(alpha: .55) : p.goldLight),
      overlayColor: WidgetStatePropertyAll(p.gold.withValues(alpha: .12)),
      side: WidgetStatePropertyAll(BorderSide(color: p.outline, width: 2)),
      shape: WidgetStatePropertyAll(AbyssFrameBorder(chamfer: abyssButtonChamfer, ornaments: false, shadowOffset: 2, side: BorderSide(color: p.outline, width: 2), innerColor: p.goldLine)),
      elevation: const WidgetStatePropertyAll(0),
      // Parte do labelLarge do tema (tamanho, altura e fonte) e só reforça o peso.
      // Mesmo tamanho e altura do labelLarge do Material 3 (14 / 1,43), só com
      // peso maior; a fonte e a cor vêm do textTheme do tema.
      textStyle: WidgetStatePropertyAll((label ?? const TextStyle()).copyWith(fontSize: 14, height: 1.43, fontWeight: FontWeight.w700, letterSpacing: .3)),
    );

/// ThemeData do design do Abissal com a paleta [p] (a do Abissal por padrão).
/// Anexa a extensão [AbyssPalette] ao tema.
ThemeData buildAbyssTheme([AbyssPalette p = AbyssPalette.abyss]) {
  final isAbyss = p == AbyssPalette.abyss;
  final scheme = ColorScheme.fromSeed(seedColor: p.gold, brightness: Brightness.dark).copyWith(
    primary: p.gold,
    onPrimary: const Color(0xFF0A0F14),
    // O Abissal mantém o valor de sempre; os outros temas, o destaque sobre a barra.
    primaryContainer: isAbyss ? const Color(0xFF1E1A10) : Color.alphaBlend(p.gold.withValues(alpha: .12), p.bar),
    onPrimaryContainer: p.goldLight,
    secondary: p.energy.last,
    onSecondary: const Color(0xFF06101A),
    secondaryContainer: const Color(0xFF122131),
    onSecondaryContainer: const Color(0xFFCFE2F5),
    tertiary: p.goldLight,
    onTertiary: const Color(0xFF0A0F14),
    surface: p.card,
    onSurface: p.cream,
    onSurfaceVariant: p.creamMuted,
    surfaceContainerHighest: p.raised,
    outline: p.gold,
    outlineVariant: p.goldDim,
  );
  final cardFrame = AbyssFrameBorder(side: BorderSide(color: p.outline, width: 2), innerColor: p.goldLine);
  final smallFrame = AbyssFrameBorder(chamfer: 6, side: BorderSide(color: p.outline, width: 1.5), innerColor: p.goldLine, ornaments: false);
  final inputBorder = AbyssInputBorder(borderSide: BorderSide(color: p.goldLine));

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [p],
    // Transparente: o fundo (gradiente + fumaça) é desenhado em app.dart.
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: IconThemeData(color: p.gold),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: p.bar,
      foregroundColor: p.cream,
      iconTheme: IconThemeData(color: p.cream),
      actionsIconTheme: IconThemeData(color: p.cream),
      titleTextStyle: TextStyle(color: p.cream, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: .3),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: p.gold.withAlpha(0x99), width: 1)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.goldLight,
      unselectedLabelColor: p.cream.withValues(alpha: .6),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      indicatorColor: p.gold,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: p.goldDim.withValues(alpha: .6),
      dividerHeight: 1,
      overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? p.gold.withValues(alpha: .10) : Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: p.bar,
      indicatorColor: p.gold.withValues(alpha: .14),
      indicatorShape: abyssIndicatorShape(p),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? p.goldLight : p.cream.withValues(alpha: .6),
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: states.contains(WidgetState.selected) ? 11 : 10.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
            color: states.contains(WidgetState.selected) ? p.goldLight : p.cream.withValues(alpha: .6),
          )),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardFrame,
      // Imagens e InkWell não passam dos cantos chanfrados (a moldura é
      // pintada por cima e continua visível).
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.track,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: TextStyle(color: p.creamMuted, fontSize: 13),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: AbyssInputBorder(borderSide: BorderSide(color: p.gold)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _framedButton(p)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _framedButton(p)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _framedButton(p, background: p.card)),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.goldLight,
        shape: const AbyssFrameBorder(chamfer: 6, side: BorderSide.none, innerWidth: 0, ornaments: false),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      shape: cardFrame,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      shape: AbyssSheetBorder(outlineColor: p.outline, lineColor: p.goldLine),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: p.gold.withValues(alpha: .7),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.raised,
      surfaceTintColor: Colors.transparent,
      shape: AbyssFrameBorder(chamfer: 8, side: BorderSide(color: p.outline, width: 2), innerColor: p.goldLine, ornaments: false),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.raised,
      selectedColor: p.gold.withValues(alpha: .18),
      side: BorderSide(color: p.outline, width: 1.5),
      shape: smallFrame,
      labelStyle: TextStyle(color: p.cream, fontWeight: FontWeight.w600),
      // Respiro interno (>= 12 nas laterais e >= 8 em cima e embaixo do texto).
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.raised,
      foregroundColor: p.goldLight,
      elevation: 0,
      shape: AbyssFrameBorder(chamfer: 10, side: BorderSide(color: p.outline, width: 2), innerColor: p.goldLine, ornaments: false, shadowOffset: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.raised,
      contentTextStyle: TextStyle(color: p.cream),
    ),
    dividerTheme: DividerThemeData(space: 20, thickness: 1, color: p.goldLine),
  );
  final text = base.textTheme.apply(bodyColor: p.cream, displayColor: p.goldLight);
  final label = base.textTheme.labelLarge;
  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.textTheme.titleLarge?.copyWith(color: p.cream, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: .3),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _framedButton(p, label: label)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _framedButton(p, label: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _framedButton(p, background: p.card, label: label)),
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(color: p.goldLight, fontWeight: FontWeight.w700, letterSpacing: .3),
      titleMedium: text.titleMedium?.copyWith(color: p.goldLight, fontWeight: FontWeight.w700, letterSpacing: .3),
    ),
  );
}

/// Barra de recurso do Abissal: mesma altura (14), trilha escura, moldura
/// dourada fina e pontas em losango nas duas extremidades.
class AbyssResourceBar extends StatelessWidget {
  final double value;
  final bool secondary;

  /// Gradiente da barra (por palavra-chave do recurso); se null, a lógica de
  /// sempre (secondary ? energia : vida).
  final List<Color>? colors;

  const AbyssResourceBar({super.key, required this.value, this.secondary = false, this.colors});

  @override
  Widget build(BuildContext context) {
    final p = AbyssPalette.of(context);
    return SizedBox(
      height: 14,
      width: double.infinity,
      child: CustomPaint(painter: _AbyssBarPainter(value: value.clamp(0.0, 1.0), colors: colors ?? (secondary ? p.energy : p.life), track: p.track, gold: p.gold)),
    );
  }
}

class _AbyssBarPainter extends CustomPainter {
  final double value;
  final List<Color> colors;
  final Color track;
  final Color gold;

  const _AbyssBarPainter({required this.value, required this.colors, required this.track, required this.gold});

  static Path trackPath(Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;
    const tip = 3.0; // espaço do losango em cada ponta
    final point = math.min(6.0, w / 4);
    return Path()
      ..moveTo(tip, mid)
      ..lineTo(tip + point, 1)
      ..lineTo(w - tip - point, 1)
      ..lineTo(w - tip, mid)
      ..lineTo(w - tip - point, h - 1)
      ..lineTo(tip + point, h - 1)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 12) return;
    final trackShape = trackPath(size);
    canvas.drawPath(trackShape, Paint()..color = track);
    if (value > 0) {
      final fillWidth = size.width * value;
      final fill = Rect.fromCenter(center: size.center(Offset.zero), width: fillWidth, height: size.height);
      canvas.save();
      canvas.clipPath(trackShape);
      canvas.drawRect(fill, Paint()..shader = LinearGradient(colors: colors).createShader(fill));
      canvas.restore();
    }
    canvas.drawPath(
      trackShape,
      Paint()
        ..color = gold.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final goldPaint = Paint()..color = gold;
    final mid = size.height / 2;
    for (final x in [3.0, size.width - 3.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 3, mid)
          ..lineTo(x, mid - 3.5)
          ..lineTo(x + 3, mid)
          ..lineTo(x, mid + 3.5)
          ..close(),
        goldPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AbyssBarPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.colors != colors || oldDelegate.track != track || oldDelegate.gold != gold;
}

/// Arte de fundo por tema (themeId → asset). Para outro tema ganhar a sua
/// arte, basta acrescentar uma linha aqui (e registrar a pasta no pubspec).
const themeBackgroundArt = <String, String>{
  'abyss': 'assets/backgrounds/abyss_background.webp',
};

/// Fundo do app: gradiente de ardósia atrás do conteúdo e, por cima dele, a
/// arte do tema ([themeBackgroundArt]) ou, sem arte, a fumaça roxa estática.
/// Se a arte falhar ao carregar, volta para a fumaça, sem erro na tela.
class AbyssBackground extends StatelessWidget {
  final Widget child;

  /// Tema ativo; sem tema (ou tema sem arte), o fundo é gradiente + fumaça.
  final String? themeId;

  const AbyssBackground({super.key, required this.child, this.themeId});

  @override
  Widget build(BuildContext context) {
    final p = AbyssPalette.of(context);
    final art = themeBackgroundArt[themeId];
    final smoke = RepaintBoundary(child: CustomPaint(painter: AbyssSmokePainter(color: p.smoke)));
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.backgroundMiddle, p.backgroundBottom],
          stops: const [0, .52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: art == null
                  ? smoke
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Tela larga (computador): altura inteira, centralizada,
                        // com o gradiente dos lados (sem ampliar e borrar a arte).
                        final wide = constraints.maxWidth > constraints.maxHeight * .75;
                        return Image.asset(
                          art,
                          key: ValueKey('theme-background-$themeId'),
                          fit: wide ? BoxFit.fitHeight : BoxFit.cover,
                          alignment: Alignment.center,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) => smoke,
                        );
                      },
                    ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Pré-carrega a arte de fundo do tema (sem "piscada" na primeira tela).
/// Falha ao carregar é ignorada: o fundo cai no gradiente + fumaça.
Future<void> precacheThemeBackground(BuildContext context, String themeId) async {
  final art = themeBackgroundArt[themeId];
  if (art == null) return;
  await precacheImage(AssetImage(art), context, onError: (_, __) {});
}

/// Filetes ondulados de fumaça roxa translúcida (8–14%), estáticos.
class AbyssSmokePainter extends CustomPainter {
  final Color color;

  const AbyssSmokePainter({this.color = AbyssColors.smoke});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint stroke(double opacity, double width) => Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // Canto superior.
    canvas.drawPath(
      Path()
        ..moveTo(w * .35, h * .02)
        ..cubicTo(w * .55, h * .07, w * .68, -h * .01, w * .86, h * .045)
        ..cubicTo(w * .95, h * .07, w * 1.02, h * .05, w * 1.08, h * .03),
      stroke(.12, 14),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-w * .05, h * .085)
        ..cubicTo(w * .12, h * .05, w * .2, h * .12, w * .38, h * .075),
      stroke(.08, 9),
    );
    // Perto do canto inferior.
    canvas.drawPath(
      Path()
        ..moveTo(-w * .06, h * .93)
        ..cubicTo(w * .14, h * .88, w * .26, h * .97, w * .5, h * .915),
      stroke(.14, 13),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .62, h * .985)
        ..cubicTo(w * .78, h * .94, w * .9, h * 1.0, w * 1.06, h * .955),
      stroke(.09, 10),
    );
  }

  /// Estático: só redesenha se a cor (o tema) mudar.
  @override
  bool shouldRepaint(covariant AbyssSmokePainter oldDelegate) => oldDelegate.color != color;
}

/// Decoração da barra inferior do app: filete dourado de 1 px no topo com um
/// pequeno losango dourado centralizado.
class AbyssNavBarDecoration extends Decoration {
  final AbyssPalette palette;

  const AbyssNavBarDecoration({this.palette = AbyssPalette.abyss});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _AbyssNavBarPainter(palette);
}

class _AbyssNavBarPainter extends BoxPainter {
  final AbyssPalette palette;

  _AbyssNavBarPainter(this.palette);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.drawRect(offset & size, Paint()..color = palette.bar);
    final top = offset.dy + .5;
    canvas.drawLine(Offset(offset.dx, top), Offset(offset.dx + size.width, top), Paint()
      ..color = palette.gold.withValues(alpha: .8)
      ..strokeWidth = 1);
    final cx = offset.dx + size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 5, top)
        ..lineTo(cx, top - 4)
        ..lineTo(cx + 5, top)
        ..lineTo(cx, top + 4)
        ..close(),
      Paint()..color = palette.gold,
    );
  }
}

/// Célula de aba do Abissal (barra inferior e abas da ficha): a selecionada
/// fica emoldurada (chanfro, borda dourada, preenchimento dourado a 14%).
class AbyssTabCell extends StatelessWidget {
  final bool selected;
  final bool reduceMotion;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Widget Function(Color color, bool selected) icon;
  final String label;
  final TextStyle? labelStyle;

  /// Ocupa toda a altura disponível (barra inferior do app).
  final bool fill;

  const AbyssTabCell({
    super.key,
    required this.selected,
    required this.reduceMotion,
    required this.icon,
    required this.label,
    this.labelStyle,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbyssPalette.of(context);
    final color = selected ? p.goldLight : p.cream.withValues(alpha: .6);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      padding: padding,
      margin: margin,
      decoration: ShapeDecoration(
        color: selected ? p.gold.withValues(alpha: .14) : Colors.transparent,
        shape: AbyssFrameBorder(
          side: BorderSide(color: selected ? p.gold : Colors.transparent, width: 1.2),
          chamfer: 7,
          innerWidth: 0,
          ornaments: false,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          icon(color, selected),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle?.copyWith(color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Ajustes de densidade do app (equivalente ao `buildAppTheme` dos outros
/// temas) só para o Abissal: mais respiro nos ListTile para o texto não
/// encostar na moldura, e botões mantendo a moldura chanfrada (só padding e
/// tamanho mínimo do modo compacto, os mesmos de hoje).
ThemeData buildAbyssAppTheme(ThemeData base, bool compact) {
  // Botões com moldura: o conteúdo (texto e ícone, inclusive em .icon e
  // .tonalIcon) fica fora dos cantos chanfrados e centralizado na forma.
  final padding = WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.symmetric(horizontal: abyssButtonPaddingH(compact), vertical: abyssButtonPaddingV(compact)));
  final minimumSize = WidgetStatePropertyAll<Size>(Size(44, abyssButtonMinHeight(compact)));
  return base.copyWith(
    visualDensity: compact ? const VisualDensity(horizontal: -4, vertical: -4) : const VisualDensity(horizontal: -3, vertical: -3),
    cardTheme: base.cardTheme.copyWith(margin: EdgeInsets.zero),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      contentPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 8 : 10),
      isDense: true,
      constraints: BoxConstraints(minHeight: compact ? 42 : 48),
      labelStyle: base.inputDecorationTheme.labelStyle?.copyWith(fontSize: compact ? 11 : 11.5),
      floatingLabelStyle: base.inputDecorationTheme.labelStyle?.copyWith(fontSize: compact ? 11 : 11.5),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      // 10 px nos dois modos: os cards do Abissal têm ornamentos nos cantos.
      minVerticalPadding: 10,
      minTileHeight: compact ? 44 : 48,
      minLeadingWidth: compact ? 30 : 34,
      contentPadding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
    ),
    filledButtonTheme: FilledButtonThemeData(style: base.filledButtonTheme.style!.copyWith(padding: padding, minimumSize: minimumSize, visualDensity: VisualDensity.standard)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: base.outlinedButtonTheme.style!.copyWith(padding: padding, minimumSize: minimumSize, visualDensity: VisualDensity.standard)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: base.elevatedButtonTheme.style!.copyWith(padding: padding, minimumSize: minimumSize, visualDensity: VisualDensity.standard)),
  );
}

/// Respiro interno dos cards do Abissal: 12 px nas laterais e 10 px em cima e
/// embaixo (a moldura e os entalhes ocupam até ~6 px da borda).
const abyssCardInset = EdgeInsets.fromLTRB(12, 10, 12, 10);

/// Grade dos atributos: no Abissal a altura da célula acompanha o texto
/// (escala de fonte) em vez da proporção fixa, para nada ser cortado.
SliverGridDelegate abyssAttributeGridDelegate(BuildContext context) {
  final theme = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  double lineHeight(TextStyle? style) => scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.3);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
    mainAxisExtent: math.max(67.0, 20 + lineHeight(theme.bodyLarge) + lineHeight(theme.headlineSmall) + 4),
  );
}

/// Altura de faixas horizontais de chips: acompanha a escala do texto e o
/// respiro do chip (nunca menor que [current]).
double abyssChipBarHeight(BuildContext context, double current) {
  final label = MediaQuery.textScalerOf(context).scale(14) * 1.43;
  return math.max(current, label + 2 * 11 + 4);
}
