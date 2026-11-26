import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

JSObject? get _navigator => globalContext.getProperty<JSObject?>('navigator'.toJS);

bool canShareFiles() {
  try {
    final navigator = _navigator;
    if (navigator == null || !navigator.has('share') || !navigator.has('canShare')) return false;
    final fileClass = globalContext.getProperty<JSFunction?>('File'.toJS);
    if (fileClass == null) return false;
    final options = JSObject()..setProperty('type'.toJS, 'image/png'.toJS);
    final file = fileClass.callAsConstructor<JSObject>(<JSAny>[].toJS, 'grimorio.png'.toJS, options);
    final data = JSObject()..setProperty('files'.toJS, <JSAny>[file].toJS);
    final result = navigator.callMethod<JSAny?>('canShare'.toJS, data);
    return result.isA<JSBoolean>() && (result as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}

bool canShareText() {
  try {
    final navigator = _navigator;
    return navigator != null && navigator.has('share');
  } catch (_) {
    return false;
  }
}

bool download(Uint8List bytes, String fileName, String mimeType) {
  try {
    final document = globalContext.getProperty<JSObject>('document'.toJS);
    final body = document.getProperty<JSObject>('body'.toJS);
    final anchor = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
    anchor.setProperty('href'.toJS, 'data:$mimeType;base64,${base64Encode(bytes)}'.toJS);
    anchor.setProperty('download'.toJS, fileName.toJS);
    anchor.getProperty<JSObject>('style'.toJS).setProperty('display'.toJS, 'none'.toJS);
    body.callMethod<JSAny?>('appendChild'.toJS, anchor);
    anchor.callMethod<JSAny?>('click'.toJS);
    anchor.callMethod<JSAny?>('remove'.toJS);
    return true;
  } catch (_) {
    return false;
  }
}

/// 'prompt', 'ios' ou 'none' (window.rpgInstallState, definida no index.html).
String installState() {
  try {
    final state = globalContext.getProperty<JSFunction?>('rpgInstallState'.toJS)?.callAsFunction();
    return state.isA<JSString>() ? (state as JSString).toDart : 'none';
  } catch (_) {
    return 'none';
  }
}

Future<bool> promptInstall() async {
  try {
    final prompt = globalContext.getProperty<JSFunction?>('rpgPromptInstall'.toJS);
    final result = prompt?.callAsFunction();
    if (result == null || !result.isA<JSPromise<JSAny?>>()) return false;
    final accepted = await (result as JSPromise<JSAny?>).toDart;
    return accepted.isA<JSBoolean>() && (accepted as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}

void Function() onInstallStateChange(void Function() onChange) {
  final listener = ((JSAny? _) => onChange()).toJS;
  try {
    globalContext.callMethod<JSAny?>('addEventListener'.toJS, 'rpg-install-change'.toJS, listener);
  } catch (_) {
    return () {};
  }
  return () {
    try {
      globalContext.callMethod<JSAny?>('removeEventListener'.toJS, 'rpg-install-change'.toJS, listener);
    } catch (_) {}
  };
}
