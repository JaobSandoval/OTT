import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/network/debug_dio.dart';
import 'package:flutter/foundation.dart';

/// Bitácora de actividad hacia el logTool corporativo (mismo destino que usa
/// `PaginaBase.GenerarLTLog` en el sitio web XLStore), para monitoreo cross-plataforma
/// de qué pantallas visita y qué acciones realiza el usuario.
///
/// Fire-and-forget: nunca lanza, nunca bloquea al llamador.
class LtLogService {
  LtLogService._();

  static final LtLogService instance = LtLogService._();

  static const _proyecto = 'XLStoreApp';

  final Dio _dio = createDebugDio();

  String _idCliente = '';
  String _idUsuario = '';
  String _nombreUsuario = '';

  String _currentLink = 'App Móvil';
  String _previousLink = '';

  /// Se llama al iniciar sesión (o al restaurarla desde storage) con los datos
  /// del usuario, para que queden incluidos en cada log posterior.
  void setSession({
    required String idCliente,
    required String idUsuario,
    required String nombreUsuario,
  }) {
    _idCliente = idCliente;
    _idUsuario = idUsuario;
    _nombreUsuario = nombreUsuario;
  }

  /// Se llama al cerrar sesión.
  void clearSession() {
    _idCliente = '';
    _idUsuario = '';
    _nombreUsuario = '';
  }

  /// Registra un cambio de pantalla. Pensado para llamarse en cada navegación
  /// (ver `redirect` en `AppRouter`). Ignora repeticiones de la misma pantalla.
  void trackScreen(String pantalla) {
    if (pantalla.isEmpty || pantalla == _currentLink) return;
    _previousLink = _currentLink;
    _currentLink = pantalla;
    unawaited(_send(
      pantalla: pantalla,
      tipoOperacion: 'Navegacion',
      comentarios: '',
    ));
  }

  /// Registra una acción de negocio puntual (login, logout, carrito, búsqueda, etc.).
  Future<void> logAccion({
    required String pantalla,
    required String tipoOperacion,
    String comentarios = '',
  }) {
    return _send(
      pantalla: pantalla,
      tipoOperacion: tipoOperacion,
      comentarios: comentarios,
    );
  }

  Future<void> _send({
    required String pantalla,
    required String tipoOperacion,
    required String comentarios,
  }) async {
    final data = {
      'Token': '',
      'Proyecto': _proyecto,
      'Rol': '',
      'IdCliente': _idCliente,
      'NombreCliente': _idCliente,
      'IdUsuario': _idUsuario,
      'NombreUsuario': _nombreUsuario,
      'DireccionIP': '',
      'TipoOperacion': tipoOperacion,
      'Pantalla': pantalla,
      'Trans_Code': '',
      'Trans_No': '',
      'Comentarios': comentarios,
      'Link': _currentLink,
      'LinkReferido': _previousLink,
    };

    try {
      final url = '${AppRuntimeEndpoints.instance.urlLogTool}log.aspx';
      final response = await _dio.post<dynamic>(
        url,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      debugPrint('LOGTOOL enviado: $tipoOperacion / $pantalla → ${response.statusCode} $url');
      TechnicalLogStore.instance.info(
        'LOGTOOL',
        'Log enviado: $tipoOperacion / $pantalla',
        fields: {'statusCode': '${response.statusCode}'},
      );
    } on Object catch (e) {
      debugPrint('LOGTOOL fallido: $tipoOperacion / $pantalla → $e');
      TechnicalLogStore.instance.error(
        'LOGTOOL',
        'Log fallido: $tipoOperacion / $pantalla',
        error: e.toString(),
      );
    }
  }
}
