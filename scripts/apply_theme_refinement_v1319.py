from pathlib import Path
import base64

ROOT = Path(__file__).resolve().parents[1]

asset_dir = ROOT / 'assets' / 'cyberpunk'
asset_dir.mkdir(parents=True, exist_ok=True)
assets = {
    'demon.png': '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',
    'skull.png': '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',
    'chip.png': 'iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAALEUlEQVR42t1Za4wb1RX+ZsbZQF4rKEFFAlKGFrfMYsfi2oHi0m6rQSotIhsoUiurIfEOEztVC5YQMgGpf8KoabtVFeLNYHu3UZeqStIkUhFQRmAkXB72gNfbMTAFBpm24keJqGmeuzsz/ZF7l4mzZHdJGiKuNJrrufM4j++c851r4OTB0eN8HbPL5zj2SQuKkuPPQ+GDMnFU5o+F5gJ6+f55aPouuzMZeQDQ9fKaSLT/WV4Q/8oLYjW6uv9xx7GXAxAUJScA+EwOISQKQkgUHMdeFon27+EF8WVeEF+IRPuf0fXyGgAIUYW+B+DbfX2rAACJeIwAGATglkpDp2h/robnOszSPYl47M6u5ecAvMIUWG1Z7emNG9Z6hEiCabYmNU3frSi5Y59hUPsAeEKkI4ZR/QUhUiGfV7Oapk+OjB7gAawOeuBYX9+qECGSa5otoVTatZwXer9/PmB/ZPQA+vpWfT2bSd1qGNU/ECI9Vas3lgOYDiqwO5tJ3SLLyRWm2WLPuifc2GHWOGvxyAu9c0Cnc9LPieaEaJqtZwiRbgKgZzOpLIADMwqoanqfrpfrAH4G4D4AHgDBczuIRCNuQNGzAm3Lap82TUeikeBPAcDUyOiBKwFsz+fVHxhG9TFVTb89o4Dj2JwohtuOYz9PFfDZi7KZlCDLyaMAjtCXcfPM2fwsmAaAZZqmo1Tahdk80WV9JOIx1OoNwXM7HgARQEhV029RmU8oYBhVVrwuDLzIz2ZSkOXk7w2jqgH47wKEPy7LSXa/H6ii0wA2ECJtHxntnZcxavVGsAJfCqBXUXKT7L0z0CgWh7x8Xj02I4XQy5lm60NZTuZUNX1wIRhxHPtSTdPXApgKeI0D4BEiTZpm66jndpZSqLK1mdhIxGNB4bu96FNZOZwG28xqRwBwipLjS6Uhr7sKsvoQ/L1zZ/mrmqY/Ta01Rd8xGfDO5YRIANZ3W9q3rDbHBGdKBAyK2TwWOg1pYuuhYnHIU5Tct2v1xj1UqNmCkLes9lRheExOxGNvECLlAXwE4DjLaAAOA7hWlpO3yHLyCsOoCgA4WU5eZxjVpdnNW8ELvZhoTsCy2ujrWwXLap/W23Nll6DG91pW+zbP7WBw8IT1WCBu3LB2xt3ZTAoAFFVNP0khcgqsAfyOvlsA4DqOvQbAEwAuZvBlrICdP0kRfh4KTDuOvRiARC05Rc/BYzoRj/mFHVsgy8nHVDX9hOPYUJRcaI5KOw3AF8Xwy6bZejMY9JbVntP6mGd+96mlQp7b4QBwAYxyntvxAYTyefV9w6gODazbVHAcmx9Yt4lvjlemHce+jH5nahYMM4F5w6heMDJ6YGaBWf5MFfDpPUcJkd4H1l9J+QldPgElQqRDhlH9rqqmmxwHDKzbtKg5XplSlNwGTdMfopa+qCtBBJXha/XGRfNExYIgBACcKIZ9APfn8+prhEhvA9gDYDchkp3Pq28A2Kiq6aaul3si0X4mfBrACCHSe4RIy2v1xspSaddKQqSVtXrj0sB8Zam06wtzVecz8YBH6cYLAK4HsJhmFgDooedJes8k7ejuBlAgRPoVgD/LcnJbYXjsMl7o9ZjReKHXZ17ghd7pblkY/ueCUmgBxakHwBKq0FJ6eZrRA0YANU2/A8CjhEi/LgyPPdIcrxzS9fI92UzqeQC9AOxsJnUVVf71bCb1ZQA9ptnC/yMGGJmCpukbavXGNio034VjhmsvEY9dTIj0c9Ns7aDCC6qantD18g0AerObt75V2LHlawB6CsNjr2UzqWtkOZkFsIEqwM3miTNRwKUV90eW1V7RXQcAYHBw/UwdIERyTLNVKhaHPlCUnGCaLTiOHRLF8N8DxPElOudFMfyq49iDANbQVO3RonhW6gAPwH3nHXsJIdJV1NIu4yQAfIplN5tJIZtJHQLw02Jx6F+KkgsVi0NusTjkimKYQQ00IbC5F7h2cC5meiYxwNN7vQABAwDfczs+IVJIlpOPG0b1EVVNv05hM0250a2B2JmtDngAlppm65ru9DoL3fY/TRZaJIrhg7pefrawY0uKxcQJuGyboQeiGP4xAI/CZdpxbF7T9L2m2RogREJheCzI70+ZByDCzdGleQuBkB/Q+j4ADwDYCuAOAHfR+cMA7lSUHKcouQtEMew6jr1Y0/S9AOKESI/KcrIDYGqiOTFJiDRJ51OBuXu6ttWy2n4kGvEJkf4BoMOamYVQCahq+gMA27rW9nQHvOPYnKbpfyJE+gaA76hq+m+6Xv5PIh57iFHkRDyGRDwGWU4i0IP7swXqRHPCj0QjXjaTCslysiiK4SldLwuM4c5HAY4Wp6sA3NyFZS7gJQ9ASNP0uwFcAeAuVU2/ynHwTbP1S0KkKymFNvJ5tQ/AJYZRfSWfV68HIBtGdVF289ZTYMOEB6CJYrhMM5e7kCBmMHugVm+ojKcn4rGZwsPotGW1UdixBQDWqWr6L9TVXLE49FGx2NXBnFwkkwD2AbgkaLRINOJnMykBwG9VNf0gFd5faD/AYEEsq+16bsdLxGMC65uZFxLxmE/d/OzAuk1POo4tDKzbxAHwo6v7OQofxmw9QiTfNFshAK4ohquKknsXwErmYfodXpaTfxTF8L2OYwt0bcEKePS+5Z7b4btaPj6wg+YC2GUY1Yeb45XjmqYLzfHKNAA0xytojldO2m8qFj+eO44dMozqkiCVCAi6l+2ed1t/vmmUB+ASIh2v1SMcAD4Rj3GESKjVIwDAUXr9Q1VN7wWA6Or+RcXi0JSi5FIAUpTsfdK3pjRN92v1xpe60iiD7mFRDPu6XvY/TSX2AQi0Yu7cv2/n4WwmNUmI1ADwajaTOrp/384jALaqanqv49ghRcn1sF4AwCj9Rg/r3AKHB6BDiHQ1IdLtltVe1qUAOx/71JWYEGmmqKhquqAouecIkRapavpNui3/FcOouqqatmkXxjXHK5OKklsPYCch0iOm2doN4J+1euPYRLPif7z71s81xysuIeXrADxN8Y+FbibPK4gBCNHV/XyxOPQmxS5HlXodAISQKIhimAfALF8EcH9heKzYHK8cmk2w5ngFQkjkVTXd0PXyS319q263rLYbrPRn2pH5ptlaCuByjoM70axMcdyJvR+Og08PcBzguY7LcTPClwmRHiyVhn4z0awcmuWZmYM+BwAXzqeB/0QPyHKSi67uDwW05+jW9pJavbFncDD3Il3zT5OpFtfqjYFEPOabZuvOwcFclBrIm8O7ywrDY9/03A54oVc4zSbbzP93tXqD379vpyuKYT9E6ex0V8Cw7APLaouW1Rbna5GJ5gR4oTcOIL4gKJzKPFn7eUHwYrE45AHwTuJCul6+2jRb9xlGdQUTnhapIE2YzwgWuPk+w80GZd8/6HcVrpCi5ACgH8CthEjbVTX9Lgvim2v1xmZCJHTtW3JBwRY4BJzhIESaMoyqTRPGcQqhLbV641uESC0AZabADZbVnjbNlk+ItIgQyadw+oDi9Fz+T+YD8GQ5edgwqrtUNf2e49icYVRvBBA1zda1ltWeBnBjUIHLAHAjowfckdED7sYNa4/n8+rNA+s2vRNsOs6lAtTibFe7tzA89pRltVfQaxyALwbrwIuFHVtuM82WQGnBIQCt5njlWIDDnPPhOLYgimHXMKp8NpP6CMAK02z1UBlfCCqwHcCifF69CcC/DaO6XxTDxx3H5s/yH3zzHqIYBu3uOFEMf6jr5Y2ynPyJLCcvNIxqzTRbw/g8DU7Xy4Lj2Jzj2Dy1/Hk1FCXHU9k42lJynwvL/w8rbEDg/5G8/AAAAABJRU5ErkJggg==',
}
for name, data in assets.items():
    (asset_dir / name).write_bytes(base64.b64decode(data))

p = ROOT / 'lib/app/theme.dart'
s = p.read_text(encoding='utf-8')
s = s.replace('0xFFB7211C', '0xFFFF2B2B')
s = s.replace("seed: Color(0xFF0401FE)", "seed: Color(0xFF1755FF)")
s = s.replace("return secondary ? [const Color(0xFF6A00F4), const Color(0xFF00E5FF)] : [const Color(0xFF00E5FF), const Color(0xFF00FFC6)];", "return secondary ? [const Color(0xFF0E36B8), const Color(0xFF1755FF), const Color(0xFF6B93FF)] : [const Color(0xFF0E36B8), const Color(0xFF1755FF), const Color(0xFF6B93FF)];")
if "final cyberpunk = themeId == 'cyberpunk';" not in s:
    s = s.replace("  final vampire = themeId == 'vampire';", "  final vampire = themeId == 'vampire';\n  final arcane = themeId == 'arcane';\n  final cyberpunk = themeId == 'cyberpunk';")
old = """              outline: const Color(0xFFFF2B2B),
              outlineVariant: const Color(0xFFFF2B2B),
            )
          : baseScheme;"""
new = """              outline: const Color(0xFFFF2B2B),
              outlineVariant: const Color(0xFFFF2B2B),
            )
          : cyberpunk
              ? baseScheme.copyWith(
                  primary: const Color(0xFF1755FF),
                  onPrimary: const Color(0xFFFFFFFF),
                  primaryContainer: const Color(0xFF10265E),
                  onPrimaryContainer: const Color(0xFFEAF0FF),
                  secondary: const Color(0xFF1755FF),
                  onSecondary: const Color(0xFFFFFFFF),
                )
              : baseScheme;"""
if old not in s:
    raise SystemExit('scheme anchor not found')
s = s.replace(old, new)
old = "side: BorderSide(color: vampire ? const Color(0xFFFF2B2B) : scheme.outlineVariant.withOpacity(.18), width: vampire ? 1.35 : 1),"
new = """side: BorderSide(
            color: vampire
                ? const Color(0xFFFF2B2B)
                : (arcane
                    ? const Color(0xFFD0C3E8)
                    : (cyberpunk ? const Color(0xFF6B93FF) : scheme.outlineVariant.withOpacity(.18))),
            width: (vampire || arcane || cyberpunk) ? 1.35 : 1,
          ),"""
if old not in s:
    raise SystemExit('card side anchor not found')
s = s.replace(old, new)
old = """Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color}) {
  if (themeId != 'vampire') return Icon(themedIcon(themeId, role), size: size, color: color);
  final iconColor = color ?? const Color(0xFFB70F00);
  if (role == 'general') return Icon(Icons.circle, size: size, color: iconColor);
  if (role == 'skillTree') return CustomPaint(size: Size.square(size), painter: _AnatomicalHeartPainter(iconColor));
  if (role == 'abilities') return CustomPaint(size: Size.square(size), painter: _BatPainter(iconColor));
  return Icon(themedIcon(themeId, role), size: size, color: iconColor);
}"""
new = """Widget themedCharacterTabIcon(String themeId, String role, {double size = 18, Color? color}) {
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
  if (themeId != 'vampire') return Icon(themedIcon(themeId, role), size: size, color: color);
  final iconColor = color ?? const Color(0xFFB70F00);
  if (role == 'general') return Icon(Icons.circle, size: size, color: iconColor);
  if (role == 'skillTree') return CustomPaint(size: Size.square(size), painter: _AnatomicalHeartPainter(iconColor));
  if (role == 'abilities') return CustomPaint(size: Size.square(size), painter: _BatPainter(iconColor));
  return Icon(themedIcon(themeId, role), size: size, color: iconColor);
}"""
if old not in s:
    raise SystemExit('tab icon anchor not found')
s = s.replace(old, new)
p.write_text(s, encoding='utf-8')

for rel in ['lib/app/app.dart', 'lib/screens/character/character_screen.dart']:
    p = ROOT / rel
    p.write_text(p.read_text(encoding='utf-8').replace('0xFFB7211C', '0xFFFF2B2B'), encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.18+118', 'version: 1.3.19+119')
if '    - assets/cyberpunk/' not in s:
    s = s.replace('    - assets/character2d/\n', '    - assets/character2d/\n    - assets/cyberpunk/\n')
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/core/app_version.dart'
s = p.read_text(encoding='utf-8').replace("appVersion = '1.3.18'", "appVersion = '1.3.19'").replace('appBuildNumber = 118', 'appBuildNumber = 119')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web/rpg_service_worker.js'
p.write_text(p.read_text(encoding='utf-8').replace("const VERSION='1.3.18+118';", "const VERSION='1.3.19+119';"), encoding='utf-8')

p = ROOT / 'README.md'
s = p.read_text(encoding='utf-8').replace('V1.3.18 (Web/PWA)', 'V1.3.19 (Web/PWA)').replace('**1.3.18+118**', '**1.3.19+119**')
p.write_text(s, encoding='utf-8')

(ROOT / 'RELEASE_NOTES_1.3.19.md').write_text("""# RPG Sheet 1.3.19+119

## Temas
- Vampírico: bordas e divisores em `#FF2B2B`, mantendo a cor principal `#B70F00`.
- Arcano: bordas dos cards em `#D0C3E8`.
- Cyberpunk: cor principal `#1755FF`, bordas dos cards `#6B93FF` e barras de Vida/Energia em gradiente azul.
- Cyberpunk: ícones personalizados do usuário em Geral (caveira), Habilidades (demônio) e Perícias (chip).
- Pirata: identidade preservada, com o refinamento estrutural de navegação e abas já adotado globalmente.
""", encoding='utf-8')
