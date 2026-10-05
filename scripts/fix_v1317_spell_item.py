from pathlib import Path

p = Path(__file__).resolve().parents[1] / 'lib/screens/character/character_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace(
    "_itemIcon(\n                          category,\n                          name: name,\n                          description: widget.descriptions[name] ?? '',\n                        )",
    "_itemIcon(\n                          category,\n                          name: item,\n                          description: widget.descriptions[item] ?? '',\n                        )",
)
p.write_text(s, encoding='utf-8')
