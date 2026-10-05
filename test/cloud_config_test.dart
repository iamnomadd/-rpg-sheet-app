import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';

void main() {
  test('configuração padrão do Supabase é válida para HTTPS', () {
    final uri = Uri.parse(CloudService.supabaseUrl);

    expect(CloudService.configured, isTrue);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(CloudService.supabaseAnonKey, isNotEmpty);
  });

  test('sessão anônima usa nome amigável', () {
    const session = CloudSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      userId: 'user',
      email: '',
      isAnonymous: true,
    );

    expect(session.displayName, 'Nuvem anônima');
  });
}
