import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Datos del dispositivo para [LoginRegistrarToken].
class DeviceRegistrationInfo {
  const DeviceRegistrationInfo({
    required this.plataforma,
    required this.modelo,
    required this.versionSo,
    required this.appVersion,
  });

  final String plataforma;
  final String modelo;
  final String versionSo;
  final String appVersion;

  static Future<DeviceRegistrationInfo> collect() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (kIsWeb) {
      return DeviceRegistrationInfo(
        plataforma: 'Web',
        modelo: 'Browser',
        versionSo: '',
        appVersion: appVersion,
      );
    }

    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await plugin.androidInfo;
      return DeviceRegistrationInfo(
        plataforma: 'Android',
        modelo: '${android.manufacturer} ${android.model}'.trim(),
        versionSo: android.version.release,
        appVersion: appVersion,
      );
    }

    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      return DeviceRegistrationInfo(
        plataforma: 'iOS',
        modelo: ios.utsname.machine,
        versionSo: ios.systemVersion,
        appVersion: appVersion,
      );
    }

    return DeviceRegistrationInfo(
      plataforma: Platform.operatingSystem,
      modelo: Platform.localHostname,
      versionSo: Platform.operatingSystemVersion,
      appVersion: appVersion,
    );
  }
}
