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
import '../utils/error_message.dart';
import 'backup_merge.dart';
import 'character_publish_queue.dart';
import 'cloud_service.dart';

/// Espaço de referência do armazenamento do navegador (~5 MB por site).
const storageQuotaBytes = 5 * 1024 * 1024;

/// Acima disso, um personagem 2D personalizado não é salvo.
const customSpriteStorageLimitBytes = 4.5 * 1024 * 1024;

/// Mensagem do aviso de salvamento que falhou.
const saveFailedMessage = 'Não foi possível salvar neste aparelho: o espaço está cheio. Remova personagens 2D personalizados ou exporte um backup em Dados e sincronização.';

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

  /// Ligada pelo "Apagar todos os dados": enquanto estiver ligada e a nuvem
  /// tiver dados, a sincronização só traz a nuvem de volta (aparelho vazio) e
  /// nunca substitui o backup sem confirmação (chave 'cloud_restore_pending').
  bool cloudRestorePending = false;

  /// Exclusões feitas pelo usuário ({kind, id, deletedAt}), para a junção da
  /// sincronização não trazer de volta o que foi apagado em outro aparelho.
  List<Map<String, dynamic>> deletedItems = [];

  /// O último salvamento falhou (por exemplo, espaço cheio). A interface mostra
  /// um aviso fixo até um salvamento dar certo.
  bool lastSaveFailed = false;
  String? lastSaveError;

  /// Tamanho aproximado (em caracteres ≈ bytes) do que o app guarda neste
  /// aparelho, recalculado no load e a cada salvamento.
  int storageUsage = 0;

  /// Substitui a gravação de textos nos testes (para simular falha).
  @visibleForTesting
  Future<bool> Function(String key, String value)? writeStringOverride;
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
          description: 'Ficha genérica e flexível do Grimório.',
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
    cloudRestorePending = prefs.getBool('cloud_restore_pending') ?? false;
    // Exclusões com mais de 90 dias são descartadas.
    deletedItems = cleanDeletedItems(_safeDecodeList(prefs.getString('deleted_items')));
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
    storageUsage = _storageUsageOf(prefs);
    notifyListeners();
    // Local data is ready immediately. Cloud sync runs after startup instead of
    // holding the first usable screen behind network/auth latency.
    if (autoSync) {
      Future<void>.delayed(const Duration(milliseconds:900),(){
        // Confere de novo: o "Apagar todos os dados" pode ter desligado a
        // sincronização automática nesse meio-tempo.
        if (autoSync) syncNow(silent:true, automatic:true);
      });
    }
  }

  /// Grava o estado local. Com [markLocalChange] false (só o "Apagar todos os
  /// dados" e a aplicação da nuvem), não marca uma alteração local nova nem
  /// agenda sincronização.
  ///
  /// Nunca lança: se a gravação falhar (por exemplo, espaço cheio no
  /// navegador), liga [lastSaveFailed], guarda a mensagem e avisa a interface.
  /// Os dados continuam na memória (e a sincronização, se ligada, segue).
  Future<void> save({bool markLocalChange = true}) async {
    Object? failure;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final results = <bool>[
        await _setString(prefs, 'characters', jsonEncode(characters.map((e) => e.toJson()).toList())),
        await _setString(prefs, 'systems', jsonEncode(systems.map((e) => e.toJson()).toList())),
        await _setString(prefs, 'campaigns', jsonEncode(campaigns.map((e) => e.toJson()).toList())),
        await _setString(prefs, 'dice_history', jsonEncode(diceHistory)),
        await _setString(prefs, 'saved_rolls', jsonEncode(savedRolls)),
        await _setString(prefs, 'deleted_items', jsonEncode(deletedItems)),
        await prefs.setString('theme_id', themeId),
        await prefs.setBool('large_text', largeText),
        await prefs.setBool('compact_mode', compactMode),
        await prefs.setBool('reduce_animations', reduceAnimations),
        await prefs.setBool('master_tools_enabled', masterToolsEnabled),
        await prefs.setBool('auto_sync', autoSync),
      ];
      if (results.contains(false)) failure = 'O armazenamento recusou a gravação.';
    } catch (e) {
      failure = e;
    }
    if (!_applyingCloud && markLocalChange) {
      _localRevision++;
      lastLocalChangeUtc = DateTime.now().toUtc();
      try {
        await prefs?.setString('last_local_change_utc', lastLocalChangeUtc!.toIso8601String());
      } catch (e) {
        failure ??= e;
      }
    }
    try {
      if (lastSyncUtc != null) await prefs?.setString('last_sync_utc', lastSyncUtc!.toIso8601String());
    } catch (e) {
      failure ??= e;
    }
    if (prefs != null) storageUsage = _storageUsageOf(prefs);
    final failed = failure != null;
    if (failed) debugPrint('Salvar falhou: $failure');
    if (failed != lastSaveFailed || failed) {
      lastSaveFailed = failed;
      lastSaveError = failed ? failure.toString() : null;
      notifyListeners();
    }
    if (!_applyingCloud && markLocalChange && autoSync && loaded) {
      _autoSyncDebounce?.cancel();
      _autoSyncDebounce=Timer(const Duration(milliseconds:700),(){
        syncNow(silent:true, automatic:true);
      });
    }
  }

  Future<bool> _setString(SharedPreferences prefs, String key, String value) {
    final override = writeStringOverride;
    return override != null ? override(key, value) : prefs.setString(key, value);
  }

  /// Chaves de dados que o [save] grava a partir da memória.
  static const _dataKeys = ['characters', 'systems', 'campaigns', 'dice_history', 'saved_rolls', 'deleted_items'];

  static int _entrySize(String key, Object? value) {
    // No navegador cada chave fica como 'flutter.<chave>' e o valor em JSON.
    final text = value is String ? value.length + 2 : '$value'.length;
    return 'flutter.$key'.length + text;
  }

  static int _storageUsageOf(SharedPreferences prefs) {
    var total = 0;
    for (final key in prefs.getKeys()) {
      total += _entrySize(key, prefs.get(key));
    }
    return total;
  }

  String _dataKeyValue(String key) => switch (key) {
        'characters' => jsonEncode(characters.map((e) => e.toJson()).toList()),
        'systems' => jsonEncode(systems.map((e) => e.toJson()).toList()),
        'campaigns' => jsonEncode(campaigns.map((e) => e.toJson()).toList()),
        'dice_history' => jsonEncode(diceHistory),
        'saved_rolls' => jsonEncode(savedRolls),
        _ => jsonEncode(deletedItems),
      };

  /// Tamanho que o armazenamento teria com os dados que estão na memória
  /// agora (antes de salvar), para recusar mudanças que não cabem.
  Future<int> projectedStorageUsage() async {
    final prefs = await SharedPreferences.getInstance();
    var total = 0;
    for (final key in prefs.getKeys()) {
      if (!_dataKeys.contains(key)) total += _entrySize(key, prefs.get(key));
    }
    for (final key in _dataKeys) {
      total += _entrySize(key, _dataKeyValue(key));
    }
    return total;
  }

  /// Data de agora para marcar itens alterados pelo usuário.
  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Registra a exclusão feita pelo usuário (vale também para outros
  /// aparelhos, via sincronização).
  void _recordDeletion(String kind, String id) {
    deletedItems.removeWhere((e) => e['kind'] == kind && e['id'] == id);
    deletedItems.add({'kind': kind, 'id': id, 'deletedAt': _nowIso()});
  }

  Map<String, dynamic> cloudPayload() => {
        'backupSchema': 5,
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
        'deletedItems': deletedItems,
      };

  /// Aparelho sem fichas e sem campanhas.
  bool get isLocalEmpty => characters.isEmpty && campaigns.isEmpty;

  /// Quantas fichas e campanhas há num backup da nuvem.
  static ({int characters, int campaigns}) backupCounts(Map<String, dynamic>? payload) {
    int count(Object? value) => value is List ? value.length : 0;
    return (characters: count(payload?['characters']), campaigns: count(payload?['campaigns']));
  }

  /// O envio substituiria um backup da nuvem com dados por um aparelho vazio.
  bool wouldOverwriteCloudWithEmpty(Map<String, dynamic>? cloudPayload) {
    if (!isLocalEmpty || cloudPayload == null) return false;
    final counts = backupCounts(cloudPayload);
    return counts.characters > 0 || counts.campaigns > 0;
  }

  /// Liga/desliga a marca de "aparelho apagado, nuvem a restaurar" e grava.
  Future<void> setCloudRestorePending(bool value) async {
    cloudRestorePending = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloud_restore_pending', value);
  }

  /// O backup tem pelo menos uma ficha ou campanha.
  static bool backupHasData(Map<String, dynamic>? payload) {
    final counts = backupCounts(payload);
    return counts.characters > 0 || counts.campaigns > 0;
  }

  /// Sincroniza juntando por item (1.3.68): baixa a nuvem; sem backup, envia
  /// o aparelho; com backup, calcula a junção ([mergeBackups]), aplica no
  /// aparelho se mudou algo (sem marcar alteração local nova) e envia se a
  /// nuvem precisar. Se o envio esbarrar num conflito (a nuvem mudou no meio),
  /// refaz o ciclo uma vez.
  ///
  /// [automatic] (a sincronização ao abrir o app e a do salvamento): com o
  /// aparelho sem nada para guardar e sem sessão salva, não cria uma conta
  /// anônima nova (não chama ensureSession).
  Future<String> syncNow({bool silent = false, bool automatic = false}) async {
    if (_syncing) return syncStatus;
    if (!CloudService.configured) {
      syncStatus = 'Nuvem não configurada';
      if (!silent) notifyListeners();
      return syncStatus;
    }
    if (automatic && !hasDataToKeep && await CloudService.loadSession() == null) {
      syncStatus = 'Nada para sincronizar ainda';
      if (!silent) notifyListeners();
      return syncStatus;
    }
    _syncing = true;
    syncStatus = 'Sincronizando…';
    if (!silent) notifyListeners();
    try {
      for (var attempt = 1;; attempt++) {
        try {
          await _syncOnce();
          break;
        } on AppMessageException catch (e) {
          // Conflito no envio: a nuvem mudou entre o download e o envio.
          if (attempt >= 2 || !_isCloudConflict(e)) rethrow;
        }
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

  static bool _isCloudConflict(AppMessageException e) => e is CloudConflictException;

  /// Ids dos sistemas que já vêm com o app.
  static final Set<String> _builtInSystemIds = _builtInSystems().map((s) => s.id).toSet();

  /// Há algo deste aparelho para guardar na nuvem (fichas, campanhas ou
  /// sistemas personalizados).
  bool get hasDataToKeep => characters.isNotEmpty || campaigns.isNotEmpty || systems.any((s) => !_builtInSystemIds.contains(s.id));

  static bool _sameData(Map<String, dynamic> a, Map<String, dynamic> b) => jsonEncode(backupDataView(a)) == jsonEncode(backupDataView(b));

  Future<void> _syncOnce() async {
    final revisionAtStart = _localRevision;
    final session = await CloudService.ensureSession();
    final cloud = await CloudService.downloadSnapshot(session);
    if (cloud == null) {
      // Nada a proteger na nuvem: envia o aparelho.
      if (cloudRestorePending) await setCloudRestorePending(false);
      await CloudService.uploadBackup(session, cloudPayload());
      syncStatus = 'Enviado para a nuvem';
      return;
    }
    final wasLocalEmpty = isLocalEmpty;
    // Aparelho vazio SEM exclusões registradas = "Apagar todos os dados" (ou
    // aparelho novo): não envia por cima da nuvem. Com exclusões (por exemplo,
    // a última ficha foi excluída), envia a junção normalmente.
    final blockEmptyUpload = wasLocalEmpty && deletedItems.isEmpty;
    final local = cloudPayload();
    final merged = mergeBackups(local, cloud.payload, localTime: lastLocalChangeUtc, cloudTime: cloud.updatedAt);
    final changesLocal = !_sameData(merged, local);
    final changesCloud = !_sameData(merged, cloud.payload);
    if (changesLocal || changesCloud) {
      // Alteração local durante a requisição: não sobrescreve o aparelho; a
      // próxima sincronização junta com segurança.
      if (revisionAtStart != _localRevision) {
        syncStatus = 'Alterações locais preservadas';
        return;
      }
    }
    if (changesLocal) {
      _applyingCloud = true;
      try {
        await replaceFromBackup(merged);
      } finally {
        _applyingCloud = false;
      }
    }
    var uploaded = false;
    if (changesCloud) {
      if (blockEmptyUpload && backupHasData(cloud.payload)) {
        // Proteção da 1.3.66: um aparelho vazio nunca envia sozinho por cima de
        // um backup com dados (ele só recebe a nuvem neste ciclo).
      } else {
        await CloudService.uploadBackup(session, cloudPayload(), expectedCloudUpdatedAt: cloud.updatedAt);
        uploaded = true;
      }
    }
    // Depois do "Apagar todos os dados", a junção já trouxe a nuvem.
    if (cloudRestorePending) await setCloudRestorePending(false);
    syncStatus = uploaded
        ? 'Alterações enviadas'
        : changesLocal
            ? 'Atualizado pela nuvem'
            : wasLocalEmpty && changesCloud
                ? 'Nada enviado: este aparelho está vazio'
                : 'Tudo sincronizado';
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
      updatedAt: _nowIso(),
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
    if (characters.any((c) => c.id == id)) _recordDeletion('character', id);
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
    character.updatedAt = _nowIso();
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
    // Backups antigos (schema 4) não têm exclusões.
    deletedItems = cleanDeletedItems(data['deletedItems']);

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

  /// Ids atuais de fichas, campanhas e sistemas, por kind.
  Map<String, Set<String>> _currentIds() => {
        'character': characters.map((c) => c.id).toSet(),
        'campaign': campaigns.map((c) => c.id).toSet(),
        'system': systems.map((s) => s.id).toSet(),
      };

  /// Depois de restaurar um arquivo .rpg (substituir tudo): os itens
  /// restaurados ficam com updatedAt = agora e os ids que existiam antes e
  /// não estão no backup viram exclusões, para a próxima sincronização
  /// respeitar a restauração.
  void _markFileRestore(Map<String, Set<String>> before, List<Map<String, dynamic>> previousDeleted) {
    final now = _nowIso();
    for (final c in characters) {
      c.updatedAt = now;
    }
    for (final c in campaigns) {
      c.updatedAt = now;
    }
    for (final sys in systems) {
      sys.updatedAt = now;
    }
    deletedItems = unionDeletedItems(previousDeleted, deletedItems);
    final after = _currentIds();
    for (final entry in before.entries) {
      for (final id in entry.value.difference(after[entry.key]!)) {
        _recordDeletion(entry.key, id);
      }
    }
  }

  /// Restaurar a partir de um arquivo .rpg (substitui tudo) — ver
  /// [_markFileRestore].
  Future<void> restoreFromFileBackup(Map<String, dynamic> data) async {
    final before = _currentIds();
    final previousDeleted = [...deletedItems];
    await replaceFromBackup(data);
    _markFileRestore(before, previousDeleted);
    await save();
    notifyListeners();
  }

  Future<void> restoreBackupSections(
    Map<String, dynamic> data, {
    required bool restoreGameData,
    required bool restoreRollData,
    required bool restorePreferences,
  }) async {
    final before = _currentIds();
    final previousDeleted = [...deletedItems];
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
      deletedItems = cleanDeletedItems(data['deletedItems']);
      _markFileRestore(before, previousDeleted);
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
    if (index >= 0) {
      character.updatedAt = _nowIso();
      characters[index] = character;
    }
    await save();
    notifyListeners();
    // Ficha que não existe mais localmente (apagada) não é republicada. O envio
    // é agrupado: toques seguidos geram uma publicação do estado mais recente.
    if (index >= 0 && character.shareCode.isNotEmpty && (CloudService.configured || sharedCharacterPublisherOverride != null)) {
      _publishQueue.schedule(character.id);
    }
  }

  /// Substitui o envio da ficha compartilhada nos testes.
  @visibleForTesting
  Future<void> Function(Map<String, dynamic> snapshot, String shareCode)? sharedCharacterPublisherOverride;

  late final CharacterPublishQueue _publishQueue = CharacterPublishQueue(publish: _publishShared);

  /// Envia na hora as publicações pendentes das fichas compartilhadas (o app
  /// foi para segundo plano ou ficou oculto).
  Future<void> flushSharedCharacterPublications() => _publishQueue.flush();

  Future<void> _publishShared(String characterId) async {
    final current = characters.where((c) => c.id == characterId).firstOrNull;
    // Apagada ou descompartilhada depois do agendamento: não publica.
    if (current == null || current.shareCode.isEmpty) return;
    final snapshot = sharedSnapshotFor(current.toJson());
    final override = sharedCharacterPublisherOverride;
    if (override != null) return override(snapshot, current.shareCode);
    final session = await CloudService.loadSession();
    if (session != null) await CloudService.publishCharacter(session, snapshot, current.shareCode);
  }

  Future<void> addSystem(RpgSystem system) async {
    system.updatedAt = _nowIso();
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

    final now = _nowIso();
    for (final character in characters.where((c) => c.systemId == system.id)) {
      // As fichas do sistema podem mudar (renomeações e campos novos).
      character.updatedAt = now;
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

    system.updatedAt = now;
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

    final copy = source.copyWith(id: _uuid.v4(), name: copyName)..updatedAt = _nowIso();

    systems.add(copy);
    await save();
    notifyListeners();
    return copy;
  }

  Future<bool> deleteSystem(String id) async {
    if (id == 'generic') return false;
    if (characters.any((c) => c.systemId == id)) return false;
    if (systems.any((s) => s.id == id)) _recordDeletion('system', id);
    systems.removeWhere((s) => s.id == id);
    await save();
    notifyListeners();
    return true;
  }

  Future<void> addCampaign(Campaign campaign) async {
    campaign.updatedAt = _nowIso();
    campaigns.add(campaign);
    await save();
    notifyListeners();
  }

  Future<void> updateCampaign(Campaign campaign) async {
    final index = campaigns.indexWhere((c) => c.id == campaign.id);
    if (index >= 0) {
      campaign.updatedAt = _nowIso();
      campaigns[index] = campaign;
      await save();
      notifyListeners();
    }
  }

  Future<void> deleteCampaign(String id) async {
    if (campaigns.any((c) => c.id == id)) _recordDeletion('campaign', id);
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
    final now = _nowIso();
    for (final character in characters) {
      if (!systemIds.contains(character.systemId)) {
        character.systemId = 'generic';
        character.updatedAt = now;
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

      var roundFixed = false;
      if (campaign.sessionRound < 1) {
        campaign.sessionRound = 1;
        roundFixed = true;
        repairs++;
      }
      if (roundFixed || campaign.characterIds.length != beforeCharacters || campaign.hiddenCharacterIds.length != beforeHidden) {
        campaign.updatedAt = now;
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

  /// Apaga os dados SÓ deste aparelho. Não pode apagar o backup da nuvem:
  /// 1. cancela a sincronização automática pendente;
  /// 2. desliga a sincronização automática (e salva a preferência);
  /// 3. apaga os dados locais;
  /// 4. não marca o apagar como alteração local nova (lastLocalChangeUtc
  ///    nulo), para uma sincronização futura trazer a nuvem de volta;
  /// 5. salva sem disparar sincronização.
  Future<void> clearAll() async {
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = null;
    final prefs = await SharedPreferences.getInstance();
    autoSync = false;
    await prefs.setBool('auto_sync', false);
    characters.clear();
    systems = [_builtInSystems().first];
    campaigns.clear();
    savedRolls.clear();
    // Uma sincronização em andamento não aplica a nuvem por cima do apagar.
    _localRevision++;
    lastLocalChangeUtc = null;
    await prefs.remove('last_local_change_utc');
    // Até a nuvem voltar (ou a pessoa confirmar um envio), nada substitui o
    // backup da nuvem.
    cloudRestorePending = true;
    await prefs.setBool('cloud_restore_pending', true);
    await save(markLocalChange: false);
    notifyListeners();
  }
}