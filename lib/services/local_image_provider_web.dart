import 'dart:convert';
import 'package:flutter/widgets.dart';

ImageProvider? localImageProvider(String path) {
  if (path.isEmpty) return null;
  if (path.startsWith('data:image/')) {
    final comma = path.indexOf(',');
    if (comma > 0) {
      try {
        return MemoryImage(base64Decode(path.substring(comma + 1)));
      } catch (_) {
        return null;
      }
    }
  }
  return NetworkImage(path);
}
