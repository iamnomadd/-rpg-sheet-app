import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Fora do navegador só há PNG (dart:ui), com transparência preservada.
Future<String> encodeCustomSpriteDataUri(ui.Image image, Uint8List rgba, {required bool opaque}) async {
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) throw StateError('png');
  return 'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
}
