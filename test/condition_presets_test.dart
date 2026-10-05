import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/app/condition_presets.dart';

void main() {
  test('condições prontas têm nomes únicos e ícones definidos', () {
    final names = conditionPresets.map((item) => item.name).toList();
    expect(names.toSet().length, names.length);
    expect(conditionPresetFor('Envenenado'), isNotNull);
    expect(conditionPresetFor('Queimando'), isNotNull);
    expect(conditionPresetFor('condição antiga'), isNull);
  });
}
