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

  /// ASMX base para login SOAP `LoginRegistrarToken` (fijo, no viene del JSON remoto).
  static const String loginRegistrarTokenSoapUrl =
      'https://www.exel.com.mx/APISeguridad/WS.asmx';

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

