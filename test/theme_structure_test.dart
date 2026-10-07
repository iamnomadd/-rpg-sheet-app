import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/theme.dart';

/// Descreve a estrutura de uma borda sem a cor: tipo, raio, espessura e
/// opacidade. A cor é própria de cada tema e fica de fora.
String _side(BorderSide side) =>
    side.style == BorderStyle.none ? 'sem borda' : 'largura ${side.width} opacidade ${side.color.a.toStringAsFixed(2)}';

String _shape(ShapeBorder? shape) {
  if (shape == null) return 'null';
  if (shape is RoundedRectangleBorder) return 'Rounded(${shape.borderRadius}, ${_side(shape.side)})';
  if (shape is OutlineInputBorder) return 'Outline(${shape.borderRadius}, ${_side(shape.borderSide)})';
  return shape.runtimeType.toString();
}

String _style(TextStyle? style) => 'size ${style?.fontSize} weight ${style?.fontWeight} spacing ${style?.letterSpacing}';

const _none = <WidgetState>{};
const _selected = <WidgetState>{WidgetState.selected};

Map<String, String> _structure(ThemeData theme) {
  final input = theme.inputDecorationTheme;
  final filled = theme.filledButtonTheme.style!;
  final outlined = theme.outlinedButtonTheme.style!;
  final nav = theme.navigationBarTheme;
  final tab = theme.tabBarTheme;
  return {
    'card': _shape(theme.cardTheme.shape),
    'campo (border)': _shape(input.border),
    'campo (enabled)': _shape(input.enabledBorder),
    'campo (focused)': _shape(input.focusedBorder),
    'botão preenchido (forma)': _shape(filled.shape?.resolve(_none)),
    'botão preenchido (borda)': filled.side?.resolve(_none) == null ? 'null' : _side(filled.side!.resolve(_none)!),
    'botão contornado (forma)': _shape(outlined.shape?.resolve(_none)),
    'botão contornado (borda)': outlined.side?.resolve(_none) == null ? 'null' : _side(outlined.side!.resolve(_none)!),
    'diálogo': _shape(theme.dialogTheme.shape),
    'bottom sheet': _shape(theme.bottomSheetTheme.shape),
    'menu': _shape(theme.popupMenuTheme.shape),
    'chip (forma)': _shape(theme.chipTheme.shape),
    'chip (borda)': theme.chipTheme.side == null ? 'null' : _side(theme.chipTheme.side!),
    'FAB': _shape(theme.floatingActionButtonTheme.shape),
    'indicador da navegação': _shape(nav.indicatorShape),
    'altura da navegação': '${nav.height}',
    'ícone da navegação (selecionado)': '${nav.iconTheme?.resolve(_selected)?.size}',
    'ícone da navegação (não selecionado)': '${nav.iconTheme?.resolve(_none)?.size}',
    'rótulo da navegação (selecionado)': _style(nav.labelTextStyle?.resolve(_selected)),
    'rótulo da navegação (não selecionado)': _style(nav.labelTextStyle?.resolve(_none)),
    'abas (divisor)': 'altura ${tab.dividerHeight} opacidade ${tab.dividerColor?.a.toStringAsFixed(2)}',
    'abas (rótulo)': _style(tab.labelStyle),
    'abas (rótulo não selecionado)': _style(tab.unselectedLabelStyle),
    'divisor': 'espessura ${theme.dividerTheme.thickness} espaço ${theme.dividerTheme.space} opacidade ${theme.dividerTheme.color?.a.toStringAsFixed(2)}',
  };
}

void main() {
  final classic = buildTheme('classic');
  final classicStructure = _structure(classic);

  test('há 10 temas e o Clássico Escuro é o primeiro', () {
    expect(appThemes, hasLength(10));
    expect(appThemes.first.id, 'classic');
  });

  for (final preset in appThemes) {
    test('tema ${preset.id} tem a mesma estrutura do Clássico', () {
      final structure = _structure(buildTheme(preset.id));
      for (final entry in classicStructure.entries) {
        expect(structure[entry.key], entry.value, reason: '${preset.id}: ${entry.key}');
      }
      expect(preset.radius, themePreset('classic').radius, reason: '${preset.id}: raio base');
    });

    test('tema ${preset.id} marca o ícone selecionado só pela cor', () {
      final nav = buildTheme(preset.id).navigationBarTheme;
      final selected = nav.iconTheme!.resolve(_selected)!;
      final unselected = nav.iconTheme!.resolve(_none)!;
      expect(selected.size, unselected.size);
      expect(selected.color, isNot(unselected.color));
    });

  }

  test('cores e ícones próprios continuam diferentes entre os temas', () {
    final ids = appThemes.map((t) => t.id).toList();
    expect(appThemes.map((t) => t.seed).toSet(), hasLength(ids.length));
    expect(ids.map((id) => buildTheme(id).colorScheme.primary).toSet(), hasLength(ids.length));
    expect(ids.map((id) => themedResourceBarColors(id).first).toSet(), hasLength(ids.length));
    expect(ids.map((id) => themedResourceTrackColor(id)).toSet(), hasLength(ids.length));
    expect(ids.map((id) => themedIcon(id, 'general')).toSet(), hasLength(ids.length));
    expect(ids.map((id) => themedMainIcon(id, 'characters')).toSet(), hasLength(ids.length));
  });
}
