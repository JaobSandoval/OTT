import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/notifications/push_notification_service.dart';
import 'package:exel_ott/features/auth/data/login_registrar_token_api.dart';
import 'package:exel_ott/features/auth/data/login_registrar_token_response_parser.dart';
import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/auth/domain/user.dart';

/// Autenticación Exel únicamente vía `LoginRegistrarToken` (usuario + contraseña + dispositivo + FCM).
class AuthExelRepository implements AuthRepository {
  AuthExelRepository({
    required SessionStore sessionStore,
    LoginRegistrarTokenApi? loginRegistrarTokenApi,
  })  : _sessionStore = sessionStore,
        _loginApi = loginRegistrarTokenApi ?? LoginRegistrarTokenApi();

  final SessionStore _sessionStore;
  final LoginRegistrarTokenApi _loginApi;

  static String _asString(Object? v) => v?.toString() ?? '';

  static String _canonicalUsuario(Map<String, dynamic> profile, {required String fallback}) {
    final fromServer = _asString(profile['Usuario'] ?? profile['usuario']);
    return fromServer.isNotEmpty ? fromServer : fallback;
  }

  static User _mapUser(Map<String, dynamic> row, {required String fallbackUsuario}) {
    var name = _asString(row['NombreCompleto'] ?? row['nombre'] ?? row['Nombre']);
    if (name.isEmpty) name = _asString(row['nombre_del_cliente'] ?? row['NombreDelCliente']);
    if (name.isEmpty) name = _asString(row['nombre_cliente'] ?? row['NombreCliente']);
    if (name.isEmpty) name = _asString(row['usuario'] ?? row['Usuario']);
    if (name.isEmpty) name = fallbackUsuario;

    final email = _asString(row['email'] ?? row['Email']);
    final idCliente = _asString(row['IdCliente']);
    final idLocalidad = _asString(row['IdLocalidad']);
    final suc = _asString(row['sucursal'] ?? row['Sucursal']);
    final idSuc = _asString(row['id_sucursal'] ?? row['IdSucursal']);
    final regions = [idLocalidad, idCliente, idSuc, suc]
        .where((e) => e.isNotEmpty)
        .toSet()
        .join(', ');

    return User(
      name: name,
      email: email,
      regions: regions.isEmpty ? '—' : regions,
    );
  }

  User _userFromProfileOrStored({
    required String usuario,
    Map<String, dynamic> profile = const {},
    ({String name, String email, String regions})? stored,
  }) {
    if (profile.isNotEmpty) {
      return _mapUser(profile, fallbackUsuario: usuario);
    }
    if (stored != null && stored.name.isNotEmpty) {
      return User(
        name: stored.name,
        email: stored.email,
        regions: stored.regions.isEmpty ? '—' : stored.regions,
      );
    }
    return User(name: usuario, email: '', regions: '—');
  }

  Future<LoginRegistrarTokenResult> _loginAndRegisterDevice({
    required String usuario,
    required String password,
  }) async {
    final fcmToken = await PushNotificationService.instance.getFcmToken();
    return _loginApi.login(
      usuario: usuario,
      password: password,
      tokenFirebase: fcmToken,
    );
  }

  @override
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final usuario = usernameOrEmail.trim();
    if (usuario.isEmpty) {
      throw Exception('Ingresa tu usuario.');
    }

    final result = await _loginAndRegisterDevice(usuario: usuario, password: password);
    final usuarioSesion = _canonicalUsuario(result.profile, fallback: usuario);
    final user = _userFromProfileOrStored(
      usuario: usuarioSesion,
      profile: result.profile,
    );

    final securityIds =
        LoginRegistrarTokenResponseParser.securityIds(result.profile);

    await _sessionStore.writeExelSession(
      usuario: usuarioSesion,
      password: password,
      idCliente: securityIds.idCliente,
      idUsuario: securityIds.idUsuario,
      userName: user.name,
      userEmail: user.email,
      userRegions: user.regions,
    );

    final token = 'exel_${usuarioSesion}_${DateTime.now().millisecondsSinceEpoch}';
    return AuthResult(token: token, user: user);
  }

  @override
  Future<User> getCurrentUser({required String token}) async {
    final creds = await _sessionStore.readExelCredentials();
    if (creds == null) {
      throw Exception('Sesión incompleta. Vuelve a iniciar sesión.');
    }

    final stored = await _sessionStore.readExelUserProfile();

    try {
      final result = await _loginAndRegisterDevice(
        usuario: creds.usuario,
        password: creds.password,
      );
      final user = _userFromProfileOrStored(
        usuario: creds.usuario,
        profile: result.profile,
        stored: stored,
      );
      final securityIds =
          LoginRegistrarTokenResponseParser.securityIds(result.profile);

      await _sessionStore.writeExelSession(
        usuario: creds.usuario,
        password: creds.password,
        idCliente: securityIds.idCliente,
        idUsuario: securityIds.idUsuario,
        userName: user.name,
        userEmail: user.email,
        userRegions: user.regions,
      );
      return user;
    } on Object {
      return _userFromProfileOrStored(
        usuario: creds.usuario,
        stored: stored,
      );
    }
  }
}
