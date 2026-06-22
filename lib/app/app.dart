import 'package:exel_ott/app/app_router.dart';
import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_config_gate_controller.dart';
import 'package:exel_ott/core/debug/debug_terminal_overlay.dart';
import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/ui/force_update_screen.dart';
import 'package:exel_ott/core/ui/maintenance_screen.dart';
import 'package:exel_ott/core/notifications/local_notifications_service.dart';
import 'package:exel_ott/core/notifications/push_notification_service.dart';
import 'package:exel_ott/features/auth/data/auth_api_repository.dart';
import 'package:exel_ott/features/auth/data/auth_exel_repository.dart';
import 'package:exel_ott/features/auth/data/auth_mock_repository.dart';
import 'package:exel_ott/features/auth/domain/auth_repository.dart';
import 'package:exel_ott/features/otp/data/otp_api_repository.dart';
import 'package:exel_ott/features/otp/data/otp_exel_repository.dart';
import 'package:exel_ott/features/otp/data/otp_mock_repository.dart';
import 'package:exel_ott/features/otp/domain/otp_repository.dart';
import 'package:exel_ott/core/theme/app_theme.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/product_photo_search/data/product_photo_search_repository.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_from_photo_repository.dart';
import 'package:exel_ott/features/visual_scan/data/visual_scan_repository.dart';
import 'package:exel_ott/core/permissions/image_scan_permission_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExelOttApp extends StatefulWidget {
  const ExelOttApp({super.key});

  @override
  State<ExelOttApp> createState() => _ExelOttAppState();
}

class _ExelOttAppState extends State<ExelOttApp> {
  late final AppConfigGateController _configGate;
  late final SessionStore _sessionStore;
  late final AuthController _authController;
  late final LocalNotificationsService _notifications;

  late final AuthRepository _authRepository;
  late final OtpRepository _otpRepository;
  late final ProductsRepository _productsRepository;
  late final CartRepository _cartRepository;
  late final QuoteFromPhotoRepository _quoteFromPhotoRepository;
  late final ProductPhotoSearchRepository _productPhotoSearchRepository;
  late final VisualScanRepository _visualScanRepository;
  late final ImageScanPermissionService _imageScanPermissionService;

  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _configGate = AppConfigGateController();
    _configGate.evaluate();
    _sessionStore = SessionStore();
    _notifications = LocalNotificationsService();

    _authRepository = AppConfig.useMockApi
        ? AuthMockRepository()
        : AppConfig.useExelAuth
            ? AuthExelRepository(sessionStore: _sessionStore)
            : AuthApiRepository(sessionStore: _sessionStore);

    _otpRepository = AppConfig.useMockApi
        ? OtpMockRepository()
        : AppConfig.useExelAuth
            ? OtpExelRepository(sessionStore: _sessionStore)
            : OtpApiRepository(sessionStore: _sessionStore);

    _productsRepository = ProductsRepository(sessionStore: _sessionStore);
    _cartRepository = CartRepository(
      sessionStore: _sessionStore,
      productsRepository: _productsRepository,
    );
    _quoteFromPhotoRepository = QuoteFromPhotoRepository(
      sessionStore: _sessionStore,
      productsRepository: _productsRepository,
      cartRepository: _cartRepository,
    );
    _productPhotoSearchRepository = ProductPhotoSearchRepository(
      sessionStore: _sessionStore,
      productsRepository: _productsRepository,
      cartRepository: _cartRepository,
    );
    _visualScanRepository = VisualScanRepository(
      sessionStore: _sessionStore,
      productPhotoSearchRepository: _productPhotoSearchRepository,
      quoteFromPhotoRepository: _quoteFromPhotoRepository,
    );
    _imageScanPermissionService = ImageScanPermissionService(
      sessionStore: _sessionStore,
    );

    _authController = AuthController(
      sessionStore: _sessionStore,
      authRepository: _authRepository,
    );

    _appRouter = AppRouter(
      authController: _authController,
      otpRepository: _otpRepository,
      notifications: _notifications,
      productsRepository: _productsRepository,
      cartRepository: _cartRepository,
      visualScanRepository: _visualScanRepository,
      imageScanPermissionService: _imageScanPermissionService,
    );

    _authController.addListener(_onAuthChanged);
    _bootstrap();
  }

  void _onAuthChanged() {
    if (!_authController.isSignedIn) {
      _imageScanPermissionService.reset();
      return;
    }
    if (!_imageScanPermissionService.loaded) {
      _imageScanPermissionService.refresh();
    }
  }

  Future<void> _bootstrap() async {
    await _notifications.init(
      onNotificationTap: (payload) {
        if (payload == kNotificationPayloadOpenOtp) {
          _appRouter.router.go('/home/otp');
        }
      },
    );
    await PushNotificationService.instance.configure(
      router: _appRouter.router,
      localNotifications: _notifications,
    );
    await _authController.loadFromStorage();
    if (_authController.isSignedIn) {
      await _imageScanPermissionService.refresh();
    }
    if (await _notifications.launchedFromOpenOtpTap()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appRouter.router.go('/home/otp');
      });
    }
    PushNotificationService.instance.consumePendingLaunchNavigation();
  }

  @override
  void dispose() {
    _configGate.dispose();
    _authController.removeListener(_onAuthChanged);
    _authController.dispose();
    super.dispose();
  }

  Widget _buildMainApp() {
    return MaterialApp.router(
      routerConfig: _appRouter.router,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: AppColors.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: DebugTerminalOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _configGate,
      builder: (context, _) {
        switch (_configGate.state) {
          case AppConfigGateState.loading:
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          case AppConfigGateState.maintenance:
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: MaintenanceScreen(
                message: _configGate.maintenanceMessage,
                isReloading: _configGate.isRefreshing,
                onReload: () => _configGate.evaluate(refreshRemote: true),
              ),
            );
          case AppConfigGateState.forceUpdate:
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: ForceUpdateScreen(
                appVersion: _configGate.appVersion,
                requiredVersion: _configGate.requiredVersion,
              ),
            );
          case AppConfigGateState.ready:
            return _buildMainApp();
        }
      },
    );
  }
}

