import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crashlytics + Analytics. Inicializar tras [Firebase.initializeApp].
class FirebaseMonitoringService {
  FirebaseMonitoringService._();

  static final FirebaseMonitoringService instance =
      FirebaseMonitoringService._();

  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  static FirebaseCrashlytics get crashlytics => FirebaseCrashlytics.instance;

  bool _configured = false;

  bool get isConfigured => _configured;

  Future<void> configure() async {
    if (_configured || Firebase.apps.isEmpty) return;

    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = crashlytics.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    await analytics.setAnalyticsCollectionEnabled(!kDebugMode);

    _configured = true;
  }

  Future<void> setSignedInUser({required String userId}) async {
    if (!_configured) return;
    await crashlytics.setUserIdentifier(userId);
    await analytics.setUserId(id: userId);
  }

  Future<void> clearSignedInUser() async {
    if (!_configured) return;
    await crashlytics.setUserIdentifier('');
    await analytics.setUserId(id: null);
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    if (!_configured) return;
    await analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> logLogin({String method = 'email'}) async {
    if (!_configured) return;
    await analytics.logLogin(loginMethod: method);
  }

  Future<void> logLoginFailed({required String reason}) async {
    await logEvent('login_failed', parameters: {'reason': _clip(reason, 100)});
  }

  Future<void> logLogout() async {
    await logEvent('logout');
  }

  Future<void> logOtpRequested() async {
    await logEvent('otp_requested');
  }

  Future<void> logOtpVerified() async {
    await logEvent('otp_verified');
  }

  Future<void> logPhotoSearchStarted({String source = 'visual_scan'}) async {
    await logEvent('photo_search_started', parameters: {'source': source});
  }

  Future<void> logPhotoSearchFailed({
    required String reason,
    String source = 'visual_scan',
  }) async {
    await logEvent('photo_search_failed', parameters: {
      'reason': _clip(reason, 100),
      'source': source,
    });
  }

  Future<void> logBarcodeScanned({String source = 'visual_scan'}) async {
    await logEvent('barcode_scanned', parameters: {'source': source});
  }

  Future<void> logViewItem({
    required String itemId,
    String? itemName,
  }) async {
    if (!_configured) return;
    await analytics.logViewItem(
      items: [
        AnalyticsEventItem(
          itemId: itemId,
          itemName: itemName != null ? _clip(itemName, 100) : null,
        ),
      ],
    );
  }

  Future<void> logAddToCart({
    required String itemId,
    required int quantity,
    String? itemName,
  }) async {
    if (!_configured) return;
    await analytics.logAddToCart(
      items: [
        AnalyticsEventItem(
          itemId: itemId,
          itemName: itemName != null ? _clip(itemName, 100) : null,
          quantity: quantity,
        ),
      ],
    );
  }

  Future<void> logApiError({
    required String endpoint,
    int? statusCode,
    required String errorType,
    int? durationMs,
  }) async {
    await logEvent('api_error', parameters: {
      'endpoint': _endpointSlug(endpoint),
      if (statusCode != null) 'status_code': statusCode,
      'error_type': _clip(errorType, 40),
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  Future<void> logConfigLoadFailed({
    required String source,
    required String reason,
  }) async {
    await logEvent('config_load_failed', parameters: {
      'source': source,
      'reason': _clip(reason, 100),
    });
  }

  Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_configured) return;
    await crashlytics.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  static String _clip(String value, int maxLen) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return trimmed.substring(0, maxLen);
  }

  static String _endpointSlug(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return _clip(url, 100);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return uri.host;
    if (segments.length >= 2) {
      return '${segments[segments.length - 2]}/${segments.last}';
    }
    return segments.last;
  }
}
