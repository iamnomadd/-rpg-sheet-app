/// Frase para erros que não são mensagens do próprio app.
const genericErrorMessage = 'Não foi possível concluir. Verifique a conexão e tente de novo.';

/// Erro com uma mensagem escrita pelo próprio app, pensada para o usuário
/// (por exemplo "Há alterações mais recentes na nuvem…"). O `toString()` é o
/// mesmo de um `Exception('…')`, para manter o texto de hoje onde ele já é
/// mostrado com `replaceFirst('Exception: ', '')`.
class AppMessageException implements Exception {
  final String message;

  const AppMessageException(this.message);

  @override
  String toString() => 'Exception: $message';
}

/// A mensagem de uma [AppMessageException]. Para qualquer outro erro
/// (resposta do servidor, `Exception` genérica de biblioteca, erro de tipo, de
/// formato etc.), null — a tela mostra [genericErrorMessage].
String? appErrorMessage(Object error) {
  if (error is! AppMessageException) return null;
  final message = error.message.trim();
  return message.isEmpty ? null : message;
}
