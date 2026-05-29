/// Credenciales ocultas para activar la terminal de debug en login.
abstract final class DebugTerminalGate {
  static const username = 'Terminal123';
  static const password = 'Terminal123';

  static bool matches({required String user, required String pass}) {
    return user == username && pass == password;
  }
}
