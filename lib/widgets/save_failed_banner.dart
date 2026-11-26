import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';

/// Aviso fixo no topo do conteúdo enquanto o último salvamento tiver falhado
/// (por exemplo, espaço cheio no navegador). Some sozinho quando um
/// salvamento der certo.
class SaveFailedBanner extends StatelessWidget {
  final Widget child;

  const SaveFailedBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final failed = context.select<AppState?, bool>((s) => s?.lastSaveFailed ?? false);
    if (!failed) return child;
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Material(
        color: scheme.errorContainer,
        child: SafeArea(
          bottom: false,
          child: MaterialBanner(
            key: const ValueKey('save-failed-banner'),
            backgroundColor: scheme.errorContainer,
            leading: Icon(Icons.sd_card_alert_outlined, color: scheme.onErrorContainer),
            content: Text(saveFailedMessage, style: TextStyle(color: scheme.onErrorContainer)),
            actions: [
              TextButton(
                onPressed: () => context.read<AppState>().save(),
                child: Text('Tentar de novo', style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
      // O aviso já ocupa a área segura do topo.
      Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
    ]);
  }
}
