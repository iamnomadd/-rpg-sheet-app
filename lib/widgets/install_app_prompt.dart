import 'package:flutter/material.dart';

import '../services/web_platform.dart';

/// Texto da instrução de instalação no iPhone/iPad.
const iosInstallInstruction = 'Para instalar: toque em Compartilhar e depois em Adicionar à Tela de Início';

/// Opção de instalar o app (PWA): botão "Instalar app" no Android/Chrome
/// (pedido beforeinstallprompt), instrução curta no iPhone/iPad e nada quando
/// o app já está instalado ou fora do Web.
class InstallAppPrompt extends StatefulWidget {
  /// Dentro de um Card das Configurações (ListTile) ou solto na tela de entrada.
  final bool asListTile;

  const InstallAppPrompt({super.key, this.asListTile = false});

  @override
  State<InstallAppPrompt> createState() => _InstallAppPromptState();
}

class _InstallAppPromptState extends State<InstallAppPrompt> {
  late InstallState _state = WebPlatform.instance.installState();
  void Function()? _cancel;

  @override
  void initState() {
    super.initState();
    _cancel = WebPlatform.instance.onInstallStateChange(() {
      if (mounted) setState(() => _state = WebPlatform.instance.installState());
    });
  }

  @override
  void dispose() {
    _cancel?.call();
    super.dispose();
  }

  Future<void> _install() async {
    await WebPlatform.instance.promptInstall();
    if (mounted) setState(() => _state = WebPlatform.instance.installState());
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case InstallState.none:
        return const SizedBox.shrink();
      case InstallState.prompt:
        if (widget.asListTile) {
          return ListTile(
            key: const ValueKey('install-app'),
            leading: const Icon(Icons.install_mobile_outlined),
            title: const Text('Instalar app'),
            subtitle: const Text('Coloca o Grimório na tela inicial do aparelho.'),
            onTap: _install,
          );
        }
        return OutlinedButton.icon(
          key: const ValueKey('install-app'),
          onPressed: _install,
          icon: const Icon(Icons.install_mobile_outlined),
          label: const Text('Instalar app'),
        );
      case InstallState.ios:
        if (widget.asListTile) {
          return const ListTile(
            key: ValueKey('install-app-ios'),
            leading: Icon(Icons.ios_share),
            title: Text('Instalar app'),
            subtitle: Text(iosInstallInstruction),
          );
        }
        return Text(
          iosInstallInstruction,
          key: const ValueKey('install-app-ios'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        );
    }
  }
}
