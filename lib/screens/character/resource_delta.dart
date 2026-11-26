import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';

/// Cor do número flutuante quando um recurso diminui (contraste ≥ 4,5 sobre o
/// card de todos os temas).
const resourceDeltaDownColor = Color(0xFFFF6B6B);

/// Cor do número flutuante quando um recurso aumenta (contraste ≥ 4,5 sobre o
/// card de todos os temas).
const resourceDeltaUpColor = Color(0xFF4ADE80);

/// Duração da animação do número flutuante.
const resourceDeltaDuration = Duration(milliseconds: 900);

/// Quanto o número sobe durante a animação (px).
const resourceDeltaRise = 20.0;

/// Uma mudança de recurso feita pelo próprio jogador.
@immutable
class ResourceDeltaEvent {
  final String resource;
  final int delta;
  final int serial;

  const ResourceDeltaEvent(this.resource, this.delta, this.serial);
}

/// Canal das mudanças de recurso feitas pelo jogador na tela da ficha. Só as
/// ações da própria tela avisam aqui (botões, Dano/Cura, edição do valor,
/// usar item, lançar magia); sincronização da nuvem ou do Mestre não passam
/// por aqui e não mostram número.
class ResourceDeltaEvents extends ChangeNotifier {
  ResourceDeltaEvent? _last;
  int _serial = 0;

  ResourceDeltaEvent? get last => _last;

  void report(String resource, int delta) {
    if (delta == 0) return;
    _last = ResourceDeltaEvent(resource, delta, ++_serial);
    notifyListeners();
  }

  /// Avisa a diferença de cada recurso entre [before] e [after].
  void reportChanges(Map<String, int> before, Map<String, int> after) {
    for (final entry in after.entries) {
      report(entry.key, entry.value - (before[entry.key] ?? 0));
    }
  }
}

/// Disponibiliza o [ResourceDeltaEvents] da tela da ficha para as barras.
class ResourceDeltaScope extends InheritedWidget {
  final ResourceDeltaEvents events;

  const ResourceDeltaScope({super.key, required this.events, required super.child});

  static ResourceDeltaEvents? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ResourceDeltaScope>()?.events;

  @override
  bool updateShouldNotify(ResourceDeltaScope oldWidget) => oldWidget.events != events;
}

/// Desenha, por cima de [child] (a barra do recurso), um número flutuante
/// ("−5" vermelho, "+3" verde) quando o jogador muda o recurso [resource].
/// Não muda o layout: o número fica num Positioned dentro de um Stack que
/// não corta e tem o tamanho de [child]. Mudanças seguidas enquanto o número
/// ainda está na tela (~1 s) somam num número só.
class FloatingResourceDelta extends StatefulWidget {
  final String resource;
  final Widget child;

  const FloatingResourceDelta({super.key, required this.resource, required this.child});

  @override
  State<FloatingResourceDelta> createState() => _FloatingResourceDeltaState();
}

class _FloatingResourceDeltaState extends State<FloatingResourceDelta> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this, duration: resourceDeltaDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _total = 0);
    });
  ResourceDeltaEvents? _events;
  int _total = 0;
  int _lastSerial = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final events = ResourceDeltaScope.maybeOf(context);
    if (events == _events) return;
    _events?.removeListener(_onEvent);
    _events = events;
    // Só reage a mudanças feitas depois de aparecer (abrir a ficha não mostra número).
    _lastSerial = events?.last?.serial ?? 0;
    events?.addListener(_onEvent);
  }

  void _onEvent() {
    final event = _events?.last;
    if (event == null || event.serial == _lastSerial) return;
    _lastSerial = event.serial;
    if (event.resource != widget.resource) return;
    setState(() {
      // Ainda na tela: soma; senão, começa um número novo.
      _total = _animation.isAnimating ? _total + event.delta : event.delta;
    });
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _events?.removeListener(_onEvent);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      // Mesma estrutura com ou sem número (a barra não é recriada).
      return Stack(clipBehavior: Clip.none, children: [widget.child]);
    }
    final reduceMotion = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || (Provider.of<AppState?>(context, listen: false)?.reduceAnimations ?? false);
    final down = _total < 0;
    final label = down ? '−${-_total}' : '+$_total';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          right: 4,
          bottom: 6,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final t = _animation.value;
                // Com "reduzir movimento": não sobe nem esmaece; só aparece e some.
                final dy = reduceMotion ? 0.0 : -resourceDeltaRise * Curves.easeOut.transform(t);
                final opacity = reduceMotion ? 1.0 : (t < .5 ? 1.0 : (1 - (t - .5) / .5).clamp(0.0, 1.0));
                return Transform.translate(offset: Offset(0, dy), child: Opacity(opacity: opacity, child: child));
              },
              child: Text(
                label,
                key: ValueKey('resource-delta-${widget.resource}'),
                style: TextStyle(
                  color: down ? resourceDeltaDownColor : resourceDeltaUpColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
