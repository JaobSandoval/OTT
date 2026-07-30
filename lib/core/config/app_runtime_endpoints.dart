import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/core/network/debug_dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Endpoints resueltos en tiempo de ejecución.
///
/// Orden de prioridad (de menor a mayor): defaults de [AppConfig] → asset local
/// → JSON remoto en [AppConfig.configuracionRemotaUrl].
class AppRuntimeEndpoints {
  AppRuntimeEndpoints._();

  static final AppRuntimeEndpoints instance = AppRuntimeEndpoints._();

  static const String configAssetPath = 'assets/config/configuracion.json';

  static final Dio _configDio = createDebugDio(
    baseOptions: BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {Headers.acceptHeader: 'application/json'},
    ),
  );

  String _exelInfoUsuarioUrl = AppConfig.exelInfoUsuarioUrl;
  String _apiBaseUrl = AppConfig.baseUrl;
  String _apiXlMovilAsmxUrl =
      normalizeApiXlMovilAsmxUrl(AppConfig.apiXlMovilAsmxUrl);
  String _loginRegistrarTokenSoapUrl = AppConfig.loginRegistrarTokenSoapUrl;
  String? _nombreApp;
  String? _configVersion;
  String? _urlExel;
  String? _urlXlStore;
  String? _urlGooglePlay;
  String? _urlAppStore;
  String? _urlHazOlvidadoTuContrasena;
  String? _urlAltaDeCliente;
  String _urlLogTool = AppConfig.defaultUrlLogTool;
  bool _enMantenimiento = false;
  String? _mensajeEnMantenimiento;

  String get exelInfoUsuarioUrl => _exelInfoUsuarioUrl;

  /// Base del servicio AI.asmx (sin nombre de método), p. ej. `.../AI/AI.asmx`.
  String get exelAiAsmxBaseUrl => normalizeExelAiAsmxBaseUrl(_exelInfoUsuarioUrl);
  String get apiBaseUrl => _apiBaseUrl;
  String get apiXlMovilAsmxUrl => _apiXlMovilAsmxUrl;
  String get loginRegistrarTokenSoapUrl => _loginRegistrarTokenSoapUrl;
  String? get nombreApp => _nombreApp;
  String? get configVersion => _configVersion;
  String get urlExel => _urlExel ?? AppConfig.defaultUrlExel;
  String get urlXlStore => _urlXlStore ?? AppConfig.defaultUrlXlStore;
  String get urlGooglePlay => _urlGooglePlay ?? AppConfig.defaultUrlGooglePlay;
  String get urlAppStore => _urlAppStore ?? AppConfig.defaultUrlAppStore;
  String get urlHazOlvidadoTuContrasena =>
      _urlHazOlvidadoTuContrasena ?? AppConfig.defaultUrlHazOlvidadoTuContrasena;
  String get urlAltaDeCliente =>
      _urlAltaDeCliente ?? AppConfig.defaultUrlAltaDeCliente;

  /// Base del logTool corporativo, siempre terminada en `/`.
  String get urlLogTool =>
      _urlLogTool.endsWith('/') ? _urlLogTool : '$_urlLogTool/';
  bool get enMantenimiento => _enMantenimiento;
  String? get mensajeEnMantenimiento => _mensajeEnMantenimiento;

  /// Tienda según plataforma (Android → Play, iOS → App Store).
  String get storeUpdateUrl {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return urlAppStore;
      case TargetPlatform.android:
        return urlGooglePlay;
      default:
        return urlGooglePlay;
    }
  }

  String get displayAppName => _nombreApp ?? AppConfig.appName;
  String get displayVersion => _configVersion ?? '—';

  /// URL del carrito en XLStore para confirmar el pedido en el navegador.
  String get miCarritoUrl {
    final base = urlXlStore.trim();
    if (base.isEmpty) {
      return 'https://www.exel.com.mx/xlstore/Carrito/MiCarrito';
    }
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$normalized/Carrito/MiCarrito';
  }

  /// Recarga solo el JSON remoto (p. ej. al abrir productos), sin reiniciar la app.
  Future<void> refreshRemoteConfig() async {
    if (AppConfig.skipRemoteConfig) return;
    await _loadFromRemote();
  }

  /// Carga asset local y luego intenta fusionar el JSON remoto.
  Future<void> load() async {
    TechnicalLogStore.instance.info('CONFIG', 'Cargando configuración runtime');
    await _loadFromAsset();
    if (!AppConfig.skipRemoteConfig) {
      await _loadFromRemote();
    }
    TechnicalLogStore.instance.info(
      'CONFIG',
      'Configuración resuelta',
      fields: {
        'exelInfoUsuarioUrl': _exelInfoUsuarioUrl,
        'apiBaseUrl': _apiBaseUrl,
        'apiXlMovilAsmxUrl': _apiXlMovilAsmxUrl,
        'loginRegistrarTokenSoapUrl': _loginRegistrarTokenSoapUrl,
        'nombreApp': _nombreApp ?? '(default)',
        'configVersion': _configVersion ?? '(default)',
      },
    );
  }

  Future<void> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(configAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _merge(decoded);
      }
    } on Object catch (e) {
      debugPrint('Config local no disponible: $e');
      TechnicalLogStore.instance.error(
        'CONFIG',
        'Config local no disponible',
        error: e.toString(),
      );
      await FirebaseMonitoringService.instance.logConfigLoadFailed(
        source: 'local',
        reason: e.toString(),
      );
    }
  }

  Future<void> _loadFromRemote() async {
    try {
      final res = await _configDio.get<dynamic>(AppConfig.configuracionRemotaUrl);
      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) map = decoded;
      }
      if (map == null) {
        debugPrint('Config remota: respuesta no es un objeto JSON.');
        TechnicalLogStore.instance.error(
          'CONFIG',
          'Config remota: respuesta no es JSON',
        );
        await FirebaseMonitoringService.instance.logConfigLoadFailed(
          source: 'remote',
          reason: 'invalid_json',
        );
        return;
      }
      _merge(map);
      debugPrint('Config remota cargada desde ${AppConfig.configuracionRemotaUrl}');
      TechnicalLogStore.instance.info(
        'CONFIG',
        'Config remota cargada',
        fields: {'url': AppConfig.configuracionRemotaUrl},
        body: jsonEncode(map),
      );
    } on Object catch (e) {
      debugPrint(
        'Config remota no disponible (${AppConfig.configuracionRemotaUrl}): $e',
      );
      TechnicalLogStore.instance.error(
        'CONFIG',
        'Config remota no disponible',
        fields: {'url': AppConfig.configuracionRemotaUrl},
        error: e.toString(),
      );
      await FirebaseMonitoringService.instance.logConfigLoadFailed(
        source: 'remote',
        reason: e.toString(),
      );
    }
  }

  void _merge(Map<String, dynamic> map) {
    final exel = _pickString(map, const [
      'exelInfoUsuarioUrl',
      'infoUsuarioUrl',
      'EXEL_INFO_USUARIO_URL',
    ]);
    if (exel != null) _exelInfoUsuarioUrl = exel;

    final base = _pickString(map, const [
      'apiBaseUrl',
      'baseUrl',
      'API_BASE_URL',
    ]);
    if (base != null) _apiBaseUrl = base;

    final apiXlMovil = _pickString(map, const [
      'urlApiXLMovil',
      'urlApiXlmovil',
      'apiXlMovilUrl',
      'apiXlMovilAsmxUrl',
      'API_XL_MOVIL_URL',
    ]);
    if (apiXlMovil != null) {
      _apiXlMovilAsmxUrl = normalizeApiXlMovilAsmxUrl(apiXlMovil);
    }

    final loginSoap = _pickString(map, const [
      'loginRegistrarTokenSoapUrl',
      'apiSeguridadUrl',
      'LOGIN_SOAP_URL',
    ]);
    if (loginSoap != null) _loginRegistrarTokenSoapUrl = loginSoap;

    _nombreApp = _pickString(map, const ['nombreApp', 'NombreApp']) ?? _nombreApp;
    _configVersion =
        _pickString(map, const ['version', 'Version']) ?? _configVersion;
    _urlExel = _pickString(map, const ['urlExel', 'UrlExel']) ?? _urlExel;
    _urlXlStore =
        _pickString(map, const ['urlXLStore', 'urlXlStore', 'UrlXLStore']) ??
            _urlXlStore;
    _urlGooglePlay =
        _pickString(map, const ['urlGooglePlay', 'UrlGooglePlay']) ??
            _urlGooglePlay;
    _urlAppStore =
        _pickString(map, const ['urlAppStore', 'UrlAppStore']) ?? _urlAppStore;
    _urlHazOlvidadoTuContrasena = _pickString(map, const [
          'urlHazOlvidadoTuContraseña',
          'urlHazOlvidadoTuContrasena',
          'UrlHazOlvidadoTuContraseña',
        ]) ??
        _urlHazOlvidadoTuContrasena;
    _urlAltaDeCliente =
        _pickString(map, const ['urlAltaDeCliente', 'UrlAltaDeCliente']) ??
            _urlAltaDeCliente;
    _urlLogTool =
        _pickString(map, const ['urlLogTool', 'UrlLogTool']) ?? _urlLogTool;

    final mantenimiento = _pickBoolFlag(map, const [
      'enMantenimiento',
      'EnMantenimiento',
    ]);
    if (mantenimiento != null) _enMantenimiento = mantenimiento;

    _mensajeEnMantenimiento = _pickString(map, const [
          'mensajeEnMantenimiento',
          'MensajeEnMantenimiento',
        ]) ??
        _mensajeEnMantenimiento;
  }

  String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  bool? _pickBoolFlag(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t.isEmpty) continue;
        if (t == '1' || t == 'true' || t == 'si' || t == 'sí') return true;
        if (t == '0' || t == 'false' || t == 'no') return false;
      }
    }
    return null;
  }

  /// Deriva la URL base de AI.asmx desde `exelInfoUsuarioUrl` u otra URL del mismo ASMX.
  static String normalizeExelAiAsmxBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;

    final lower = url.toLowerCase();
    final asmxIndex = lower.indexOf('.asmx');
    if (asmxIndex >= 0) {
      return url.substring(0, asmxIndex + 5);
    }

    if (!url.endsWith('/')) {
      url = '$url/';
    }
    return '${url}AI.asmx';
  }

  /// Acepta URL base (`.../apiXLMovil/`) o ASMX completo (`.../APIXLMovil.asmx`).
  static String normalizeApiXlMovilAsmxUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;

    if (url.toLowerCase().contains('.asmx')) {
      return url;
    }

    if (!url.endsWith('/')) {
      url = '$url/';
    }
    return '${url}APIXLMovil.asmx';
  }
}
