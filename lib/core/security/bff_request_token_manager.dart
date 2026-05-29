import 'package:exel_ott/core/security/bff_request_token.dart';

/// Cache del X-Request-Token por usuario (renueva antes de expirar).
class BffRequestTokenManager {
  BffRequestTokenManager._();

  static final BffRequestTokenManager instance = BffRequestTokenManager._();

  static const _refreshBufferMs = 5000;

  String? _userId;
  String? _token;
  int _expiresAt = 0;

  String getToken(String userId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_userId == userId &&
        _token != null &&
        _token!.isNotEmpty &&
        _expiresAt - _refreshBufferMs > now) {
      return _token!;
    }

    _userId = userId;
    _token = BffRequestToken.buildForUser(userId);
    _expiresAt = BffRequestToken.expiresAtMs(userId);
    return _token!;
  }

  void clear() {
    _userId = null;
    _token = null;
    _expiresAt = 0;
  }
}
