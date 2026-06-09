import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class QuoteImageCompressor {
  /// Comprime y devuelve JPEG en base64 listo para el ASMX.
  static Future<({String base64, String contentType})> compressToBase64(
    String filePath,
  ) async {
    final bytes = await _compressBytes(filePath);
    return (
      base64: base64Encode(bytes),
      contentType: 'image/jpeg',
    );
  }

  static Future<Uint8List> _compressBytes(String filePath) async {
    final result = await FlutterImageCompress.compressWithFile(
      filePath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 72,
      format: CompressFormat.jpeg,
    );
    if (result != null && result.isNotEmpty) {
      return result;
    }
    return File(filePath).readAsBytes();
  }
}
