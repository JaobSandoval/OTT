import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:exel_ott/app/app.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/notifications/fcm_background.dart';
import 'package:exel_ott/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (e) {
    debugPrint('Firebase no disponible (ejecuta flutterfire configure): $e');
  }

  await AppRuntimeEndpoints.instance.load();
  runApp(const ExelOttApp());
}
