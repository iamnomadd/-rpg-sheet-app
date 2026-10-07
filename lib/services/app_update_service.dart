import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

export 'app_update_stub.dart' if (dart.library.js_interop) 'app_update_web.dart';

/// Converte "X.Y.Z+N" em [X, Y, Z, N]; null se o formato for inválido.
List<int>? _parseFullVersion(String value) {
  final parts = value.trim().split('+');
  if (parts.length != 2) return null;
  final numbers = parts[0].split('.');
  if (numbers.length != 3) return null;
  final result = <int>[];
  for (final part in [...numbers, parts[1]]) {
    final n = int.tryParse(part);
    if (n == null || n < 0) return null;
    result.add(n);
  }
  return result;
}

/// true só se [remote] for mais nova que [local] (formato "X.Y.Z+N").
/// Entrada inválida em qualquer lado devolve false.
bool isNewerVersion(String remote, String local) {
  final r = _parseFullVersion(remote);
  final l = _parseFullVersion(local);
  if (r == null || l == null) return false;
  for (var i = 0; i < 4; i++) {
    if (r[i] != l[i]) return r[i] > l[i];
  }
  return false;
}

/// Lê "fullVersion" do version.json publicado. Só na web; devolve null fora
/// dela e em qualquer erro (nunca lança exceção).
Future<String?> fetchRemoteFullVersion() async {
  if (!kIsWeb) return null;
  try {
    final uri = Uri.parse('${Uri.base.origin}/version.json?t=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is Map && data['fullVersion'] is String) return data['fullVersion'] as String;
    return null;
  } catch (_) {
    return null;
  }
}
