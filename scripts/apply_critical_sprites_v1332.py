from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


path = Path('lib/screens/character/character_screen.dart')
text = path.read_text(encoding='utf-8')

text = replace_once(text,
"""  String get _pose {
    if (_life <= 0) return 'incapacitated';
    if (_lifeRatio <= .40) return 'agony';
    if (_negativeStatuses.isNotEmpty) return 'agony';
    return 'normal';
  }
""",
"""  String get _pose {
    if (_life <= 0) return 'incapacitated';
    if (_lifeRatio <= .30) return 'critical';
    if (_lifeRatio <= .40) return 'agony';
    if (_negativeStatuses.isNotEmpty) return 'agony';
    return 'normal';
  }
""", 'critical pose')

text = replace_once(text,
"""    final visibleStatuses = [...negatives, ...positives];
    final incapacitated = _pose == 'incapacitated';
    final agony = _pose == 'agony';
    final themeId = context.watch<AppState>().themeId;
    final pirateTheme = themeId == 'parchment';
    final cyberpunkTheme = themeId == 'cyberpunk';
""",
"""    final visibleStatuses = [...negatives, ...positives];
    final incapacitated = _pose == 'incapacitated';
    final critical = _pose == 'critical';
    final agony = _pose == 'agony';
    final state = context.watch<AppState>();
    final themeId = state.themeId;
    final reduceMotion = state.reduceAnimations || MediaQuery.maybeOf(context)?.disableAnimations == true;
    final pirateTheme = themeId == 'parchment';
    final cyberpunkTheme = themeId == 'cyberpunk';
""", 'critical flags')

text = replace_once(text,
"""                  color: incapacitated || agony ? scheme.error : scheme.onSurfaceVariant,
""",
"""                  color: incapacitated || critical || agony ? scheme.error : scheme.onSurfaceVariant,
""", 'critical label color')

text = replace_once(text,
"""              final wounded = !incapacitated && _lifeRatio <= .60;
              final breath = incapacitated ? 0.0 : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 2.7 : (phase - .5) * 3.6;
              final lean = incapacitated ? 0.0 : agony ? -.018 + (phase - .5) * .034 : wounded ? -.009 + (phase - .5) * .016 : (phase - .5) * .008;
              final scale = incapacitated ? 1.0 : 1.0 + (agony ? phase * .005 : wounded ? phase * .006 : phase * .009);
              final sideSway = incapacitated ? 0.0 : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 1.2 : (phase - .5) * .6;
""",
"""              final wounded = !incapacitated && !critical && _lifeRatio <= .60;
              final breath = reduceMotion || incapacitated ? 0.0 : critical ? (phase - .5) * 2.0 : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 2.7 : (phase - .5) * 3.6;
              final lean = reduceMotion || incapacitated || critical ? 0.0 : agony ? -.018 + (phase - .5) * .034 : wounded ? -.009 + (phase - .5) * .016 : (phase - .5) * .008;
              final scale = reduceMotion || incapacitated || critical ? 1.0 : 1.0 + (agony ? phase * .005 : wounded ? phase * .006 : phase * .009);
              final sideSway = reduceMotion || incapacitated ? 0.0 : critical ? (phase - .5) * 2.0 : agony ? (phase - .5) * 2.0 : wounded ? (phase - .5) * 1.2 : (phase - .5) * .6;
""", 'critical motion')

text = replace_once(text,
"""                        (agony ? scheme.error : scheme.primary).withOpacity(.08 + phase * .035),
""",
"""                        (critical || agony ? scheme.error : scheme.primary).withOpacity(.08 + phase * .035),
""", 'critical glow')

text = replace_once(text,
"""                                            ? (_pose == 'incapacitated'
                                                ? 'assets/character2d/cyberpunk_incapacitated.png'
                                                : _pose == 'agony'
                                                    ? 'assets/character2d/cyberpunk_agony.png'
                                                    : 'assets/character2d/cyberpunk_normal.png')
                                            : (_pose == 'incapacitated'
                                                ? 'assets/character2d/pirate_incapacitated.webp'
                                                : _pose == 'agony'
                                                    ? 'assets/character2d/pirate_critical.webp'
                                                    : 'assets/character2d/pirate_normal.webp'),
""",
"""                                            ? (_pose == 'incapacitated'
                                                ? 'assets/character2d/cyberpunk_incapacitated.png'
                                                : _pose == 'critical'
                                                    ? 'assets/character2d/cyberpunk_critical.png'
                                                    : _pose == 'agony'
                                                        ? 'assets/character2d/cyberpunk_agony.png'
                                                        : 'assets/character2d/cyberpunk_normal.png')
                                            : (_pose == 'incapacitated'
                                                ? 'assets/character2d/pirate_incapacitated.webp'
                                                : _pose == 'critical'
                                                    ? 'assets/character2d/pirate_critical_new.webp'
                                                    : _pose == 'agony'
                                                        ? 'assets/character2d/pirate_critical.webp'
                                                        : 'assets/character2d/pirate_normal.webp'),
""", 'critical assets')

path.write_text(text, encoding='utf-8')

pubspec = Path('pubspec.yaml')
p = pubspec.read_text(encoding='utf-8')
p = replace_once(p, 'version: 1.3.31+131', 'version: 1.3.32+132', 'pubspec version')
pubspec.write_text(p, encoding='utf-8')

app_version = Path('lib/core/app_version.dart')
a = app_version.read_text(encoding='utf-8')
a = replace_once(a, "const String appVersion = '1.3.31';", "const String appVersion = '1.3.32';", 'app version')
a = replace_once(a, 'const int appBuildNumber = 131;', 'const int appBuildNumber = 132;', 'build number')
app_version.write_text(a, encoding='utf-8')

version_json = Path('web/version.json')
v = version_json.read_text(encoding='utf-8')
v = replace_once(v, '"version": "1.3.31"', '"version": "1.3.32"', 'web version')
v = replace_once(v, '"build": 131', '"build": 132', 'web build')
v = replace_once(v, '"fullVersion": "1.3.31+131"', '"fullVersion": "1.3.32+132"', 'web full version')
version_json.write_text(v, encoding='utf-8')

sw = Path('web/rpg_service_worker.js')
s = sw.read_text(encoding='utf-8')
s = replace_once(s, "const VERSION='1.3.31+131';", "const VERSION='1.3.32+132';", 'service worker cache version')
sw.write_text(s, encoding='utf-8')

print('v1.3.32 critical sprite integration applied successfully')
