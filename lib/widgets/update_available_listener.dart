import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_version.dart';
import '../services/app_update_service.dart';

/// Checa se há versão nova publicada e mostra o aviso "Nova versão disponível"
/// com a ação "Atualizar". Só recarrega quando o usuário toca em "Atualizar".
///
/// Checa 6 s depois de abrir, ao voltar para o app (se a última checagem foi
/// há 10 min ou mais) e a cada 30 min. Falhas de rede são ignoradas.
class UpdateAvailableListener extends StatefulWidget {
  final Widget child;
  final Future<String?> Function() fetchRemoteVersion;
  final Future<void> Function() applyUpdate;
  final String localVersion;
  final bool enabled;
  final Duration initialDelay;

  const UpdateAvailableListener({
    super.key,
    required this.child,
    this.fetchRemoteVersion = fetchRemoteFullVersion,
    this.applyUpdate = applyUpdateAndReload,
    this.localVersion = appVersionWithBuild,
    this.enabled = kIsWeb,
    this.initialDelay = const Duration(seconds: 6),
  });

  @override
  State<UpdateAvailableListener> createState() => _UpdateAvailableListenerState();
}

class _UpdateAvailableListenerState extends State<UpdateAvailableListener> with WidgetsBindingObserver {
  static const _periodicInterval = Duration(minutes: 30);
  static const _resumeInterval = Duration(minutes: 10);

  Timer? _initialTimer;
  Timer? _periodicTimer;
  DateTime? _lastCheck;
  String? _notifiedVersion;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _initialTimer = Timer(widget.initialDelay, _check);
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => _check());
  }

  @override
  void dispose() {
    _initialTimer?.cancel();
    _periodicTimer?.cancel();
    if (widget.enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last == null || DateTime.now().difference(last) >= _resumeInterval) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    _lastCheck = DateTime.now();
    String? remote;
    try {
      remote = await widget.fetchRemoteVersion();
    } catch (_) {
      remote = null;
    } finally {
      _checking = false;
    }
    if (!mounted || remote == null) return;
    if (!isNewerVersion(remote, widget.localVersion)) return;
    final notified = _notifiedVersion;
    if (notified != null && !isNewerVersion(remote, notified)) return;
    _notifiedVersion = remote;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: const Text('Nova versão disponível'),
      action: SnackBarAction(label: 'Atualizar', onPressed: () => widget.applyUpdate()),
      showCloseIcon: true,
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
