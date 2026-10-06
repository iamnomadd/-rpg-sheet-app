import 'package:flutter/material.dart';

const _piratePalette = <Color>[
  Color(0xFFC29E85),
  Color(0xFF8C6A5A),
  Color(0xFF896453),
  Color(0xFF7A4238),
  Color(0xFF534240),
  Color(0xFF6F3732),
  Color(0xFF4E3E3C),
  Color(0xFF48312C),
  Color(0xFF582E2A),
  Color(0xFF382A2A),
  Color(0xFF312B2E),
  Color(0xFF2E292E),
  Color(0xFF2B2225),
  Color(0xFF2B1E1F),
  Color(0xFF201D21),
  Color(0xFF1B1A1F),
  Color(0xFF15151A),
  Color(0xFF121318),
  Color(0xFF111115),
  Color(0xFF120D11),
  Color(0xFF0B0B0F),
  Color(0xFF0B060A),
  Color(0xFF07070B),
  Color(0xFF040204),
];

const _paletteChars = '0123456789ABCDEFGHIJKLMN';

const _pirateNormalRows = <String>[
  '................................',
  '...............KGGIMIK..........',
  '..............KCCCCEKGH.........',
  '...........KFCAAFCCCCCDKM.......',
  '..........HHKAKECCCCCDCEKH......',
  '........HGNLELAK373GIIECCM......',
  '.......HI537DCG553D55333LGK.....',
  '......HL7KKMEK533L35533357I.....',
  '.....IK3KC7CECML3553335335I.....',
  '.....I5ML5NCDICL3L53353355I.....',
  '.....IIL3ICKDMA3EA6ED5355KK.....',
  '.....GG35ICMEMF2FE2M2D65LIK.....',
  '.....G35MIMHKML0G22ME20LII......',
  '.....L5MIC6AELK0L2200NMKIK......',
  '.....NDHMLL6AFELLL000LMII.......',
  '.....KII220GAAK2MM22NKIGI.......',
  '.....HGK6006DIA7377FENMI........',
  '.....GN25002DDAL276FINKK........',
  '.....FD00002G376D3C6D2G.........',
  '.....F60000ME77603G672F.........',
  '.....M00000EAG6M20GAD0MF........',
  '....F000000FAAHN2NFF702IG.......',
  '....L070020KAAK000M26067F.......',
  '....L0E7EKAD7C7675GFK7IEG.......',
  '.....M20AMDD57777LDDK6D3N.......',
  '.....ILEDKNGDEIN00K77D5DM.......',
  '.....N367LE0AN0IHFK37LD6M.......',
  '.....M3C76N06M2ECEC355EENG......',
  '.....L3D6EN72H70AFA33360MF......',
  '.....L607NCF2AEDMEA533LLLF......',
  '.....N60E0E636AKHA63357LLF......',
  '......MLMNG2E6AKGAA3357MF.......',
  '......HMAN0I66AMKAA3KGGIG.......',
  '......KAACC2006GLA6G73ACI.......',
  '......F6NE6A02MGMAI66G56G.......',
  '.....K66G5IAEKMHHM7555D7H.......',
  '.....2LA75EG37KIHL577677L.......',
  '.....6IN37767MIIHL33333IN.......',
  '......HN776C5MHIHGMEKNLIG.......',
  '......M7CG7K3MHIIHN7777IG.......',
  '......E37DCKMHHHIHD6D7LHG.......',
  '......DD7DMGHHHHHM6D77D7NMM.....',
  '.....K5233CGHHHHHK76D753236.....',
  '....GN3333AHGFEEGM7DLLD777EFF...',
  '.FEAENE77DKECDEEFELKKILLLLLCCEE.',
  '...HECCCCACCCCEFCCEECCEECCCCF...',
  '......F..FHF..FG....FFFHFGG.....',
  '................................',
];

const _pirateCriticalRows = <String>[
  '................................',
  '....................KI..........',
  '...................LKAKKI.......',
  '.................KFAADAAKIK.....',
  '.............HHHMIAFAAADAKFI....',
  '............GK33KIKAHAAADDAK....',
  '...........GJ777FDAI5DFAAADFK...',
  '..........F55FDLAFI5733HIDAAAK..',
  '..........K3J3JFFF5537A535IAFI..',
  '..........KKDDDF7ILD57533535AG..',
  '..........IH7IFG3FAKL3535333DF..',
  '..........HHMFKALFG5J33533533LK.',
  '..........IHAIFFGDK3FA5353335KI.',
  '.........MKF6AAKDFI5I01I35557KK.',
  '........F001AAMFAIF11MM1J3557IK.',
  '.......FK00377KAFLDL10100M5J7I..',
  '.......FD00016KIKADKD01LMKKKAI..',
  '.......F10001ADKK3LIKMNLMGKGF...',
  '......FD00001D73M3FJLN7IKDK7....',
  '.....FN003017FDDK311A61HIGHA....',
  '.....FL0J100LAK5M63IA11LKKIF....',
  '.....L00FJ007F6A7301K11LIHIK....',
  '.....M17AJ0J6FALJN0MJ111IH......',
  '.....GGL1G7KLID0F1LDI171JG......',
  '......I7101MD73711DALIAIGH......',
  '......3DL00LD777D5DD7M17LH......',
  '......MJ57FJ11JKKKM75DDDJH......',
  '.....HJM1FD0L6AFAAF753J17G......',
  '.....I1K577NNA6AAFA7337L0M......',
  '.....31K7D01M6AALF67335K0M......',
  '....K0KFDM0MA66FLAA553D0JF......',
  '....KNG31MKF666MIIF3D3J6NF......',
  '....G50N0G66101KHK55F7A6AF......',
  '....HGL0JA66006KHKDM6A66DK......',
  '....IJ6MD6F66AFLHILKA66A0K......',
  '.....J3D7K0FA6MHHGL73JADFM......',
  '.....MK3577D67HIIK777773FK......',
  '.....LJ367ADDMHIIK667773LG......',
  '.....L6DFD55LHIIIIIIIDDDNG......',
  '.....L77DFM3IHIIIIIJ7ADLIG......',
  '....I76DDLGGGHIIIHLD7D7DKGG.....',
  '....M5D77LGHGHHHHHF7A7D7333K....',
  '....L10333LHGGFFIGLDDGD7667JFG..',
  '..IFMD777DLADDADGIKLMIMMMMKMFFG.',
  '.DFAFLLLLKFAADAA7AAFFFDDA7AAAF..',
  '...........FDADAFFADFHGFFFF.....',
  '.............GGFH....GG.........',
  '................................',
];

const _pirateIncapacitatedRows = <String>[
  '.............................................................',
  '.............................................................',
  '.......................KKKKJILCBC9B9E..K.....................',
  '......................JJHKJJKIEHHEC999LLC....................',
  '.....................KJJN535NLKE999E999JBC...................',
  '....................KJGL5333JIB9999CC99JC9B..................',
  '...................KJKJ5555EJ9JGC9CCCCCEC99KKJ...............',
  '..................KJK95IJKKK953CJG9CCCCBECCLEB...............',
  '.................KJJ735J77KL5533533GC99CCCCE9................',
  '.................KKE35L759KCJ35915GGEGEGC99C9................',
  '.................KK95JJ35KCCL5C357953333JJCCBE...............',
  '.................JKLL735JJJK9J73J7355333333JC9C..............',
  '.................HGGL55LNCKCCK35E53355533333IGC..............',
  '.................HGIKJLNEGG9GE1J7555333355733JG..............',
  '.................GNNBBBNLL97IC1LC5335333333795K..............',
  '.................L34CBBCKK9CEC0JCC335533333355K..............',
  '................LBK019BBEL7J9J1KBJ75335533335EK..............',
  '................EL313044BK7LCI1KL301333555557LG..............',
  '...............GGN007014BCJCJ53KJ4KE17933555JK...............',
  '...............EK10004074BI9G35N1LNN101J335JJ................',
  '..............EEN00007094BLCJ1JL13NL4001N77KC................',
  '.............GEJ700001414GKKG4NEG0000JJ9LLJKE................',
  '............GEH9000000409KELCJLN11009NLLKKJLK................',
  '...........HGEK0000000E1LCKCE4KLKL7JJLNLEKJLH................',
  '...........GEK10000001CJKCLBC4CKJ7KLKJJNCKKLK................',
  '...........EEK01100009NIC95NBE1493JEGN3G9NJKJ11..............',
  '...........EK00000107KKLK7CCG91E1IBBGJ3G9K941114.............',
  '...........N00000041G444KL97J49JJBB4L43NLB4444449K...........',
  '...........LLJJ900KB433744LLK401J9BBN1JL944B449100N..........',
  '...........GL11K01K4337479BKK9100KBBKLL444BB440000L..........',
  '...........EK007LKG435974344BJ115JBK95E7BBE44447774E.........',
  '...........GKI301LB47C4443444ENNKGL55L1GBCG44B433337L........',
  '...........JL403KJB4B74449B977GEKJ53J10KBHB9E7534LK9L........',
  '..........GK549JKKBBB449G40001K77535100EBKBG453JGCCLI........',
  '.........GGK747KNEGB434H9001GJNE555J100BBKEC53JE757LG........',
  '........GGN7997JKBKE44B00175477N777K0KBBEEG79G77577N99CE.....',
  '...ECGK11014J7CLHLLG7BC01G7595C7354CLEBEEELJK9947C9777LCE....',
  '..CCEL1000000J7KLHGL9BJ1J979794157CC9LEBGKNLLG959431334LGH...',
  '..HGK100CKN00KKHECGLLBJ1JE99973159E99LGGLLHHLE777333779NEEG..',
  '..ECEKKNHGL7NHGHHJKKKLK44KC999534E999LKLJHHJN77C7577CGLGCCB..',
  '..CCB99CBCCC99CCEEGGGGGKLLKLNC747C79GNEEEEEEKEEEC9JLLLCBBEI..',
  '..GCCCC9999CC999999999CCEEEGGLJJC9EJKEEEC99CNECELLLJCCCCCEG..',
  '.........GEC97777777797977999CLLKKLN97999999BNNLLGCCCC9ECE...',
  '.........EC9C9999799CGGEC9C979CCCCB9777CEEBBECCCCCCE.........',
  '..........GEG....GECCCEECCCCC9979CEE...CCC......EEE..........',
  '.............................................................',
  '.............................................................',
];

class PirateSprite extends StatelessWidget {
  final String pose;
  final double height;

  const PirateSprite({super.key, required this.pose, this.height = 198});

  List<String> get _rows => switch (pose) {
        'incapacitated' => _pirateIncapacitatedRows,
        'agony' => _pirateCriticalRows,
        _ => _pirateNormalRows,
      };

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final width = height * rows.first.length / rows.length;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _PiratePixelSpritePainter(rows)),
    );
  }
}

class _PiratePixelSpritePainter extends CustomPainter {
  final List<String> rows;
  const _PiratePixelSpritePainter(this.rows);

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final pixelW = size.width / rows.first.length;
    final pixelH = size.height / rows.length;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final char = row[x];
        if (char == '.') continue;
        final index = _paletteChars.indexOf(char);
        if (index < 0 || index >= _piratePalette.length) continue;
        paint.color = _piratePalette[index];
        canvas.drawRect(
          Rect.fromLTWH(x * pixelW, y * pixelH, pixelW + .1, pixelH + .1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PiratePixelSpritePainter oldDelegate) => oldDelegate.rows != rows;
}
