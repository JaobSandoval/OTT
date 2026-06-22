import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/config/app_version_compare.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppConfigGateState { loading, ready, maintenance, forceUpdate }

class AppConfigGateController extends ChangeNotifier {
  AppConfigGateState _state = AppConfigGateState.loading;
  String _maintenanceMessage = _defaultMaintenanceMessage;
  String _appVersion = '—';
  String _requiredVersion = '—';
  bool _isRefreshing = false;

  AppConfigGateState get state => _state;
  String get maintenanceMessage => _maintenanceMessage;
  String get appVersion => _appVersion;
  String get requiredVersion => _requiredVersion;
  bool get isRefreshing => _isRefreshing;

  static const _defaultMaintenanceMessage =
      'La aplicación se encuentra en mantenimiento. '
      'Favor de revisar más tarde.';

  Future<void> evaluate({bool refreshRemote = false}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();

    try {
      if (refreshRemote && !AppConfig.skipRemoteConfig) {
        await AppRuntimeEndpoints.instance.refreshRemoteConfig();
      }

      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      if (AppConfig.skipRemoteConfig) {
        _state = AppConfigGateState.ready;
        TechnicalLogStore.instance.info(
          'CONFIG',
          'Gate omitido (SKIP_REMOTE_CONFIG)',
        );
        return;
      }

      final endpoints = AppRuntimeEndpoints.instance;
      _requiredVersion = endpoints.configVersion ?? '—';

      if (endpoints.enMantenimiento) {
        _maintenanceMessage =
            endpoints.mensajeEnMantenimiento ?? _defaultMaintenanceMessage;
        _state = AppConfigGateState.maintenance;
        TechnicalLogStore.instance.info(
          'CONFIG',
          'App bloqueada: mantenimiento',
          fields: {'mensaje': _maintenanceMessage},
        );
        return;
      }

      final requiredVersion = endpoints.configVersion;
      if (isAppVersionOlderThanRequired(_appVersion, requiredVersion)) {
        _state = AppConfigGateState.forceUpdate;
        TechnicalLogStore.instance.info(
          'CONFIG',
          'App bloqueada: actualización requerida',
          fields: {
            'appVersion': _appVersion,
            'requiredVersion': requiredVersion ?? '(vacía)',
          },
        );
        return;
      }

      _state = AppConfigGateState.ready;
      TechnicalLogStore.instance.info(
        'CONFIG',
        'Gate aprobado',
        fields: {
          'appVersion': _appVersion,
          'configVersion': requiredVersion ?? '(vacía)',
        },
      );
    } on Object catch (e) {
      debugPrint('AppConfigGate evaluate error: $e');
      TechnicalLogStore.instance.error(
        'CONFIG',
        'Error evaluando gate de configuración',
        error: e.toString(),
      );
      _state = AppConfigGateState.ready;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
