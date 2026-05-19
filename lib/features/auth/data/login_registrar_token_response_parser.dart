import 'dart:convert';

import 'package:exel_ott/core/auth/exel_security_ids.dart';
import 'package:xml/xml.dart';

/// Parsea `clsResultadoLoginMovil` (XML directo o dentro de `{"d":"..."}` ASP.NET).
class LoginRegistrarTokenResponseParser {
  const LoginRegistrarTokenResponseParser._();

  /// IDs para `ConsultarTokensPendientes` a partir del perfil normalizado.
  static ExelSecurityIds securityIds(Map<String, dynamic> profile) =>
      exelSecurityIdsFromProfile(profile);

  static Map<String, dynamic> parse(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map.containsKey('d')) {
        return parse(map['d']);
      }
      if (_isLoginProfileMap(map)) {
        _ensureSuccessFromMap(map);
        return _normalizeFromMap(map);
      }
    }

    if (data is! String) {
      throw Exception('LoginRegistrarToken: formato de respuesta no reconocido.');
    }

    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      throw Exception('LoginRegistrarToken: respuesta vacía.');
    }

    if (trimmed.startsWith('<')) {
      if (trimmed.contains('soap:Fault') || trimmed.contains(':Fault>')) {
        final fault = parseSoapFault(trimmed);
        if (fault.isNotEmpty) throw Exception(fault);
      }
      return _parseXml(trimmed);
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return parse(jsonDecode(trimmed));
    }

    if (trimmed.toLowerCase() == 'true') {
      return const {};
    }
    if (trimmed.toLowerCase() == 'false') {
      throw Exception('LoginRegistrarToken: credenciales o registro rechazado.');
    }

    throw Exception('LoginRegistrarToken: $trimmed');
  }

  static bool _isLoginProfileMap(Map<String, dynamic> map) {
    return map.containsKey('NombreCompleto') ||
        map.containsKey('ResultadoOperacion') ||
        map.containsKey('Usuario');
  }

  static void _ensureSuccessFromXml(XmlElement root) {
    final operacion = _firstElement(root, 'ResultadoOperacion');
    if (operacion == null) return;

    final operacionExitosa = _bool(_textIn(operacion, 'OperacionExitosa'));
    if (operacionExitosa) return;

    final mensajeError = _textIn(operacion, 'MensajeError');
    throw Exception(
      mensajeError.isEmpty
          ? 'LoginRegistrarToken: operación rechazada.'
          : mensajeError,
    );
  }

  static void _ensureSuccessFromMap(Map<String, dynamic> map) {
    final resultado = map['ResultadoOperacion'];
    if (resultado is Map) {
      final ok = resultado['OperacionExitosa'];
      if (ok is bool && !ok) {
        final msg = resultado['MensajeError']?.toString().trim() ?? '';
        throw Exception(
          msg.isEmpty ? 'LoginRegistrarToken: operación rechazada.' : msg,
        );
      }
    }
  }

  static Map<String, dynamic> _normalizeFromMap(Map<String, dynamic> map) {
    final usuario = map['Usuario'];
    final usuarioMap = usuario is Map ? Map<String, dynamic>.from(usuario) : null;

    final nombreCompleto = _str(map['NombreCompleto']);
    final email = usuarioMap != null ? _str(usuarioMap['Email']) : '';
    final usuarioLogin = usuarioMap != null ? _str(usuarioMap['Usuario']) : '';

    final ids = exelSecurityIdsFromProfile(map);

    return {
      'NombreCompleto': nombreCompleto,
      'nombre': nombreCompleto,
      'Email': email,
      'email': email,
      'Usuario': usuarioLogin,
      'usuario': usuarioLogin,
      'Id_Usuario': ids.idUsuario,
      'IdLocalidad': _str(map['IdLocalidad']),
      'IdCliente': ids.idCliente,
      'TokenRegistrado': map['TokenRegistrado'] == true ||
          _str(map['TokenRegistrado']).toLowerCase() == 'true',
    };
  }

  /// Texto de `soap:Fault` si la respuesta es un error SOAP.
  static String parseSoapFault(String xml) {
    try {
      final doc = XmlDocument.parse(xml);
      final faultString = _textIn(doc.rootElement, 'faultstring');
      if (faultString.isNotEmpty) return faultString;
      return _textIn(doc.rootElement, 'faultcode');
    } on Object {
      return '';
    }
  }

  static Map<String, dynamic> _parseXml(String xml) {
    final doc = XmlDocument.parse(xml);
    final root =
        _firstElement(doc.rootElement, 'clsResultadoLoginMovil') ?? doc.rootElement;

    _ensureSuccessFromXml(root);

    final usuarioNode = _firstElement(root, 'Usuario');
    final email = usuarioNode != null ? _textIn(usuarioNode, 'Email') : '';
    final usuarioLogin = usuarioNode != null ? _textIn(usuarioNode, 'Usuario') : '';
    final idUsuarioNode =
        usuarioNode != null ? _textIn(usuarioNode, 'Id_Usuario') : '';

    final nombreCompleto = _textIn(root, 'NombreCompleto');
    final idLocalidad = _textIn(root, 'IdLocalidad');
    final idCliente = _textIn(root, 'IdCliente');
    final tokenRegistrado = _bool(_textIn(root, 'TokenRegistrado'));

    final raw = {
      'NombreCompleto': nombreCompleto,
      'nombre': nombreCompleto,
      'Email': email,
      'email': email,
      'Usuario': usuarioLogin,
      'usuario': usuarioLogin,
      'Id_Usuario': idUsuarioNode,
      'IdLocalidad': idLocalidad,
      'IdCliente': idCliente,
      'TokenRegistrado': tokenRegistrado,
    };
    final ids = exelSecurityIdsFromProfile(raw);
    return {
      ...raw,
      'Id_Usuario': ids.idUsuario,
      'IdCliente': ids.idCliente,
    };
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

  static String _str(Object? v) => v?.toString().trim() ?? '';

  static bool _bool(String value) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'sí' || v == 'si';
  }
}
