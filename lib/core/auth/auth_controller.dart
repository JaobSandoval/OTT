import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/core/security/bff_request_token_manager.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/auth/domain/user.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required SessionStore sessionStore,
    required AuthRepository authRepository,
  })  : _sessionStore = sessionStore,
        _authRepository = authRepository;

  final SessionStore _sessionStore;
  final AuthRepository _authRepository;

  bool _initialized = false;
  bool _loading = false;
  String? _token;
  User? _user;

  bool get initialized => _initialized;
  bool get isLoading => _loading;
  bool get isSignedIn => _token != null;
  User? get user => _user;

  Future<void> loadFromStorage() async {
    _token = await _sessionStore.readToken();
    if (_token != null) {
      _user = await _authRepository.getCurrentUser(token: _token!);
      final userKey = _user?.email.trim();
      if (userKey != null && userKey.isNotEmpty) {
        await FirebaseMonitoringService.instance.setSignedInUser(
          userId: userKey,
        );
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<String?> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      TechnicalLogStore.instance.info(
        'AUTH',
        'Inicio de login',
        fields: {'usuario': usernameOrEmail.trim()},
      );
      final result = await _authRepository.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      _token = result.token;
      _user = result.user;
      await _sessionStore.writeToken(result.token);
      final userKey = result.user.email.trim();
      if (userKey.isNotEmpty) {
        await FirebaseMonitoringService.instance.setSignedInUser(
          userId: userKey,
        );
      }
      await FirebaseMonitoringService.instance.logLogin();
      TechnicalLogStore.instance.info(
        'AUTH',
        'Login exitoso',
        fields: {
          'usuario': result.user.name,
          'tokenLocal': '${result.token.substring(0, result.token.length.clamp(0, 20))}…',
        },
      );
      return null;
    } catch (e) {
      final message = friendlyErrorMessage(e);
      await FirebaseMonitoringService.instance.logLoginFailed(reason: message);
      TechnicalLogStore.instance.error(
        'AUTH',
        'Login fallido (mensaje amigable al usuario)',
        error: message,
        fields: {'raw': e.toString()},
      );
      return message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    BffRequestTokenManager.instance.clear();
    await FirebaseMonitoringService.instance.logLogout();
    await FirebaseMonitoringService.instance.clearSignedInUser();
    await _sessionStore.clear();
    notifyListeners();
  }
}

