import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/condition_presets.dart';
import '../../models/campaign.dart';
import '../../models/character.dart';
import '../../services/app_state.dart';
import '../../services/cloud_service.dart';
import '../../services/rpg_file_service.dart';
import 'npc_sheet_screen.dart';
import 'initiative_tools.dart';
import '../character/resource_quick_adjust.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/card_spacing.dart';

part 'master_screen.dart';
part 'campaigns_list_screen.dart';
part 'campaign_detail_screen.dart';
part 'master_tools_screen.dart';
part 'session_tools_screen.dart';

IconData _npcKindIcon(String kind) => switch (kind) {
      'Monstro' => Icons.bug_report_outlined,
      'Chefe' => Icons.workspace_premium_outlined,
      'Aliado' => Icons.shield_outlined,
      _ => Icons.person_outline,
    };

/// Vínculo remoto (com shareCode) do jogador com esse id, se houver.
Map<String, dynamic>? _remoteLink(Campaign campaign, String id) {
  for (final link in campaign.linkedCharacters) {
    final snapshot = link['snapshot'];
    if (snapshot is Map &&
        '${snapshot['id']}' == id &&
        '${link['shareCode'] ?? ''}'.isNotEmpty) {
      return link;
    }
  }
  return null;
}

/// Condições exibidas para o participante. A ficha do jogador é a fonte da
/// verdade: local mostra só character.conditions; remoto mostra o snapshot
/// com as pendências do mestre (entry['conditions'] = adições,
/// entry['conditionsRemoved'] = remoções). NPC/avulso ou jogador sem ficha:
/// entry['conditions'] como lista definitiva.
List<String> _participantConditions(
    AppState state, Campaign campaign, Map<String, dynamic> entry) {
  if (entry['type'] != 'player') return initiativeConditions(entry);
  final id = '${entry['id'] ?? ''}';
  final local = state.characters.where((c) => c.id == id);
  if (local.isNotEmpty) return conditionsFromRaw(local.first.conditions);
  final link = _remoteLink(campaign, id);
  if (link == null) return initiativeConditions(entry);
  return playerDisplayConditions(
    conditionsFromRaw((link['snapshot'] as Map)['conditions']),
    initiativeConditions(entry),
    conditionsFromRaw(entry['conditionsRemoved']),
  );
}

/// Publica o estado de combate da campanha (rodada, turno e iniciativa).
Future<void> _syncCombatState(Campaign campaign) async {
  try {
    final session = await CloudService.ensureSession();
    await CloudService.publishSessionState(session, campaign.id, {
      'round': campaign.sessionRound,
      'active': campaign.combatActive,
      'current_index': campaign.currentTurnIndex,
      'initiative': campaign.initiative,
    });
  } catch (_) {}
}
