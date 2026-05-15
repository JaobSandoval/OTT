// Reemplaza este archivo con el generado por FlutterFire:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Los valores de abajo son solo formato válido; hasta que configures tu proyecto,
// `Firebase.initializeApp` fallará y la app seguirá sin push (se captura en main.dart).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FCM web: añade la app web en Firebase y vuelve a ejecutar flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'FCM solo está pensado para Android/iOS en este proyecto.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBCfi62fvg_hcg4xTqejLP3KO1Phb4OVF0',
    appId: '1:420544796421:android:5e9e71a05ce1af13a0c96c',
    messagingSenderId: '420544796421',
    projectId: 'test-491ff',
    storageBucket: 'test-491ff.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYNPYWgx7WplbJvDtxQeO7yV6IVDzEefg',
    appId: '1:420544796421:ios:620825b44bd8239ca0c96c',
    messagingSenderId: '420544796421',
    projectId: 'test-491ff',
    storageBucket: 'test-491ff.firebasestorage.app',
    iosBundleId: 'com.exel.exelOtt',
  );

}