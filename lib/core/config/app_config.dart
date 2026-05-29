class AppConfig {
  static const String appName = 'AppXLStore';

  /// Solo desarrollo local: `flutter run --dart-define=USE_MOCK_API=true`
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  /// Auth Exel vía `LoginRegistrarToken` (usuario + contraseña + dispositivo + FCM).
  /// Desactivar solo para probar el backend prototipo: `--dart-define=USE_EXEL_AUTH=false`
  static const bool useExelAuth = bool.fromEnvironment(
    'USE_EXEL_AUTH',
    defaultValue: true,
  );

  /// Si true, no carga configuracion.json remoto (útil en local).
  /// `flutter run --dart-define=SKIP_REMOTE_CONFIG=true`
  static const bool skipRemoteConfig = bool.fromEnvironment(
    'SKIP_REMOTE_CONFIG',
    defaultValue: false,
  );

  /// ASMX login SOAP. Producción por defecto; en local usa asset o `--dart-define=LOGIN_SOAP_URL=...`
  static const String loginRegistrarTokenSoapUrl = String.fromEnvironment(
    'LOGIN_SOAP_URL',
    defaultValue: 'https://www.exel.com.mx/APISeguridad/WS.asmx',
  );

  /// APIXLMovil (fallback si falla JSON remoto). Override: `--dart-define=API_XL_MOVIL_URL=...`
  /// En producción prevalece `urlApiXLMovil` del JSON remoto.
  static const String apiXlMovilAsmxUrl = String.fromEnvironment(
    'API_XL_MOVIL_URL',
    defaultValue: 'https://www.exel.com.mx/apiXLMovil/',
  );

  /// Secreto HMAC para X-Request-Token (debe coincidir con BffSigning.Secret en APIXLMovil).
  /// Override: `--dart-define=APP_BFF_SIGNING_SECRET=...`
  static const String appBffSigningSecret = String.fromEnvironment(
    'APP_BFF_SIGNING_SECRET',
    defaultValue:
        'ExelAppXLMovilBff_v1_a7f3c9e2b1d0486f9a0e5c8d3b7a1f4e6c2d9b0a8f5e3c1d7b9a4f2e8c0d6b3a1f5',
  );

  /// Id de aplicación Exel (OTT). Override opcional: `--dart-define=EXEL_ID_APLICACION=6`
  static const String exelIdAplicacion = String.fromEnvironment(
    'EXEL_ID_APLICACION',
    defaultValue: '6',
  );

  /// Valores por defecto si falta el JSON o una clave; también base para `--dart-define`.
  /// En runtime usa [AppRuntimeEndpoints] (tras `await` en `main`).
  static const String exelInfoUsuarioUrl = String.fromEnvironment(
    'EXEL_INFO_USUARIO_URL',
    defaultValue: 'https://xls.exel.mx:6983/AI/AI.asmx/InfoUsuario',
  );

  /// URL base del API (sin barra final). Se completa con el JSON remoto en runtime.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// JSON remoto (se carga al iniciar la app; el asset local solo rellena claves faltantes).
  static const String configuracionRemotaUrl = String.fromEnvironment(
    'CONFIGURACION_APP_URL',
    defaultValue:
        'https://www.exel.com.mx/AplicacionConfiguracion/appXLStore/configuracion.json',
  );
}

