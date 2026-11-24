import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cloud_service.dart';

/// Tamanho máximo (bytes do JSON) do snapshot de uma ficha compartilhada.
/// Acima disso, o envio vai sem as imagens próprias do personagem 2D.
const int sharedSnapshotMaxBytes = 1800 * 1024;

/// Snapshot que vai para a nuvem. Se o JSON passar de [maxBytes], devolve uma
/// CÓPIA sem `customSpriteImages` e com `customSpriteEnabled = false` (o Mestre
/// vê o personagem do tema). A ficha local não é alterada.
Map<String, dynamic> sharedSnapshotFor(Map<String, dynamic> json, {int maxBytes = sharedSnapshotMaxBytes}) {
  if (utf8.encode(jsonEncode(json)).length <= maxBytes) return json;
  return Map<String, dynamic>.of(json)
    ..remove('customSpriteImages')
    ..['customSpriteEnabled'] = false;
}

/// Descrição do erro de publicação para o log, sem o corpo do snapshot nem
/// tokens: só o tipo do erro e, quando houver, o status HTTP.
String describePublishError(Object error) {
  final status = error is CloudRequestException && error.statusCode != null ? ', status ${error.statusCode}' : '';
  return 'Falha ao publicar a ficha compartilhada (${error.runtimeType}$status).';
}

/// Junta as publicações de cada ficha: várias alterações seguidas geram uma
/// única publicação depois de [delay] sem novas alterações. Se uma publicação
/// da mesma ficha ainda estiver em andamento, a próxima sai quando ela
/// terminar. [publish] resolve o estado MAIS RECENTE da ficha na hora do envio,
/// então o último estado nunca se perde.
class CharacterPublishQueue {
  CharacterPublishQueue({required this.publish, this.delay = defaultDelay});

  static const defaultDelay = Duration(milliseconds: 1500);

  final Future<void> Function(String characterId) publish;
  final Duration delay;

  final _timers = <String, Timer>{};
  final _running = <String, Future<void>>{};
  final _again = <String>{};

  /// Há publicação agendada ou em andamento.
  bool get hasPending => _timers.isNotEmpty || _running.isNotEmpty;

  void schedule(String characterId) {
    _timers.remove(characterId)?.cancel();
    _timers[characterId] = Timer(delay, () {
      _timers.remove(characterId);
      _run(characterId);
    });
  }

  /// Publica JÁ o estado mais recente de cada ficha com publicação pendente
  /// (usado quando o app vai para segundo plano) e espera também as que estão
  /// em andamento. Sem pendência, não publica nada.
  Future<void> flush() {
    final pending = _timers.keys.toList();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    final runs = [for (final id in pending) _run(id)];
    return Future.wait([...runs, ..._running.values]);
  }

  /// Uma publicação por vez por ficha. Se outra for pedida durante o envio,
  /// sai mais uma ao terminar, já com o estado mais novo.
  Future<void> _run(String characterId) {
    final running = _running[characterId];
    if (running != null) {
      _again.add(characterId);
      return running;
    }
    final future = _loop(characterId);
    _running[characterId] = future;
    return future;
  }

  Future<void> _loop(String characterId) async {
    try {
      do {
        _again.remove(characterId);
        try {
          await publish(characterId);
        } catch (error) {
          debugPrint(describePublishError(error));
        }
      } while (_again.contains(characterId));
    } finally {
      _running.remove(characterId);
    }
  }
}
