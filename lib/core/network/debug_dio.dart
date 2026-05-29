import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:exel_ott/core/debug/technical_log_entry.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:flutter/foundation.dart';

const _requestStartKey = '_techLogStart';

/// Crea un [Dio] con interceptor que escribe en [TechnicalLogStore] cuando está activo.
Dio createDebugDio({BaseOptions? baseOptions}) {
  final dio = Dio(baseOptions);
  _configureLocalDevCertificates(dio);
  dio.interceptors.add(TechnicalLogInterceptor());
  return dio;
}

/// En debug, acepta certificados autofirmados de IIS Express (localhost / LAN).
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
    final store = TechnicalLogStore.instance;
    if (store.isEnabled) {
      store.log(
        TechnicalLogEntry(
          timestamp: DateTime.now(),
          level: TechnicalLogLevel.request,
          category: _categoryFromUrl(options.uri.toString()),
          title: '${options.method} ${options.uri}',
          fields: _headersForLog(options.headers),
          body: _sanitizeBody(options.data),
        ),
      );
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
    handler.next(err);
  }

  void _logResponse(Response<dynamic>? response, DioException? err) {
    final store = TechnicalLogStore.instance;
    if (!store.isEnabled) return;

    final options = err?.requestOptions ?? response?.requestOptions;
    final started = options?.extra[_requestStartKey] as DateTime?;
    final durationMs = started != null
        ? DateTime.now().difference(started).inMilliseconds
        : null;

    final status = response?.statusCode ?? err?.response?.statusCode;
    final isError = err != null || (status != null && status >= 400);
    final body = _bodyToString(response?.data ?? err?.response?.data);

    store.log(
      TechnicalLogEntry(
        timestamp: DateTime.now(),
        level: isError ? TechnicalLogLevel.error : TechnicalLogLevel.response,
        category: _categoryFromUrl(options?.uri.toString() ?? ''),
        title: status != null
            ? 'HTTP $status ${options?.method ?? ''} ${options?.uri ?? ''}'
            : 'Error de red ${options?.uri ?? ''}',
        statusCode: status,
        durationMs: durationMs,
        body: body.isEmpty ? null : body,
        error: err != null ? '${err.type}: ${err.message}' : null,
        fields: err != null
            ? {
                if (err.type.name.isNotEmpty) 'dioType': err.type.name,
              }
            : null,
      ),
    );
  }

  static String _categoryFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('loginregistrar') || lower.contains('login.asmx')) {
      return 'AUTH';
    }
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
      if (k.toLowerCase() == 'authorization') {
        out[k] = '(redactado)';
      } else {
        out[k] = value?.toString() ?? '';
      }
    });
    return out;
  }

  static String _bodyToString(dynamic data) {
    if (data == null) return '';
    if (data is String) return _sanitizeBody(data);
    return _sanitizeBody(data.toString());
  }

  static String _sanitizeBody(dynamic data) {
    if (data == null) return '';
    var text = data is String ? data : data.toString();
    text = _redactXmlTag(text, 'Password');
    text = _redactXmlTag(text, 'password');
    return text;
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
}
