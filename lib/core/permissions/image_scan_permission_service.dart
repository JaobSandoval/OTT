import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/permissions/apixlmovil_image_scan_permission_client.dart';
import 'package:flutter/foundation.dart';

/// Permiso de escaneo/búsqueda por imagen (OpenAI) según el cliente.
class ImageScanPermissionService extends ChangeNotifier {
  ImageScanPermissionService({
    required SessionStore sessionStore,
    ApiXlMovilImageScanPermissionClient? client,
  })  : _sessionStore = sessionStore,
        _client = client ?? ApiXlMovilImageScanPermissionClient();

  final SessionStore _sessionStore;
  final ApiXlMovilImageScanPermissionClient _client;

  bool _loading = false;
  bool _loaded = false;
  bool _enabled = false;

  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get imageScanEnabled => _enabled;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      await AppRuntimeEndpoints.instance.refreshRemoteConfig();
      final creds = await _sessionStore.readExelCredentials();
      final ids = await _sessionStore.readExelSecurityIds();
      if (creds == null || ids == null) {
        _enabled = false;
        _loaded = true;
        return;
      }

      final idUsuario = int.tryParse(ids.idUsuario);
      if (idUsuario == null || idUsuario <= 0) {
        _enabled = false;
        _loaded = true;
        return;
      }

      _enabled = await _client.consultar(
        idUsuario: idUsuario,
        password: creds.password,
      );
      _loaded = true;
    } on Object {
      _enabled = false;
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _loading = false;
    _loaded = false;
    _enabled = false;
    notifyListeners();
  }
}
