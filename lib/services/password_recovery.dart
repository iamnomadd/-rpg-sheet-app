import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_message.dart';
import 'cloud_service.dart';

/// Mensagem mostrada depois de pedir a recuperação (sempre a mesma, exista ou
/// não a conta, para não revelar quais e-mails estão cadastrados).
const passwordRecoverySentMessage = 'Se houver uma conta com esse e-mail, você vai receber um link para criar uma senha nova.';

/// Mensagem do link de recuperação expirado ou inválido.
const passwordRecoveryExpiredMessage = 'Este link expirou ou já foi usado. Peça um novo em Esqueci minha senha.';

/// Mensagem depois de salvar a senha nova.
const passwordChangedMessage = 'Senha alterada. Você já está conectado.';

/// Resultado de um link de recuperação: sessão pronta para criar a senha
/// nova ([session]) ou erro ([error]).
@immutable
class PasswordRecoveryEvent {
  final CloudSession? session;
  final String? error;

  const PasswordRecoveryEvent.ready(CloudSession this.session) : error = null;
  const PasswordRecoveryEvent.failed(String this.error) : session = null;
}

/// "Esqueci minha senha": pedido do e-mail, reconhecimento do link de volta
/// (type=recovery) e aviso para a tela de entrada abrir "Criar nova senha".
class PasswordRecovery {
  PasswordRecovery._();

  /// Último link de recuperação tratado (a tela de entrada consome e limpa).
  static final events = ValueNotifier<PasswordRecoveryEvent?>(null);

  /// Marca de que este aparelho pediu uma recuperação (para reconhecer um
  /// link de recuperação que volta só com erro, sem type=recovery).
  static const _pendingKey = 'password_recovery_requested_at';
  static const _pendingMaxAge = Duration(days: 2);

  /// Pede o e-mail de recuperação.
  static Future<void> request(String email) async {
    await CloudService.requestPasswordRecovery(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, DateTime.now().toUtc().toIso8601String());
  }

  static Future<bool> _hasPendingRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final at = DateTime.tryParse(prefs.getString(_pendingKey) ?? '');
    return at != null && DateTime.now().toUtc().difference(at) <= _pendingMaxAge;
  }

  static Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  /// Se o link é de RECUPERAÇÃO de senha: type=recovery; ou um link só com
  /// erro quando este aparelho pediu uma recuperação há pouco. Links de
  /// confirmação de e-mail continuam no fluxo de sempre.
  static Future<bool> isRecoveryLink(Uri uri) async {
    final params = CloudService.authLinkParameters(uri);
    if (params['type'] == 'recovery') return true;
    final error = params['error_description'] ?? params['error'];
    if (error == null || error.trim().isEmpty) return false;
    return _hasPendingRequest();
  }

  /// Trata o link de recuperação: salva a sessão (como os outros links) e
  /// avisa a tela de entrada para abrir "Criar nova senha"; com erro, avisa
  /// a mensagem de link expirado.
  static Future<void> handleLink(Uri uri) async {
    final params = CloudService.authLinkParameters(uri);
    final error = params['error_description'] ?? params['error'];
    if (error != null && error.trim().isNotEmpty) {
      await _clearPending();
      events.value = const PasswordRecoveryEvent.failed(passwordRecoveryExpiredMessage);
      return;
    }
    try {
      final session = await CloudService.handleAuthCallback(uri);
      if (session == null) {
        events.value = const PasswordRecoveryEvent.failed(passwordRecoveryExpiredMessage);
        return;
      }
      await _clearPending();
      events.value = PasswordRecoveryEvent.ready(session);
    } on CloudRequestException catch (e) {
      events.value = PasswordRecoveryEvent.failed(e.isUnauthorized ? passwordRecoveryExpiredMessage : genericErrorMessage);
    } catch (e) {
      events.value = PasswordRecoveryEvent.failed(appErrorMessage(e) ?? passwordRecoveryExpiredMessage);
    }
  }
}
