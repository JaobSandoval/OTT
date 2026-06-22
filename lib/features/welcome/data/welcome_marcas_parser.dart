import 'dart:convert';

import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/features/products/data/apixlmovil_soap_client.dart';
import 'package:exel_ott/features/welcome/domain/welcome_marca.dart';

class WelcomeMarcasParser {
  const WelcomeMarcasParser._();

  static List<WelcomeMarca> parse(String xml) {
    final payload = ApiXlMovilSoapClient.extractSoapResult(
      xml,
      'MarcasPreLoginPublicoResult',
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
      return _parseMarcasList(Map<String, dynamic>.from(decoded)['marcas']);
    }

    if (decoded is List) {
      return _parseMarcasList(decoded);
    }

    return const [];
  }

  static List<WelcomeMarca> _parseMarcasList(dynamic raw) {
    if (raw is! List) return const [];
    final marcas = <WelcomeMarca>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final idMarca = _readString(map, 'id_marca', 'idMarca', 'Id_Marca');
      final nombre = _readString(
        map,
        'marca',
        'Marca',
        'descripcion_marca',
        'descripcion',
        'nombre',
        'Nombre',
      );
      final imageUrl = _resolveImageUrl(
        _readString(
          map,
          'UrlLogo',
          'urlLogo',
          'logo_marca',
          'imageUrl',
          'linkImagen',
          'linkImagenXLSTORE',
        ),
        idMarca,
      );
      if (nombre.isEmpty && imageUrl.isEmpty) continue;
      marcas.add(
        WelcomeMarca(
          idMarca: idMarca,
          nombre: nombre,
          imageUrl: imageUrl,
          linkUrl: _resolveLinkUrl(
            _readString(map, 'LinkLogo', 'linkLogo', 'linkUrl', 'LinkUrl'),
            idMarca,
            nombre,
          ),
        ),
      );
    }
    return marcas;
  }

  static String _resolveLinkUrl(
    String linkLogo,
    String idMarca,
    String nombre,
  ) {
    final trimmed = linkLogo.trim();
    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://')) {
      return trimmed;
    }
    if (idMarca.isNotEmpty) return 'marca|$idMarca';
    if (nombre.isNotEmpty) return 'buscar|$nombre';
    return '';
  }

  static String _resolveImageUrl(String raw, String idMarca) {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.startsWith(r'\\') || trimmed.startsWith('//')) {
        // PathLogo en red UNC no sirve en la app; se usa fallback por id.
      } else {
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('http://') || lower.startsWith('https://')) {
          return trimmed;
        }
        if (trimmed.startsWith('/')) {
          return 'https://www.exel.com.mx$trimmed';
        }
        final base = AppConfig.defaultUrlXlStore;
        return trimmed.startsWith(base) ? trimmed : '$base$trimmed';
      }
    }
    if (idMarca.isEmpty) return '';
    return '${AppConfig.defaultUrlXlStore}Imagenes/Marcas/$idMarca.jpg';
  }

  static String _readString(
    Map<String, dynamic> map,
    String primary,
    String secondary, [
    String? tertiary,
    String? quaternary,
    String? quinary,
    String? senary,
    String? septenary,
    String? octonary,
  ]) {
    for (final key in [
      primary,
      secondary,
      ?tertiary,
      ?quaternary,
      ?quinary,
      ?senary,
      ?septenary,
      ?octonary,
    ]) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
