from pathlib import Path
p=Path('lib/screens/character/character_screen.dart')
s=p.read_text(encoding='utf-8')
old="head(critical?const Offset(82,50):const Offset(84,43),tilt:critical?.13:0);"
new="head(critical ? const Offset(82, 50) : const Offset(84, 43), tilt: critical ? .13 : 0);"
if old not in s:
    raise SystemExit('target syntax not found')
s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
print('fixed v1.3.26 analyzer syntax')
