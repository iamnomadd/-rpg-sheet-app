from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

p = ROOT / 'lib' / 'screens' / 'character' / 'character_screen.dart'
s = p.read_text(encoding='utf-8')

old_build = """  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negatives = _negativeStatuses;
    final positives = _positiveStatuses;
    final visibleStatuses = [...negatives, ...positives];
    final incapacitated = _pose == 'incapacitated';
    final agony = _pose == 'agony';
"""
new_build = """  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeId = context.watch<AppState>().themeId;
    final negatives = _negativeStatuses;
    final positives = _positiveStatuses;
    final visibleStatuses = [...negatives, ...positives];
    final incapacitated = _pose == 'incapacitated';
    final agony = _pose == 'agony';
    final pirateNormal = themeId == 'parchment' && !incapacitated && !agony;
"""
if old_build not in s:
    raise SystemExit('Combat character build block not found')
s = s.replace(old_build, new_build, 1)

old_sprite = """child: incapacitated
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
new_sprite = """child: pirateNormal
                              ? const SizedBox(
                                  width: 150,
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
if old_sprite not in s:
    raise SystemExit('Sprite image block not found')
s = s.replace(old_sprite, new_sprite, 1)

marker = "class _CombatCharacter2D extends StatelessWidget {"
if marker not in s:
    raise SystemExit('Combat character class marker not found')

painter = r'''
class _PirateSkeletonPainter extends CustomPainter {
  const _PirateSkeletonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 150.0;
    final sy = size.height / 198.0;
    canvas.save();
    canvas.scale(sx, sy);

    final outline = Paint()
      ..color = const Color(0xFF17130F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bone = Paint()..color = const Color(0xFFE7D8B9);
    final boneShade = Paint()..color = const Color(0xFFC9B78F);
    final brown = Paint()..color = const Color(0xFF6B452A);
    final brownDark = Paint()..color = const Color(0xFF402A1D);
    final navy = Paint()..color = const Color(0xFF17324B);
    final beige = Paint()..color = const Color(0xFFC9B88E);
    final gold = Paint()..color = const Color(0xFFB08A4B);
    final shadow = Paint()..color = const Color(0x55000000);

    canvas.drawOval(const Rect.fromLTWH(28, 183, 94, 10), shadow);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(39, 163, 28, 24), const Radius.circular(7)), brownDark);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(82, 163, 28, 24), const Radius.circular(7)), brownDark);
    canvas.drawPath(Path()..moveTo(38,183)..lineTo(68,183)..lineTo(65,190)..lineTo(34,190)..close(), brown);
    canvas.drawPath(Path()..moveTo(81,183)..lineTo(111,183)..lineTo(115,190)..lineTo(84,190)..close(), brown);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(44, 126, 23, 42), const Radius.circular(9)), navy);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(82, 126, 23, 42), const Radius.circular(9)), navy);

    canvas.drawPath(Path()
      ..moveTo(44,75)..quadraticBezierTo(75,63,106,75)
      ..lineTo(101,129)..quadraticBezierTo(75,139,49,129)..close(), beige);

    canvas.drawPath(Path()..moveTo(44,75)..lineTo(62,69)..lineTo(67,128)..lineTo(48,125)..close(), brown);
    canvas.drawPath(Path()..moveTo(106,75)..lineTo(88,69)..lineTo(83,128)..lineTo(102,125)..close(), brown);

    canvas.drawPath(Path()..moveTo(47,118)..lineTo(103,115)..lineTo(107,128)..lineTo(50,132)..close(), navy);
    canvas.drawPath(Path()..moveTo(95,126)..lineTo(108,133)..lineTo(101,158)..lineTo(92,137)..close(), navy);

    canvas.drawRect(const Rect.fromLTWH(49,129,52,7), brownDark);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(70,126,13,13), const Radius.circular(3)), gold);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(73,129,7,7), const Radius.circular(2)), brownDark);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(31,80,15,55), const Radius.circular(8)), beige);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(104,80,15,55), const Radius.circular(8)), beige);
    canvas.drawCircle(const Offset(38,137), 7, bone);
    canvas.drawCircle(const Offset(112,137), 7, bone);

    final rope = Paint()
      ..color = const Color(0xFF9B7B4D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(const Rect.fromLTWH(102,105,18,28), rope);
    canvas.drawOval(const Rect.fromLTWH(105,111,12,18), rope);

    canvas.drawOval(const Rect.fromLTWH(49,23,52,51), bone);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(57,57,36,21), const Radius.circular(7)), bone);
    canvas.drawOval(const Rect.fromLTWH(57,39,14,16), brownDark);
    canvas.drawOval(const Rect.fromLTWH(79,39,14,16), brownDark);
    canvas.drawPath(Path()..moveTo(75,50)..lineTo(70,60)..lineTo(80,60)..close(), boneShade);
    for (final x in [62.0,68.0,74.0,80.0,86.0]) {
      canvas.drawLine(Offset(x,64), Offset(x,73), Paint()..color=const Color(0xFF17130F)..strokeWidth=1.5);
    }

    canvas.drawPath(Path()
      ..moveTo(48,31)..quadraticBezierTo(75,16,102,31)
      ..lineTo(99,41)..quadraticBezierTo(75,29,51,41)..close(), navy);
    canvas.drawPath(Path()..moveTo(99,33)..lineTo(120,27)..lineTo(108,45)..close(), navy);

    canvas.drawLine(const Offset(69,77), const Offset(75,98), outline);
    canvas.drawLine(const Offset(81,77), const Offset(75,98), outline);
    canvas.drawCircle(const Offset(75,101), 6, gold);
    canvas.drawCircle(const Offset(75,101), 2, brownDark);

    final wear = Paint()
      ..color = const Color(0x88765C3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(54,91), const Offset(61,95), wear);
    canvas.drawLine(const Offset(91,92), const Offset(98,88), wear);
    canvas.drawLine(const Offset(59,145), const Offset(64,149), wear);
    canvas.drawLine(const Offset(88,149), const Offset(95,145), wear);

    canvas.drawOval(const Rect.fromLTWH(49,23,52,51), outline);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(57,57,36,21), const Radius.circular(7)), outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PirateSkeletonPainter oldDelegate) => false;
}

'''

if 'class _PirateSkeletonPainter extends CustomPainter' not in s:
    s = s.replace(marker, painter + marker, 1)

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

(ROOT / 'RELEASE_NOTES_1.3.25.md').write_text("""# RPG Sheet 1.3.25\n\n- Primeiro teste de personagem 2D temático no Sombrio Pirata.\n- Pose normal passa a usar um pirata caveira com botas, colete, faixa, bandana, cinto, corda e medalhão.\n- Paleta do personagem usa marrom, bege e azul escuro, com acabamento gasto de aventura.\n- Estados crítico e incapacitado continuam usando as artes existentes, como definido.\n""", encoding='utf-8')

print('v1.3.25 pirate skeleton sprite applied')
