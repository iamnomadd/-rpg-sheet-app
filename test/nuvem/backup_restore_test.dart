import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_sheet_app/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restauração completa preserva preferências modernas', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();

    await state.replaceFromBackup({
      'characters': <dynamic>[],
      'systems': <dynamic>[],
      'campaigns': <dynamic>[],
      'savedRolls': <dynamic>[],
      'diceHistory': <dynamic>[],
      'preferences': {
        'themeId': 'parchment',
        'largeText': true,
        'compactMode': true,
        'reduceAnimations': true,
        'masterToolsEnabled': true,
      },
    });

    expect(state.themeId, 'parchment');
    expect(state.largeText, isTrue);
    expect(state.compactMode, isTrue);
    expect(state.reduceAnimations, isTrue);
    expect(state.masterToolsEnabled, isTrue);
    expect(state.systems.any((s) => s.id == 'generic' && s.name == 'Sistema Padrão'), isTrue);
  });

  test('restauração seletiva também recupera acessibilidade e modo mestre', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();

    await state.restoreBackupSections(
      {
        'preferences': {
          'reduceAnimations': true,
          'masterToolsEnabled': true,
        },
      },
      restoreGameData: false,
      restoreRollData: false,
      restorePreferences: true,
    );

    expect(state.reduceAnimations, isTrue);
    expect(state.masterToolsEnabled, isTrue);
  });
}
