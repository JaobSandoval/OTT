import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _tokenKey = 'access_token';
  static const _exelUsuarioKey = 'exel_usuario';
  static const _exelIdUsuarioKey = 'exel_id_usuario'; // migración
  static const _exelIdClienteKey = 'exel_id_cliente';
  static const _exelIdUsuarioNumericKey = 'exel_id_usuario_numeric';
  static const _exelPasswordKey = 'exel_password';
  static const _exelUserNameKey = 'exel_user_name';
  static const _exelUserEmailKey = 'exel_user_email';
  static const _exelUserRegionsKey = 'exel_user_regions';
  static const _exelIdSucursalKey = 'exel_id_sucursal';
  static const _exelSucursalNombreKey = 'exel_sucursal_nombre';
  static const _cartLocationNamesKey = 'cart_location_names';

  final FlutterSecureStorage _storage;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> writeExelSession({
    required String usuario,
    required String password,
    String? idCliente,
    String? idUsuario,
    String? userName,
    String? userEmail,
    String? userRegions,
    String? idSucursal,
    String? sucursalNombre,
  }) async {
    await _storage.write(key: _exelUsuarioKey, value: usuario);
    await _storage.write(key: _exelPasswordKey, value: password);
    if (idCliente != null && idCliente.isNotEmpty) {
      await _storage.write(key: _exelIdClienteKey, value: idCliente);
    }
    if (idUsuario != null && idUsuario.isNotEmpty) {
      await _storage.write(key: _exelIdUsuarioNumericKey, value: idUsuario);
    }
    if (userName != null) {
      await _storage.write(key: _exelUserNameKey, value: userName);
    }
    if (userEmail != null) {
      await _storage.write(key: _exelUserEmailKey, value: userEmail);
    }
    if (userRegions != null) {
      await _storage.write(key: _exelUserRegionsKey, value: userRegions);
    }
    if (idSucursal != null && idSucursal.isNotEmpty) {
      await _storage.write(key: _exelIdSucursalKey, value: idSucursal);
    }
    if (sucursalNombre != null && sucursalNombre.isNotEmpty) {
      await _storage.write(key: _exelSucursalNombreKey, value: sucursalNombre);
    }
  }

  Future<({String idSucursal, String sucursalNombre})?> readExelSucursal() async {
    final idSucursal = (await _storage.read(key: _exelIdSucursalKey))?.trim() ?? '';
    final sucursalNombre =
        (await _storage.read(key: _exelSucursalNombreKey))?.trim() ?? '';
    if (idSucursal.isEmpty && sucursalNombre.isEmpty) return null;
    return (idSucursal: idSucursal, sucursalNombre: sucursalNombre);
  }

  Future<Map<String, String>> readCartLocationNames() async {
    final raw = await _storage.read(key: _cartLocationNamesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } on Object {
      // Ignorar mapa corrupto.
    }
    return {};
  }

  Future<void> rememberCartLocation({
    required String idLocalidad,
    required String localidad,
  }) async {
    final id = idLocalidad.trim();
    final name = localidad.trim();
    if (id.isEmpty || name.isEmpty) return;

    final current = await readCartLocationNames();
    if (current[id] == name) return;

    current[id] = name;
    await _storage.write(
      key: _cartLocationNamesKey,
      value: jsonEncode(current),
    );
  }

  Future<({String usuario, String password})?> readExelCredentials() async {
    var usuario = await _storage.read(key: _exelUsuarioKey);
    if (usuario == null || usuario.isEmpty) {
      usuario = await _storage.read(key: _exelIdUsuarioKey);
    }
    final password = await _storage.read(key: _exelPasswordKey);
    if (usuario == null || password == null) return null;
    return (usuario: usuario, password: password);
  }

  Future<({String idCliente, String idUsuario})?> readExelSecurityIds() async {
    final idCliente = (await _storage.read(key: _exelIdClienteKey))?.trim() ?? '';
    final idUsuario =
        (await _storage.read(key: _exelIdUsuarioNumericKey))?.trim() ?? '';
    if (idCliente.isEmpty || idUsuario.isEmpty) return null;
    return (idCliente: idCliente, idUsuario: idUsuario);
  }

  Future<({String name, String email, String regions})?> readExelUserProfile() async {
    final name = await _storage.read(key: _exelUserNameKey);
    final email = await _storage.read(key: _exelUserEmailKey);
    final regions = await _storage.read(key: _exelUserRegionsKey);
    if (name == null && email == null && regions == null) return null;
    return (
      name: name ?? '',
      email: email ?? '',
      regions: regions ?? '',
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _exelUsuarioKey);
    await _storage.delete(key: _exelIdUsuarioKey);
    await _storage.delete(key: _exelIdClienteKey);
    await _storage.delete(key: _exelIdUsuarioNumericKey);
    await _storage.delete(key: _exelPasswordKey);
    await _storage.delete(key: _exelUserNameKey);
    await _storage.delete(key: _exelUserEmailKey);
    await _storage.delete(key: _exelUserRegionsKey);
    await _storage.delete(key: _exelIdSucursalKey);
    await _storage.delete(key: _exelSucursalNombreKey);
    await _storage.delete(key: _cartLocationNamesKey);
  }
}
