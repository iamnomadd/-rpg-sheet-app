from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

p = ROOT / 'lib' / 'screens' / 'character' / 'character_screen.dart'
s = p.read_text(encoding='utf-8')

# Add theme-aware pirate normal-state renderer.
needle = """    final incapacitated = _pose == 'incapacitated';
    final agony = _pose == 'agony';

    return Card("""
replacement = """    final incapacitated = _pose == 'incapacitated';
    final agony = _pose == 'agony';
    final themeId = context.watch<AppState>().themeId;
    final pirateNormal = themeId == 'parchment' && !incapacitated && !agony;

    return Card("""
if needle not in s:
    raise SystemExit('Could not find combat character build state block')
s = s.replace(needle, replacement, 1)

old = """child: incapacitated
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
new = """child: pirateNormal
                              ? const SizedBox(
                                  width: 168,
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
if old not in s:
    raise SystemExit('Could not find sprite renderer block')
s = s.replace(old, new, 1)

# Add painter just before combat character widget.
marker = "class _CombatCharacter2D extends StatelessWidget {"
if marker not in s:
    raise SystemExit('Could not find _CombatCharacter2D marker')

painter = r'''
class _PirateSkeletonPainter extends CustomPainter {
  const _PirateSkeletonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 168.0;
    final sy = size.height / 198.0;
    canvas.save();
    canvas.scale(sx, sy);

    const bone = Color(0xFFD8C7A1);
    const boneShadow = Color(0xFF9E8E6C);
    const brown = Color(0xFF6B4A2F);
    const brownDark = Color(0xFF3C291B);
    const navy = Color(0xFF14263D);
    const navyLight = Color(0xFF243D5A);
    const gold = Color(0xFFB08A4B);
    const soot = Color(0xFF181818);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Soft shadow under the character.
    fill.color = const Color(0x33000000);
    canvas.drawOval(const Rect.fromLTWH(34, 180, 100, 10), fill);

    // Boots.
    fill.color = brownDark;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(43, 155, 29, 29), const Radius.circular(6)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(96, 155, 29, 29), const Radius.circular(6)), fill);
    fill.color = brown;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(39, 176, 38, 10), const Radius.circular(4)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(92, 176, 38, 10), const Radius.circular(4)), fill);

    // Bone legs with worn dark-blue trousers.
    stroke
      ..color = bone
      ..strokeWidth = 8;
    canvas.drawLine(const Offset(62, 123), const Offset(58, 158), stroke);
    canvas.drawLine(const Offset(106, 123), const Offset(110, 158), stroke);
    fill.color = navy;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 116, 25, 40), const Radius.circular(7)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(95, 116, 25, 40), const Radius.circular(7)), fill);

    // Torso / beige shirt.
    fill.color = bone;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(50, 61, 68, 62), const Radius.circular(13)), fill);

    // Dark-blue worn undershirt.
    fill.color = navy;
    final shirt = Path()
      ..moveTo(57, 69)
      ..lineTo(78, 61)
      ..lineTo(85, 80)
      ..lineTo(92, 61)
      ..lineTo(112, 69)
      ..lineTo(113, 116)
      ..lineTo(55, 116)
      ..close();
    canvas.drawPath(shirt, fill);

    // Brown vest.
    fill.color = brown;
    final leftVest = Path()
      ..moveTo(52, 66)
      ..lineTo(73, 60)
      ..lineTo(79, 81)
      ..lineTo(77, 115)
      ..lineTo(54, 115)
      ..close();
    final rightVest = Path()
      ..moveTo(116, 66)
      ..lineTo(95, 60)
      ..lineTo(89, 81)
      ..lineTo(91, 115)
      ..lineTo(114, 115)
      ..close();
    canvas.drawPath(leftVest, fill);
    canvas.drawPath(rightVest, fill);

    // Worn fabric scratches.
    stroke
      ..color = const Color(0x55735C45)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(60, 80), const Offset(69, 76), stroke);
    canvas.drawLine(const Offset(99, 88), const Offset(108, 83), stroke);
    canvas.drawLine(const Offset(61, 101), const Offset(70, 98), stroke);

    // Belt + buckle.
    fill.color = brownDark;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(49, 111, 70, 11), const Radius.circular(3)), fill);
    fill.color = gold;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(79, 112, 11, 9), const Radius.circular(2)), fill);

    // Bone arms and wrist wraps.
    stroke
      ..color = bone
      ..strokeWidth = 7;
    canvas.drawLine(const Offset(54, 75), const Offset(36, 109), stroke);
    canvas.drawLine(const Offset(114, 75), const Offset(132, 109), stroke);
    canvas.drawLine(const Offset(36, 109), const Offset(43, 129), stroke);
    canvas.drawLine(const Offset(132, 109), const Offset(125, 129), stroke);
    stroke
      ..color = brown
      ..strokeWidth = 6;
    canvas.drawLine(const Offset(38, 112), const Offset(42, 122), stroke);
    canvas.drawLine(const Offset(130, 112), const Offset(126, 122), stroke);

    // Rope coil on right hip.
    stroke
      ..color = const Color(0xFFC0A476)
      ..strokeWidth = 3;
    canvas.drawArc(const Rect.fromLTWH(109, 112, 24, 24), 0.2, 5.4, false, stroke);
    canvas.drawArc(const Rect.fromLTWH(113, 116, 16, 16), 0.2, 5.4, false, stroke);

    // Neck / spine.
    stroke
      ..color = bone
      ..strokeWidth = 7;
    canvas.drawLine(const Offset(84, 58), const Offset(84, 66), stroke);

    // Skull.
    fill.color = bone;
    canvas.drawOval(const Rect.fromLTWH(62, 23, 44, 39), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(69, 49, 30, 20), const Radius.circular(7)), fill);

    // Skull shadow / cheek structure.
    stroke
      ..color = boneShadow
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(68, 49), const Offset(73, 57), stroke);
    canvas.drawLine(const Offset(100, 49), const Offset(95, 57), stroke);

    // Eye sockets.
    fill.color = soot;
    canvas.drawOval(const Rect.fromLTWH(69, 35, 11, 10), fill);
    canvas.drawOval(const Rect.fromLTWH(88, 35, 11, 10), fill);

    // Nose.
    final nose = Path()
      ..moveTo(84, 44)
      ..lineTo(79, 51)
      ..lineTo(89, 51)
      ..close();
    canvas.drawPath(nose, fill);

    // Teeth.
    stroke
      ..color = soot
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(74, 58), const Offset(94, 58), stroke);
    for (final x in [78.0, 82.0, 86.0, 90.0]) {
      canvas.drawLine(Offset(x, 54), Offset(x, 62), stroke);
    }

    // Dark-blue bandana and knot.
    fill.color = navyLight;
    final bandana = Path()
      ..moveTo(61, 33)
      ..quadraticBezierTo(84, 18, 108, 32)
      ..lineTo(104, 39)
      ..quadraticBezierTo(84, 29, 64, 40)
      ..close();
    canvas.drawPath(bandana, fill);
    canvas.drawCircle(const Offset(106, 34), 5, fill);
    final tail = Path()
      ..moveTo(108, 36)
      ..lineTo(127, 43)
      ..lineTo(112, 47)
      ..close();
    canvas.drawPath(tail, fill);

    // Medallion.
    stroke
      ..color = gold
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(84, 72), const Offset(84, 86), stroke);
    fill.color = gold;
    canvas.drawCircle(const Offset(84, 90), 5, fill);
    fill.color = navy;
    canvas.drawCircle(const Offset(84, 90), 2, fill);

    // Tiny fabric wear highlights.
    stroke
      ..color = const Color(0x447E91AA)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(57, 92), const Offset(64, 89), stroke);
    canvas.drawLine(const Offset(102, 73), const Offset(108, 71), stroke);
    canvas.drawLine(const Offset(101, 104), const Offset(109, 102), stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PirateSkeletonPainter oldDelegate) => false;
}

'''
s = s.replace(marker, painter + marker, 1)
p.write_text(s, encoding='utf-8')

# Version bump.
p = ROOT / 'lib' / 'core' / 'app_version.dart'
s = p.read_text(encoding='utf-8').replace("1.3.24", "1.3.25").replace("appBuildNumber = 124", "appBuildNumber = 125")
p.write_text(s, encoding='utf-8')

p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.24+124', 'version: 1.3.25+125')
p.write_text(s, encoding='utf-8')

p = ROOT / 'web' / 'rpg_service_worker.js'
s = p.read_text(encoding='utf-8').replace("const VERSION='1.3.24+124';", "const VERSION='1.3.25+125';")
p.write_text(s, encoding='utf-8')

(ROOT / 'RELEASE_NOTES_1.3.25.md').write_text("""# RPG Sheet 1.3.25\n\n- Adiciona um primeiro design temático do personagem 2D para o tema Sombrio Pirata.\n- O estado normal usa um pirata caveira vetorial com bandana, colete, faixa/cinto, botas, corda e medalhão.\n- Paleta do personagem: marrom, bege e azul escuro, com acabamento visual gasto.\n- Estados Crítico e Incapacitado continuam usando os visuais existentes, como definido para o teste inicial.\n""", encoding='utf-8')

print('v1.3.25 pirate character applied')
