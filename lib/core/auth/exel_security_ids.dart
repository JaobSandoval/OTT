/// `IdCliente` e `IdUsuario` numérico para `ConsultarTokensPendientes`.
class ExelSecurityIds {
  const ExelSecurityIds({
    required this.idCliente,
    required this.idUsuario,
  });

  final String idCliente;
  final String idUsuario;

  bool get isComplete => idCliente.isNotEmpty && idUsuario.isNotEmpty;
}

String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final v = map[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// Extrae IDs del perfil de `LoginRegistrarToken` (mapa normalizado o JSON).
ExelSecurityIds exelSecurityIdsFromProfile(Map<String, dynamic> map) {
  var idCliente = _pick(map, ['IdCliente', 'idCliente', 'id_cliente', 'IDCliente']);
  var idUsuario = _pick(map, ['Id_Usuario', 'IdUsuario', 'id_usuario', 'idUsuario']);

  final usuario = map['Usuario'];
  if (usuario is Map) {
    final u = Map<String, dynamic>.from(usuario);
    if (idUsuario.isEmpty) {
      idUsuario = _pick(u, ['Id_Usuario', 'IdUsuario', 'id_usuario', 'idUsuario']);
    }
    // No usar u['Usuario']: es el login (ej. MYL9997XL04254), no el id numérico.
  }

  return ExelSecurityIds(idCliente: idCliente, idUsuario: idUsuario);
}
