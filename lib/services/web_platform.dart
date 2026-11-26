import 'dart:typed_data';

import 'web_platform_stub.dart' if (dart.library.js_interop) 'web_platform_web.dart' as impl;

/// Estado da instalação do app (PWA) neste navegador.
enum InstallState {
  /// Já instalado (display-mode standalone) ou fora do Web: não mostra nada.
  none,

  /// Android/Chrome com o evento beforeinstallprompt disponível: botão.
  prompt,

  /// iPhone/iPad no navegador: instrução curta (não há botão possível).
  ios,
}

/// Ponte com o navegador (baixar arquivo, compartilhar, instalar o app).
/// Nos testes, troque [instance] por uma versão falsa.
class WebPlatform {
  static WebPlatform instance = WebPlatform();

  /// Se o navegador consegue compartilhar arquivos de imagem (navigator.canShare).
  bool canShareFiles() => impl.canShareFiles();

  /// Se o navegador tem o compartilhamento de texto (navigator.share).
  bool canShareText() => impl.canShareText();

  /// Baixa [bytes] como o arquivo [fileName]. false fora do Web ou se falhar.
  bool download(Uint8List bytes, String fileName, String mimeType) => impl.download(bytes, fileName, mimeType);

  InstallState installState() => switch (impl.installState()) {
        'prompt' => InstallState.prompt,
        'ios' => InstallState.ios,
        _ => InstallState.none,
      };

  /// Abre o pedido de instalação do navegador; true se a pessoa aceitou.
  Future<bool> promptInstall() => impl.promptInstall();

  /// Avisa [onChange] quando a instalação fica disponível ou termina.
  /// Devolve a função que cancela o aviso.
  void Function() onInstallStateChange(void Function() onChange) => impl.onInstallStateChange(onChange);
}
