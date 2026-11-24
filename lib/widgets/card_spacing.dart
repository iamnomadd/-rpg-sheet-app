import 'package:flutter/widgets.dart';

/// Distância vertical entre cards, igual à do "Em Cena": cada módulo da aba
/// fica num `Padding(bottom: 10)` (character_screen.dart, `_GeneralTab`) e os
/// recursos secundários são separados por `SizedBox(height: 10)`.
///
/// O `cardTheme` global continua com `margin: EdgeInsets.zero` (a aba Config.
/// não muda); as telas aplicam esta separação por conta própria.
const double cardSpacing = 10;

/// Margem de baixo para cards em lista, no mesmo padrão do Em Cena.
const EdgeInsets cardSpacingMargin = EdgeInsets.only(bottom: cardSpacing);

/// Põe [cardSpacing] ENTRE os itens (nada antes do primeiro nem depois do
/// último).
List<Widget> spacedCards(Iterable<Widget> items) {
  final result = <Widget>[];
  for (final item in items) {
    if (result.isNotEmpty) result.add(const SizedBox(height: cardSpacing));
    result.add(item);
  }
  return result;
}
