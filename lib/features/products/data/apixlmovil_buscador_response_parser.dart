import 'dart:convert';

import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:xml/xml.dart';

/// Parsea respuesta SOAP de `Buscador` (APIXLMovil.asmx).
class ApiXlMovilBuscadorResponseParser {
  const ApiXlMovilBuscadorResponseParser._();

  static List<ProductCard> parse(String xml) {
    final trimmed = xml.trim();
    if (trimmed.isEmpty) {
      throw Exception('El servidor no respondió.');
    }

    if (trimmed.contains('soap:Fault') || trimmed.contains(':Fault>')) {
      final fault = _parseSoapFault(trimmed);
      throw Exception(fault.isEmpty ? 'Error en el servicio de productos.' : fault);
    }

    final doc = XmlDocument.parse(trimmed);
    final resultNode = _firstElement(doc.rootElement, 'BuscadorResult');
    if (resultNode == null) {
      throw Exception('Respuesta SOAP sin BuscadorResult.');
    }

    final payload = resultNode.innerText.trim();
    if (payload.isEmpty) return const [];

    return _parseProductJson(payload);
  }

  static String _parseSoapFault(String xml) {
    try {
      final doc = XmlDocument.parse(xml);
      final faultString = _textIn(doc.rootElement, 'faultstring');
      if (faultString.isNotEmpty) return faultString;
      return _textIn(doc.rootElement, 'faultcode');
    } on Object {
      return '';
    }
  }

  static List<ProductCard> _parseProductJson(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } on Object {
      // A veces el JSON viene escapado como string dentro del XML.
      final unescaped = payload
          .replaceAll('&quot;', '"')
          .replaceAll('&#34;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll('&#39;', "'");
      decoded = jsonDecode(unescaped);
    }

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => ProductCard.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.idProducto.isNotEmpty)
          .toList();
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final mensaje = map['mensaje']?.toString();
      if (mensaje != null && mensaje.isNotEmpty) {
        throw Exception(mensaje);
      }
    }

    return const [];
  }

  static XmlElement? _firstElement(XmlElement parent, String localName) {
    for (final node in parent.descendants.whereType<XmlElement>()) {
      if (node.name.local == localName) return node;
    }
    return null;
  }

  static String _textIn(XmlElement parent, String localName) {
    final node = _firstElement(parent, localName);
    return node?.innerText.trim() ?? '';
  }
}
