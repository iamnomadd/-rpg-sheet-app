import '../services/cloud_service.dart';

/// Frase para erros que não são mensagens do próprio app.
const genericErrorMessage = 'Não foi possível concluir. Verifique a conexão e tente de novo.';

/// A mensagem de um `Exception('…')` lançado pelo próprio app (em lib/, por
/// exemplo "Há alterações mais recentes na nuvem…"), sem o prefixo
/// "Exception: ". Para qualquer outro erro (resposta do servidor, erro de
/// tipo, de formato etc.), null.
String? appErrorMessage(Object error) {
  if (error is CloudRequestException || error is! Exception) return null;
  const prefix = 'Exception: ';
  final text = error.toString();
  if (!text.startsWith(prefix)) return null;
  final message = text.substring(prefix.length).trim();
  return message.isEmpty ? null : message;
}
