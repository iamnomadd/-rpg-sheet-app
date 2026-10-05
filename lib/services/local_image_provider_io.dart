import 'dart:io';
import 'package:flutter/widgets.dart';
ImageProvider? localImageProvider(String path){if(path.isEmpty)return null;final f=File(path);return f.existsSync()?FileImage(f):null;}
