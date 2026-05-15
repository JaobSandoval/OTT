import 'package:exel_ott/core/auth/session_store.dart';
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
      final result = await _authRepository.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      _token = result.token;
      _user = result.user;
      await _sessionStore.writeToken(result.token);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _sessionStore.clear();
    notifyListeners();
  }
}

