from pathlib import Path

p = Path('lib/screens/character/character_screen.dart')
s = p.read_text(encoding='utf-8')

old = """child: pirateTheme
                              ? SizedBox(
                                  width: 168,
                                  height: 198,
                                  child: CustomPaint(painter: _PirateSkeletonPainter(pose: _pose)),
                                )
                              : incapacitated"""
new = """child: pirateTheme
                              ? Image.asset(
                                  _pose == 'incapacitated'
                                      ? 'assets/character2d/pirate_incapacitated.webp'
                                      : _pose == 'agony'
                                          ? 'assets/character2d/pirate_critical.webp'
                                          : 'assets/character2d/pirate_normal.webp',
                                  height: _pose == 'incapacitated' ? 164 : 198,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                  isAntiAlias: false,
                                )
                              : incapacitated"""
if old not in s:
    raise SystemExit('pirate render block not found')
s = s.replace(old, new)
p.write_text(s, encoding='utf-8')

v = Path('lib/core/app_version.dart')
v.write_text("""const String appVersion = '1.3.27';
const int appBuildNumber = 127;
const String appVersionWithBuild = '$appVersion+$appBuildNumber';
const String appVersionDisplay = 'RPG Sheet • V$appVersion';
""", encoding='utf-8')

pub = Path('pubspec.yaml')
text = pub.read_text(encoding='utf-8').replace('version: 1.3.26+126', 'version: 1.3.27+127')
pub.write_text(text, encoding='utf-8')

sw = Path('web/rpg_service_worker.js')
text = sw.read_text(encoding='utf-8').replace("const VERSION='1.3.26+126';", "const VERSION='1.3.27+127';")
sw.write_text(text, encoding='utf-8')
