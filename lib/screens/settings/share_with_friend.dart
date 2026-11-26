import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/web_platform.dart';
import '../../widgets/install_app_prompt.dart';

/// Endereço do próprio site (sem domínio fixo no código); vazio fora do Web.
String currentSiteOrigin() => kIsWeb ? Uri.base.origin : '';

/// Mensagem do "Compartilhar com um amigo" com o endereço [origin] do site.
String friendShareMessage(String origin) => origin.isEmpty
    ? 'Estou usando o Grimório para as fichas de RPG.'
    : 'Estou usando o Grimório para as fichas de RPG. Entra por aqui e instala no celular: $origin';

/// Abre o compartilhamento do sistema com a mensagem; sem compartilhamento
/// disponível (ou se falhar), copia a mensagem e avisa "Mensagem copiada".
/// Não tem relação com o código de vínculo da ficha com o Mestre.
Future<void> shareWithFriend(BuildContext context, {String? origin}) async {
  final message = friendShareMessage(origin ?? currentSiteOrigin());
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!kIsWeb || WebPlatform.instance.canShareText()) {
    try {
      await Share.share(message, subject: 'Grimório');
      return;
    } catch (_) {
      // Sem compartilhamento: copia abaixo.
    }
  }
  await Clipboard.setData(ClipboardData(text: message));
  messenger?.showSnackBar(const SnackBar(content: Text('Mensagem copiada')));
}

/// Seção "Compartilhar com um amigo" das Configurações (todos os usuários).
class ShareWithFriendSection extends StatelessWidget {
  const ShareWithFriendSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('share-with-friend'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compartilhar com um amigo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar com um amigo'),
              subtitle: const Text('Envia o endereço do Grimório para alguém instalar.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => shareWithFriend(context),
            ),
            const InstallAppPrompt(asListTile: true),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
