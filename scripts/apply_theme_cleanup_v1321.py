from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

# theme.dart
p = ROOT / 'lib' / 'app' / 'theme.dart'
s = p.read_text(encoding='utf-8')

# Make Cyberpunk custom tab icons render as proper alpha-mask icons.
pattern = re.compile(r"Widget themedCharacterTabIcon\(String themeId, String role, \{double size = 18, Color\? color\}\) \{\n  if \(themeId == 'cyberpunk'\) \{.*?\n  \}\n  if \(themeId != 'vampire'\)", re.S)
replacement = """Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color}) {
  if (themeId == 'cyberpunk') {
    final iconColor = color ?? const Color(0xFF1755FF);
    if (role == 'general') {
      return ImageIcon(const AssetImage('assets/cyberpunk/skull.png'), size: size * 1.12, color: iconColor);
    }
    if (role == 'abilities') {
      return ImageIcon(const AssetImage('assets/cyberpunk/demon.png'), size: size * 1.22, color: iconColor);
    }
    if (role == 'skills') {
      return ImageIcon(const AssetImage('assets/cyberpunk/chip.png'), size: size * 1.12, color: iconColor);
    }
    return Icon(themedIcon(themeId, role), size: size, color: iconColor);
  }
  if (themeId != 'vampire')"""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('Could not replace cyberpunk tab icon renderer')

# Remove card borders from the four refined themes while preserving their shapes.
pattern = re.compile(r"  final radius = preset\.radius;\n  final cardShape = pirate\n      \? BeveledRectangleBorder\(.*?\n        \);\n  final fieldShape =", re.S)
replacement = """  final radius = preset.radius;
  final borderlessCards = pirate || vampire || arcane || cyberpunk;
  final cardShape = pirate
      ? BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        )
      : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.clamp(12, 18)),
          side: borderlessCards
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant.withOpacity(.18), width: 1),
        );
  final fieldShape ="""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('Could not replace card shape block')

p.write_text(s, encoding='utf-8')

# Version bump
p = ROOT / 'lib' / 'core' / 'app_version.dart'
s = p.read_text(encoding='utf-8').replace("1.3.20", "1.3.21").replace("appBuildNumber = 120", "appBuildNumber = 121")
p.write_text(s, encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.20+120', 'version: 1.3.21+121')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web' / 'rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.20+120';", "const VERSION='1.3.21+121';")
p.write_text(s, encoding='utf-8')

# Release notes
(ROOT / 'RELEASE_NOTES_1.3.21.md').write_text("""# RPG Sheet 1.3.21\n\n- Remove as bordas dos cards nos temas Vampírico, Arcano, Cyberpunk e Sombrio Pirata para um visual mais limpo.\n- Corrige o ícone de Habilidades do tema Cyberpunk usando renderização por máscara (`ImageIcon`).\n- Mantém o comportamento de abas com destaque apenas na aba selecionada.\n- Ajusta o fluxo de publicação para evitar um build intermediário da versão anterior antes do deploy da versão nova.\n""", encoding='utf-8')

print('v1.3.21 theme cleanup applied')
