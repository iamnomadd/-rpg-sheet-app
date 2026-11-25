import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Altura de um texto com a escala de texto [scaler] (largura máxima e número
/// de linhas opcionais), com o estilo mesclado ao `DefaultTextStyle`.
double measuredTextHeight(BuildContext context, String text, TextStyle? style, {required TextScaler scaler, double maxWidth = double.infinity, int? maxLines}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: maxLines,
  )..layout(maxWidth: maxWidth);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Quanto o texto cresce na escala de texto atual em relação à escala 1.0.
/// É 0 com texto 1.0, então alturas fixas somadas a isto ficam idênticas a
/// hoje com texto normal e crescem só com texto maior.
double textGrowth(BuildContext context, String text, TextStyle? style, {double maxWidth = double.infinity, int? maxLines}) {
  final scaler = MediaQuery.textScalerOf(context);
  if (scaler == TextScaler.noScaling) return 0;
  final grown = measuredTextHeight(context, text, style, scaler: scaler, maxWidth: maxWidth, maxLines: maxLines);
  final base = measuredTextHeight(context, text, style, scaler: TextScaler.noScaling, maxWidth: maxWidth, maxLines: maxLines);
  // Arredonda para cima: as alturas de linha não crescem de forma exata.
  return grown > base ? (grown - base).ceilToDouble() : 0;
}

/// Grade de colunas fixas com a proporção de sempre e [extraHeight] a mais na
/// altura de cada célula (0 = exatamente a grade de proporção fixa).
class TextGrowthGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  final double extraHeight;

  const TextGrowthGridDelegate({
    required super.crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    super.childAspectRatio,
    this.extraHeight = 0,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usable = constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1);
    final cross = usable / crossAxisCount;
    final main = cross / childAspectRatio + extraHeight;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: main + mainAxisSpacing,
      crossAxisStride: cross + crossAxisSpacing,
      childMainAxisExtent: main,
      childCrossAxisExtent: cross,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(TextGrowthGridDelegate oldDelegate) => super.shouldRelayout(oldDelegate) || oldDelegate.extraHeight != extraHeight;
}
