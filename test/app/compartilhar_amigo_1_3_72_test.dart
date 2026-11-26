// 1.3.72 — "Compartilhar com um amigo" e "Instalar app".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_sheet_app/screens/settings/settings_screen.dart';
import 'package:rpg_sheet_app/screens/settings/share_with_friend.dart';
import 'package:rpg_sheet_app/services/app_state.dart';
import 'package:rpg_sheet_app/services/web_platform.dart';
import 'package:rpg_sheet_app/widgets/install_app_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWeb extends WebPlatform {
  InstallState state;
  int prompts = 0;
  void Function()? listener;
  _FakeWeb(this.state);

  @override
  InstallState installState() => state;

  @override
  Future<bool> promptInstall() async {
    prompts++;
    state = InstallState.none;
    return true;
  }

  @override
  void Function() onInstallStateChange(void Function() onChange) {
    listener = onChange;
    return () => listener = null;
  }

  @override
  bool download(Uint8List bytes, String fileName, String mimeType) => false;
}

const _share = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> shared;
  late List<String> copied;
  var shareFails = false;

  setUp(() {
    shared = [];
    copied = [];
    shareFails = false;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_share, (call) async {
      if (shareFails) throw PlatformException(code: 'unavailable');
      shared.add((call.arguments as Map)['text'] as String);
      return '';
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_share, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    WebPlatform.instance = WebPlatform();
  });

  test('a mensagem contém a origem do site, sem domínio fixo', () {
    expect(friendShareMessage('https://exemplo.test'),
        'Estou usando o Grimório para as fichas de RPG. Entra por aqui e instala no celular: https://exemplo.test');
    expect(friendShareMessage(''), isNot(contains('http')));
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('share-with-friend')), 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
  }

  testWidgets('a seção aparece para usuário comum e compartilha a mensagem', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Compartilhar com um amigo'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Compartilhar com um amigo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(shared, hasLength(1));
    expect(shared.single, startsWith('Estou usando o Grimório para as fichas de RPG.'));
    expect(copied, isEmpty);
  });

  testWidgets('sem compartilhamento, copia a mensagem e avisa', (tester) async {
    shareFails = true;
    await pumpSettings(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Compartilhar com um amigo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(copied, hasLength(1));
    expect(copied.single, startsWith('Estou usando o Grimório'));
    expect(find.text('Mensagem copiada'), findsOneWidget);
  });

  testWidgets('a entrada "Gerenciar convites" não aparece nas Configurações', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Gerenciar convites'), findsNothing);
    expect(find.text('Administração'), findsNothing);
  });

  Future<void> pumpPrompt(WidgetTester tester, {bool asListTile = false}) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: Card(child: InstallAppPrompt(asListTile: asListTile)))),
      ));

  testWidgets('Android/Chrome: botão "Instalar app" que chama o pedido do navegador', (tester) async {
    final web = _FakeWeb(InstallState.prompt);
    WebPlatform.instance = web;
    await pumpPrompt(tester);
    expect(find.text('Instalar app'), findsOneWidget);
    await tester.tap(find.text('Instalar app'));
    await tester.pump();
    expect(web.prompts, 1);
    expect(find.text('Instalar app'), findsNothing);
  });

  testWidgets('iPhone/iPad: instrução curta, sem botão', (tester) async {
    WebPlatform.instance = _FakeWeb(InstallState.ios);
    await pumpPrompt(tester);
    expect(find.text(iosInstallInstruction), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('já instalado ou fora do Web: nada; aparece quando o evento chega', (tester) async {
    final web = _FakeWeb(InstallState.none);
    WebPlatform.instance = web;
    await pumpPrompt(tester, asListTile: true);
    expect(find.text('Instalar app'), findsNothing);
    web.state = InstallState.prompt;
    web.listener!();
    await tester.pump();
    expect(find.text('Instalar app'), findsOneWidget);
  });

  test('fora do Web a ponte não mostra instalação', () {
    expect(WebPlatform().installState(), InstallState.none);
    expect(WebPlatform().canShareFiles(), isFalse);
  });
}
