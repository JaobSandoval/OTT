import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Payload al tocar una notificación que debe abrir la pantalla de código (OTP).
const String kNotificationPayloadOpenOtp = 'open_otp';

/// Mismo id que [AndroidManifest] `com.google.firebase.messaging.default_notification_channel_id`.
const String kFcmAndroidNotificationChannelId = 'fcm_high_channel';

class LocalNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  void Function(String? payload)? _onNotificationTap;

  Future<void> init({void Function(String? payload)? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
    } catch (_) {
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      const channel = AndroidNotificationChannel(
        kFcmAndroidNotificationChannelId,
        'Confirmación y pedidos',
        description: 'Avisos del comercio (producto retenido, código, etc.)',
        importance: Importance.high,
      );
      await android?.createNotificationChannel(channel);

      await android?.requestNotificationsPermission();
    }

    if (!kIsWeb && Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    _onNotificationTap?.call(response.payload);
  }

  /// `true` si el usuario abrió la app tocando una notificación local con payload OTP.
  Future<bool> launchedFromOpenOtpTap() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return false;
      return details.notificationResponse?.payload == kNotificationPayloadOpenOtp;
    } catch (_) {
      return false;
    }
  }

  Future<void> showOtpAvailableNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      kFcmAndroidNotificationChannelId,
      'Códigos',
      channelDescription: 'Notificaciones cuando hay un código disponible',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    try {
      await _plugin.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: details,
        payload: kNotificationPayloadOpenOtp,
      );
    } catch (_) {}
  }

  /// Misma UX que FCM en foreground: título/cuerpo y al tocar abre OTP.
  Future<void> showProductRetainedNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      kFcmAndroidNotificationChannelId,
      'Confirmación y pedidos',
      channelDescription: 'Avisos del comercio (producto retenido, código, etc.)',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    try {
      await _plugin.show(
        id: 1002,
        title: title,
        body: body,
        notificationDetails: details,
        payload: kNotificationPayloadOpenOtp,
      );
    } catch (_) {}
  }
}
