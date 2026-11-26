import 'dart:io';

/// Lê o arquivo [path] e junta o conteúdo dos arquivos `part '...';` dele
/// (telas divididas em partes), para os testes que procuram trechos no código.
String readWithParts(String path) {
  final main = File(path).readAsStringSync();
  final dir = File(path).parent.path;
  final parts = RegExp(r"^part '([^']+)';", multiLine: true).allMatches(main).map((m) => File('$dir/${m.group(1)}').readAsStringSync());
  return [main, ...parts].join('\n');
}
