import 'dart:convert';
import 'dart:typed_data';
import '../core/app_version.dart';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/campaign.dart';
import '../models/character.dart';
import '../models/rpg_system.dart';
import 'app_state.dart';

class RpgFileService {
  static const format = 'rpg_sheet';
  static const formatVersion = 2;
  static const supportedFormatVersions = {1, 2};
  static const _uuid = Uuid();

  static Map<String, dynamic> _envelope({
    required String type,
    required dynamic data,
  }) => {
        'format': format,
        'formatVersion': formatVersion,
        'type': type,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': data,
      };

  static Future<void> _shareJson(
    Map<String, dynamic> json,
    String fileName,
  ) async {
    const encoder=JsonEncoder.withIndent('  ');
    final bytes=Uint8List.fromList(utf8.encode(encoder.convert(json)));
    await Share.shareXFiles(
      [XFile.fromData(bytes,mimeType:'application/json',name:fileName)],
      text:'Arquivo RPG Sheet: $fileName',
    );
  }

  static Future<void> exportSystem(RpgSystem system) => _shareJson(
        _envelope(type: 'system', data: system.toJson()),
        _safeName('${system.name}.rpg'),
      );

  static Future<void> exportCharacter(
    Character character,
    RpgSystem system,
  ) => _shareJson(
        _envelope(
          type: 'character',
          data: {
            'character': character.toJson(),
            'system': system.toJson(),
          },
        ),
        _safeName('${character.name}.rpg'),
      );

  static Future<void> shareCharacterSummary(
    Character character,
    RpgSystem system,
  ) async {
    final buffer = StringBuffer()
      ..writeln('RPG Sheet • ${character.name}')
      ..writeln('Sistema: ${system.name}')
      ..writeln('Nível: ${character.level}');

    if (character.className.isNotEmpty) buffer.writeln('Classe: ${character.className}');
    if (character.race.isNotEmpty) buffer.writeln('Raça: ${character.race}');
    if (character.player.isNotEmpty) buffer.writeln('Jogador: ${character.player}');

    if (system.attributes.isNotEmpty) {
      buffer.writeln('\nAtributos:');
      for (final name in system.attributes) {
        buffer.writeln('• $name: ${character.attributes[name] ?? 0}');
      }
    }

    if (system.resources.isNotEmpty) {
      buffer.writeln('\nRecursos:');
      for (final name in system.resources) {
        buffer.writeln('• $name: ${character.resourceValues[name] ?? 0}/${character.resourceMaxValues[name] ?? 0}');
      }
    }

    if (character.abilities.isNotEmpty) {
      buffer.writeln('\nHabilidades: ${character.abilities.join(', ')}');
    }
    if (character.inventory.isNotEmpty) {
      buffer.writeln('Inventário: ${character.inventory.join(', ')}');
    }

    await Share.share(buffer.toString(), subject: 'Ficha • ${character.name}');
  }

  static Future<void> exportCampaign(
    Campaign campaign,
    AppState state, {
    required bool playerPackage,
  }) async {
    final allowedIds = playerPackage
        ? campaign.characterIds.where((id) => !campaign.hiddenCharacterIds.contains(id)).toSet()
        : campaign.characterIds.toSet();

    final characters = state.characters.where((c) => allowedIds.contains(c.id)).toList();
    final systemIds = characters.map((c) => c.systemId).toSet();
    final systems = state.systems.where((s) => systemIds.contains(s.id)).toList();

    final exportedCampaign = Campaign(
      id: campaign.id,
      name: campaign.name,
      description: campaign.description,
      characterIds: characters.map((e) => e.id).toList(),
      hiddenCharacterIds: playerPackage ? [] : List<String>.from(campaign.hiddenCharacterIds),
      npcs: List<String>.from(campaign.npcs),
      npcSheets: playerPackage ? [] : (jsonDecode(jsonEncode(campaign.npcSheets)) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      locations: List<String>.from(campaign.locations),
      notes: campaign.notes,
      masterNotes: playerPackage ? '' : campaign.masterNotes,
      sessionNotes: playerPackage ? '' : campaign.sessionNotes,
      sessionRound: playerPackage ? 1 : campaign.sessionRound,
      initiative: playerPackage ? [] : campaign.initiative.map((e) => Map<String, dynamic>.from(e)).toList(),
      conditions: playerPackage ? [] : List<String>.from(campaign.conditions),
      masterScene: playerPackage ? '' : campaign.masterScene,
      masterObjectives: playerPackage ? [] : List<String>.from(campaign.masterObjectives),
      sessionLog: playerPackage ? [] : List<String>.from(campaign.sessionLog),
      // Vínculos remotos dependem das contas/autorização do Supabase e não são portáteis.
      linkedCharacters: const [],
      combatActive: playerPackage ? false : campaign.combatActive,
      currentTurnIndex: playerPackage ? 0 : campaign.currentTurnIndex,
    );

    await _shareJson(
      _envelope(
        type: 'campaign',
        data: {
          'shareMode': playerPackage ? 'player' : 'master',
          'campaign': exportedCampaign.toJson(),
          'characters': characters.map((e) => e.toJson()).toList(),
          'systems': systems.map((e) => e.toJson()).toList(),
        },
      ),
      _safeName('${campaign.name}-${playerPackage ? 'jogadores' : 'mestre'}.rpg'),
    );
  }

  static Future<void> shareCampaignSummary(
    Campaign campaign,
    AppState state,
  ) async {
    final visibleCharacters = campaign.characterIds
        .where((id) => !campaign.hiddenCharacterIds.contains(id))
        .map((id) {
          final found = state.characters.where((c) => c.id == id);
          return found.isEmpty ? 'Ficha indisponível' : found.first.name;
        })
        .toList();

    final buffer = StringBuffer()
      ..writeln('RPG Sheet • ${campaign.name}');
    if (campaign.description.isNotEmpty) buffer.writeln(campaign.description);
    if (visibleCharacters.isNotEmpty) buffer.writeln('\nPersonagens: ${visibleCharacters.join(', ')}');
    final npcNames = <String>[...campaign.npcs, ...campaign.npcSheets.map((e) { final raw=e['sheet']; return raw is Map ? '${raw['name'] ?? e['name'] ?? 'NPC'}' : '${e['name'] ?? 'NPC'}'; })];
    if (npcNames.isNotEmpty) buffer.writeln('NPCs: ${npcNames.join(', ')}');
    if (campaign.locations.isNotEmpty) buffer.writeln('Locais: ${campaign.locations.join(', ')}');
    if (campaign.notes.isNotEmpty) buffer.writeln('\nNotas:\n${campaign.notes}');

    await Share.share(buffer.toString(), subject: 'Campanha • ${campaign.name}');
  }

  static Future<void> exportBackup(AppState state) => _shareJson(
        _envelope(
          type: 'backup',
          data: {
            'backupSchema': 4,
            'appVersion': appVersion,
            'characters': state.characters.map((e) => e.toJson()).toList(),
            'systems': state.systems.map((e) => e.toJson()).toList(),
            'campaigns': state.campaigns.map((e) => e.toJson()).toList(),
            'savedRolls': state.savedRolls,
            'diceHistory': state.diceHistory,
            'preferences': {
              'themeId': state.themeId,
              'largeText': state.largeText,
              'compactMode': state.compactMode,
              'reduceAnimations': state.reduceAnimations,
              'masterToolsEnabled': state.masterToolsEnabled,
            },
          },
        ),
        'rpg-sheet-backup.rpg',
      );

  static Future<Map<String, dynamic>?> pickBackupForRestore() async {
    final json = await pickAndRead();
    if (json == null) return null;
    _validateEnvelope(json);
    if (json['type'] != 'backup') {
      throw const FormatException('Escolha um arquivo de backup do RPG Sheet.');
    }
    return Map<String, dynamic>.from(json['data'] ?? {});
  }

  static Map<String, int> backupSummary(Map<String, dynamic> data) => {
        'characters': (data['characters'] as List? ?? []).length,
        'systems': (data['systems'] as List? ?? []).length,
        'campaigns': (data['campaigns'] as List? ?? []).length,
        'savedRolls': (data['savedRolls'] as List? ?? []).length,
        'diceHistory': (data['diceHistory'] as List? ?? []).length,
      };

  static void _validateEnvelope(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Este arquivo não pertence ao RPG Sheet.');
    }
    final version = json['formatVersion'];
    if (version is! int || !supportedFormatVersions.contains(version)) {
      throw const FormatException('Versão do arquivo não suportada.');
    }
  }

  static Future<Map<String, dynamic>?> pickAndRead() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['rpg', 'json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;

    final text = utf8.decode(result.files.single.bytes!);
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('Arquivo inválido.');
    return Map<String, dynamic>.from(decoded);
  }

  static Future<String> importInto(AppState state) async {
    final json = await pickAndRead();
    if (json == null) return 'cancelled';

    _validateEnvelope(json);

    final type = json['type'];
    final data = Map<String, dynamic>.from(json['data'] ?? {});

    switch (type) {
      case 'system':
        final original = RpgSystem.fromJson(data);
        final imported = original.copyWith(id: _uuid.v4(), name: _uniqueSystemName(state, original.name));
        await state.addSystem(imported);
        return 'system';

      case 'character':
        final originalSystem = RpgSystem.fromJson(
          Map<String, dynamic>.from(data['system'] ?? {}),
        );
        final importedSystem = originalSystem.copyWith(id: _uuid.v4(), name: _uniqueSystemName(state, originalSystem.name));
        final originalCharacter = Character.fromJson(
          Map<String, dynamic>.from(data['character'] ?? {}),
        );
        final importedCharacter = _copyCharacter(
          originalCharacter,
          newId: _uuid.v4(),
          newSystemId: importedSystem.id,
        );
        await state.addSystem(importedSystem);
        await state.addImportedCharacter(importedCharacter);
        return 'character';

      case 'campaign':
        await _importCampaignPackage(state, data);
        return 'campaign';

      case 'backup':
        await state.replaceFromBackup(data);
        return 'backup';

      default:
        throw const FormatException('Tipo de arquivo desconhecido.');
    }
  }

  static Future<void> _importCampaignPackage(
    AppState state,
    Map<String, dynamic> data,
  ) async {
    final rawSystems = (data['systems'] as List? ?? [])
        .map((e) => RpgSystem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final rawCharacters = (data['characters'] as List? ?? [])
        .map((e) => Character.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final originalCampaign = Campaign.fromJson(
      Map<String, dynamic>.from(data['campaign'] ?? {}),
    );

    final systemMap = <String, String>{};
    for (final source in rawSystems) {
      final imported = source.copyWith(id: _uuid.v4(), name: _uniqueSystemName(state, source.name));
      systemMap[source.id] = imported.id;
      await state.addSystem(imported);
    }

    final characterMap = <String, String>{};
    for (final source in rawCharacters) {
      final mappedSystemId = systemMap[source.systemId] ??
          (state.systems.any((s) => s.id == source.systemId) ? source.systemId : 'generic');
      final newId = _uuid.v4();
      characterMap[source.id] = newId;
      await state.addImportedCharacter(
        _copyCharacter(source, newId: newId, newSystemId: mappedSystemId),
      );
    }

    var campaignName = originalCampaign.name.trim().isEmpty ? 'Campanha importada' : originalCampaign.name.trim();
    final baseName = campaignName;
    var counter = 2;
    while (state.campaigns.any((c) => c.name.toLowerCase() == campaignName.toLowerCase())) {
      campaignName = '$baseName ($counter)';
      counter++;
    }

    final npcIdMap = <String, String>{};
    final importedNpcSheets = <Map<String, dynamic>>[];
    for (final source in originalCampaign.npcSheets) {
      final oldNpcId='${source['id'] ?? ''}';
      final newNpcId=_uuid.v4();
      if(oldNpcId.isNotEmpty) npcIdMap[oldNpcId]=newNpcId;
      final copied=Map<String,dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
      copied['id']=newNpcId;
      final raw=copied['sheet'];
      if(raw is Map){final data=Map<String,dynamic>.from(raw);data['id']=newNpcId;data['shareCode']='';data['player']='Mestre';copied['sheet']=data;copied['name']=data['name'] ?? copied['name'];}
      importedNpcSheets.add(copied);
    }

    final importedCampaign = Campaign(
      id: _uuid.v4(),
      name: campaignName,
      description: originalCampaign.description,
      characterIds: originalCampaign.characterIds
          .where((id) => characterMap.containsKey(id))
          .map((id) => characterMap[id]!)
          .toList(),
      hiddenCharacterIds: originalCampaign.hiddenCharacterIds
          .where((id) => characterMap.containsKey(id))
          .map((id) => characterMap[id]!)
          .toList(),
      npcs: List<String>.from(originalCampaign.npcs),
      npcSheets: importedNpcSheets,
      locations: List<String>.from(originalCampaign.locations),
      notes: originalCampaign.notes,
      masterNotes: originalCampaign.masterNotes,
      sessionNotes: originalCampaign.sessionNotes,
      sessionRound: originalCampaign.sessionRound,
      initiative: originalCampaign.initiative.map((entry) {
        final mapped = Map<String, dynamic>.from(entry);
        final oldId = mapped['id']?.toString() ?? '';
        if (characterMap.containsKey(oldId)) mapped['id'] = characterMap[oldId];
        if (oldId.startsWith('npc:')) { final sourceId=oldId.substring(4); if(npcIdMap.containsKey(sourceId)) mapped['id']='npc:${npcIdMap[sourceId]}'; }
        return mapped;
      }).toList(),
      conditions: List<String>.from(originalCampaign.conditions),
      masterScene: originalCampaign.masterScene,
      masterObjectives: List<String>.from(originalCampaign.masterObjectives),
      sessionLog: List<String>.from(originalCampaign.sessionLog),
      // Vínculos remotos não são importados: precisam ser refeitos pelas contas envolvidas.
      linkedCharacters: const [],
      combatActive: originalCampaign.combatActive,
      currentTurnIndex: originalCampaign.currentTurnIndex,
    );
    await state.addCampaign(importedCampaign);
  }

  static Character _copyCharacter(
    Character original, {
    required String newId,
    required String newSystemId,
  }) {
    return Character(
      id: newId,
      name: original.name,
      player: original.player,
      systemId: newSystemId,
      className: original.className,
      race: original.race,
      background: original.background,
      history: original.history,
      portraitPath: _portableImagePath(original.portraitPath),
      fullBodyPath: _portableImagePath(original.fullBodyPath),
      level: original.level,
      hp: original.hp,
      maxHp: original.maxHp,
      energy: original.energy,
      maxEnergy: original.maxEnergy,
      attributes: Map<String, int>.from(original.attributes),
      resourceValues: Map<String, int>.from(original.resourceValues),
      resourceMaxValues: Map<String, int>.from(original.resourceMaxValues),
      sectionNotes: Map<String, String>.from(original.sectionNotes),
      skills: List<String>.from(original.skills),
      abilities: List<String>.from(original.abilities),
      inventory: List<String>.from(original.inventory),
      equipment: List<String>.from(original.equipment),
      abilityDescriptions: Map<String, String>.from(original.abilityDescriptions),
      inventoryDescriptions: Map<String, String>.from(original.inventoryDescriptions),
      abilityDetails: original.abilityDetails.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))),
      inventoryDetails: original.inventoryDetails.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))),
      skillTree: original.skillTree.map((node) => Map<String, dynamic>.from(node)).toList(),
      generalOrder: List<String>.from(original.generalOrder),
      sheetTabOrder: List<String>.from(original.sheetTabOrder),
      conditions: List<String>.from(original.conditions),
      actionOrder: List<String>.from(original.actionOrder),
      hiddenActionGroups: List<String>.from(original.hiddenActionGroups),
    );
  }

  static String _portableImagePath(String value) {
    // URLs data: são autocontidas e continuam válidas depois de exportar/importar.
    // Caminhos locais e blob: pertencem somente ao dispositivo/sessão original.
    return value.startsWith('data:image/') ? value : '';
  }

  static Future<RpgSystem?> importSystemOnly(AppState state) async {
    final json = await pickAndRead();
    if (json == null) return null;

    _validateEnvelope(json);
    if (json['type'] != 'system') {
      throw const FormatException('Escolha um arquivo de sistema .rpg.');
    }

    final data = Map<String, dynamic>.from(json['data'] ?? {});
    final original = RpgSystem.fromJson(data);
    final imported = original.copyWith(id: _uuid.v4(), name: _uniqueSystemName(state, original.name));
    await state.addSystem(imported);
    return imported;
  }

  static String _uniqueSystemName(AppState state, String base) {
    final clean = base.trim().isEmpty ? 'Sistema importado' : base.trim();
    var name = clean;
    var counter = 2;
    while (state.systems.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      name = '$clean ($counter)';
      counter++;
    }
    return name;
  }

  static String _safeName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'rpg-sheet.rpg' : sanitized;
  }
}