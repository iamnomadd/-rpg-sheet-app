import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// No navegador: JPEG (qualidade 0,85) pela canvas quando a imagem não tem
/// transparência; PNG (dart:ui) quando tem, ou se a canvas falhar.
Future<String> encodeCustomSpriteDataUri(ui.Image image, Uint8List rgba, {required bool opaque}) async {
  if (opaque) {
    try {
      final document = globalContext['document'] as JSObject;
      final canvas = document.callMethod<JSObject>('createElement'.toJS, 'canvas'.toJS);
      canvas['width'] = image.width.toJS;
      canvas['height'] = image.height.toJS;
      final context = canvas.callMethod<JSObject>('getContext'.toJS, '2d'.toJS);
      final pixels = Uint8ClampedList.fromList(rgba).toJS;
      final imageData = (globalContext['ImageData'] as JSFunction).callAsConstructor<JSObject>(pixels, image.width.toJS, image.height.toJS);
      context.callMethod<JSAny?>('putImageData'.toJS, imageData, 0.toJS, 0.toJS);
      final url = canvas.callMethod<JSString>('toDataURL'.toJS, 'image/jpeg'.toJS, 0.85.toJS).toDart;
      if (url.startsWith('data:image/jpeg')) return url;
    } catch (_) {
      // Cai para PNG.
    }
  }
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) throw StateError('png');
  return 'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
}
