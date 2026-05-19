import 'package:dio/dio.dart';

const _generic =
    'Ocurrió un problema. Intenta de nuevo o más tarde.';

/// Mensaje único ante fallo de acceso (no indica si falló usuario o contraseña).
const kInvalidCredentialsMessage = 'Usuario o contraseña incorrectos.';

/// Convierte errores técnicos en mensajes claros para el usuario.
String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    return _fromDio(error);
  }

  final raw = _stripExceptionPrefix(error.toString()).trim();
  if (raw.isEmpty) return _generic;

  final lower = raw.toLowerCase();

  if (_hintsInvalidCredentials(lower)) {
    return kInvalidCredentialsMessage;
  }

  if (_looksLikeUserMessage(raw)) return raw;

  if (lower.contains('sesión incompleta') || lower.contains('vuelve a iniciar sesión')) {
    return 'Tu sesión expiró. Vuelve a iniciar sesión.';
  }
  if (lower.contains('ingresa tu usuario')) {
    return 'Ingresa tu usuario.';
  }
  if (lower.contains('credenciales inválidas') || lower.contains('incorrect')) {
    return kInvalidCredentialsMessage;
  }
  if (lower.contains('idcliente') || lower.contains('idusuario')) {
    return 'No se pudo verificar tu cuenta. Cierra sesión e ingresa de nuevo.';
  }
  if (lower.contains('no se obtuvo idcliente')) {
    return 'No se pudo verificar tu cuenta. Cierra sesión e ingresa de nuevo.';
  }
  if (lower.contains('loginregistrartoken')) {
    if (lower.contains('credenciales') || lower.contains('rechazado')) {
      return kInvalidCredentialsMessage;
    }
    if (lower.contains('vacía') || lower.contains('vacia')) {
      return 'El servidor no respondió. Intenta más tarde.';
    }
    if (lower.contains('formato')) {
      return 'No pudimos validar tu acceso. Intenta de nuevo.';
    }
    return kInvalidCredentialsMessage;
  }
  if (lower.contains('consultartokens') || lower.contains('consultartoken')) {
    if (lower.contains('vacía') || lower.contains('vacia')) {
      return 'No hay respuesta del servidor. Intenta más tarde.';
    }
    return 'No se pudo obtener el código. Intenta de nuevo.';
  }
  if (lower.contains('no se pudo conectar') && lower.contains('login')) {
    return 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';
  }
  if (lower.contains('no se pudo consultar el código')) {
    return 'No se pudo obtener el código. Revisa tu conexión e intenta de nuevo.';
  }
  if (lower.contains('error en el servidor') ||
      lower.contains('error al consultar') ||
      RegExp(r'\(\d{3}\)').hasMatch(raw)) {
    return 'El servicio no está disponible. Intenta más tarde.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out') ||
      lower.contains('timeout')) {
    return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
  }
  if (lower.contains('xml') || lower.contains('soap') || lower.contains('fault')) {
    return _generic;
  }

  return _generic;
}

String _fromDio(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'La conexión tardó demasiado. Intenta de nuevo.';
    case DioExceptionType.connectionError:
      return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
    case DioExceptionType.badResponse:
      final data = error.response?.data;
      if (data is String && data.trim().isNotEmpty) {
        return friendlyErrorMessage(Exception(data));
      }
      if (data is Map) {
        final msg = data['message'] ?? data['detail'] ?? data['error'];
        if (msg != null) {
          final text = msg.toString().trim();
          if (text.isNotEmpty && _looksLikeUserMessage(text)) return text;
        }
      }
      return 'El servicio no está disponible. Intenta más tarde.';
    case DioExceptionType.cancel:
      return 'La operación se canceló.';
    default:
      return _generic;
  }
}

String _stripExceptionPrefix(String text) {
  return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
}

/// Mensajes del servidor (`MensajeError`) u otros ya legibles.
bool _looksLikeUserMessage(String message) {
  if (message.length > 280) return false;

  final lower = message.toLowerCase();
  const technical = [
    'loginregistrartoken',
    'consultartokens',
    'consultartoken',
    'exception',
    'dioexception',
    'stacktrace',
    'soap:',
    'faultcode',
    'faultstring',
    'idcliente',
    'idusuario',
    'xmlns',
    '<',
    '>',
  ];
  for (final token in technical) {
    if (lower.contains(token)) return false;
  }

  if (RegExp(r'error\s+(en|al)\s+').hasMatch(lower) &&
      RegExp(r'\(\d{3}\)').hasMatch(message)) {
    return false;
  }

  return true;
}

/// Detecta mensajes del servidor que revelan si falló usuario o contraseña.
bool _hintsInvalidCredentials(String lower) {
  if (lower.contains('usuario o contraseña') ||
      lower.contains('usuario y contraseña')) {
    return true;
  }

  const failureWords = [
    'incorrect',
    'inválid',
    'invalid',
    'no existe',
    'no encontr',
    'erróne',
    'errone',
    'no coincide',
    'no válid',
    'no valid',
    'falló',
    'fallo',
    'denegad',
    'rechazad',
  ];

  const usuarioHints = ['usuario', 'user ', 'username', 'cuenta'];
  const passwordHints = ['contraseña', 'password', 'clave de acceso', ' clave '];

  var mentionsUsuario = false;
  var mentionsPassword = false;
  for (final hint in usuarioHints) {
    if (lower.contains(hint)) mentionsUsuario = true;
  }
  for (final hint in passwordHints) {
    if (lower.contains(hint)) mentionsPassword = true;
  }

  final hasFailureWord = failureWords.any(lower.contains);
  if (hasFailureWord && (mentionsUsuario || mentionsPassword)) {
    return true;
  }

  if (lower.contains('credencial') && hasFailureWord) return true;
  if (lower.contains('autentic') && hasFailureWord) return true;
  if (lower.contains('iniciar sesión') &&
      (hasFailureWord || lower.contains('no se pudo') || lower.contains('verifica'))) {
    return true;
  }
  if (lower.contains('verifica tus datos')) return true;
  if (lower.contains('acceso') && hasFailureWord) return true;

  return false;
}
