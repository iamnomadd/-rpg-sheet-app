from pathlib import Path
p = Path('lib/screens/character/character_screen.dart')
s = p.read_text(encoding='utf-8')
old = """                          child: pirateTheme
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
                              : incapacitated
"""
new = """                          child: pirateTheme
                              ? SizedBox(
                                  height: 198,
                                  width: 198,
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
                                        width: 182,
                                        height: 182,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                        filterQuality: FilterQuality.none,
                                        isAntiAlias: false,
                                      ),
                                    ),
                                  ),
                                )
                              : incapacitated
"""
if old not in s:
    raise SystemExit('target pirate image block not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('pirate framing patched')
