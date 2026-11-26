// Junção de dois pacotes de backup (o do aparelho e o da nuvem) por item.
// Função pura, sem rede nem armazenamento: testável sozinha.
//
// Regras (1.3.68):
// - fichas, campanhas e sistemas juntam por id: item só de um lado entra; item
//   dos dois lados fica com o `updatedAt` mais novo (com só um lado datado,
//   vence o datado; empate, vence o aparelho); com os dois sem `updatedAt`
//   (dados antigos), vence o lado cujo pacote é mais novo;
// - exclusões (`deletedItems`, unidas por kind+id com o `deletedAt` mais
//   novo; mais de 90 dias são descartadas): o item some se a exclusão for mais
//   nova que o `updatedAt` dele (ou se ele não tiver `updatedAt`);
// - savedRolls, diceHistory e preferences: os do aparelho;
// - ordem das listas: a do aparelho, com os itens que só existem na nuvem no
//   fim, na ordem da nuvem.

/// Validade de uma exclusão registrada.
const deletedItemsMaxAge = Duration(days: 90);

/// Lista de cada tipo de item no pacote e o `kind` da exclusão.
const _kinds = <String, String>{
  'characters': 'character',
  'campaigns': 'campaign',
  'systems': 'system',
};

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString())?.toUtc();

List<Map<String, dynamic>> _items(Object? raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];

/// Exclusões válidas (kind, id e deletedAt legíveis e com menos de 90 dias).
List<Map<String, dynamic>> cleanDeletedItems(Object? raw, {DateTime? now}) {
  final limit = (now ?? DateTime.now().toUtc()).subtract(deletedItemsMaxAge);
  return [
    for (final entry in _items(raw))
      if (_kinds.containsValue(entry['kind']) &&
          (entry['id']?.toString() ?? '').isNotEmpty &&
          (_date(entry['deletedAt'])?.isAfter(limit) ?? false))
        {'kind': entry['kind'], 'id': entry['id'].toString(), 'deletedAt': _date(entry['deletedAt'])!.toIso8601String()},
  ];
}

/// Une as exclusões dos dois lados por kind+id, mantendo o deletedAt mais novo.
List<Map<String, dynamic>> unionDeletedItems(Object? a, Object? b, {DateTime? now}) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final entry in [...cleanDeletedItems(a, now: now), ...cleanDeletedItems(b, now: now)]) {
    final key = '${entry['kind']}:${entry['id']}';
    final current = byKey[key];
    if (current == null || _date(entry['deletedAt'])!.isAfter(_date(current['deletedAt'])!)) byKey[key] = entry;
  }
  return byKey.values.toList();
}

/// Junta o pacote do aparelho ([local]) com o da nuvem ([cloud]).
///
/// [localTime] e [cloudTime] são as datas dos pacotes (por padrão, o
/// `localChangedAt` de cada um); valem só para itens sem `updatedAt`.
Map<String, dynamic> mergeBackups(
  Map<String, dynamic> local,
  Map<String, dynamic> cloud, {
  DateTime? localTime,
  DateTime? cloudTime,
  DateTime? now,
}) {
  final localPackage = localTime ?? _date(local['localChangedAt']);
  final cloudPackage = cloudTime ?? _date(cloud['localChangedAt']);
  // Pacote do aparelho mais novo (ou empate, ou sem data na nuvem).
  final localNewer = cloudPackage == null || (localPackage != null && !cloudPackage.isAfter(localPackage));
  final deleted = unionDeletedItems(local['deletedItems'], cloud['deletedItems'], now: now);
  final deletedAt = {for (final entry in deleted) '${entry['kind']}:${entry['id']}': _date(entry['deletedAt'])!};

  Map<String, dynamic> pick(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = _date(a['updatedAt']);
    final tb = _date(b['updatedAt']);
    if (ta != null && tb != null) return tb.isAfter(ta) ? b : a;
    if (ta != null) return a;
    if (tb != null) return b;
    return localNewer ? a : b;
  }

  bool removed(String kind, Map<String, dynamic> item) {
    final when = deletedAt['$kind:${item['id']}'];
    if (when == null) return false;
    final updated = _date(item['updatedAt']);
    return updated == null || when.isAfter(updated);
  }

  final merged = <String, dynamic>{...local};
  for (final MapEntry(key: listKey, value: kind) in _kinds.entries) {
    final localItems = _items(local[listKey]);
    final cloudItems = _items(cloud[listKey]);
    final cloudById = {for (final item in cloudItems) item['id']?.toString() ?? '': item};
    final localIds = {for (final item in localItems) item['id']?.toString() ?? ''};
    final result = <Map<String, dynamic>>[
      for (final item in localItems)
        cloudById.containsKey(item['id']?.toString() ?? '') ? pick(item, cloudById[item['id']?.toString() ?? '']!) : item,
      for (final item in cloudItems)
        if (!localIds.contains(item['id']?.toString() ?? '')) item,
    ];
    merged[listKey] = [
      for (final item in result)
        if (!removed(kind, item)) item,
    ];
  }
  merged['deletedItems'] = deleted;
  // savedRolls, diceHistory e preferences: os do aparelho (já em `local`).
  return merged;
}

/// As partes do pacote que contam para saber se dois pacotes têm os mesmos
/// dados (sem datas e versão do pacote).
Map<String, dynamic> backupDataView(Map<String, dynamic> payload) => {
      for (final key in const ['characters', 'systems', 'campaigns', 'deletedItems', 'savedRolls', 'diceHistory', 'preferences'])
        key: payload[key] ?? (key == 'preferences' ? const <String, dynamic>{} : const <Object>[]),
    };
