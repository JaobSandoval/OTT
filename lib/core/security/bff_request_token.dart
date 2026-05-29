import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:exel_ott/core/config/app_config.dart';

/// Firma X-Request-Token (mismo esquema que chatxlstore `buildClientToken`).
/// Formato: `{window}.{hmac_hex}` con message `client|{userId}|{window}`.
class BffRequestToken {
  BffRequestToken._();

  static const _windowMs = 30000;

  static String buildForUser(String userId) {
    final secret = AppConfig.appBffSigningSecret;
    if (secret.isEmpty) return '';

    final window = DateTime.now().millisecondsSinceEpoch ~/ _windowMs;
    final message = 'client|$userId|$window';
    final digest = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(message));
    final sig = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$window.$sig';
  }

  /// Timestamp ms hasta el que el token suele ser válido (~60 s).
  static int expiresAtMs(String userId) {
    final window = DateTime.now().millisecondsSinceEpoch ~/ _windowMs;
    return (window + 2) * _windowMs;
  }
}
