import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Chama window.rpgApplyUpdate (definida no index.html), que atualiza o
/// service worker e recarrega a página uma vez. Sem a função, só recarrega.
Future<void> applyUpdateAndReload() async {
  final apply = globalContext.getProperty<JSFunction?>('rpgApplyUpdate'.toJS);
  if (apply == null) {
    globalContext.getProperty<JSObject>('location'.toJS).callMethod<JSAny?>('reload'.toJS);
    return;
  }
  final result = apply.callAsFunction();
  if (result != null && result.isA<JSPromise<JSAny?>>()) {
    await (result as JSPromise<JSAny?>).toDart;
  }
}
