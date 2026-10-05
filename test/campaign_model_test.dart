import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_sheet_app/models/campaign.dart';

void main() {
  test('campanha preserva estado completo da sessão ao serializar', () {
    final original = Campaign(
      id: 'camp-1',
      name: 'Maré Negra',
      masterScene: 'Convés em tempestade',
      masterObjectives: ['[ ] Encontrar o mapa'],
      sessionLog: ['Combate iniciado.'],
      initiative: [
        {'id': 'char-1', 'name': 'Capitão', 'type': 'player', 'value': 18, 'done': false},
      ],
      conditions: ['Chuva forte'],
      combatActive: true,
      currentTurnIndex: 0,
      sessionRound: 3,
    );

    final restored = Campaign.fromJson(original.toJson());

    expect(restored.masterScene, original.masterScene);
    expect(restored.masterObjectives, original.masterObjectives);
    expect(restored.sessionLog, original.sessionLog);
    expect(restored.initiative.single['id'], 'char-1');
    expect(restored.conditions, contains('Chuva forte'));
    expect(restored.combatActive, isTrue);
    expect(restored.sessionRound, 3);
  });

  test('campanha preserva fichas independentes de NPCs e monstros', () {
    final original = Campaign(
      id: 'camp-npc',
      name: 'Caçada',
      npcSheets: [
        {
          'id': 'npc-1',
          'name': 'Lobo Sombrio',
          'kind': 'Monstro',
          'source': 'custom',
          'sheet': {
            'id': 'npc-1',
            'name': 'Lobo Sombrio',
            'player': 'Mestre',
            'systemId': 'generic',
            'resourceValues': {'Vida': 24},
            'resourceMaxValues': {'Vida': 30},
            'conditions': ['Sangrando'],
          },
        },
      ],
    );

    final restored = Campaign.fromJson(original.toJson());
    expect(restored.npcSheets, hasLength(1));
    expect(restored.npcSheets.first['kind'], 'Monstro');
    final sheet = Map<String, dynamic>.from(restored.npcSheets.first['sheet'] as Map);
    expect((sheet['resourceValues'] as Map)['Vida'], 24);
    expect(sheet['conditions'], contains('Sangrando'));
  });
}
