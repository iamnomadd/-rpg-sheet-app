import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/character.dart';
import 'custom_sprite_encoder.dart';

// Imagens próprias do personagem 2D: ilustrações (não pixel art), uma por
// estado, cortadas de uma imagem única ou enviadas separadas.

/// Estados na ordem usada pelos cortes e pela prévia.
const customSpritePoses = ['normal', 'agony', 'critical', 'incapacitated'];

const customSpritePoseLabels = {
  'normal': 'Normal',
  'agony': 'Ferido',
  'critical': 'Crítico',
  'incapacitated': 'Incapacitado',
};

/// Como a imagem única está dividida.
enum CustomSpriteLayout { row4, row3, grid2x2 }

const customSpriteLayoutLabels = {
  CustomSpriteLayout.row4: 'Fileira de 4',
  CustomSpriteLayout.row3: 'Fileira de 3',
  CustomSpriteLayout.grid2x2: 'Grade 2×2',
};

/// Estados de cada parte, na ordem das partes. Na fileira de 3 o Crítico não
/// tem imagem própria e usa a de Ferido.
List<String> customSpriteLayoutPoses(CustomSpriteLayout layout) => switch (layout) {
      CustomSpriteLayout.row3 => const ['normal', 'agony', 'incapacitated'],
      _ => const ['normal', 'agony', 'critical', 'incapacitated'],
    };

/// Layout sugerido pela proporção (largura/altura): ≥ 2,5 fileira de 4;
/// de 1,5 a 2,5 fileira de 3; abaixo disso, grade 2×2.
CustomSpriteLayout suggestCustomSpriteLayout(int width, int height) {
  if (width <= 0 || height <= 0) return CustomSpriteLayout.grid2x2;
  final ratio = width / height;
  if (ratio >= 2.5) return CustomSpriteLayout.row4;
  if (ratio >= 1.5) return CustomSpriteLayout.row3;
  return CustomSpriteLayout.grid2x2;
}

/// Um corte em pixels inteiros.
typedef PanelRect = ({int left, int top, int width, int height});

/// Corta a imagem em partes iguais (limites com floor), cobrindo a imagem
/// inteira sem sobra nem sobreposição, na ordem de [customSpriteLayoutPoses].
List<PanelRect> stripPanelRects(int width, int height, CustomSpriteLayout layout) {
  List<int> cuts(int size, int parts) => [for (var i = 0; i <= parts; i++) (i * size) ~/ parts];
  final (columns, rows) = switch (layout) {
    CustomSpriteLayout.row4 => (4, 1),
    CustomSpriteLayout.row3 => (3, 1),
    CustomSpriteLayout.grid2x2 => (2, 2),
  };
  final xs = cuts(width, columns);
  final ys = cuts(height, rows);
  return [
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < columns; c++) (left: xs[c], top: ys[r], width: xs[c + 1] - xs[c], height: ys[r + 1] - ys[r]),
  ];
}

/// Imagem do estado, com fallback: crítico → ferido → normal.
String? resolveCustomSpriteImage(Map<String, String> images, String pose) {
  for (final candidate in switch (pose) {
    'critical' => const ['critical', 'agony', 'normal'],
    'agony' => const ['agony', 'normal'],
    'incapacitated' => const ['incapacitated', 'normal'],
    _ => const ['normal'],
  }) {
    final image = images[candidate];
    if (image != null && image.isNotEmpty) return image;
  }
  return null;
}

/// Imagens próprias ligadas e com a imagem Normal salva.
bool customSpriteActive(Character character) =>
    character.customSpriteEnabled && (character.customSpriteImages['normal']?.isNotEmpty ?? false);

/// Movimento da imagem própria num instante.
typedef CustomSpriteMotion = ({double scale, double dx, double dy, double angle});

/// Escala-base para que nenhuma borda apareça durante o movimento.
const customSpriteBaseScale = 1.04;

/// Multiplicadores (respiração, vento) por estado.
({double breath, double wind}) customSpriteMotionStrength(String pose) => switch (pose) {
      'normal' => (breath: 1.0, wind: 1.0),
      'agony' => (breath: 1.25, wind: 0.6),
      'critical' => (breath: 1.5, wind: 0.0),
      _ => (breath: 0.0, wind: 0.0),
    };

/// Respiração (escala ±0,8% e ±1,5 px na vertical) e vento (±1,5 px na
/// horizontal e ±0,35° de rotação, defasados), já multiplicados pelo estado.
/// [breathPhase] vem do controlador `idle` (0→1→0) e [windPhase] de 0 a 1.
/// A escala da respiração oscila acima de 1 para nunca encolher além da base.
CustomSpriteMotion customSpriteMotion({
  required String pose,
  required double breathPhase,
  required double windPhase,
  required bool reduceMotion,
}) {
  if (reduceMotion) return (scale: 1.0, dx: 0.0, dy: 0.0, angle: 0.0);
  final strength = customSpriteMotionStrength(pose);
  final breath = (Curves.easeInOut.transform(breathPhase.clamp(0.0, 1.0)) - .5) * 2; // -1..1
  final wind = windPhase * 2 * math.pi;
  return (
    scale: 1 + .008 * strength.breath * (1 + breath),
    dx: 1.5 * strength.wind * math.sin(wind),
    dy: -1.5 * strength.breath * breath,
    angle: .006 * strength.wind * math.cos(wind),
  );
}

/// Erro de importação com mensagem pronta para o usuário.
class CustomSpriteException implements Exception {
  final String message;
  const CustomSpriteException(this.message);
  @override
  String toString() => message;
}

/// Limites das imagens processadas.
class CustomSpriteLimits {
  final int sourceMaxBytes;
  final int perStateMaxBytes;
  final int totalMaxBytes;
  final List<int> maxSides;
  const CustomSpriteLimits({
    this.sourceMaxBytes = 10 * 1024 * 1024,
    this.perStateMaxBytes = 350 * 1024,
    this.totalMaxBytes = 1200 * 1024,
    this.maxSides = const [512, 448, 384, 320],
  });
}

/// Tamanho em bytes da imagem dentro do data URI.
int customSpriteDataUriBytes(String dataUri) {
  final comma = dataUri.indexOf(',');
  if (comma < 0) return dataUri.length;
  final payload = dataUri.length - comma - 1;
  final padding = dataUri.endsWith('==') ? 2 : dataUri.endsWith('=') ? 1 : 0;
  return payload * 3 ~/ 4 - padding;
}

/// Bytes da imagem de um data URI, ou null se inválido.
Uint8List? customSpriteDataUriBytesOf(String dataUri) {
  final comma = dataUri.indexOf(',');
  if (!dataUri.startsWith('data:image/') || comma < 0) return null;
  try {
    return base64Decode(dataUri.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

bool _supportedFormat(Uint8List bytes) {
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (bytes.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[offset + i] != sig[i]) return false;
    }
    return true;
  }

  return startsWith(const [0x89, 0x50, 0x4E, 0x47]) || // PNG
      startsWith(const [0xFF, 0xD8, 0xFF]) || // JPEG
      (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)); // WebP
}

/// Confere tamanho e formato e decodifica a imagem de origem.
Future<ui.Image> decodeCustomSpriteSource(Uint8List bytes, {CustomSpriteLimits limits = const CustomSpriteLimits()}) async {
  if (bytes.length > limits.sourceMaxBytes) {
    throw CustomSpriteException('A imagem é muito grande (máximo ${limits.sourceMaxBytes ~/ (1024 * 1024)} MB).');
  }
  if (!_supportedFormat(bytes)) {
    throw const CustomSpriteException('Formato não suportado. Use PNG, JPG ou WebP.');
  }
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    throw const CustomSpriteException('Não foi possível ler a imagem. Tente outro arquivo.');
  }
}

Future<String> _encodePanel(ui.Image source, PanelRect rect, int maxSide) async {
  final scale = math.min(1.0, maxSide / math.max(rect.width, rect.height));
  final width = math.max(1, (rect.width * scale).round());
  final height = math.max(1, (rect.height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    source,
    Rect.fromLTWH(rect.left.toDouble(), rect.top.toDouble(), rect.width.toDouble(), rect.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('rgba');
    final rgba = data.buffer.asUint8List();
    var opaque = true;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 255) {
        opaque = false;
        break;
      }
    }
    return await encodeCustomSpriteDataUri(image, rgba, opaque: opaque);
  } finally {
    image.dispose();
  }
}

/// Corta, reduz (maior lado ≤ 512, nunca amplia) e codifica as partes. Usa o
/// mesmo tamanho em todas as partes e reduz em passos (512→448→384→320) até
/// cada estado e o total caberem nos limites; senão, erro e nada é devolvido.
Future<Map<String, String>> processCustomSpritePanels(
  ui.Image source,
  List<PanelRect> rects,
  List<String> poses, {
  CustomSpriteLimits limits = const CustomSpriteLimits(),
  Map<String, String> keep = const {},
}) async {
  final keptBytes = keep.entries.where((e) => !poses.contains(e.key)).fold<int>(0, (sum, e) => sum + customSpriteDataUriBytes(e.value));
  try {
    for (final maxSide in limits.maxSides) {
      final result = <String, String>{};
      var fits = true;
      var total = keptBytes;
      for (var i = 0; i < rects.length; i++) {
        final uri = await _encodePanel(source, rects[i], maxSide);
        final size = customSpriteDataUriBytes(uri);
        total += size;
        if (size > limits.perStateMaxBytes || total > limits.totalMaxBytes) {
          fits = false;
          break;
        }
        result[poses[i]] = uri;
      }
      if (fits) return result;
    }
  } on CustomSpriteException {
    rethrow;
  } catch (_) {
    throw const CustomSpriteException('Não foi possível processar a imagem. Tente outro arquivo.');
  }
  throw const CustomSpriteException('As imagens ficaram grandes demais mesmo reduzidas. Use imagens mais simples ou menores.');
}

/// Imagem única: decodifica, corta pelo [layout] e processa.
Future<Map<String, String>> processCustomSpriteSheet(
  Uint8List bytes,
  CustomSpriteLayout layout, {
  CustomSpriteLimits limits = const CustomSpriteLimits(),
}) async {
  final source = await decodeCustomSpriteSource(bytes, limits: limits);
  try {
    return await processCustomSpritePanels(source, stripPanelRects(source.width, source.height, layout), customSpriteLayoutPoses(layout), limits: limits);
  } finally {
    source.dispose();
  }
}

/// Um estado avulso (imagem inteira), respeitando o total com as [keep].
Future<String> processCustomSpriteSingle(
  Uint8List bytes,
  String pose, {
  CustomSpriteLimits limits = const CustomSpriteLimits(),
  Map<String, String> keep = const {},
}) async {
  final source = await decodeCustomSpriteSource(bytes, limits: limits);
  try {
    final result = await processCustomSpritePanels(
      source,
      [(left: 0, top: 0, width: source.width, height: source.height)],
      [pose],
      limits: limits,
      keep: keep,
    );
    return result[pose]!;
  } finally {
    source.dispose();
  }
}

/// Imagem própria de um estado: ilustração inteira (contain), cantos
/// arredondados, filtro suave e respiração + vento sutis, com escala-base de
/// 1,04 para nenhuma borda aparecer no recorte.
class CustomSpriteView extends StatefulWidget {
  final String dataUri;
  final String pose;
  final Animation<double> breath;
  final bool reduceMotion;
  final double height;

  const CustomSpriteView({
    super.key,
    required this.dataUri,
    required this.pose,
    required this.breath,
    required this.reduceMotion,
    this.height = 198,
  });

  @override
  State<CustomSpriteView> createState() => _CustomSpriteViewState();
}

class _CustomSpriteViewState extends State<CustomSpriteView> with SingleTickerProviderStateMixin {
  late final AnimationController _wind = AnimationController(vsync: this, duration: const Duration(milliseconds: 6600));
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspect;

  bool get _moves => !widget.reduceMotion && customSpriteMotionStrength(widget.pose).breath > 0;
  bool get _windy => !widget.reduceMotion && customSpriteMotionStrength(widget.pose).wind > 0;

  @override
  void initState() {
    super.initState();
    _load();
    _syncWind();
  }

  @override
  void didUpdateWidget(covariant CustomSpriteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataUri != widget.dataUri) _load();
    _syncWind();
  }

  void _syncWind() {
    if (_windy) {
      if (!_wind.isAnimating) _wind.repeat();
    } else if (_wind.isAnimating) {
      _wind.stop();
    }
  }

  void _load() {
    _stopListening();
    final bytes = customSpriteDataUriBytesOf(widget.dataUri);
    _provider = bytes == null ? null : MemoryImage(bytes);
    _aspect = null;
    final provider = _provider;
    if (provider == null) return;
    _stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      final aspect = info.image.width / info.image.height;
      info.dispose();
      if (mounted) setState(() => _aspect = aspect);
    }, onError: (_, __) {});
    _stream!.addListener(_listener!);
  }

  void _stopListening() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    _wind.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final aspect = _aspect;
    if (provider == null || aspect == null) return SizedBox(height: widget.height);
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : widget.height * aspect;
      var height = widget.height;
      var width = height * aspect;
      if (width > maxWidth) {
        width = maxWidth;
        height = width / aspect;
      }
      final image = Image(
        image: provider,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
      return SizedBox(
        height: widget.height,
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AnimatedBuilder(
                animation: Listenable.merge([widget.breath, _wind]),
                child: Transform.scale(
                  key: const ValueKey('custom-sprite-base'),
                  scale: customSpriteBaseScale,
                  child: image,
                ),
                builder: (context, child) {
                  final motion = _moves
                      ? customSpriteMotion(pose: widget.pose, breathPhase: widget.breath.value, windPhase: _wind.value, reduceMotion: false)
                      : (scale: 1.0, dx: 0.0, dy: 0.0, angle: 0.0);
                  return Transform.translate(
                    key: const ValueKey('custom-sprite-motion'),
                    offset: Offset(motion.dx, motion.dy),
                    child: Transform.rotate(
                      angle: motion.angle,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(scale: motion.scale, alignment: Alignment.bottomCenter, child: child),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}
