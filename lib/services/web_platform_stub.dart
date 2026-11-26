import 'dart:typed_data';

// Fora do Web: sem download nem instalação de PWA.
bool canShareFiles() => false;
bool canShareText() => false;
bool download(Uint8List bytes, String fileName, String mimeType) => false;
String installState() => 'none';
Future<bool> promptInstall() async => false;
void Function() onInstallStateChange(void Function() onChange) => () {};
