import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:exel_ott/core/notifications/local_notifications_service.dart';

/// Texto por defecto si el servidor no envía título/cuerpo en el payload `notification`.
abstract final class PushNotificationCopy {
  static const String productoRetenidoTitle = 'Producto retenido';
  static const String productoRetenidoBody =
      'Revise código para confirmación.';
}

/// Registro FCM, permisos y navegación al tocar la notificación (pantalla OTP).
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  GoRouter? _router;
  LocalNotificationsService? _local;
  bool _configured = false;
  bool _pendingOpenOtp = false;
  String? _cachedFcmToken;

  /// Llama tras [Firebase.initializeApp] y con el router ya creado.
  Future<void> configure({
    required GoRouter router,
    required LocalNotificationsService localNotifications,
  }) async {
    if (_configured) return;
    _configured = true;
    _router = router;
    _local = localNotifications;

    if (Firebase.apps.isEmpty) {
      debugPrint('PushNotificationService: Firebase no inicializado; FCM omitido.');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('PushNotificationService: permiso FCM = ${settings.authorizationStatus}');

    try {
      _cachedFcmToken = await messaging.getToken();
      debugPrint(
        'PushNotificationService: FCM token (para pruebas / backend): $_cachedFcmToken',
      );
    } on Object catch (e) {
      debugPrint('PushNotificationService: no se pudo leer FCM token: $e');
    }

    messaging.onTokenRefresh.listen((token) {
      _cachedFcmToken = token;
      debugPrint('PushNotificationService: FCM token actualizado');
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);

    final initial = await messaging.getInitialMessage();
    if (_shouldNavigateToOtp(initial)) {
      _pendingOpenOtp = true;
    }
  }

  /// Invocar al final del arranque (p. ej. tras restaurar sesión) para abrir OTP si el usuario abrió la app desde la notificación.
  void consumePendingLaunchNavigation() {
    if (!_pendingOpenOtp) return;
    _pendingOpenOtp = false;
    _goOtp();
  }

  bool _shouldNavigateToOtp(RemoteMessage? message) {
    if (message == null) return false;
    final type = message.data['type'] as String?;
    if (type == 'producto_retenido') return true;
    if (message.notification != null) return true;
    return false;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final local = _local;
    if (local == null) return;

    final n = message.notification;
    final title = n?.title ?? PushNotificationCopy.productoRetenidoTitle;
    final body = n?.body ?? PushNotificationCopy.productoRetenidoBody;

    await local.showProductRetainedNotification(title: title, body: body);
  }

  void _onOpenedFromBackground(RemoteMessage message) {
    if (_shouldNavigateToOtp(message)) {
      _goOtp();
    }
  }

  /// Token FCM actual (vacío si Firebase no está listo o el usuario denegó permisos).
  Future<String> getFcmToken() async {
    if (_cachedFcmToken != null && _cachedFcmToken!.isNotEmpty) {
      return _cachedFcmToken!;
    }
    if (Firebase.apps.isEmpty) return '';
    try {
      _cachedFcmToken = await FirebaseMessaging.instance.getToken();
      return _cachedFcmToken ?? '';
    } on Object {
      return '';
    }
  }

  void _goOtp() {
    final router = _router;
    if (router == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go('/home/otp');
    });
  }
}
