import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';

/// Quando o app vai para segundo plano ou fica oculto, envia na hora as
/// publicações de fichas compartilhadas que ainda estavam esperando a pausa de
/// agrupamento, para o último estado chegar ao Mestre.
///
/// Usa `hidden` e `paused` (na web, aba oculta = `hidden`; `paused` não ocorre).
/// `inactive` fica de fora: na web é só perder o foco da janela.
class FlushOnBackground extends StatefulWidget {
  final Widget child;

  const FlushOnBackground({super.key, required this.child});

  @override
  State<FlushOnBackground> createState() => _FlushOnBackgroundState();
}

class _FlushOnBackgroundState extends State<FlushOnBackground> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      context.read<AppState>().flushSharedCharacterPublications();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
