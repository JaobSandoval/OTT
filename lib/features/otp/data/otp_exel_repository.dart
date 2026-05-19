import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/notifications/push_notification_service.dart';
import 'package:exel_ott/features/auth/data/login_registrar_token_api.dart';
import 'package:exel_ott/features/auth/data/login_registrar_token_response_parser.dart';
import 'package:exel_ott/features/otp/data/consultar_tokens_pendientes_api.dart';
import 'package:exel_ott/features/otp/data/consultar_tokens_pendientes_response_parser.dart';
import 'package:exel_ott/features/otp/domain/otp_code.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';

/// Producción Exel: consulta el último token pendiente vía `ConsultarTokensPendientes`.
class OtpExelRepository implements OtpRepository {
  OtpExelRepository({
    required SessionStore sessionStore,
    ConsultarTokensPendientesApi? consultarTokensApi,
    LoginRegistrarTokenApi? loginApi,
  })  : _sessionStore = sessionStore,
        _consultarTokensApi = consultarTokensApi ?? ConsultarTokensPendientesApi(),
        _loginApi = loginApi ?? LoginRegistrarTokenApi();

  final SessionStore _sessionStore;
  final ConsultarTokensPendientesApi _consultarTokensApi;
  final LoginRegistrarTokenApi _loginApi;

  static const _defaultTtl = Duration(minutes: 10);

  @override
  Future<OtpCode?> fetchCurrent() async {
    final ids = await _ensureSecurityIds();

    final tokens = await _consultarTokensApi.consultar(
      idCliente: ids.idCliente,
      idUsuario: ids.idUsuario,
    );

    if (tokens.isEmpty) return null;

    final latest = _latestToken(tokens);
    if (latest == null || latest.token.isEmpty) return null;

    return OtpCode(
      code: latest.token,
      expiresAt: _expiresAtFor(latest),
    );
  }

  /// Garantiza `IdCliente` (ej. MYL9997) e `IdUsuario` numérico (ej. 153264).
  Future<({String idCliente, String idUsuario})> _ensureSecurityIds() async {
    final stored = await _sessionStore.readExelSecurityIds();
    if (stored != null) return stored;

    final creds = await _sessionStore.readExelCredentials();
    if (creds == null) {
      throw Exception('Sesión incompleta. Vuelve a iniciar sesión.');
    }

    final fcmToken = await PushNotificationService.instance.getFcmToken();
    final login = await _loginApi.login(
      usuario: creds.usuario,
      password: creds.password,
      tokenFirebase: fcmToken,
    );
    final ids = LoginRegistrarTokenResponseParser.securityIds(login.profile);
    if (!ids.isComplete) {
      throw Exception(
        'No se obtuvo IdCliente del servidor. IdCliente="${ids.idCliente}", '
        'IdUsuario="${ids.idUsuario}".',
      );
    }

    await _sessionStore.writeExelSession(
      usuario: creds.usuario,
      password: creds.password,
      idCliente: ids.idCliente,
      idUsuario: ids.idUsuario,
    );

    return (idCliente: ids.idCliente, idUsuario: ids.idUsuario);
  }

  @override
  Future<OtpCode> rotateMock() {
    throw UnsupportedError('rotateMock no aplica en producción');
  }

  PendingToken? _latestToken(List<PendingToken> tokens) {
    if (tokens.isEmpty) return null;
    final sorted = List<PendingToken>.from(tokens)
      ..sort((a, b) {
        final da = a.fechaRegistro ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.fechaRegistro ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    return sorted.first;
  }

  DateTime _expiresAtFor(PendingToken token) {
    final validacion = token.fechaValidacion;
    if (validacion != null && validacion.isAfter(DateTime.now())) {
      return validacion;
    }
    final registro = token.fechaRegistro;
    if (registro != null) {
      return registro.add(_defaultTtl);
    }
    return DateTime.now().add(_defaultTtl);
  }
}
