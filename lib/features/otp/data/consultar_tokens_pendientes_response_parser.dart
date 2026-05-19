import 'package:xml/xml.dart';

/// Token pendiente (`clsTokenOperacion`) del WS `ConsultarTokensPendientes`.
class PendingToken {
  const PendingToken({
    required this.idToken,
    required this.token,
    required this.fechaRegistro,
    this.fechaValidacion,
    this.tipoToken = '',
    this.estatusToken = '',
  });

  final int idToken;
  final String token;
  final DateTime? fechaRegistro;
  final DateTime? fechaValidacion;
  final String tipoToken;
  final String estatusToken;
}

/// Parsea la respuesta SOAP de `ConsultarTokensPendientes`.
class ConsultarTokensPendientesResponseParser {
  const ConsultarTokensPendientesResponseParser._();

  static List<PendingToken> parse(String xml) {
    final trimmed = xml.trim();
    if (trimmed.isEmpty) {
      throw Exception('ConsultarTokensPendientes: respuesta vacía.');
    }

    if (trimmed.contains('soap:Fault') || trimmed.contains(':Fault>')) {
      final fault = _parseSoapFault(trimmed);
      if (fault.isNotEmpty) throw Exception(fault);
    }

    final doc = XmlDocument.parse(trimmed);
    final result = _firstElement(doc.rootElement, 'ConsultarTokenResult') ??
        _firstElement(doc.rootElement, 'ConsultarTokensPendientesResult') ??
        doc.rootElement;

    _ensureSuccess(result);

    final tokens = <PendingToken>[];
    for (final node in result.descendants.whereType<XmlElement>()) {
      if (node.name.local != 'clsTokenOperacion') continue;
      final token = _textIn(node, 'Token');
      if (token.isEmpty) continue;
      tokens.add(
        PendingToken(
          idToken: int.tryParse(_textIn(node, 'IdToken')) ?? 0,
          token: token,
          fechaRegistro: _parseDateTime(_textIn(node, 'FechaRegistro')),
          fechaValidacion: _parseDateTime(_textIn(node, 'FechaValidacion')),
          tipoToken: _textIn(node, 'TipoToken'),
          estatusToken: _textIn(node, 'EstatusToken'),
        ),
      );
    }

    return tokens;
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

  static void _ensureSuccess(XmlElement result) {
    final operacion = _firstElement(result, 'ResultadoOperacion');
    if (operacion == null) return;

    final ok = _bool(_textIn(operacion, 'OperacionExitosa'));
    if (ok) return;

    final msg = _textIn(operacion, 'MensajeError');
    throw Exception(
      msg.isEmpty ? 'ConsultarTokensPendientes: operación rechazada.' : msg,
    );
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

  static bool _bool(String value) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1';
  }

  static DateTime? _parseDateTime(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}
