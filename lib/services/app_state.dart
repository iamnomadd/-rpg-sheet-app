import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../core/app_version.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/campaign.dart';
import '../models/character.dart';
import '../models/rpg_system.dart';
import 'cloud_service.dart';

class AppState extends ChangeNotifier {
  final _uuid = const Uuid();
  List<Character> characters = [];
  List<RpgSystem> systems = [];
  List<Campaign> campaigns = [];
  List<Map<String, dynamic>> diceHistory = [];
  List<Map<String, dynamic>> savedRolls = [];
  bool loaded = false;
  String themeId = 'classic';
  bool largeText = false;
  bool compactMode = false;
  bool reduceAnimations = false;
  bool masterToolsEnabled = false;
  bool autoSync = true;
  DateTime? lastLocalChangeUtc;
  DateTime? lastSyncUtc;
  String syncStatus = 'Aguardando';
  bool _applyingCloud = false;
  bool _syncing = false;
  Timer? _autoSyncDebounce;
  int _localRevision = 0;

  static List<RpgSystem> _builtInSystems() => [
        RpgSystem(
          id: 'generic',
          name: 'Sistema Padrão',
          description: 'Ficha genérica e flexível do RPG Sheet.',
          attributes: ['FOR', 'DES', 'CON', 'INT', 'SAB', 'CAR'],
          skills: [],
          resources: ['Vida', 'Energia'],
          sections: ['História', 'Traços', 'Anotações'],
          dice: [4, 6, 8, 10, 12, 20, 100],
        ),
        RpgSystem(
          id: 'dnd5e',
          name: 'D&D 5e',
          description: 'Estrutura para Dungeons & Dragons 5ª edição.',
          attributes: ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'],
          skills: ['Acrobacia', 'Arcanismo', 'Atletismo', 'Atuação', 'Enganação', 'Furtividade', 'História', 'Intimidação', 'Intuição', 'Investigação', 'Lidar com Animais', 'Medicina', 'Natureza', 'Percepção', 'Persuasão', 'Prestidigitação', 'Religião', 'Sobrevivência'],
          resources: ['Vida', 'PV Temporários', 'Inspiração'],
          sections: ['Classe e Subclasse', 'Antecedente', 'CA e Iniciativa', 'Salvaguardas', 'Dados de Vida', 'Testes contra Morte', 'Proficiências e Idiomas', 'Magias', 'Traços', 'Anotações'],
          dice: [4, 6, 8, 10, 12, 20, 100],
          skillAttributes: Map<String, String>.from(dnd5eSkillAttributes),
        ),
        RpgSystem(
          id: 'tormenta20',
          name: 'Tormenta20',
          description: 'Estrutura de personagem para Tormenta20.',
          attributes: ['Força', 'Destreza', 'Constituição', 'Inteligência', 'Sabedoria', 'Carisma'],
          skills: ['Acrobacia', 'Adestramento', 'Atletismo', 'Atuação', 'Cavalgar', 'Conhecimento', 'Cura', 'Diplomacia', 'Enganação', 'Fortitude', 'Furtividade', 'Guerra', 'Iniciativa', 'Intimidação', 'Intuição', 'Investigação', 'Jogatina', 'Ladinagem', 'Luta', 'Misticismo', 'Nobreza', 'Ofício', 'Percepção', 'Pilotagem', 'Pontaria', 'Reflexos', 'Religião', 'Sobrevivência', 'Vontade'],
          resources: ['PV', 'PM'],
          sections: ['Origem', 'Raça', 'Classe', 'Defesa', 'Deslocamento', 'Proficiências', 'Poderes', 'Magias', 'Anotações'],
          dice: [4, 6, 8, 10, 12, 20, 100],
        ),
        RpgSystem(
          id: 'ordem_paranormal',
          name: 'Ordem Paranormal',
          description: 'Estrutura de agente para Ordem Paranormal RPG.',
          attributes: ['Agilidade', 'Intelecto', 'Vigor', 'Presença', 'Força'],
          skills: ['Acrobacia', 'Adestramento', 'Artes', 'Atletismo', 'Atualidades', 'Ciências', 'Crime', 'Diplomacia', 'Enganação', 'Fortitude', 'Furtividade', 'Iniciativa', 'Intimidação', 'Intuição', 'Investigação', 'Luta', 'Medicina', 'Ocultismo', 'Percepção', 'Pilotagem', 'Pontaria', 'Profissão', 'Reflexos', 'Religião', 'Sobrevivência', 'Tática', 'Tecnologia', 'Vontade'],
          resources: ['PV', 'PE', 'Sanidade'],
          sections: ['Origem', 'Classe e Trilha', 'NEX', 'Defesa', 'Deslocamento', 'Proteção e Resistências', 'Rituais', 'Poderes', 'Anotações'],
          dice: [4, 6, 8, 10, 12, 20, 100],
        ),
        RpgSystem(
          id: 'shadowdark',
          name: 'Shadowdark',
          description: 'Estrutura enxuta para Shadowdark RPG.',
          attributes: ['FOR', 'DES', 'CON', 'INT', 'SAB', 'CAR'],
          skills: [],
          resources: ['PV'],
          sections: ['Classe', 'Ancestralidade', 'CA', 'Iniciativa', 'Talentos', 'Magias', 'Equipamento', 'Tochas e Luz', 'Anotações'],
          dice: [4, 6, 8, 10, 12, 20, 100],
        ),
      ];

  List<dynamic> _safeDecodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final charactersJson = prefs.getString('characters');
    final systemsJson = prefs.getString('systems');
    final campaignsJson = prefs.getString('campaigns');
    final diceHistoryJson = prefs.getString('dice_history');
    final savedRollsJson = prefs.getString('saved_rolls');
    themeId = prefs.getString('theme_id') ?? 'classic';
    largeText = prefs.getBool('large_text') ?? false;
    compactMode = prefs.getBool('compact_mode') ?? false;
    reduceAnimations = prefs.getBool('reduce_animations') ?? false;
    masterToolsEnabled = prefs.getBool('master_tools_enabled') ?? false;
    autoSync = prefs.getBool('auto_sync') ?? true;
    lastLocalChangeUtc = DateTime.tryParse(prefs.getString('last_local_change_utc') ?? '')?.toUtc();
    lastSyncUtc = DateTime.tryParse(prefs.getString('last_sync_utc') ?? '')?.toUtc();

    characters = _safeDecodeList(charactersJson)
        .whereType<Map>()
        .map((e) => Character.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    systems = _safeDecodeList(systemsJson)
        .whereType<Map>()
        .map((e) => RpgSystem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // Mantém fichas/sistemas personalizados existentes e garante os cinco presets oficiais do app.
    // O preset genérico antigo é atualizado para "Sistema Padrão" sem trocar seu id,
    // preservando todas as fichas já vinculadas a "generic".
    for (final preset in _builtInSystems().reversed) {
      final index = systems.indexWhere((item) => item.id == preset.id);
      if (index < 0) {
        systems.insert(0, preset);
      } else if (preset.id == 'generic') {
        final current = systems[index];
        if (current.name == 'Sistema Genérico') {
          systems[index] = current.copyWith(name: 'Sistema Padrão');
        }
      }
    }

    campaigns = _safeDecodeList(campaignsJson)
        .whereType<Map>()
        .map((e) => Campaign.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    diceHistory = _safeDecodeList(diceHistoryJson)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    savedRolls = _safeDecodeList(savedRollsJson)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    loaded = true;
    notifyListeners();
    // Local data is ready immediately. Cloud sync runs after startup instead of
    // holding the first usable screen behind network/auth latency.
    if (autoSync) {
      Future<void>.delayed(const Duration(milliseconds:900),(){
        syncNow(silent:true);
      });
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'characters',
      jsonEncode(characters.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'systems',
      jsonEncode(systems.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'campaigns',
      jsonEncode(campaigns.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('dice_history', jsonEncode(diceHistory));
    await prefs.setString('saved_rolls', jsonEncode(savedRolls));
    await prefs.setString('theme_id', themeId);
    await prefs.setBool('large_text', largeText);
    await prefs.setBool('compact_mode', compactMode);
    await prefs.setBool('reduce_animations', reduceAnimations);
    await prefs.setBool('master_tools_enabled', masterToolsEnabled);
    await prefs.setBool('auto_sync', autoSync);
    if (!_applyingCloud) {
      _localRevision++;
      lastLocalChangeUtc = DateTime.now().toUtc();
      await prefs.setString('last_local_change_utc', lastLocalChangeUtc!.toIso8601String());
    }
    if (lastSyncUtc != null) {
      await prefs.setString('last_sync_utc', lastSyncUtc!.toIso8601String());
    }
    if (!_applyingCloud && autoSync && loaded) {
      _autoSyncDebounce?.cancel();
      _autoSyncDebounce=Timer(const Duration(milliseconds:700),(){
        syncNow(silent:true);
      });
    }
  }

  Map<String, dynamic> cloudPayload() => {
        'backupSchema': 4,
        'appVersion': appVersion,
        'characters': characters.map((e) => e.toJson()).toList(),
        'systems': systems.map((e) => e.toJson()).toList(),
        'campaigns': campaigns.map((e) => e.toJson()).toList(),
        'savedRolls': savedRolls,
        'diceHistory': diceHistory,
        'preferences': {
          'themeId': themeId,
          'largeText': largeText,
          'compactMode': compactMode,
          'reduceAnimations': reduceAnimations,
          'masterToolsEnabled': masterToolsEnabled,
        },
        'localChangedAt': lastLocalChangeUtc?.toIso8601String(),
      };

  Future<String> syncNow({bool silent = false}) async {
    if (_syncing) return syncStatus;
    if (!CloudService.configured) {
      syncStatus = 'Nuvem não configurada';
      if (!silent) notifyListeners();
      return syncStatus;
    }
    _syncing = true;
    syncStatus = 'Sincronizando…';
    if (!silent) notifyListeners();
    try {
      final revisionAtStart = _localRevision;
      final session = await CloudService.ensureSession();
      final cloud = await CloudService.downloadSnapshot(session);
      final localTime = lastLocalChangeUtc;
      final cloudTime = cloud?.updatedAt;
      if (cloud == null) {
        await CloudService.uploadBackup(session, cloudPayload());
        syncStatus = 'Enviado para a nuvem';
      } else if (cloudTime != null && (localTime == null || cloudTime.isAfter(localTime.add(const Duration(seconds: 2))))) {
        // Never replace local state if the player edited anything while this
        // cloud request was in flight. A later sync will reconcile safely.
        if (revisionAtStart != _localRevision) {
          syncStatus = 'Alterações locais preservadas';
        } else {
          _applyingCloud = true;
          try {
            await replaceFromBackup(cloud.payload);
            lastLocalChangeUtc = cloudTime;
          } finally {
            _applyingCloud = false;
          }
          syncStatus = 'Atualizado pela nuvem';
        }
      } else if (localTime != null && (cloudTime == null || localTime.isAfter(cloudTime.add(const Duration(seconds: 2))))) {
        await CloudService.uploadBackup(
          session,
          cloudPayload(),
          expectedCloudUpdatedAt: cloudTime,
        );
        syncStatus = 'Alterações enviadas';
      } else {
        syncStatus = 'Tudo sincronizado';
      }
      lastSyncUtc = DateTime.now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_utc', lastSyncUtc!.toIso8601String());
      if (lastLocalChangeUtc != null) await prefs.setString('last_local_change_utc', lastLocalChangeUtc!.toIso8601String());
    } catch (_) {
      syncStatus = 'Falha na sincronização';
      if (!silent) rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
    return syncStatus;
  }

  Future<void> setAutoSync(bool value) async {
    autoSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', value);
    notifyListeners();
    if (value) await syncNow(silent: true);
  }

  Future<Character> addCharacter({
    required String name,
    String systemId = 'generic',
  }) async {
    final system = systems.firstWhere(
      (s) => s.id == systemId,
      orElse: () => systems.firstWhere((s) => s.id == 'generic'),
    );

    final attributes = <String, int>{};
    for (final attribute in system.attributes) {
      attributes[attribute] = 10;
    }

    final resourceValues = <String, int>{};
    final resourceMaxValues = <String, int>{};
    for (final resource in system.resources) {
      final key = resource.toLowerCase();
      final isLife = key == 'vida' || key == 'pv';
      final isEnergy = key == 'energia' || key == 'pm' || key == 'pe';
      final isSanity = key == 'sanidade';
      final isInspiration = key == 'inspiração';
      final isTemporaryHp = key == 'pv temporários';
      final start = isLife ? 10 : isSanity ? 10 : isInspiration ? 0 : isTemporaryHp ? 0 : isEnergy ? 0 : 0;
      resourceValues[resource] = start;
      resourceMaxValues[resource] = isLife || isSanity ? 10 : 0;
    }

    final sectionNotes = <String, String>{};
    for (final section in system.sections) {
      sectionNotes[section] = '';
    }

    final character = Character(
      id: _uuid.v4(),
      name: name,
      systemId: system.id,
      attributes: attributes,
      resourceValues: resourceValues,
      resourceMaxValues: resourceMaxValues,
      sectionNotes: sectionNotes,
    );
    characters.add(character);
    await save();
    notifyListeners();
    return character;
  }

  /// Limpeza na nuvem ao apagar uma ficha compartilhada (vínculos com o
  /// Mestre e a ficha publicada). Substituível só em testes.
  @visibleForTesting
  Future<void> Function(String characterId, String shareCode) deleteSharedCleanup = _deleteSharedInCloud;

  static Future<void> _deleteSharedInCloud(String characterId, String shareCode) async {
    if (!CloudService.configured) return;
    final session = await CloudService.loadSession();
    if (session == null) return;
    try { await CloudService.deleteLinkRequestsByShareCode(session, shareCode); } catch (_) {}
    await CloudService.deleteSharedCharacter(session, characterId);
  }

  Future<void> deleteCharacter(String id) async {
    final shareCode = characters.where((c) => c.id == id).map((c) => c.shareCode).firstWhere((code) => code.isNotEmpty, orElse: () => '');
    characters.removeWhere((c) => c.id == id);
    await save();
    notifyListeners();
    if (shareCode.isEmpty) return;
    // Melhor esforço e sem atrasar a remoção local; offline ou sem sessão, a
    // reconciliação do Mestre cobre o vínculo.
    unawaited(() async {
      try { await deleteSharedCleanup(id, shareCode); } catch (_) {}
    }());
  }

  Future<void> addImportedCharacter(Character character) async {
    characters.add(character);
    await save();
    notifyListeners();
  }

  Future<void> replaceFromBackup(Map<String, dynamic> data) async {
    characters = (data['characters'] as List? ?? [])
        .map((e) => Character.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    systems = (data['systems'] as List? ?? [])
        .map((e) => RpgSystem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    campaigns = (data['campaigns'] as List? ?? [])
        .map((e) => Campaign.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    savedRolls = (data['savedRolls'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    diceHistory = (data['diceHistory'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final preferences = Map<String, dynamic>.from(data['preferences'] ?? {});
    themeId = preferences['themeId']?.toString() ?? themeId;
    largeText = preferences['largeText'] is bool
        ? preferences['largeText'] as bool
        : largeText;
    compactMode = preferences['compactMode'] is bool
        ? preferences['compactMode'] as bool
        : compactMode;
    reduceAnimations = preferences['reduceAnimations'] is bool
        ? preferences['reduceAnimations'] as bool
        : reduceAnimations;
    masterToolsEnabled = preferences['masterToolsEnabled'] is bool
        ? preferences['masterToolsEnabled'] as bool
        : masterToolsEnabled;

    if (!systems.any((s) => s.id == 'generic')) {
      systems.insert(0, _builtInSystems().first);
    }

    await save();
    notifyListeners();
  }

  Future<void> restoreBackupSections(
    Map<String, dynamic> data, {
    required bool restoreGameData,
    required bool restoreRollData,
    required bool restorePreferences,
  }) async {
    if (restoreGameData) {
      characters = (data['characters'] as List? ?? [])
          .map((e) => Character.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      systems = (data['systems'] as List? ?? [])
          .map((e) => RpgSystem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      campaigns = (data['campaigns'] as List? ?? [])
          .map((e) => Campaign.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!systems.any((s) => s.id == 'generic')) {
        systems.insert(0, _builtInSystems().first);
      }
    }

    if (restoreRollData) {
      savedRolls = (data['savedRolls'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      diceHistory = (data['diceHistory'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (restorePreferences) {
      final preferences = Map<String, dynamic>.from(data['preferences'] ?? {});
      themeId = preferences['themeId']?.toString() ?? themeId;
      largeText = preferences['largeText'] is bool
          ? preferences['largeText'] as bool
          : largeText;
      compactMode = preferences['compactMode'] is bool
          ? preferences['compactMode'] as bool
          : compactMode;
      reduceAnimations = preferences['reduceAnimations'] is bool
          ? preferences['reduceAnimations'] as bool
          : reduceAnimations;
      masterToolsEnabled = preferences['masterToolsEnabled'] is bool
          ? preferences['masterToolsEnabled'] as bool
          : masterToolsEnabled;
    }

    await save();
    notifyListeners();
  }

  Future<void> publishExistingShareCodes() async {
    if (!CloudService.configured) return;
    try {
      final session = await CloudService.ensureSession();
      for (final character in characters) {
        if (character.shareCode.isNotEmpty) {
          await CloudService.publishCharacter(session, character.toJson(), character.shareCode);
        }
      }
    } catch (_) {}
  }

  Future<void> updateCharacter(Character character) async {
    final index = characters.indexWhere((c) => c.id == character.id);
    if (index >= 0) characters[index] = character;
    await save();
    notifyListeners();
    // Ficha que não existe mais localmente (apagada) não é republicada.
    if (index >= 0 && character.shareCode.isNotEmpty && CloudService.configured) {
      try {
        final session = await CloudService.loadSession();
        if (session != null) await CloudService.publishCharacter(session, character.toJson(), character.shareCode);
      } catch (_) {}
    }
  }

  Future<void> addSystem(RpgSystem system) async {
    systems.add(system);
    await save();
    notifyListeners();
  }

  Future<void> updateSystem(
    RpgSystem system, {
    Map<String, String> attributeRenames = const {},
    Map<String, String> skillRenames = const {},
    Map<String, String> resourceRenames = const {},
    Map<String, String> sectionRenames = const {},
  }) async {
    final index = systems.indexWhere((s) => s.id == system.id);
    if (index < 0) return;

    for (final character in characters.where((c) => c.systemId == system.id)) {
      for (final entry in attributeRenames.entries) {
        if (character.attributes.containsKey(entry.key)) {
          final value = character.attributes.remove(entry.key)!;
          character.attributes.putIfAbsent(entry.value, () => value);
        }
      }

      for (final entry in resourceRenames.entries) {
        if (character.resourceValues.containsKey(entry.key)) {
          final value = character.resourceValues.remove(entry.key)!;
          character.resourceValues.putIfAbsent(entry.value, () => value);
        }
        if (character.resourceMaxValues.containsKey(entry.key)) {
          final value = character.resourceMaxValues.remove(entry.key)!;
          character.resourceMaxValues.putIfAbsent(entry.value, () => value);
        }
      }

      for (final entry in sectionRenames.entries) {
        if (character.sectionNotes.containsKey(entry.key)) {
          final value = character.sectionNotes.remove(entry.key)!;
          character.sectionNotes.putIfAbsent(entry.value, () => value);
        }
      }

      for (final entry in skillRenames.entries) {
        character.skills = character.skills
            .map((skill) => skill == entry.key ? entry.value : skill)
            .toSet()
            .toList();
      }

      for (final attribute in system.attributes) {
        character.attributes.putIfAbsent(attribute, () => 10);
      }
      for (final resource in system.resources) {
        character.resourceValues.putIfAbsent(resource, () => resource.toLowerCase() == 'vida' ? 10 : 0);
        character.resourceMaxValues.putIfAbsent(resource, () => resource.toLowerCase() == 'vida' ? 10 : 0);
      }
      for (final section in system.sections) {
        character.sectionNotes.putIfAbsent(section, () => '');
      }
    }

    systems[index] = system;
    await save();
    notifyListeners();
  }

  Future<RpgSystem?> duplicateSystem(String id) async {
    final index = systems.indexWhere((s) => s.id == id);
    if (index < 0) return null;

    final source = systems[index];
    final baseName = '${source.name} - Cópia';
    var copyName = baseName;
    var counter = 2;
    while (systems.any((s) => s.name.toLowerCase() == copyName.toLowerCase())) {
      copyName = '$baseName ($counter)';
      counter++;
    }

    final copy = source.copyWith(id: _uuid.v4(), name: copyName);

    systems.add(copy);
    await save();
    notifyListeners();
    return copy;
  }

  Future<bool> deleteSystem(String id) async {
    if (id == 'generic') return false;
    if (characters.any((c) => c.systemId == id)) return false;
    systems.removeWhere((s) => s.id == id);
    await save();
    notifyListeners();
    return true;
  }

  Future<void> addCampaign(Campaign campaign) async {
    campaigns.add(campaign);
    await save();
    notifyListeners();
  }

  Future<void> updateCampaign(Campaign campaign) async {
    final index = campaigns.indexWhere((c) => c.id == campaign.id);
    if (index >= 0) {
      campaigns[index] = campaign;
      await save();
      notifyListeners();
    }
  }

  Future<void> deleteCampaign(String id) async {
    campaigns.removeWhere((c) => c.id == id);
    await save();
    notifyListeners();
  }

  Map<String, dynamic> rollAdvanced({
    required int sides,
    int count = 1,
    int modifier = 0,
    String mode = 'normal',
    String? label,
  }) {
    final random = Random();
    final rolls = <int>[];
    var total = modifier;

    if ((mode == 'advantage' || mode == 'disadvantage') && count == 1) {
      final first = random.nextInt(sides) + 1;
      final second = random.nextInt(sides) + 1;
      rolls.add(first);
      rolls.add(second);
      total += mode == 'advantage'
          ? (first > second ? first : second)
          : (first < second ? first : second);
    } else {
      for (var i = 0; i < count; i++) {
        final value = random.nextInt(sides) + 1;
        rolls.add(value);
        total += value;
      }
    }

    final entry = <String, dynamic>{
      'expression': '${count}d$sides${modifier == 0 ? '' : modifier > 0 ? ' + $modifier' : ' - ${modifier.abs()}'}',
      'sides': sides,
      'count': count,
      'modifier': modifier,
      'mode': mode,
      'rolls': rolls,
      'result': total,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
    };
    diceHistory.insert(0, entry);
    if (diceHistory.length > 50) diceHistory.removeRange(50, diceHistory.length);
    save();
    notifyListeners();
    return entry;
  }

  int roll(int sides, {int count = 1, int modifier = 0}) {
    return rollAdvanced(sides: sides, count: count, modifier: modifier)['result'] as int;
  }

  Future<void> saveRollPreset({
    required String name,
    required int sides,
    required int count,
    required int modifier,
    required String mode,
  }) async {
    final cleanName = name.trim().isEmpty ? '${count}d$sides' : name.trim();
    savedRolls.insert(0, {
      'id': _uuid.v4(),
      'name': cleanName,
      'sides': sides,
      'count': count,
      'modifier': modifier,
      'mode': mode,
    });
    await save();
    notifyListeners();
  }

  Future<void> deleteRollPreset(String id) async {
    savedRolls.removeWhere((e) => e['id'] == id);
    await save();
    notifyListeners();
  }

  Future<void> renameRollPreset(String id, String name) async {
    final index = savedRolls.indexWhere((e) => e['id'] == id);
    if (index < 0 || name.trim().isEmpty) return;
    savedRolls[index]['name'] = name.trim();
    await save();
    notifyListeners();
  }

  void clearDiceHistory() {
    diceHistory.clear();
    save();
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    themeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_id', id);
    notifyListeners();
  }

  Future<void> setLargeText(bool value) async {
    largeText = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('large_text', value);
    notifyListeners();
  }

  Future<void> setCompactMode(bool value) async {
    compactMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('compact_mode', value);
    notifyListeners();
  }

  Future<void> setReduceAnimations(bool value) async {
    reduceAnimations = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduce_animations', value);
    notifyListeners();
  }

  Future<void> setMasterToolsEnabled(bool value) async {
    masterToolsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('master_tools_enabled', value);
    notifyListeners();
  }

  List<String> get dataIntegrityIssues {
    final issues = <String>[];
    final systemIds = systems.map((s) => s.id).toSet();
    final characterIds = characters.map((c) => c.id).toSet();

    if (!systemIds.contains('generic')) {
      issues.add('Sistema Padrão ausente.');
    }

    final orphanCharacters = characters
        .where((c) => !systemIds.contains(c.systemId))
        .length;
    if (orphanCharacters > 0) {
      issues.add('$orphanCharacters ficha(s) apontam para sistemas inexistentes.');
    }

    var invalidCampaignLinks = 0;
    var invalidHiddenLinks = 0;
    var invalidRounds = 0;
    for (final campaign in campaigns) {
      invalidCampaignLinks += campaign.characterIds
          .where((id) => !characterIds.contains(id))
          .length;
      invalidHiddenLinks += campaign.hiddenCharacterIds
          .where((id) => !campaign.characterIds.contains(id))
          .length;
      if (campaign.sessionRound < 1) invalidRounds++;
    }
    if (invalidCampaignLinks > 0) {
      issues.add('$invalidCampaignLinks vínculo(s) de campanha apontam para fichas inexistentes.');
    }
    if (invalidHiddenLinks > 0) {
      issues.add('$invalidHiddenLinks ficha(s) oculta(s) não pertencem mais à campanha.');
    }
    if (invalidRounds > 0) {
      issues.add('$invalidRounds campanha(s) possuem rodada inválida.');
    }
    if (diceHistory.length > 50) {
      issues.add('O histórico de dados ultrapassa o limite de 50 registros.');
    }

    return issues;
  }

  Future<int> repairDataIntegrity() async {
    var repairs = 0;

    if (!systems.any((s) => s.id == 'generic')) {
      systems.insert(0, _builtInSystems().first);
      repairs++;
    }

    final systemIds = systems.map((s) => s.id).toSet();
    for (final character in characters) {
      if (!systemIds.contains(character.systemId)) {
        character.systemId = 'generic';
        repairs++;
      }
    }

    final characterIds = characters.map((c) => c.id).toSet();
    for (final campaign in campaigns) {
      final beforeCharacters = campaign.characterIds.length;
      campaign.characterIds = campaign.characterIds
          .where(characterIds.contains)
          .toSet()
          .toList();
      repairs += beforeCharacters - campaign.characterIds.length;

      final beforeHidden = campaign.hiddenCharacterIds.length;
      campaign.hiddenCharacterIds = campaign.hiddenCharacterIds
          .where(campaign.characterIds.contains)
          .toSet()
          .toList();
      repairs += beforeHidden - campaign.hiddenCharacterIds.length;

      if (campaign.sessionRound < 1) {
        campaign.sessionRound = 1;
        repairs++;
      }
    }

    if (diceHistory.length > 50) {
      repairs += diceHistory.length - 50;
      diceHistory = diceHistory.take(50).toList();
    }

    if (repairs > 0) {
      await save();
      notifyListeners();
    }
    return repairs;
  }

  Future<void> clearAll() async {
    characters.clear();
    systems = [_builtInSystems().first];
    campaigns.clear();
    savedRolls.clear();
    await save();
    notifyListeners();
  }
}