from pathlib import Path

p = Path(__file__).resolve().parents[1] / 'lib/screens/character/character_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace(
    "_itemIcon(category, name: name, description: widget.descriptions[name] ?? '')",
    "_itemIcon(category, name: item, description: widget.descriptions[item] ?? '')",
)
p.write_text(s, encoding='utf-8')
