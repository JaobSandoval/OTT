import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_android/image_picker_android.dart';
// Transitive via image_picker; needed to configure the registered Android implementation.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:exel_ott/app/app.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/core/notifications/fcm_background.dart';
import 'package:exel_ott/firebase_options.dart';

void _configureAndroidPhotoPicker() {
  if (!Platform.isAndroid) return;
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  _configureAndroidPhotoPicker();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseMonitoringService.instance.configure();
  } on Object catch (e) {
    debugPrint('Firebase no disponible (ejecuta flutterfire configure): $e');
  }

  await AppRuntimeEndpoints.instance.load();
  runApp(const ExelOttApp());
}
