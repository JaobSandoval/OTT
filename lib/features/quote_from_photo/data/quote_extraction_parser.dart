import 'dart:convert';

import 'package:exel_ott/features/quote_from_photo/domain/quote_line.dart';

class QuoteExtractionParser {
  static QuoteExtractionResult parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw Exception('Respuesta vacía del servicio de visión.');
    }

    var decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Formato de respuesta no válido.');
    }

    // Los servicios ASMX con [ScriptService] envuelven la respuesta en {"d":"..."}.
    // Si existe, desempacamos y re-parseamos el valor interno.
    if (decoded.containsKey('d') && decoded['d'] is String) {
      final inner = jsonDecode(decoded['d'] as String);
      if (inner is! Map<String, dynamic>) {
        throw Exception('Formato de respuesta no válido (inner d).');
      }
      decoded = inner;
    }

    final status = (decoded['status'] as String?)?.toLowerCase();
    if (status == 'error') {
      final msg = (decoded['mensaje'] as String?) ?? 'Error al analizar la imagen.';
      throw Exception(msg);
    }

    final lineasRaw = decoded['lineas'];
    final lineas = <QuoteLine>[];
    if (lineasRaw is List) {
      for (final item in lineasRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final texto = _str(map['texto']);
        final sku = _str(map['sku']);
        if (texto.isEmpty && sku.isEmpty) continue;

        var cantidad = _int(map['cantidad']);
        if (cantidad < 1) cantidad = 1;

        lineas.add(
          QuoteLine(
            texto: texto.isNotEmpty ? texto : sku,
            sku: sku,
            cantidad: cantidad,
            notas: _str(map['notas']),
          ),
        );
      }
    }

    if (lineas.isEmpty) {
      throw Exception('No se detectaron líneas en la imagen. Intenta con otra foto.');
    }

    return QuoteExtractionResult(
      lineas: lineas,
      observaciones: _str(decoded['observaciones']),
    );
  }

  static String _str(Object? v) => v?.toString().trim() ?? '';

  static int _int(Object? v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 1;
  }
}
