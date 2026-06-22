import 'dart:convert';

import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/welcome/domain/welcome_banner.dart';

class WelcomeBannersParser {
  const WelcomeBannersParser._();

  static List<WelcomeBanner> parseBanners(String xml) {
    final payload = ApiXlMovilSoapClient.extractSoapResult(
      xml,
      'BannersPreLoginPublicoResult',
    );
    if (payload.isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } on Object {
      final unescaped = payload
          .replaceAll('&quot;', '"')
          .replaceAll('&#34;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll('&#39;', "'");
      decoded = jsonDecode(unescaped);
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final squaresRaw = map['squares'] ?? map['promocionales'];
      return _parseSquares(squaresRaw);
    }

    if (decoded is List) {
      return _parseSquareList(decoded);
    }

    return const [];
  }

  static List<WelcomeBanner> _parseSquares(dynamic raw) {
    if (raw is! List) return const [];
    return _parseSquareList(raw);
  }

  static List<WelcomeBanner> _parseSquareList(List<dynamic> raw) {
    final squares = <WelcomeBanner>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final idContenido = _readString(map, 'idContenido', 'IdContenido');
      final imageUrl = _readString(map, 'imageUrl', 'ImageUrl');
      if (idContenido.isEmpty || imageUrl.isEmpty) continue;

      squares.add(
        WelcomeBanner(
          idContenido: idContenido,
          idSegmentacion: _readString(map, 'idSegmentacion', 'IdSegmentacion'),
          imageUrl: imageUrl,
          linkUrl: _readString(map, 'linkUrl', 'LinkUrl', 'linkContenido'),
          posicion: _readString(
            map,
            'posicion',
            'Posicion',
            'claveTipoSegmentacionContenido',
          ),
          tipoContenido: _readString(map, 'tipoContenido', 'TipoContenido'),
          titulo: _readString(map, 'titulo', 'Titulo', 'descripcionContenido'),
          orden: _readInt(map, 'orden', 'Orden', 'ordenContenido'),
        ),
      );
    }

    squares.sort((a, b) => a.orden.compareTo(b.orden));
    return squares;
  }

  static int _readInt(
    Map<String, dynamic> map,
    String primary,
    String secondary, [
    String? tertiary,
  ]) {
    final text = _readString(map, primary, secondary, tertiary);
    return int.tryParse(text) ?? 0;
  }

  static String _readString(
    Map<String, dynamic> map,
    String primary,
    String secondary, [
    String? tertiary,
  ]) {
    for (final key in [primary, secondary, ?tertiary]) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
