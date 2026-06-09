import 'package:exel_ott/core/security/bff_request_token.dart';

/// Genera X-Request-Token por petición (sin caché).
class BffRequestTokenManager {
  BffRequestTokenManager._();

  static final BffRequestTokenManager instance = BffRequestTokenManager._();

  String getToken(String userId) => BffRequestToken.buildForUser(userId);

  /// Mismo resultado que [getToken]; útil tras 403 en reintentos.
  String refreshToken(String userId) => getToken(userId);

  void clear() {}
}
