import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({'auto_sync': false}));

  test('rollAdvanced sem label mantém o formato antigo', () {
    final state = AppState();
    final entry = state.rollAdvanced(sides: 20, modifier: 3);
    expect(entry.containsKey('label'), isFalse);
    expect(entry['expression'], '1d20 + 3');
    expect(state.diceHistory.first, same(entry));
  });

  test('rollAdvanced com label grava o título no histórico', () {
    final state = AppState();
    final entry = state.rollAdvanced(sides: 20, modifier: 2, mode: 'advantage', label: 'Atletismo');
    expect(entry['label'], 'Atletismo');
    expect(entry['expression'], '1d20 + 2');
    expect(entry['rolls'], hasLength(2));
    expect(state.diceHistory.first['label'], 'Atletismo');
  });

  test('label vazio é ignorado', () {
    final state = AppState();
    expect(state.rollAdvanced(sides: 6, label: '  ').containsKey('label'), isFalse);
  });
}
