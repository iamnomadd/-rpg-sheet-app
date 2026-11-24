// Tema "Abissal (experimental)", id 'abyss'.
//
// Tema isolado e fácil de remover: tudo o que é dele mora neste arquivo. Para
// remover: apague este arquivo, a entrada 'abyss' de `appThemes` e os ramos
// `'abyss'` (veja a descrição do PR). Os ornamentos são originais, desenhados
// em código (Path/CustomPainter/ShapeBorder); sem imagens nem fontes novas.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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

  const AbyssSheetBorder({this.chamfer = 11});

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
      ..color = AbyssColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawPath(_topEdge(rect, 3), Paint()
      ..color = const Color(0xB3C9A24A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  ShapeBorder scale(double t) => AbyssSheetBorder(chamfer: chamfer * t);

  @override
  bool operator ==(Object other) => other is AbyssSheetBorder && other.chamfer == chamfer;

  @override
  int get hashCode => chamfer.hashCode;
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
ShapeBorder abyssIndicatorShape() => const AbyssFrameBorder(
      side: BorderSide(color: AbyssColors.gold, width: 1.2),
      chamfer: 7,
      innerWidth: 0,
      ornaments: false,
    );

const _buttonFrame = AbyssFrameBorder(chamfer: 7, ornaments: false, shadowOffset: 2);

ButtonStyle _framedButton({Color background = AbyssColors.raised, TextStyle? label}) => ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AbyssColors.card : background),
      foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? AbyssColors.creamMuted.withValues(alpha: .55) : AbyssColors.goldLight),
      overlayColor: WidgetStatePropertyAll(AbyssColors.gold.withValues(alpha: .12)),
      side: const WidgetStatePropertyAll(BorderSide(color: AbyssColors.outline, width: 2)),
      shape: const WidgetStatePropertyAll(_buttonFrame),
      elevation: const WidgetStatePropertyAll(0),
      // Parte do labelLarge do tema (tamanho, altura e fonte) e só reforça o peso.
      // Mesmo tamanho e altura do labelLarge do Material 3 (14 / 1,43), só com
      // peso maior; a fonte e a cor vêm do textTheme do tema.
      textStyle: WidgetStatePropertyAll((label ?? const TextStyle()).copyWith(fontSize: 14, height: 1.43, fontWeight: FontWeight.w700, letterSpacing: .3)),
    );

/// ThemeData completo do tema Abissal (não reutiliza os ternários dos outros
/// temas).
ThemeData buildAbyssTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AbyssColors.gold, brightness: Brightness.dark).copyWith(
    primary: AbyssColors.gold,
    onPrimary: const Color(0xFF0A0F14),
    primaryContainer: const Color(0xFF1E1A10),
    onPrimaryContainer: AbyssColors.goldLight,
    secondary: AbyssColors.energy.last,
    onSecondary: const Color(0xFF06101A),
    secondaryContainer: const Color(0xFF122131),
    onSecondaryContainer: const Color(0xFFCFE2F5),
    tertiary: AbyssColors.goldLight,
    onTertiary: const Color(0xFF0A0F14),
    surface: AbyssColors.card,
    onSurface: AbyssColors.cream,
    onSurfaceVariant: AbyssColors.creamMuted,
    surfaceContainerHighest: AbyssColors.raised,
    outline: AbyssColors.gold,
    outlineVariant: AbyssColors.goldDim,
  );
  const cardFrame = AbyssFrameBorder();
  const smallFrame = AbyssFrameBorder(chamfer: 6, side: BorderSide(color: AbyssColors.outline, width: 1.5), ornaments: false);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Transparente: o fundo (gradiente + fumaça) é desenhado em app.dart.
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: const IconThemeData(color: AbyssColors.gold),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AbyssColors.bar,
      foregroundColor: AbyssColors.cream,
      iconTheme: IconThemeData(color: AbyssColors.cream),
      actionsIconTheme: IconThemeData(color: AbyssColors.cream),
      titleTextStyle: TextStyle(color: AbyssColors.cream, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: .3),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: Color(0x99C9A24A), width: 1)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AbyssColors.goldLight,
      unselectedLabelColor: AbyssColors.cream.withValues(alpha: .6),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      indicatorColor: AbyssColors.gold,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AbyssColors.goldDim.withValues(alpha: .6),
      dividerHeight: 1,
      overlayColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? AbyssColors.gold.withValues(alpha: .10) : Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: AbyssColors.bar,
      indicatorColor: AbyssColors.gold.withValues(alpha: .14),
      indicatorShape: abyssIndicatorShape(),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? AbyssColors.goldLight : AbyssColors.cream.withValues(alpha: .6),
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: states.contains(WidgetState.selected) ? 11 : 10.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
            color: states.contains(WidgetState.selected) ? AbyssColors.goldLight : AbyssColors.cream.withValues(alpha: .6),
          )),
    ),
    cardTheme: const CardThemeData(
      color: AbyssColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardFrame,
      // Imagens e InkWell não passam dos cantos chanfrados (a moldura é
      // pintada por cima e continua visível).
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AbyssColors.track,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: const TextStyle(color: AbyssColors.creamMuted, fontSize: 13),
      border: const AbyssInputBorder(),
      enabledBorder: const AbyssInputBorder(),
      focusedBorder: const AbyssInputBorder(borderSide: BorderSide(color: AbyssColors.gold)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _framedButton()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _framedButton()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _framedButton(background: AbyssColors.card)),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AbyssColors.goldLight,
        shape: const AbyssFrameBorder(chamfer: 6, side: BorderSide.none, innerWidth: 0, ornaments: false),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AbyssColors.raised,
      surfaceTintColor: Colors.transparent,
      shape: cardFrame,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AbyssColors.raised,
      surfaceTintColor: Colors.transparent,
      shape: const AbyssSheetBorder(),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: AbyssColors.gold.withValues(alpha: .7),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AbyssColors.raised,
      surfaceTintColor: Colors.transparent,
      shape: AbyssFrameBorder(chamfer: 8, ornaments: false),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AbyssColors.raised,
      selectedColor: AbyssColors.gold.withValues(alpha: .18),
      side: const BorderSide(color: AbyssColors.outline, width: 1.5),
      shape: smallFrame,
      labelStyle: const TextStyle(color: AbyssColors.cream, fontWeight: FontWeight.w600),
      // Respiro interno (>= 12 nas laterais e >= 8 em cima e embaixo do texto).
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AbyssColors.raised,
      foregroundColor: AbyssColors.goldLight,
      elevation: 0,
      shape: AbyssFrameBorder(chamfer: 10, ornaments: false, shadowOffset: 2),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AbyssColors.raised,
      contentTextStyle: TextStyle(color: AbyssColors.cream),
    ),
    dividerTheme: const DividerThemeData(space: 20, thickness: 1, color: AbyssColors.goldLine),
  );
  final text = base.textTheme.apply(bodyColor: AbyssColors.cream, displayColor: AbyssColors.goldLight);
  final label = base.textTheme.labelLarge;
  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.textTheme.titleLarge?.copyWith(color: AbyssColors.cream, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: .3),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _framedButton(label: label)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _framedButton(label: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _framedButton(background: AbyssColors.card, label: label)),
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(color: AbyssColors.goldLight, fontWeight: FontWeight.w700, letterSpacing: .3),
      titleMedium: text.titleMedium?.copyWith(color: AbyssColors.goldLight, fontWeight: FontWeight.w700, letterSpacing: .3),
    ),
  );
}

/// Barra de recurso do Abissal: mesma altura (14), trilha escura, moldura
/// dourada fina e pontas em losango nas duas extremidades.
class AbyssResourceBar extends StatelessWidget {
  final double value;
  final bool secondary;

  const AbyssResourceBar({super.key, required this.value, this.secondary = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        width: double.infinity,
        child: CustomPaint(painter: _AbyssBarPainter(value: value.clamp(0.0, 1.0), colors: secondary ? AbyssColors.energy : AbyssColors.life)),
      );
}

class _AbyssBarPainter extends CustomPainter {
  final double value;
  final List<Color> colors;

  const _AbyssBarPainter({required this.value, required this.colors});

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
    final track = trackPath(size);
    canvas.drawPath(track, Paint()..color = AbyssColors.track);
    if (value > 0) {
      final fillWidth = size.width * value;
      final fill = Rect.fromCenter(center: size.center(Offset.zero), width: fillWidth, height: size.height);
      canvas.save();
      canvas.clipPath(track);
      canvas.drawRect(fill, Paint()..shader = LinearGradient(colors: colors).createShader(fill));
      canvas.restore();
    }
    canvas.drawPath(
      track,
      Paint()
        ..color = AbyssColors.gold.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final gold = Paint()..color = AbyssColors.gold;
    final mid = size.height / 2;
    for (final x in [3.0, size.width - 3.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 3, mid)
          ..lineTo(x, mid - 3.5)
          ..lineTo(x + 3, mid)
          ..lineTo(x, mid + 3.5)
          ..close(),
        gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AbyssBarPainter oldDelegate) => oldDelegate.value != value || oldDelegate.colors != colors;
}

/// Fundo do app: gradiente de ardósia + fumaça roxa estática atrás do conteúdo.
class AbyssBackground extends StatelessWidget {
  final Widget child;

  const AbyssBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AbyssColors.backgroundTop, AbyssColors.backgroundMiddle, AbyssColors.backgroundBottom],
            stops: [0, .52, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(child: CustomPaint(painter: AbyssSmokePainter())),
              ),
            ),
            child,
          ],
        ),
      );
}

/// Filetes ondulados de fumaça roxa translúcida (8–14%), estáticos.
class AbyssSmokePainter extends CustomPainter {
  const AbyssSmokePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint stroke(double opacity, double width) => Paint()
      ..color = AbyssColors.smoke.withValues(alpha: opacity)
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Decoração da barra inferior do app: filete dourado de 1 px no topo com um
/// pequeno losango dourado centralizado.
class AbyssNavBarDecoration extends Decoration {
  const AbyssNavBarDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _AbyssNavBarPainter();
}

class _AbyssNavBarPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.drawRect(offset & size, Paint()..color = AbyssColors.bar);
    final top = offset.dy + .5;
    canvas.drawLine(Offset(offset.dx, top), Offset(offset.dx + size.width, top), Paint()
      ..color = AbyssColors.gold.withValues(alpha: .8)
      ..strokeWidth = 1);
    final cx = offset.dx + size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 5, top)
        ..lineTo(cx, top - 4)
        ..lineTo(cx + 5, top)
        ..lineTo(cx, top + 4)
        ..close(),
      Paint()..color = AbyssColors.gold,
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
  final Widget Function(Color color) icon;
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
    final color = selected ? AbyssColors.goldLight : AbyssColors.cream.withValues(alpha: .6);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      padding: padding,
      margin: margin,
      decoration: ShapeDecoration(
        color: selected ? AbyssColors.gold.withValues(alpha: .14) : Colors.transparent,
        shape: AbyssFrameBorder(
          side: BorderSide(color: selected ? AbyssColors.gold : Colors.transparent, width: 1.2),
          chamfer: 7,
          innerWidth: 0,
          ornaments: false,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          icon(color),
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
  final padding = WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8));
  final minimumSize = WidgetStatePropertyAll<Size>(Size(44, compact ? 34 : 38));
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
    filledButtonTheme: FilledButtonThemeData(style: base.filledButtonTheme.style!.copyWith(padding: padding, minimumSize: minimumSize)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: base.outlinedButtonTheme.style!.copyWith(padding: padding, minimumSize: minimumSize)),
  );
}

/// Respiro interno dos cards do Abissal: 12 px nas laterais e 10 px em cima e
/// embaixo (a moldura e os entalhes ocupam até ~6 px da borda). Nos outros
/// temas devolve [current] sem mudança.
EdgeInsetsGeometry abyssCardInset(String themeId, EdgeInsetsGeometry current) =>
    themeId == 'abyss' ? const EdgeInsets.fromLTRB(12, 10, 12, 10) : current;

/// Grade dos atributos: no Abissal a altura da célula acompanha o texto
/// (escala de fonte) em vez da proporção fixa, para nada ser cortado.
SliverGridDelegate abyssAttributeGridDelegate(BuildContext context, String themeId, SliverGridDelegate current) {
  if (themeId != 'abyss') return current;
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

/// Altura de faixas horizontais de chips: no Abissal acompanha a escala do
/// texto e o respiro do chip (nunca menor que [current]); nos outros temas
/// devolve [current].
double abyssChipBarHeight(BuildContext context, String themeId, double current) {
  if (themeId != 'abyss') return current;
  final label = MediaQuery.textScalerOf(context).scale(14) * 1.43;
  return math.max(current, label + 2 * 11 + 4);
}
