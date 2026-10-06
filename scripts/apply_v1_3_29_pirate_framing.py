from pathlib import Path
import json

p = Path('lib/screens/character/character_screen.dart')
s = p.read_text(encoding='utf-8')

anchor = "return SizedBox(\n                height: 220,\n                child: Stack(alignment: Alignment.center, children: ["
replacement = "return SizedBox(\n                height: 220,\n                child: Stack(\n                  alignment: Alignment.center,\n                  clipBehavior: Clip.none,\n                  children: ["
if anchor not in s:
    raise SystemExit('character image stack anchor not found')
s = s.replace(anchor, replacement, 1)

old = """child: pirateTheme
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
new = """child: pirateTheme
                              ? SizedBox(
                                  height: 198,
                                  width: double.infinity,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Image.asset(
                                        _pose == 'incapacitated'
                                            ? 'assets/character2d/pirate_incapacitated.webp'
                                            : _pose == 'agony'
                                                ? 'assets/character2d/pirate_critical.webp'
                                                : 'assets/character2d/pirate_normal.webp',
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                        filterQuality: FilterQuality.none,
                                        isAntiAlias: false,
                                      ),
                                    ),
                                  ),
                                )
                              : incapacitated"""
if old not in s:
    raise SystemExit('pirate asset block not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

pub = Path('pubspec.yaml')
t = pub.read_text(encoding='utf-8')
if 'version: 1.3.28+128' not in t:
    raise SystemExit('pubspec version anchor not found')
pub.write_text(t.replace('version: 1.3.28+128', 'version: 1.3.29+129', 1), encoding='utf-8')

Path('lib/core/app_version.dart').write_text("""const String appVersion = '1.3.29';
const int appBuildNumber = 129;
const String appVersionWithBuild = '$appVersion+$appBuildNumber';
const String appVersionDisplay = 'RPG Sheet • V$appVersion';
""", encoding='utf-8')

sw = Path('web/rpg_service_worker.js')
t = sw.read_text(encoding='utf-8')
if "const VERSION='1.3.28+128';" not in t:
    raise SystemExit('service worker version anchor not found')
sw.write_text(t.replace("const VERSION='1.3.28+128';", "const VERSION='1.3.29+129';", 1), encoding='utf-8')

Path('web/version.json').write_text(json.dumps({
    'version': '1.3.29',
    'build': 129,
    'versionWithBuild': '1.3.29+129'
}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
