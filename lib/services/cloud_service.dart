import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_message.dart';

class CloudRequestException implements Exception {
  final int? statusCode;
  final String message;
  const CloudRequestException(this.message,{this.statusCode});
  bool get isUnauthorized => statusCode==401 || statusCode==403;
  @override String toString()=>message;
}

/// O backup da nuvem mudou entre o download e o envio (conflito). A
/// sincronização refaz o ciclo uma vez; a mensagem é a mesma de antes.
class CloudConflictException extends AppMessageException {
  const CloudConflictException(super.message);
}

class CloudSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final bool isAnonymous;

  const CloudSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.isAnonymous,
  });

  String get displayName => isAnonymous || email.trim().isEmpty ? 'Nuvem anônima' : email;
}

class CloudSnapshot {
  final Map<String, dynamic> payload;
  final DateTime? updatedAt;

  const CloudSnapshot({required this.payload, required this.updatedAt});
}

class CloudService {
  static const Duration _networkTimeout = Duration(seconds: 12);
  static Future<CloudSession>? _refreshInFlight;
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dbmyuocbglxbyiptjprd.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_mZfehw2WE9NYvy5hEAHVwQ_IuOuq-j3',
  );

  static const _accessKey = 'cloud_access_token';
  static const _refreshKey = 'cloud_refresh_token';
  static const _userIdKey = 'cloud_user_id';
  static const _emailKey = 'cloud_email';
  static const _anonymousKey = 'cloud_is_anonymous';
  static const _accessValidatedAtKey = 'cloud_access_validated_at';
  static const _accessValidatedUserKey = 'cloud_access_validated_user';
  static String get authCallbackUrl => kIsWeb ? Uri.base.origin : 'rpgsheet://auth-callback';

  static bool get configured => supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static Future<CloudSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessKey) ?? '';
    final refresh = prefs.getString(_refreshKey) ?? '';
    final userId = prefs.getString(_userIdKey) ?? '';
    final email = prefs.getString(_emailKey) ?? '';
    final isAnonymous = prefs.getBool(_anonymousKey) ?? email.isEmpty;
    if (access.isEmpty || userId.isEmpty) return null;
    return CloudSession(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      email: email,
      isAnonymous: isAnonymous,
    );
  }

  static Future<void> _saveSession(CloudSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, session.accessToken);
    await prefs.setString(_refreshKey, session.refreshToken);
    await prefs.setString(_userIdKey, session.userId);
    await prefs.setString(_emailKey, session.email);
    await prefs.setBool(_anonymousKey, session.isAnonymous);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_anonymousKey);
    await prefs.remove(_accessValidatedAtKey);
    await prefs.remove(_accessValidatedUserKey);
  }

  static Future<void> _cacheAccessValidation(CloudSession session, bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    if (!allowed) {
      await prefs.remove(_accessValidatedAtKey);
      await prefs.remove(_accessValidatedUserKey);
      return;
    }
    await prefs.setString(_accessValidatedAtKey, DateTime.now().toUtc().toIso8601String());
    await prefs.setString(_accessValidatedUserKey, session.userId);
  }

  static Future<bool> hasRecentValidatedAccess(
    CloudSession session, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_accessValidatedUserKey) != session.userId) return false;
    final raw = prefs.getString(_accessValidatedAtKey);
    final validatedAt = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    if (validatedAt == null) return false;
    return DateTime.now().toUtc().difference(validatedAt) <= maxAge;
  }

  static Future<dynamic> _rawRequest(
    String method,
    Uri uri, {
    Map<String,String>? headers,
    Object? body,
  }) async {
    try {
      final request=http.Request(method,uri);
      request.headers.addAll({'Content-Type':'application/json','apikey':supabaseAnonKey,...?headers});
      if(body!=null) request.body=jsonEncode(body);
      final streamed=await request.send().timeout(_networkTimeout);
      final text=await streamed.stream.bytesToString().timeout(_networkTimeout);
      dynamic decoded;
      if(text.trim().isNotEmpty){try{decoded=jsonDecode(text);}catch(_){decoded={'message':text};}}
      if(streamed.statusCode<200 || streamed.statusCode>=300){
        final msg=decoded is Map?(decoded['msg']??decoded['message']??decoded['error_description']??decoded['error']):null;
        throw CloudRequestException(
          msg?.toString()??'Erro de conexão (${streamed.statusCode}).',
          statusCode:streamed.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw AppMessageException('A nuvem demorou para responder. Verifique a conexão e tente novamente.');
    } on http.ClientException {
      throw AppMessageException('Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.');
    } catch(e) {
      if(e is Exception) rethrow;
      throw AppMessageException('Não foi possível acessar a nuvem. Verifique a conexão e tente novamente.');
    }
  }

  static Future<Map<String,dynamic>> _request(String method,Uri uri,{Map<String,String>? headers,Object? body}) async {
    final decoded=await _rawRequest(method,uri,headers:headers,body:body);
    if(decoded is Map) return Map<String,dynamic>.from(decoded);
    return {'data':decoded};
  }

  static CloudSession _sessionFromAuth(Map<String, dynamic> data, {String fallbackEmail = ''}) {
    final user = Map<String, dynamic>.from(data['user'] ?? {});
    final token = data['access_token']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      throw AppMessageException('Não foi possível iniciar a sessão da nuvem.');
    }
    return CloudSession(
      accessToken: token,
      refreshToken: data['refresh_token']?.toString() ?? '',
      userId: userId,
      email: user['email']?.toString() ?? fallbackEmail,
      isAnonymous: user['is_anonymous'] == true || (user['email']?.toString() ?? fallbackEmail).isEmpty,
    );
  }

  static Future<CloudSession> signInAnonymously() async {
    if (!configured) throw AppMessageException('Supabase ainda não configurado neste site.');
    final data = await _request(
      'POST',
      Uri.parse('$supabaseUrl/auth/v1/signup'),
      body: const <String, dynamic>{},
    );
    final session = _sessionFromAuth(data);
    await _saveSession(session);
    return session;
  }

  static DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      final exp = decoded is Map ? decoded['exp'] : null;
      if (exp is num) return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    } catch (_) {}
    return null;
  }

  static bool _sessionNeedsRefresh(CloudSession session) {
    final expiry = _jwtExpiry(session.accessToken);
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 2)));
  }

  static Future<CloudSession> ensureSession() async {
    final current = await loadSession();
    if (current == null) return signInAnonymously();
    if (current.refreshToken.isEmpty || !_sessionNeedsRefresh(current)) return current;

    final active = _refreshInFlight;
    if (active != null) return active;

    final future = refreshSession(current);
    _refreshInFlight = future;
    try {
      return await future;
    } on CloudRequestException catch (e) {
      // Invalid/expired credentials must return to the access screen instead of
      // leaving the app trapped with a permanently unusable session.
      if (e.isUnauthorized) {
        await signOut();
        throw AppMessageException('Sua sessão expirou. Entre novamente.');
      }
      // Network failures keep the stored session intact so offline/unstable
      // connections never log the player out accidentally.
      rethrow;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  static Future<CloudSession> refreshSession(CloudSession current) async {
    if (current.refreshToken.isEmpty) return current;

    // SharedPreferences usa armazenamento compartilhado entre abas no Web. Antes
    // de reutilizar um refresh token, adota o token mais novo que outra aba possa
    // ter gravado enquanto esta instância estava em segundo plano.
    final latest = await loadSession();
    if (latest != null &&
        latest.userId == current.userId &&
        latest.refreshToken.isNotEmpty &&
        latest.refreshToken != current.refreshToken) {
      current = latest;
      if (!_sessionNeedsRefresh(current)) return current;
    }

    try {
      final data = await _request(
        'POST',
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
        body: {'refresh_token': current.refreshToken},
      );
      final session = _sessionFromAuth(data, fallbackEmail: current.email);
      await _saveSession(session);
      return session;
    } on CloudRequestException catch (e) {
      // Se outra aba venceu a corrida de rotação, ela já recebeu e persistiu o
      // próximo refresh token. Recuperamos essa sessão em vez de iniciar uma
      // tempestade de retries ou derrubar o usuário.
      if (e.statusCode == 400 || e.statusCode == 429) {
        for (final delay in const [Duration(milliseconds: 180), Duration(milliseconds: 520)]) {
          await Future<void>.delayed(delay);
          final recovered = await loadSession();
          if (recovered != null &&
              recovered.userId == current.userId &&
              recovered.refreshToken.isNotEmpty &&
              recovered.refreshToken != current.refreshToken) {
            return recovered;
          }
        }
      }
      rethrow;
    }
  }

  static Future<CloudSession> signIn(String email, String password) async {
    if (!configured) throw AppMessageException('Supabase ainda não configurado neste site.');
    final data = await _request(
      'POST',
      Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
      body: {'email': email.trim(), 'password': password},
    );
    final session = _sessionFromAuth(data, fallbackEmail: email.trim());
    await _saveSession(session);
    return session;
  }

  static Future<CloudSession?> signUp(String email, String password) async {
    if (!configured) throw AppMessageException('Supabase ainda não configurado neste site.');
    final data = await _request(
      'POST',
      Uri.parse('$supabaseUrl/auth/v1/signup'),
      body: {'email': email.trim(), 'password': password},
    );
    final token = data['access_token']?.toString() ?? '';
    if (token.isEmpty) return null;
    final session = _sessionFromAuth(data, fallbackEmail: email.trim());
    await _saveSession(session);
    return session;
  }

  static Future<CloudSession> protectAnonymousWithEmail(
    CloudSession current, {
    required String email,
    required String password,
  }) async {
    if (!current.isAnonymous) return current;
    if (email.trim().isEmpty || !email.contains('@')) {
      throw AppMessageException('Informe um e-mail válido.');
    }
    if (password.length < 6) {
      throw AppMessageException('A senha precisa ter pelo menos 6 caracteres.');
    }

    final data = await _request(
      'PUT',
      Uri.parse('$supabaseUrl/auth/v1/user?redirect_to=${Uri.encodeComponent(authCallbackUrl)}'),
      headers: {'Authorization': 'Bearer ${current.accessToken}'},
      body: {'email': email.trim(), 'password': password},
    );

    final user = Map<String, dynamic>.from(data);
    final updated = CloudSession(
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
      userId: current.userId,
      email: user['email']?.toString() ?? email.trim(),
      isAnonymous: user['is_anonymous'] == true,
    );
    await _saveSession(updated);
    return updated;
  }


  /// Pede o e-mail de recuperação de senha (POST /auth/v1/recover). O link
  /// volta para [authCallbackUrl] (no Web, a origem do próprio site). A
  /// resposta não diz se a conta existe.
  static Future<void> requestPasswordRecovery(String email) async {
    if (!configured) throw AppMessageException('Supabase ainda não configurado neste site.');
    final clean = email.trim();
    if (clean.isEmpty || !clean.contains('@')) throw AppMessageException('Informe um e-mail válido.');
    try {
      await _rawRequest(
        'POST',
        Uri.parse('$supabaseUrl/auth/v1/recover?redirect_to=${Uri.encodeComponent(authCallbackUrl)}'),
        body: {'email': clean},
      );
    } on CloudRequestException catch (e) {
      if (e.statusCode == 429) {
        throw AppMessageException('Muitos pedidos seguidos. Espere alguns minutos e tente de novo.');
      }
      rethrow;
    }
  }

  /// Troca a senha da conta da [session] (PUT /auth/v1/user com {password}).
  static Future<void> updatePassword(CloudSession session, String password) async {
    if (password.length < 6) throw AppMessageException('A senha precisa ter pelo menos 6 caracteres.');
    try {
      await _request(
        'PUT',
        Uri.parse('$supabaseUrl/auth/v1/user'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {'password': password},
      );
    } on CloudRequestException catch (e) {
      final text = e.message.toLowerCase();
      if (text.contains('different') || text.contains('same_password')) {
        throw AppMessageException('A senha nova precisa ser diferente da atual.');
      }
      if (e.isUnauthorized) throw AppMessageException('Este link expirou ou já foi usado. Peça um novo em Esqueci minha senha.');
      rethrow;
    }
  }

  /// Parâmetros de um link de autenticação (query e fragmento).
  static Map<String, String> authLinkParameters(Uri uri) => _callbackParameters(uri);

  static Map<String, String> _callbackParameters(Uri uri) {
    final values = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      try { values.addAll(Uri.splitQueryString(uri.fragment)); } catch (_) {}
    }
    return values;
  }

  static Future<CloudSession?> handleAuthCallback(Uri uri) async {
    if (!kIsWeb && (uri.scheme != 'rpgsheet' || uri.host != 'auth-callback')) return null;
    final params = _callbackParameters(uri);
    final error = params['error_description'] ?? params['error'];
    if (error != null && error.trim().isNotEmpty) throw Exception(Uri.decodeComponent(error));

    final callbackAccess = params['access_token'] ?? '';
    final callbackRefresh = params['refresh_token'] ?? '';
    CloudSession? current = await loadSession();

    if (callbackAccess.isNotEmpty) {
      final user = await _request('GET', Uri.parse('$supabaseUrl/auth/v1/user'),
        headers: {'Authorization': 'Bearer $callbackAccess'});
      final session = CloudSession(
        accessToken: callbackAccess,
        refreshToken: callbackRefresh.isNotEmpty ? callbackRefresh : (current?.refreshToken ?? ''),
        userId: user['id']?.toString() ?? current?.userId ?? '',
        email: user['email']?.toString() ?? current?.email ?? '',
        isAnonymous: user['is_anonymous'] == true,
      );
      if (session.userId.isEmpty) throw Exception('Confirmação recebida, mas a sessão não pôde ser validada.');
      await _saveSession(session);
      return session;
    }

    if (current == null) return null;
    if (current.refreshToken.isNotEmpty) current = await refreshSession(current);
    final user = await _request('GET', Uri.parse('$supabaseUrl/auth/v1/user'),
      headers: {'Authorization': 'Bearer ${current.accessToken}'});
    final updated = CloudSession(
      accessToken: current.accessToken, refreshToken: current.refreshToken,
      userId: user['id']?.toString() ?? current.userId,
      email: user['email']?.toString() ?? current.email,
      isAnonymous: user['is_anonymous'] == true,
    );
    await _saveSession(updated);
    return updated;
  }


  static Future<void> uploadBackup(CloudSession session, Map<String, dynamic> payload, {DateTime? expectedCloudUpdatedAt}) async {
    if (!configured) throw AppMessageException('Supabase ainda não configurado neste site.');
    if (expectedCloudUpdatedAt != null) {
      final latest = await downloadSnapshot(session);
      final latestTime = latest?.updatedAt;
      if (latestTime != null && latestTime.isAfter(expectedCloudUpdatedAt.add(const Duration(milliseconds: 500)))) {
        throw const CloudConflictException('Há alterações mais recentes na nuvem. Sincronize novamente antes de enviar.');
      }
    }
    await _request(
      'POST',
      Uri.parse('$supabaseUrl/rest/v1/rpg_cloud_backups?on_conflict=user_id'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: {
        'user_id': session.userId,
        'payload': payload,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  static Future<CloudSnapshot?> downloadSnapshot(CloudSession session) async {
    if (!configured) throw AppMessageException('Supabase ainda não configurado.');
    final uri=Uri.parse('$supabaseUrl/rest/v1/rpg_cloud_backups?user_id=eq.${Uri.encodeComponent(session.userId)}&select=payload,updated_at&limit=1');
    final decoded=await _rawRequest('GET',uri,headers:{'Authorization':'Bearer ${session.accessToken}'});
    if(decoded is! List || decoded.isEmpty) return null;
    final row=Map<String,dynamic>.from(decoded.first as Map);
    final payload=row['payload']; if(payload is! Map) return null;
    return CloudSnapshot(payload:Map<String,dynamic>.from(payload),updatedAt:DateTime.tryParse(row['updated_at']?.toString()??'')?.toUtc());
  }


  static Future<void> publishCharacter(CloudSession session, Map<String, dynamic> snapshot, String shareCode) async {
    await _request('POST', Uri.parse('$supabaseUrl/rest/v1/rpg_shared_characters?on_conflict=owner_id,character_id'), headers: {
      'Authorization': 'Bearer ${session.accessToken}',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    }, body: {'owner_id': session.userId, 'character_id': snapshot['id'], 'share_code': shareCode, 'snapshot': snapshot, 'updated_at': DateTime.now().toUtc().toIso8601String()});
  }

  static Future<Map<String,dynamic>?> lookupSharedCharacter(CloudSession session,String code) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/resolve_rpg_share_code'),headers:{'Authorization':'Bearer ${session.accessToken}'},body:{'p_code':code.trim().toUpperCase()});
    if(decoded is! List || decoded.isEmpty) return null;
    return Map<String,dynamic>.from(decoded.first as Map);
  }


  static Future<void> requestCharacterLink(CloudSession session, Map<String, dynamic> shared, String campaignId) async {
    await _request('POST', Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer': 'return=minimal',
    }, body: {'share_code': shared['share_code'], 'character_owner_id': shared['owner_id'], 'requester_id': session.userId, 'campaign_id': campaignId, 'status': 'pending'});
  }



  static SupabaseClient createRealtimeClient(CloudSession session) {
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    client.realtime.setAuth(session.accessToken);
    return client;
  }

  static Future<void> publishSessionState(CloudSession session, String campaignId, Map<String, dynamic> state) async {
    await _request('POST', Uri.parse('$supabaseUrl/rest/v1/rpg_campaign_session_state?on_conflict=campaign_id'), headers: {
      'Authorization': 'Bearer ${session.accessToken}',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    }, body: {
      'campaign_id': campaignId,
      'master_id': session.userId,
      'round': state['round'] ?? 1,
      'active': state['active'] == true,
      'current_index': state['current_index'] ?? 0,
      'initiative': state['initiative'] ?? <dynamic>[],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<Map<String,dynamic>?> fetchSessionState(CloudSession session,String campaignId) async {
    final uri=Uri.parse('$supabaseUrl/rest/v1/rpg_campaign_session_state?campaign_id=eq.${Uri.encodeComponent(campaignId)}&select=round,active,current_index,initiative,updated_at&limit=1');
    final decoded=await _rawRequest('GET',uri,headers:{'Authorization':'Bearer ${session.accessToken}'});
    if(decoded is! List || decoded.isEmpty) return null;
    return Map<String,dynamic>.from(decoded.first as Map);
  }


  static Future<List<Map<String,dynamic>>> incomingLinkRequests(CloudSession session) async {
    final uri=Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?character_owner_id=eq.${Uri.encodeComponent(session.userId)}&status=eq.pending&select=id,share_code,requester_id,campaign_id,status,created_at&order=created_at.desc');
    final decoded=await _rawRequest('GET',uri,headers:{'Authorization':'Bearer ${session.accessToken}'});
    return (decoded as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }


  static Future<void> updateLinkStatus(CloudSession session, String requestId, String status) async {
    await _request('PATCH', Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?id=eq.${Uri.encodeComponent(requestId)}'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer': 'return=minimal',
    }, body: {'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()});
  }

  /// DELETE devolve 2xx mesmo quando o RLS não deixa apagar nada; com
  /// return=representation a resposta lista as linhas realmente apagadas.
  static Future<bool> deleteLinkRequest(CloudSession session, String requestId) async {
    final decoded=await _rawRequest('DELETE', Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?id=eq.${Uri.encodeComponent(requestId)}'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer': 'return=representation',
    });
    return decoded is List && decoded.isNotEmpty;
  }

  /// Vínculo do Mestre localizado pelo código (pedido pendente guarda só
  /// shareCode/ownerId, sem o id da linha).
  static Future<bool> deleteOwnLinkRequestByCode(CloudSession session, String campaignId, String shareCode) async {
    final decoded=await _rawRequest('DELETE', Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?requester_id=eq.${Uri.encodeComponent(session.userId)}&campaign_id=eq.${Uri.encodeComponent(campaignId)}&share_code=eq.${Uri.encodeComponent(shareCode)}'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer': 'return=representation',
    });
    return decoded is List && decoded.isNotEmpty;
  }

  /// O vínculo do Mestre ainda existe? Por id quando houver; senão pelo
  /// código (requester_id = usuário + campaign_id + share_code).
  static Future<bool> linkRequestExists(CloudSession session, {String requestId = '', required String campaignId, required String shareCode}) async {
    final filter=requestId.isNotEmpty
        ? 'id=eq.${Uri.encodeComponent(requestId)}'
        : 'requester_id=eq.${Uri.encodeComponent(session.userId)}&campaign_id=eq.${Uri.encodeComponent(campaignId)}&share_code=eq.${Uri.encodeComponent(shareCode)}';
    final decoded=await _rawRequest('GET',Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?$filter&select=id&limit=1'),headers:{'Authorization':'Bearer ${session.accessToken}'});
    return decoded is List && decoded.isNotEmpty;
  }

  /// Vínculos do próprio jogador para um código (ficha apagada).
  static Future<bool> deleteLinkRequestsByShareCode(CloudSession session, String shareCode) async {
    final decoded=await _rawRequest('DELETE', Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?character_owner_id=eq.${Uri.encodeComponent(session.userId)}&share_code=eq.${Uri.encodeComponent(shareCode)}'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer': 'return=representation',
    });
    return decoded is List && decoded.isNotEmpty;
  }

  static Future<void> deleteSharedCharacter(CloudSession session, String characterId) async {
    await _request('DELETE', Uri.parse('$supabaseUrl/rest/v1/rpg_shared_characters?owner_id=eq.${Uri.encodeComponent(session.userId)}&character_id=eq.${Uri.encodeComponent(characterId)}'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer': 'return=minimal',
    });
  }

  static Future<List<Map<String,dynamic>>> approvedLinksForCampaign(CloudSession session,String campaignId) async {
    final uri=Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?requester_id=eq.${Uri.encodeComponent(session.userId)}&campaign_id=eq.${Uri.encodeComponent(campaignId)}&status=eq.approved&select=id,share_code,character_owner_id,campaign_id,status');
    final decoded=await _rawRequest('GET',uri,headers:{'Authorization':'Bearer ${session.accessToken}'});
    return (decoded as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }


  static Future<Map<String,dynamic>?> sharedCharacterByCode(CloudSession session,String code) async {
    final uri=Uri.parse('$supabaseUrl/rest/v1/rpg_shared_characters?share_code=eq.${Uri.encodeComponent(code)}&select=owner_id,character_id,share_code,snapshot,master_patch,master_patch_updated_at,updated_at&limit=1');
    final decoded=await _rawRequest('GET',uri,headers:{'Authorization':'Bearer ${session.accessToken}'});
    if(decoded is! List || decoded.isEmpty) return null;
    return Map<String,dynamic>.from(decoded.first as Map);
  }


  static Future<void> updateSharedCharacterPatch(CloudSession session,String code,Map<String,dynamic> patch) async {
    final ok=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/set_rpg_master_patch'),headers:{'Authorization':'Bearer ${session.accessToken}'},body:{'p_share_code':code,'p_patch':patch});
    if(ok!=true) throw AppMessageException('Sem permissão para alterar esta ficha.');
  }

  static Future<void> clearSharedCharacterPatch(CloudSession session, String code) async {
    await _request('PATCH', Uri.parse('$supabaseUrl/rest/v1/rpg_shared_characters?share_code=eq.${Uri.encodeComponent(code)}'), headers: {
      'Authorization': 'Bearer ${session.accessToken}', 'Prefer':'return=minimal',
    }, body: {'master_patch': <String,dynamic>{}, 'master_patch_updated_at': null});
  }

  static Future<Map<String, dynamic>?> downloadBackup(CloudSession session) async {
    final snapshot = await downloadSnapshot(session);
    return snapshot?.payload;
  }
  static Future<bool> hasAppAccess(CloudSession session) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/has_rpg_app_access'),headers:{'Authorization':'Bearer ${session.accessToken}'},body:const {});
    final allowed = decoded == true;
    await _cacheAccessValidation(session, allowed);
    return allowed;
  }

  static Future<bool> redeemInvite(CloudSession session,String code) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/redeem_rpg_invite'),headers:{'Authorization':'Bearer ${session.accessToken}'},body:{'p_code':code.trim().toUpperCase()});
    return decoded==true;
  }

  /// Libera o acesso ao Grimório para a conta atual sem convite (1.3.72,
  /// "Criar conta"). Precisa da migração *_open_access_v172.sql aplicada.
  static Future<bool> claimOpenAccess(CloudSession session) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/claim_rpg_open_access'),headers:{'Authorization':'Bearer ${session.accessToken}'},body:const {});
    return decoded==true;
  }

  static Future<List<Map<String,dynamic>>> approvedPlayerCampaigns(CloudSession session) async {
    final uri=Uri.parse('$supabaseUrl/rest/v1/rpg_character_link_requests?character_owner_id=eq.${Uri.encodeComponent(session.userId)}&status=eq.approved&share_code=not.is.null&select=campaign_id,share_code');
    final decoded=await _rawRequest('GET',uri,headers:{'Authorization':'Bearer ${session.accessToken}'});
    return (decoded as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }


  static Future<bool> isAppAdmin(CloudSession session) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/is_rpg_app_admin'),
      headers:{'Authorization':'Bearer ${session.accessToken}'},body:const {});
    return decoded==true;
  }

  static Future<List<Map<String,dynamic>>> listInvitesAdmin(CloudSession session) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/list_rpg_invites_admin'),
      headers:{'Authorization':'Bearer ${session.accessToken}'},body:const {});
    return (decoded as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }

  static Future<String> createInviteAdmin(CloudSession session,{String label='',int maxUses=1,DateTime? expiresAt}) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/create_rpg_invite_admin'),
      headers:{'Authorization':'Bearer ${session.accessToken}'},
      body:{'p_label':label.trim(),'p_max_uses':maxUses,'p_expires_at':expiresAt?.toUtc().toIso8601String()});
    return decoded?.toString() ?? '';
  }

  static Future<bool> revokeInviteAdmin(CloudSession session,String id) async {
    final decoded=await _rawRequest('POST',Uri.parse('$supabaseUrl/rest/v1/rpc/revoke_rpg_invite_admin'),
      headers:{'Authorization':'Bearer ${session.accessToken}'},body:{'p_id':id});
    return decoded==true;
  }


}
