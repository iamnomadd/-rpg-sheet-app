from pathlib import Path
import re

p = Path('lib/screens/character/character_screen.dart')
s = p.read_text(encoding='utf-8')

if "../../widgets/pirate_sprite.dart" not in s:
    anchor = "import '../../utils/spell_icon.dart';\n"
    s = s.replace(anchor, anchor + "import '../../widgets/pirate_sprite.dart';\n")

s, count = re.subn(
    r"\nclass _PirateSkeletonPainter extends CustomPainter \{.*?\n\}\n\nclass _CombatCharacter2D",
    "\nclass _CombatCharacter2D",
    s,
    flags=re.S,
)
if count != 1:
    raise SystemExit(f'pirate painter removal count={count}')

old = """child: pirateTheme
                              ? SizedBox(
                                  width: 168,
                                  height: 198,
                                  child: CustomPaint(painter: _PirateSkeletonPainter(pose: _pose)),
                                )
                              : incapacitated"""
new = """child: pirateTheme
                              ? PirateSprite(pose: _pose, height: 198)
                              : incapacitated"""
if old not in s:
    raise SystemExit('pirate render block not found')
s = s.replace(old, new)

s = s.replace("if (_lifeRatio <= .30) return 'Crítico';", "if (_lifeRatio <= .40) return 'Crítico';")

p.write_text(s, encoding='utf-8')

Path('lib/core/app_version.dart').write_text("""const String appVersion = '1.3.27';
const int appBuildNumber = 127;
const String appVersionWithBuild = '$appVersion+$appBuildNumber';
const String appVersionDisplay = 'RPG Sheet • V$appVersion';
""", encoding='utf-8')

pub = Path('pubspec.yaml')
pub.write_text(pub.read_text(encoding='utf-8').replace('version: 1.3.26+126', 'version: 1.3.27+127'), encoding='utf-8')

sw = Path('web/rpg_service_worker.js')
sw.write_text(sw.read_text(encoding='utf-8').replace("const VERSION='1.3.26+126';", "const VERSION='1.3.27+127';"), encoding='utf-8')

Path('PIRATE_SPRITE_CHECKLIST.md').write_text("""# Checklist oficial — personagem 2D do tema Sombrio Pirata

- [x] Usar exclusivamente o pirata esqueleto em pixel art aprovado como base visual.
- [x] Não utilizar versões simplificadas, geométricas ou blocadas do personagem.
- [x] Manter a mesma identidade do personagem nos estados Normal, Crítico e Incapacitado.
- [x] Alterar apenas postura/expressão corporal entre os três estados.
- [x] Manter caveira, braços e mãos ósseos, bandana vermelha, colete azul-escuro, botas, cinto, corda e medalhão.
- [x] Renderizar em pixel art real, sem suavização.
- [x] Estado Crítico ativado em 40% ou menos da Vida máxima.
- [x] Estado Incapacitado ativado em 0 de Vida.
- [x] Não trocar para o sprite humano padrão em nenhum estado do tema pirata.
""", encoding='utf-8')

Path('RELEASE_NOTES_1.3.27.md').write_text("""# RPG Sheet 1.3.27

- Substitui o desenho geométrico do tema Sombrio Pirata por sprites em pixel art derivados diretamente do design aprovado.
- Usa o mesmo pirata esqueleto nos estados Normal, Crítico e Incapacitado, mudando somente pose e expressão corporal.
- Remove o painter simplificado anterior para evitar divergência visual com a referência aprovada.
- Mantém a renderização sem suavização para preservar o visual pixelizado.
- Alinha também o rótulo Crítico ao limite de 40% da Vida máxima.
- Adiciona checklist oficial para futuras alterações do personagem do tema pirata.
""", encoding='utf-8')

print('v1.3.27 applied')
