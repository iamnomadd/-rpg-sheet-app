from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

# --- character_screen.dart ---
p = ROOT / 'lib' / 'screens' / 'character' / 'character_screen.dart'
s = p.read_text(encoding='utf-8')

# Add inventory search controller and dispose it.
s = s.replace(
    "  final TextEditingController _abilitySearch = TextEditingController();\n  @override\n  void dispose() {\n    _abilitySearch.dispose();",
    "  final TextEditingController _abilitySearch = TextEditingController();\n  final TextEditingController _inventorySearch = TextEditingController();\n  @override\n  void dispose() {\n    _abilitySearch.dispose();\n    _inventorySearch.dispose();",
)

# Unified search query for abilities and inventory.
s = s.replace(
    "    final abilityQuery = widget.isAbility ? _abilitySearch.text.trim().toLowerCase() : '';",
    "    final searchQuery = (widget.isAbility ? _abilitySearch : _inventorySearch).text.trim().toLowerCase();",
)
s = s.replace(
    "      if (abilityQuery.isEmpty) return true;\n      final description = widget.descriptions[entry.value]?.toLowerCase() ?? '';\n      return entry.value.toLowerCase().contains(abilityQuery) ||\n          category.toLowerCase().contains(abilityQuery) ||\n          description.contains(abilityQuery);",
    "      if (searchQuery.isEmpty) return true;\n      final description = widget.descriptions[entry.value]?.toLowerCase() ?? '';\n      return entry.value.toLowerCase().contains(searchQuery) ||\n          category.toLowerCase().contains(searchQuery) ||\n          description.contains(searchQuery);",
)

# Show the same search bar in both Habilidades and Inventário.
pattern = re.compile(r"        if \(widget\.isAbility\) \.\.\.\[\n          TextField\(\n            controller: _abilitySearch,.*?          const SizedBox\(height: 10\),\n        \],", re.S)
replacement = """        TextField(
          controller: widget.isAbility ? _abilitySearch : _inventorySearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.isAbility
                ? 'Buscar habilidades, magias ou técnicas'
                : 'Buscar itens, armas, consumíveis ou equipamentos',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: (widget.isAbility ? _abilitySearch : _inventorySearch).text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close, size: 19),
                    onPressed: () {
                      (widget.isAbility ? _abilitySearch : _inventorySearch).clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),"""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('Could not replace character item search block')

# Preserve showInScene when an item is edited and default new items to hidden.
s = s.replace(
    "    final old = editing ? (widget.details[oldName] ?? <String, dynamic>{}) : <String, dynamic>{};",
    "    final old = editing ? (widget.details[oldName] ?? <String, dynamic>{}) : <String, dynamic>{};\n    final showInScene = old['showInScene'] == true;",
)
s = s.replace(
    "    widget.details[newName] = Map<String, dynamic>.from(result)..remove('name')..remove('description');",
    "    widget.details[newName] = Map<String, dynamic>.from(result)..remove('name')..remove('description');\n    widget.details[newName]!['showInScene'] = showInScene;",
)

# Add toggle helper.
marker = "  Future<void> _changeItemQuantity(String item, int delta) async {"
idx = s.find(marker)
if idx < 0:
    raise SystemExit('Could not find quantity helper')
end_marker = "\n  @override\n  Widget build(BuildContext context) {"
end_idx = s.find(end_marker, idx)
if end_idx < 0:
    raise SystemExit('Could not find end of quantity helper area')
helper = """

  Future<void> _toggleInScene(String item) async {
    final detail = widget.details[item] ??= <String, dynamic>{};
    detail['showInScene'] = detail['showInScene'] != true;
    await context.read<AppState>().updateCharacter(widget.character);
    if (mounted) setState(() {});
  }
"""
if "Future<void> _toggleInScene" not in s:
    s = s[:end_idx] + helper + s[end_idx:]

# Add the Em Cena control beside the item actions.
needle = """                    if (stackable) ...[
                      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Diminuir quantidade', onPressed: qty > 0 ? () => _changeItemQuantity(item, -1) : null, icon: const Icon(Icons.remove_circle_outline, size: 20)),
                      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Aumentar quantidade', onPressed: () => _changeItemQuantity(item, 1), icon: const Icon(Icons.add_circle_outline, size: 20)),
                    ],
                    PopupMenuButton<String>("""
replacement = """                    if (stackable) ...[
                      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Diminuir quantidade', onPressed: qty > 0 ? () => _changeItemQuantity(item, -1) : null, icon: const Icon(Icons.remove_circle_outline, size: 20)),
                      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Aumentar quantidade', onPressed: () => _changeItemQuantity(item, 1), icon: const Icon(Icons.add_circle_outline, size: 20)),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: detail['showInScene'] == true ? 'Remover de Em Cena' : 'Em Cena',
                      onPressed: () => _toggleInScene(item),
                      icon: Icon(
                        detail['showInScene'] == true ? Icons.visibility : Icons.visibility_off_outlined,
                        size: 20,
                        color: detail['showInScene'] == true ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                    PopupMenuButton<String>("""
if needle not in s:
    raise SystemExit('Could not find item action area')
s = s.replace(needle, replacement, 1)

# Em Cena summary now shows only explicitly selected abilities/items.
s = s.replace(
    "      case 'inventory':\n        final lines = character.inventory;",
    "      case 'inventory':\n        final lines = character.inventory.where((name) => character.inventoryDetails[name]?['showInScene'] == true).toList();",
)
s = s.replace(
    "Row(children: [Icon(themedIcon(themeId, 'inventory')), const SizedBox(width: 8), const Text('Inventário', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${character.inventory.length} item(ns)')]),",
    "Row(children: [Icon(themedIcon(themeId, 'inventory')), const SizedBox(width: 8), const Text('Inventário', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${lines.length} item(ns)')]),",
)
s = s.replace(
    "      case 'abilities':\n        final lines = character.abilities;",
    "      case 'abilities':\n        final lines = character.abilities.where((name) => character.abilityDetails[name]?['showInScene'] == true).toList();",
)
s = s.replace(
    "Row(children: [Icon(themedIcon(themeId, 'abilities')), const SizedBox(width: 8), const Text('Habilidades', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${character.abilities.length}')]),",
    "Row(children: [Icon(themedIcon(themeId, 'abilities')), const SizedBox(width: 8), const Text('Habilidades', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${lines.length}')]),",
)

p.write_text(s, encoding='utf-8')

# --- systems_screen.dart: remove duplicated top actions, keep + only ---
p = ROOT / 'lib' / 'screens' / 'systems' / 'systems_screen.dart'
s = p.read_text(encoding='utf-8')
pattern = re.compile(r"          actions: \[\n            IconButton\(\n              onPressed: _busy \? null : \(\) => _importSystem\(context\),.*?            IconButton\(\n              onPressed: \(\) => _addSystem\(context\),\n              icon: const Icon\(Icons\.add\),\n              tooltip: 'Criar sistema',\n            \),\n          \],", re.S)
replacement = """          actions: [
            IconButton(
              onPressed: () => _addSystem(context),
              icon: const Icon(Icons.add),
              tooltip: 'Criar sistema',
            ),
          ],"""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('Could not simplify systems app bar')
p.write_text(s, encoding='utf-8')

# --- skill_trees_screen.dart: standard gap between cards ---
p = ROOT / 'lib' / 'screens' / 'home' / 'skill_trees_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace(
    "                  return Card(\n                    child: ListTile(",
    "                  return Card(\n                    margin: const EdgeInsets.only(bottom: 9),\n                    child: ListTile(\n                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),",
)
p.write_text(s, encoding='utf-8')

# --- campaigns_screen.dart: standard card spacing in notes/players ---
p = ROOT / 'lib' / 'screens' / 'campaigns' / 'campaigns_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace(
    "Card(child: ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Notas privadas do Mestre')",
    "Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.lock_outline), title: const Text('Notas privadas do Mestre')",
)
s = s.replace(
    "Card(child: ListTile(leading: const Icon(Icons.notes_outlined), title: const Text('Notas da campanha')",
    "Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.notes_outlined), title: const Text('Notas da campanha')",
)
s = s.replace(
    "return Card(child: ListTile(leading: const Icon(Icons.person_outline), title: Text(ch.name), subtitle:",
    "return Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), leading: const Icon(Icons.person_outline), title: Text(ch.name), subtitle:",
)
s = s.replace(
    "return Card(child:Padding(padding:const EdgeInsets.symmetric(vertical:4),child:ListTile(",
    "return Card(margin: const EdgeInsets.only(bottom: 9), child:Padding(padding:const EdgeInsets.symmetric(vertical:2),child:ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),",
)
p.write_text(s, encoding='utf-8')

# --- version bump ---
p = ROOT / 'lib' / 'core' / 'app_version.dart'
s = p.read_text(encoding='utf-8').replace("1.3.22", "1.3.23").replace("appBuildNumber = 122", "appBuildNumber = 123")
p.write_text(s, encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.22+122', 'version: 1.3.23+123')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web' / 'rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.22+122';", "const VERSION='1.3.23+123';")
p.write_text(s, encoding='utf-8')

(ROOT / 'RELEASE_NOTES_1.3.23.md').write_text("""# RPG Sheet 1.3.23\n\n- Adiciona seleção **Em Cena** para habilidades e itens de inventário.\n- A aba Em Cena mostra somente habilidades e itens escolhidos pelo jogador.\n- Adiciona ao Inventário a mesma barra de pesquisa existente em Habilidades.\n- Remove ações duplicadas de Modelos/Importar do topo da tela Sistemas de RPG.\n- Padroniza o espaçamento entre cards em Árvores de Habilidades, Notas do Mestre e Jogadores.\n""", encoding='utf-8')

print('v1.3.23 scene selection and UI cleanup applied')
