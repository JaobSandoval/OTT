import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/features/cart/data/cart_api.dart';
import 'package:exel_ott/features/cart/domain/cart_item.dart';
import 'package:exel_ott/features/cart/domain/cart_operation_result.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';

class CartRepository {
  CartRepository({
    required SessionStore sessionStore,
    ProductsRepository? productsRepository,
    CartApi? api,
  })  : _sessionStore = sessionStore,
        _productsRepository = productsRepository,
        _api = api ?? CartApi();

  final SessionStore _sessionStore;
  final ProductsRepository? _productsRepository;
  final CartApi _api;
  final Map<String, double> _precioCache = {};

  Future<({int idUsuario, String password})> _credentials() async {
    await AppRuntimeEndpoints.instance.refreshRemoteConfig();

    final creds = await _sessionStore.readExelCredentials();
    if (creds == null) {
      throw Exception('Sesión incompleta. Vuelve a iniciar sesión.');
    }

    final ids = await _sessionStore.readExelSecurityIds();
    if (ids == null) {
      throw Exception('No se encontró el id de usuario. Inicia sesión de nuevo.');
    }

    final idUsuario = int.tryParse(ids.idUsuario);
    if (idUsuario == null || idUsuario <= 0) {
      throw Exception('Id de usuario inválido.');
    }

    return (idUsuario: idUsuario, password: creds.password);
  }

  Future<String?> readIdSucursalUsuario() async {
    final sucursal = await _sessionStore.readExelSucursal();
    if (sucursal == null || sucursal.idSucursal.isEmpty) return null;
    return sucursal.idSucursal;
  }

  /// Existencias con stock y localidad resuelta para agregar al carrito.
  List<({ExistenciaSucursal row, String locationId})> pickableLocations(
    ProductDetail detail,
    String? idSucursalUsuario,
  ) {
    final result = <({ExistenciaSucursal row, String locationId})>[];
    for (final row in detail.existencias) {
      final qty = parseStockQuantity(row.existencia) ?? 0;
      if (qty <= 0) continue;

      var locationId = row.idLocalidad.trim();
      if (locationId.isEmpty && row.esSucursalUsuario) {
        locationId = idSucursalUsuario?.trim() ?? '';
      }
      if (locationId.isEmpty) continue;

      result.add((row: row, locationId: locationId));
    }
    return result;
  }

  Future<CartOperationResult> agregarProducto({
    required String idProducto,
    required int cantidad,
    required String idLocalidad,
    String localidadNombre = '',
  }) async {
    if (localidadNombre.isNotEmpty) {
      await _sessionStore.rememberCartLocation(
        idLocalidad: idLocalidad,
        localidad: localidadNombre,
      );
    }

    final creds = await _credentials();
    final result = await _api.agregarProducto(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
      cantidad: cantidad,
      idLocalidad: idLocalidad,
    );
    if (result.ok) {
      await FirebaseMonitoringService.instance.logAddToCart(
        itemId: idProducto,
        quantity: cantidad,
      );
    }
    return result;
  }

  Future<List<CartItem>> consultaCarrito() async {
    final creds = await _credentials();
    final items = await _api.consultaCarrito(
      idUsuario: creds.idUsuario,
      password: creds.password,
    );
    return _enrichCartItems(items);
  }

  Future<List<CartItem>> _enrichCartItems(List<CartItem> items) async {
    if (items.isEmpty) return items;

    final locationNames = await _sessionStore.readCartLocationNames();
    final userSucursal = await _sessionStore.readExelSucursal();

    final enriched = <CartItem>[];
    for (final item in items) {
      final localidad = _resolveLocalidad(
        item: item,
        locationNames: locationNames,
        userSucursal: userSucursal,
      );
      final precio = await _resolvePrecioUnitario(item);
      enriched.add(
        item.copyWith(
          localidad: localidad,
          precioUnitario: precio > 0 ? precio : item.precioUnitario,
        ),
      );
    }
    return enriched;
  }

  Future<double> _resolvePrecioUnitario(CartItem item) async {
    if (item.precioUnitario > 0) return item.precioUnitario;

    final cached = _precioCache[item.idProducto];
    if (cached != null && cached > 0) return cached;

    final products = _productsRepository;
    if (products == null) return 0;

    try {
      final raw = await products.fetchPrecio(item.idProducto);
      final value = double.tryParse(raw?.replaceAll(',', '') ?? '') ?? 0;
      if (value > 0) _precioCache[item.idProducto] = value;
      return value;
    } on Object {
      return 0;
    }
  }

  String _resolveLocalidad({
    required CartItem item,
    required Map<String, String> locationNames,
    required ({String idSucursal, String sucursalNombre})? userSucursal,
  }) {
    if (item.localidad.isNotEmpty) return item.localidad;

    final fromCache = locationNames[item.idLocalidad];
    if (fromCache != null && fromCache.isNotEmpty) return fromCache;

    if (userSucursal != null &&
        item.idLocalidad.isNotEmpty &&
        item.idLocalidad == userSucursal.idSucursal &&
        userSucursal.sucursalNombre.isNotEmpty) {
      return userSucursal.sucursalNombre;
    }

    if (item.idLocalidad.isNotEmpty) {
      return 'Sucursal ${item.idLocalidad}';
    }

    return '';
  }

  Future<CartOperationResult> ajustarCantidad({
    required String idProducto,
    required String idLocalidad,
    required int delta,
  }) async {
    final creds = await _credentials();
    return _api.ajustarCantidad(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
      idLocalidad: idLocalidad,
      delta: delta,
    );
  }

  Future<CartOperationResult> establecerCantidad({
    required String idProducto,
    required String idLocalidad,
    required int cantidad,
  }) async {
    final creds = await _credentials();
    return _api.establecerCantidad(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
      idLocalidad: idLocalidad,
      cantidad: cantidad,
    );
  }

  static double computeSubtotal(List<CartItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.lineTotal);
  }
}
