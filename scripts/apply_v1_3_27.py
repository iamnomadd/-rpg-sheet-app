from pathlib import Path
import base64

# Decode the three approved pixel-art sprites.
assets = Path('assets/character2d')
assets.mkdir(parents=True, exist_ok=True)
for key, filename in [
    ('normal', 'pirate_normal.png'),
    ('critical', 'pirate_critical.png'),
    ('incapacitated', 'pirate_incapacitated.png'),
]:
    data = base64.b64decode(Path(f'scripts/pirate_{key}.b64').read_text().strip())
    (assets / filename).write_bytes(data)

# Replace the temporary geometric pirate painter with the approved sprites.
p = Path('lib/screens/character/character_screen.dart')
s = p.read_text()
start = s.index('class _PirateSkeletonPainter extends CustomPainter')
end = s.index('class _CombatCharacter2D', start)
s = s[:start] + s[end:]

s = s.replace("if (_lifeRatio <= .30) return 'Crítico';", "if (_lifeRatio <= .40) return 'Crítico';")

old = '''child: pirateTheme
                              ? SizedBox(
                                  width: 168,
                                  height: 198,
                                  child: CustomPaint(painter: _PirateSkeletonPainter(pose: _pose)),
                                )
                              : incapacitated'''
new = '''child: pirateTheme
                              ? Image.asset(
                                  _pose == 'incapacitated'
                                      ? 'assets/character2d/pirate_incapacitated.png'
                                      : _pose == 'agony'
                                          ? 'assets/character2d/pirate_critical.png'
                                          : 'assets/character2d/pirate_normal.png',
                                  height: 198,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                )
                              : incapacitated'''
if old not in s:
    raise SystemExit('pirate render block not found')
s = s.replace(old, new)
p.write_text(s)

Path('lib/core/app_version.dart').write_text("""const String appVersion = '1.3.27';
const int appBuildNumber = 127;
const String appVersionWithBuild = '$appVersion+$appBuildNumber';
const String appVersionDisplay = 'RPG Sheet • V$appVersion';
""")

pub = Path('pubspec.yaml')
pub.write_text(pub.read_text().replace('version: 1.3.26+126', 'version: 1.3.27+127'))

sw = Path('web/rpg_service_worker.js')
sw.write_text(sw.read_text().replace("const VERSION='1.3.26+126';", "const VERSION='1.3.27+127';"))

Path('docs').mkdir(exist_ok=True)
Path('docs/PIRATE_CHARACTER_CHECKLIST.md').write_text("""# Checklist — Personagem 2D Sombrio Pirata

- [x] Usar exclusivamente o sprite pixel-art aprovado.
- [x] Não usar CustomPainter simplificado/geometrizado como personagem final.
- [x] O mesmo pirata esqueleto permanece nos estados Normal, Crítico e Incapacitado.
- [x] Só a pose/expressão corporal muda entre estados.
- [x] Corpo esquelético visível, incluindo braços, antebraços, mãos e dedos.
- [x] Manter bandana vermelha, colete azul-escuro, botas, cinto, corda e medalhão.
- [x] Fundo transparente; nenhum rótulo/texto embutido no sprite.
- [x] Renderizar com FilterQuality.none para preservar os pixels.
- [x] Crítico em vida <= 40% da vida máxima.
- [x] Incapacitado em vida <= 0.
- [x] Tema pirata nunca deve voltar ao sprite humano base durante mudança de estado.
""")

Path('RELEASE_NOTES_1.3.27.md').write_text("""# RPG Sheet 1.3.27

- Substitui a versão geométrica do personagem do tema Sombrio Pirata pelos sprites pixel-art aprovados.
- Usa o mesmo pirata esqueleto detalhado nos estados Normal, Crítico e Incapacitado, mudando apenas a pose.
- Mantém braços/mãos esqueléticos, bandana vermelha, colete, botas, cinto, corda e medalhão.
- Mantém fundo transparente e renderização sem suavização para preservar pixel art.
- Alinha o rótulo Crítico ao limite de 40% da vida máxima.
""")
