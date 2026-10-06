from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Theme palette refinements + cyberpunk icon rendering
p = ROOT / 'lib/app/theme.dart'
s = p.read_text(encoding='utf-8')
s = s.replace('0xFFFF2B2B', '0xFFFF5C5C')
s = s.replace('0xFF6B93FF', '0xFF8BB4E0')

old = """Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color}) {
  if (themeId == 'cyberpunk') {
    final iconColor = color ?? const Color(0xFF1755FF);
    if (role == 'general') {
      return Image.asset('assets/cyberpunk/skull.png', width: size, height: size, fit: BoxFit.contain, color: iconColor, colorBlendMode: BlendMode.srcIn);
    }
    if (role == 'abilities') {
      return Image.asset('assets/cyberpunk/demon.png', width: size * 1.15, height: size * 1.15, fit: BoxFit.contain);
    }
    if (role == 'skills') {
      return Image.asset('assets/cyberpunk/chip.png', width: size, height: size, fit: BoxFit.contain, color: iconColor, colorBlendMode: BlendMode.srcIn);
    }
    return Icon(themedIcon(themeId, role), size: size, color: iconColor);
  }
"""
new = """Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color}) {
  if (themeId == 'cyberpunk') {
    final iconColor = color ?? const Color(0xFF1755FF);
    Widget cyberAsset(String path, {double scale = 1.0}) => SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          path,
          width: size * scale,
          height: size * scale,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          color: iconColor,
          colorBlendMode: BlendMode.srcIn,
          gaplessPlayback: true,
        ),
      ),
    );
    if (role == 'general') return cyberAsset('assets/cyberpunk/skull.png', scale: 1.18);
    if (role == 'abilities') return cyberAsset('assets/cyberpunk/demon.png', scale: 1.28);
    if (role == 'skills') return cyberAsset('assets/cyberpunk/chip.png', scale: 1.16);
    return Icon(themedIcon(themeId, role), size: size, color: iconColor);
  }
"""
if old not in s:
    raise SystemExit('cyberpunk icon block not found')
s = s.replace(old, new)
p.write_text(s, encoding='utf-8')

# Character tabs: vampire must use neutral inactive icon colors like every other theme.
p = ROOT / 'lib/screens/character/character_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("""                            final colors = Theme.of(context).colorScheme;
                            final vampire = state.themeId == 'vampire';
""", """                            final colors = Theme.of(context).colorScheme;
""")
s = s.replace("""                                      color: vampire ? colors.primary : (selected ? colors.primary : colors.onSurfaceVariant),
""", """                                      color: selected ? colors.primary : colors.onSurfaceVariant,
""")
s = s.replace('0xFFFF2B2B', '0xFFFF5C5C')
p.write_text(s, encoding='utf-8')

# Version metadata
p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.19+119', 'version: 1.3.20+120')
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/core/app_version.dart'
s = p.read_text(encoding='utf-8').replace("appVersion = '1.3.19'", "appVersion = '1.3.20'").replace('appBuildNumber = 119', 'appBuildNumber = 120')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web/rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.19+119';", "const VERSION='1.3.20+120';")
p.write_text(s, encoding='utf-8')

p = ROOT / 'README.md'
s = p.read_text(encoding='utf-8').replace('V1.3.19 (Web/PWA)', 'V1.3.20 (Web/PWA)').replace('**1.3.19+119**', '**1.3.20+120**')
p.write_text(s, encoding='utf-8')

notes = ROOT / 'RELEASE_NOTES_1.3.20.md'
notes.write_text("""# RPG Sheet 1.3.20+120

## Temas
- Cyberpunk: borda dos cards atualizada para `#8BB4E0`.
- Vampírico: bordas e divisores atualizados para `#FF5C5C`.
- Vampírico: abas inativas agora usam tons neutros, igual aos demais temas.

## Cyberpunk
- Renderização dos ícones personalizados de Em Cena, Habilidades e Perícias revisada.
- Os três ícones passam a respeitar corretamente a cor ativa/inativa da aba.
- Escala e qualidade de renderização foram ajustadas para melhor leitura em tamanho pequeno.
""", encoding='utf-8')
