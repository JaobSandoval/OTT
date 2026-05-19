import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:exel_ott/core/config/app_config.dart';
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

  static final Dio _configDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {Headers.acceptHeader: 'application/json'},
    ),
  );

  String _exelInfoUsuarioUrl = AppConfig.exelInfoUsuarioUrl;
  String _apiBaseUrl = AppConfig.baseUrl;
  String? _nombreApp;
  String? _configVersion;
  String? _urlExel;
  String? _urlXlStore;
  String? _urlGooglePlay;
  String? _urlAppStore;

  String get exelInfoUsuarioUrl => _exelInfoUsuarioUrl;
  String get apiBaseUrl => _apiBaseUrl;
  String? get nombreApp => _nombreApp;
  String? get configVersion => _configVersion;
  String? get urlExel => _urlExel;
  String? get urlXlStore => _urlXlStore;
  String? get urlGooglePlay => _urlGooglePlay;
  String? get urlAppStore => _urlAppStore;

  /// Tienda según plataforma (Android → Play, iOS → App Store).
  String? get storeUpdateUrl {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _urlAppStore;
      case TargetPlatform.android:
        return _urlGooglePlay;
      default:
        return _urlGooglePlay ?? _urlAppStore;
    }
  }

  String get displayAppName => _nombreApp ?? AppConfig.appName;
  String get displayVersion => _configVersion ?? '—';

  /// Carga asset local y luego intenta fusionar el JSON remoto.
  Future<void> load() async {
    await _loadFromAsset();
    await _loadFromRemote();
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
        return;
      }
      _merge(map);
      debugPrint('Config remota cargada desde ${AppConfig.configuracionRemotaUrl}');
    } on Object catch (e) {
      debugPrint(
        'Config remota no disponible (${AppConfig.configuracionRemotaUrl}): $e',
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
}
