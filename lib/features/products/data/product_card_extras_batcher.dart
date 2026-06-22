import 'dart:async';
import 'dart:math' as math;

import 'package:exel_ott/features/products/data/apixlmovil_api.dart';
import 'package:exel_ott/features/products/data/apixlmovil_product_parsers.dart';

typedef ProductCardExtras = ({
  String sucursal,
  String nacional,
  String? precio,
  String? imageUrl,
});

typedef ProductCardExtrasFetchBatch = Future<void> Function(List<String> ids);
typedef ProductCardExtrasIsCached = bool Function(String id);

/// Precarga precio/existencia/imagen en bloques fijos de [batchSize] productos.
class ProductCardExtrasPrefetcher {
  ProductCardExtrasPrefetcher({
    required ApiXlMovilApi api,
    this.batchSize = 20,
    this.lookaheadItems = 5,
  }) : _api = api;

  final ApiXlMovilApi _api;
  final int batchSize;
  final int lookaheadItems;

  List<String> _orderedIds = const [];
  final Set<int> _loadedBatches = {};
  final Set<int> _loadingBatches = {};
  final Map<int, Completer<void>> _batchCompleters = {};

  ProductCardExtrasFetchBatch? _fetchBatch;
  ProductCardExtrasIsCached? _isCached;

  void reset() {
    _orderedIds = const [];
    _loadedBatches.clear();
    for (final completer in _batchCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Caché de productos reiniciada.'));
      }
    }
    _loadingBatches.clear();
    _batchCompleters.clear();
    _fetchBatch = null;
    _isCached = null;
  }

  Future<void> prepareList(
    List<String> orderedIds, {
    required ProductCardExtrasFetchBatch fetchBatch,
    required ProductCardExtrasIsCached isCached,
  }) async {
    _orderedIds = List<String>.from(orderedIds);
    _loadedBatches.clear();
    _loadingBatches.clear();
    _batchCompleters.clear();
    _fetchBatch = fetchBatch;
    _isCached = isCached;
    await ensureBatch(0);
  }

  void onItemVisible(int index) {
    if (_orderedIds.isEmpty || index < 0) return;

    final batch = index ~/ batchSize;
    unawaited(ensureBatch(batch));

    final positionInBatch = index % batchSize;
    if (positionInBatch >= batchSize - lookaheadItems) {
      unawaited(ensureBatch(batch + 1));
    }
  }

  Future<void> waitForProduct(String idProducto, {int? listIndex}) async {
    if (_isCached?.call(idProducto) ?? false) return;

    if (listIndex != null && _orderedIds.isNotEmpty) {
      onItemVisible(listIndex);
      await ensureBatch(listIndex ~/ batchSize);
      if (_isCached?.call(idProducto) ?? false) return;
    }

    await _fetchBatch?.call([idProducto]);
  }

  Future<void> ensureBatch(int batchIndex) async {
    if (batchIndex < 0 || _fetchBatch == null || _isCached == null) return;

    final start = batchIndex * batchSize;
    if (start >= _orderedIds.length) return;
    if (_loadedBatches.contains(batchIndex)) return;

    if (_loadingBatches.contains(batchIndex)) {
      return _batchCompleters[batchIndex]!.future;
    }

    _loadingBatches.add(batchIndex);
    final completer = Completer<void>();
    _batchCompleters[batchIndex] = completer;

    final end = math.min(start + batchSize, _orderedIds.length);
    final slice = _orderedIds.sublist(start, end);

    try {
      if (slice.every(_isCached!)) {
        _loadedBatches.add(batchIndex);
        completer.complete();
        return;
      }

      await _fetchBatch!(slice);
      _loadedBatches.add(batchIndex);
      completer.complete();
    } on Object catch (e, st) {
      _loadedBatches.add(batchIndex);
      completer.completeError(e, st);
    } finally {
      _loadingBatches.remove(batchIndex);
    }
  }

  Future<ProductCardExtras> fetchSingle({
    required String idProducto,
    required Future<({int idUsuario, String password})> Function() credentials,
    required Future<({String? idSucursal, String? sucursalNombre})> Function()
        readSucursal,
  }) async {
    final creds = await credentials();
    final sucursal = await readSucursal();
    final payload = await _api.productoPrecioExistencia(
      idUsuario: creds.idUsuario,
      password: creds.password,
      idProducto: idProducto,
    );
    final parsed = ApiXlMovilProductParsers.parseExistenciaSummaryBatch(
      payload,
      requestedIds: [idProducto],
      idLocalidadUsuario: sucursal.idSucursal,
      sucursalNombreUsuario: sucursal.sucursalNombre,
    );
    return parsed[idProducto]!;
  }
}
