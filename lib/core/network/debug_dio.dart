import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:exel_ott/core/debug/technical_log_entry.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const _requestStartKey = '_techLogStart';

Dio createDebugDio({BaseOptions? baseOptions}) {
  final dio = Dio(baseOptions);
  _configureLocalDevCertificates(dio);
  dio.interceptors.add(TechnicalLogInterceptor());
  return dio;
}

void _configureLocalDevCertificates(Dio dio) {
  if (!kDebugMode || kIsWeb) return;
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        final h = host.toLowerCase();
        return h == 'localhost' ||
            h == '127.0.0.1' ||
            h == '10.0.2.2' ||
            h.startsWith('192.168.') ||
            h.endsWith('.local');
      };
      return client;
    },
  );
}

class TechnicalLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStartKey] = DateTime.now();

    final bodyForTerminal = _sanitizeBody(_bodyWithTruncatedBase64(options.data));
    final bodyFull = _sanitizeBody(_toJson(options.data));

    if (kDebugMode) {
      dev.log(
        '>>> ${options.method} ${options.uri}\n'
        'Headers: ${_headersForLog(options.headers)}\n'
        'Body (preview):\n$bodyForTerminal',
        name: 'HTTP.REQ',
      );
      options.extra['_fullBody'] = bodyFull;
    }

    final store = TechnicalLogStore.instance;
    if (store.isEnabled) {
      store.log(TechnicalLogEntry(
        timestamp: DateTime.now(),
        level: TechnicalLogLevel.request,
        category: _categoryFromUrl(options.uri.toString()),
        title: '${options.method} ${options.uri}',
        fields: _headersForLog(options.headers),
        body: bodyForTerminal.isEmpty ? null : bodyForTerminal,
      ));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _logResponse(response, null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logResponse(err.response, err);
    _reportApiError(err);
    handler.next(err);
  }

  void _reportApiError(DioException err) {
    final options = err.requestOptions;
    final started = options.extra[_requestStartKey] as DateTime?;
    final durationMs = started != null
        ? DateTime.now().difference(started).inMilliseconds
        : null;
    final status = err.response?.statusCode;
    unawaited(
      FirebaseMonitoringService.instance.logApiError(
        endpoint: options.uri.toString(),
        statusCode: status,
        errorType: err.type.name,
        durationMs: durationMs,
      ),
    );
  }

  void _logResponse(Response<dynamic>? response, DioException? err) {
    final options = err?.requestOptions ?? response?.requestOptions;
    final started = options?.extra[_requestStartKey] as DateTime?;
    final durationMs = started != null
        ? DateTime.now().difference(started).inMilliseconds
        : null;

    final status = response?.statusCode ?? err?.response?.statusCode;
    final isError = err != null || (status != null && status >= 400);
    final responseBody = _bodyToString(response?.data ?? err?.response?.data);

    if (kDebugMode) {
      dev.log(
        '${isError ? "ERROR" : "OK"} $status ${options?.method ?? ""} ${options?.uri ?? ""}  '
        '${durationMs != null ? "(${durationMs}ms)" : ""}\n'
        '${err != null ? "DioError: ${err.type} - ${err.message}\n" : ""}'
        'Body:\n$responseBody',
        name: 'HTTP.RES',
      );

      final soapJson = _extractSoapResultJson(responseBody);
      if (soapJson != null) {
        dev.log(soapJson, name: 'HTTP.RES.JSON');
        _logOpenAiDebugFromJson(soapJson);
      }

      if (options != null) {
        final fullRequestBody = options.extra['_fullBody'] as String? ?? '';
        _saveToFile(options, fullRequestBody, responseBody, status, durationMs, err);
      }
    }

    final store = TechnicalLogStore.instance;
    if (!store.isEnabled) return;

    store.log(TechnicalLogEntry(
      timestamp: DateTime.now(),
      level: isError ? TechnicalLogLevel.error : TechnicalLogLevel.response,
      category: _categoryFromUrl(options?.uri.toString() ?? ''),
      title: status != null
          ? 'HTTP $status ${options?.method ?? ''} ${options?.uri ?? ''}'
          : 'Error de red ${options?.uri ?? ''}',
      statusCode: status,
      durationMs: durationMs,
      body: responseBody.isEmpty ? null : responseBody,
      error: err != null ? '${err.type}: ${err.message}' : null,
      fields: err != null && err.type.name.isNotEmpty
          ? {'dioType': err.type.name}
          : null,
    ));
  }

  // ---------------------------------------------------------------------------
  // Guardar archivo TXT completo (sin recortar nada)
  // Ruta: /sdcard/Android/data/com.appXLStore/files/  (visible en el cel)
  // ---------------------------------------------------------------------------

  static Future<void> _saveToFile(
    RequestOptions options,
    String fullBody,
    String responseBody,
    int? status,
    int? durationMs,
    DioException? err,
  ) async {
    try {
      final extDir = await getExternalStorageDirectory();
      final dir = extDir ?? await getApplicationCacheDirectory();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final slug = options.uri.path.split('/').lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => 'request',
      );
      final file = File('${dir.path}/http_${slug}_$ts.txt');

      final buf = StringBuffer()
        ..writeln('=== HTTP REQUEST ===')
        ..writeln('Timestamp : ${DateTime.now().toIso8601String()}')
        ..writeln('Method    : ${options.method}')
        ..writeln('URL       : ${options.uri}')
        ..writeln()
        ..writeln('--- Headers ---');
      _headersForLog(options.headers).forEach((k, v) => buf.writeln('$k: $v'));
      buf
        ..writeln()
        ..writeln('--- Body (COMPLETO, sin recortar) ---')
        ..writeln(fullBody)
        ..writeln()
        ..writeln('=== HTTP RESPONSE ===')
        ..writeln('Status    : $status${durationMs != null ? "  (${durationMs}ms)" : ""}');
      if (err != null) buf.writeln('Error     : ${err.type} - ${err.message}');
      buf
        ..writeln()
        ..writeln('--- Body ---')
        ..writeln(responseBody.isEmpty ? '(sin body)' : responseBody);

      await file.writeAsString(buf.toString());

      dev.log('Archivo guardado: ${file.path}', name: 'HTTP.FILE');
      dev.log(
        'En el cel: Archivos > Android > data > com.appXLStore > files > ${file.uri.pathSegments.last}',
        name: 'HTTP.FILE',
      );
      dev.log(
        'Via adb: & "C:\\Users\\Ext-Jaob.Sandoval\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe" pull "${file.path}" "%USERPROFILE%\\Downloads\\${file.uri.pathSegments.last}"',
        name: 'HTTP.FILE',
      );
    } on Object catch (e) {
      dev.log('Error guardando archivo: $e', name: 'HTTP.FILE');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers de serialización
  // ---------------------------------------------------------------------------

  static String _toJson(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } on Object {
      return data.toString();
    }
  }

  static String _bodyWithTruncatedBase64(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    try {
      final truncated = (data is Map)
          ? data.map((k, v) {
              final key = k.toString().toLowerCase();
              if (v is String &&
                  v.length > 200 &&
                  (key.contains('base64') ||
                      key.contains('imagen') ||
                      key == 'image' ||
                      key == 'img')) {
                return MapEntry(
                  k,
                  '${v.substring(0, 80)}... [BASE64 - total: ${v.length} chars]',
                );
              }
              return MapEntry(k, v);
            })
          : data;
      return const JsonEncoder.withIndent('  ').convert(truncated);
    } on Object {
      return data.toString();
    }
  }

  static String _bodyToString(dynamic data) {
    if (data == null) return '';
    if (data is String) return _sanitizeBody(data);
    try {
      return _sanitizeBody(const JsonEncoder.withIndent('  ').convert(data));
    } on Object {
      return _sanitizeBody(data.toString());
    }
  }

  static String _sanitizeBody(String text) {
    var out = _redactXmlTag(text, 'Password');
    out = _redactXmlTag(out, 'password');
    out = out.replaceAll(RegExp(r'"Password"\s*:\s*"[^"]*"'), '"Password": "***"');
    out = out.replaceAll(RegExp(r'"password"\s*:\s*"[^"]*"'), '"password": "***"');
    return out;
  }

  static String _redactXmlTag(String xml, String tag) {
    final open = '<$tag>';
    final close = '</$tag>';
    final start = xml.indexOf(open);
    if (start < 0) return xml;
    final end = xml.indexOf(close, start);
    if (end < 0) return xml;
    return '${xml.substring(0, start + open.length)}***${xml.substring(end)}';
  }

  static String _categoryFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('loginregistrar') || lower.contains('login.asmx')) return 'AUTH';
    if (lower.contains('consultartoken')) return 'OTP';
    if (lower.contains('apixlmovil')) return 'PRODUCTS';
    if (lower.contains('configuracion')) return 'CONFIG';
    if (lower.contains('/auth/')) return 'AUTH';
    if (lower.contains('/otp/')) return 'OTP';
    return 'HTTP';
  }

  static Map<String, String> _headersForLog(Map<String, dynamic> headers) {
    final out = <String, String>{};
    headers.forEach((key, value) {
      final k = key.toString();
      out[k] = k.toLowerCase() == 'authorization' ? '(redactado)' : (value?.toString() ?? '');
    });
    return out;
  }

  /// Extrae y formatea el JSON dentro de un tag *Result de respuesta SOAP.
  static String? _extractSoapResultJson(String xmlOrText) {
    if (xmlOrText.isEmpty) return null;
    final match = RegExp(
      r'<(\w+Result)[^>]*>([\s\S]*?)</\1>',
      caseSensitive: false,
    ).firstMatch(xmlOrText);
    if (match == null) return null;

    var inner = match.group(2)?.trim() ?? '';
    if (inner.isEmpty) return null;

    // Algunos ASMX escapan el JSON como entidades XML.
    inner = inner
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');

    try {
      final decoded = jsonDecode(inner);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } on Object {
      return inner;
    }
  }

  /// Si el JSON incluye debug_openai (API con OpenAI:IncludeDebugInResponse=true),
  /// lo imprime aparte para ver la llamada intermedia.
  static void _logOpenAiDebugFromJson(String prettyJson) {
    try {
      final decoded = jsonDecode(prettyJson);
      if (decoded is! Map) return;
      final debug = decoded['debug_openai'];
      if (debug == null) return;

      dev.log(
        const JsonEncoder.withIndent('  ').convert(debug),
        name: 'OpenAI.DEBUG',
      );
    } on Object {
      // ignore
    }
  }
}
