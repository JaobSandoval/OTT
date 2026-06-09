import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/network/debug_dio.dart';

class QuoteRegistrationApi {
  QuoteRegistrationApi({Dio? dio}) : _dio = dio ?? createDebugDio();

  final Dio _dio;

  String get _methodUrl {
    final base = AppRuntimeEndpoints.instance.exelAiAsmxBaseUrl;
    if (base.isEmpty) {
      throw Exception('URL de AI.asmx no configurada.');
    }
    return '$base/RegistrarCotizacion';
  }

  Future<bool> registrarCotizacion({
    required String idEvento,
    required String idUsuario,
    required String idCliente,
    required String nombreCliente,
    required double total,
    required int productosDetectados,
    required int productosEncontrados,
    String? productosCotizados,
    String? productosFaltantes,
    String? idConversacion,
  }) async {
    final payload = <String, dynamic>{
      'id_evento': idEvento,
      'id_usuario': idUsuario,
      'id_cliente': idCliente,
      'nombre_cliente': nombreCliente,
      'total': total,
      'productos_detectados': productosDetectados,
      'productos_encontrados': productosEncontrados,
      if (productosCotizados != null) 'productos_cotizados': productosCotizados,
      if (productosFaltantes != null) 'productos_faltantes': productosFaltantes,
      if (idConversacion != null) 'id_conversacion': idConversacion,
      'fecha_evento': DateTime.now().toIso8601String(),
    };

    TechnicalLogStore.instance.info(
      'QUOTE',
      'RegistrarCotizacion — solicitud',
      fields: {
        'id_evento': idEvento,
        'productos_detectados': '$productosDetectados',
        'productos_encontrados': '$productosEncontrados',
      },
    );

    final res = await _dio.post<String>(
      _methodUrl,
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    final body = res.data ?? '';
    if (res.statusCode != null && res.statusCode! >= 400) {
      TechnicalLogStore.instance.error(
        'QUOTE',
        'RegistrarCotizacion — HTTP ${res.statusCode}',
        statusCode: res.statusCode,
        body: body,
      );
      return false;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) {
          final status = first['status']?.toString().toLowerCase();
          return status == 'success';
        }
      }
      if (decoded is Map) {
        final status = decoded['status']?.toString().toLowerCase();
        return status == 'success';
      }
    } on Object {
      // Respuesta no JSON estándar; considerar éxito si HTTP 200.
    }

    return res.statusCode == 200;
  }
}
