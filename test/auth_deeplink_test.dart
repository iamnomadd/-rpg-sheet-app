import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/services/cloud_service.dart';

void main() {
  test('auth callback uses RPG Sheet custom scheme', () {
    expect(CloudService.authCallbackUrl, 'rpgsheet://auth-callback');
    final uri = Uri.parse(CloudService.authCallbackUrl);
    expect(uri.scheme, 'rpgsheet');
    expect(uri.host, 'auth-callback');
  });
}
