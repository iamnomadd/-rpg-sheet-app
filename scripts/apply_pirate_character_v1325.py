from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

p = ROOT / 'lib' / 'screens' / 'character' / 'character_screen.dart'
s = p.read_text(encoding='utf-8')

needle = """  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negatives = _negativeStatuses;"""
replacement = """  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeId = context.watch<AppState>().themeId;
    final negatives = _negativeStatuses;"""
if needle not in s:
    raise SystemExit('Could not find character combat build header')
s = s.replace(needle, replacement, 1)

pattern = re.compile(r"child: incapacitated\n\s+\? ClipRect\(\n\s+child: SizedBox\(\n\s+height: 174,\n\s+child: Align\(\n\s+alignment: Alignment\.topCenter,\n\s+child: Image\.asset\(_asset, height: 198, fit: BoxFit\.contain, filterQuality: FilterQuality\.none\),\n\s+\),\n\s+\),\n\s+\)\n\s+: Image\.asset\(_asset, height: 198, fit: BoxFit\.contain, filterQuality: FilterQuality\.none\),")
replacement = """child: themeId == 'parchment' && !incapacitated && !agony
                              ? const SizedBox(
                                  width: 156,
                                  height: 198,
                                  child: CustomPaint(painter: _PirateSkeletonPainter()),
                                )
                              : incapacitated
                                  ? ClipRect(
                                      child: SizedBox(
                                        height: 174,
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Image.asset(_asset, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                                        ),
                                      ),
                                    )
                                  : Image.asset(_asset, height: 198, fit: BoxFit.contain, filterQuality: FilterQuality.none),"""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit('Could not replace character sprite renderer')

painter = r'''

class _PirateSkeletonPainter extends CustomPainter {
  const _PirateSkeletonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 156.0;
    final sy = size.height / 198.0;
    canvas.save();
    canvas.scale(sx, sy);

    const bone = Color(0xFFE6D2A6);
    const boneShadow = Color(0xFFB99D72);
    const brown = Color(0xFF6B4428);
    const darkBrown = Color(0xFF38251B);
    const navy = Color(0xFF162A46);
    const navyLight = Color(0xFF274669);
    const rope = Color(0xFFC7A66A);
    const gold = Color(0xFFB08A4B);
    const black = Color(0xFF090A0D);

    final bonePaint = Paint()..color = bone;
    final boneShadowPaint = Paint()..color = boneShadow;
    final brownPaint = Paint()..color = brown;
    final darkBrownPaint = Paint()..color = darkBrown;
    final navyPaint = Paint()..color = navy;
    final navyLightPaint = Paint()..color = navyLight;
    final ropePaint = Paint()..color = rope..style = PaintingStyle.stroke..strokeWidth = 3.2..strokeCap = StrokeCap.round;
    final goldPaint = Paint()..color = gold;
    final blackPaint = Paint()..color = black;

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 168, 24, 17), const Radius.circular(5)), darkBrownPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(86, 168, 24, 17), const Radius.circular(5)), darkBrownPaint);
    canvas.drawRect(const Rect.fromLTWH(43, 179, 30, 8), darkBrownPaint);
    canvas.drawRect(const Rect.fromLTWH(83, 179, 30, 8), darkBrownPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(52, 126, 17, 46), const Radius.circular(7)), navyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(87, 126, 17, 46), const Radius.circular(7)), navyPaint);
    canvas.drawRect(const Rect.fromLTWH(69, 127, 18, 15), navyLightPaint);

    final torso = Path()
      ..moveTo(46, 72)
      ..lineTo(64, 62)
      ..lineTo(92, 62)
      ..lineTo(110, 72)
      ..lineTo(103, 127)
      ..lineTo(53, 127)
      ..close();
    canvas.drawPath(torso, brownPaint);
    canvas.drawPath(Path()
      ..moveTo(62, 63)
      ..lineTo(77, 89)
      ..lineTo(57, 122)
      ..lineTo(52, 78)
      ..close(), darkBrownPaint);
    canvas.drawPath(Path()
      ..moveTo(94, 63)
      ..lineTo(79, 89)
      ..lineTo(99, 122)
      ..lineTo(104, 78)
      ..close(), darkBrownPaint);

    for (var i = 0; i < 4; i++) {
      final y = 79.0 + i * 9;
      canvas.drawArc(Rect.fromCenter(center: Offset(78, y), width: 35 - i * 2.5, height: 14), 3.35, 2.72, false, Paint()..color = bone..style = PaintingStyle.stroke..strokeWidth = 3.3);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(75, 76, 6, 42), const Radius.circular(3)), boneShadowPaint);

    final sash = Path()
      ..moveTo(47, 113)
      ..lineTo(107, 105)
      ..lineTo(109, 118)
      ..lineTo(49, 126)
      ..close();
    canvas.drawPath(sash, navyLightPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 121, 60, 8), const Radius.circular(3)), darkBrownPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(73, 120, 13, 10), const Radius.circular(2)), goldPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(77, 122, 5, 6), const Radius.circular(1)), blackPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(31, 75, 20, 48), const Radius.circular(8)), brownPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(105, 75, 20, 48), const Radius.circular(8)), brownPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(28, 112, 14, 38), const Radius.circular(6)), bonePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(114, 112, 14, 38), const Radius.circular(6)), bonePaint);
    canvas.drawCircle(const Offset(35, 151), 8, bonePaint);
    canvas.drawCircle(const Offset(121, 151), 8, bonePaint);

    canvas.drawOval(const Rect.fromLTWH(55, 24, 46, 48), bonePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(62, 57, 32, 22), const Radius.circular(7)), bonePaint);
    canvas.drawOval(const Rect.fromLTWH(63, 39, 11, 13), blackPaint);
    canvas.drawOval(const Rect.fromLTWH(82, 39, 11, 13), blackPaint);
    final nose = Path()..moveTo(78, 50)..lineTo(73, 59)..lineTo(83, 59)..close();
    canvas.drawPath(nose, blackPaint);
    for (var x = 66.0; x <= 88; x += 7.2) {
      canvas.drawRect(Rect.fromLTWH(x, 65, 2, 8), boneShadowPaint);
    }

    final bandana = Path()
      ..moveTo(53, 31)
      ..quadraticBezierTo(78, 16, 104, 31)
      ..lineTo(100, 40)
      ..quadraticBezierTo(78, 28, 56, 40)
      ..close();
    canvas.drawPath(bandana, navyPaint);
    canvas.drawCircle(const Offset(101, 34), 6, navyLightPaint);
    final tail1 = Path()..moveTo(104, 36)..lineTo(125, 48)..lineTo(110, 53)..close();
    final tail2 = Path()..moveTo(103, 37)..lineTo(118, 61)..lineTo(105, 55)..close();
    canvas.drawPath(tail1, navyPaint);
    canvas.drawPath(tail2, navyLightPaint);

    final ropePath = Path()
      ..moveTo(104, 74)
      ..cubicTo(116, 90, 107, 113, 93, 130);
    canvas.drawPath(ropePath, ropePaint);

    canvas.drawLine(const Offset(78, 83), const Offset(78, 96), Paint()..color = gold..strokeWidth = 2);
    canvas.drawCircle(const Offset(78, 101), 7, goldPaint);
    canvas.drawCircle(const Offset(78, 101), 3, darkBrownPaint);

    final scratch = Paint()..color = boneShadow.withOpacity(.55)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(56, 89), const Offset(67, 86), scratch);
    canvas.drawLine(const Offset(91, 102), const Offset(100, 98), scratch);
    canvas.drawLine(const Offset(50, 176), const Offset(61, 174), scratch);
    canvas.drawLine(const Offset(91, 176), const Offset(101, 173), scratch);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PirateSkeletonPainter oldDelegate) => false;
}
'''

if 'class _PirateSkeletonPainter extends CustomPainter' in s:
    raise SystemExit('Pirate painter already exists')
s += painter
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib' / 'core' / 'app_version.dart'
s = p.read_text(encoding='utf-8').replace("1.3.24", "1.3.25").replace("appBuildNumber = 124", "appBuildNumber = 125")
p.write_text(s, encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.24+124', 'version: 1.3.25+125')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web' / 'rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.24+124';", "const VERSION='1.3.25+125';")
p.write_text(s, encoding='utf-8')

(ROOT / 'RELEASE_NOTES_1.3.25.md').write_text("""# RPG Sheet 1.3.25\n\n- Teste visual do personagem 2D específico para o tema Sombrio Pirata.\n- O estado normal usa um pirata em estilo caveira/esqueleto com botas, colete, faixa e bandana.\n- Paleta do sprite: marrom, bege e azul escuro.\n- Inclui cinto, corda e medalhão e acabamento visual gasto de aventura.\n- Estado crítico e incapacitado continuam usando as animações/sprites existentes.\n""", encoding='utf-8')

print('v1.3.25 pirate character applied')
