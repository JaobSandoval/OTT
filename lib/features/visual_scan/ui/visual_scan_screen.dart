import 'dart:io';

import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/currency_format.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/product_photo_search/domain/detected_product_match.dart';
import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/product_photo_search/ui/detected_products_pager.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_match_result.dart';
import 'package:exel_ott/features/quote_from_photo/ui/barcode_scanner_sheet.dart';
import 'package:exel_ott/features/visual_scan/data/visual_scan_repository.dart';
import 'package:exel_ott/features/visual_scan/domain/image_scan_classification.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

enum _ScanStep { capture, analyzing, searchResult, quoteReview, confirming, quoteSuccess }

const _maxPhotos = 3;

final _photoSlotHints = [
  'Foto principal con código o nombre visible',
  'Otro ángulo del producto o página de lista',
  'Vista adicional',
];

class VisualScanScreen extends StatefulWidget {
  const VisualScanScreen({
    super.key,
    required this.repository,
    required this.allowPhotoCapture,
    this.initialPhotos = const [],
    this.autoAnalyze = false,
    this.initialBarcode,
  });

  final VisualScanRepository repository;
  final bool allowPhotoCapture;
  final List<String> initialPhotos;
  final bool autoAnalyze;
  final String? initialBarcode;

  @override
  State<VisualScanScreen> createState() => _VisualScanScreenState();
}

class _VisualScanScreenState extends State<VisualScanScreen> {
  final _picker = ImagePicker();

  _ScanStep _step = _ScanStep.capture;
  final List<String> _photos = [];

  ImageScanClassification? _classification;
  String _loadingMessage = 'Analizando imagen…';
  String? _error;
  String? _eventId;
  String? _observaciones;
  double? _estimatedTotal;

  PhotoIdentificationResponse? _photoResponse;
  List<DetectedProductMatch> _detectedProducts = const [];
  int _activeDetectionIndex = 0;
  int _searchQuantity = 1;
  bool _addingToCart = false;
  bool _addedToCart = false;

  List<QuoteLineMatch> _matches = const [];
  QuoteConfirmResult? _confirmResult;

  bool get _canAnalyzePhotos => _photos.isNotEmpty;

  bool get _isLoadingStep =>
      _step == _ScanStep.analyzing || _step == _ScanStep.confirming;

  ProductCard? get _selectedProduct {
    if (_detectedProducts.isEmpty) return null;
    final index = _activeDetectionIndex.clamp(0, _detectedProducts.length - 1);
    return _detectedProducts[index].selected;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPhotos.isNotEmpty) {
      _photos.addAll(widget.initialPhotos.take(_maxPhotos));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
        _processBarcode(widget.initialBarcode!);
      } else if (widget.autoAnalyze && _photos.isNotEmpty) {
        _analyzePhotos();
      }
    });
  }

  Future<void> _processBarcode(String code) async {
    await FirebaseMonitoringService.instance.logBarcodeScanned();
    setState(() {
      _error = null;
      _confirmResult = null;
    });

    if (_step == _ScanStep.quoteReview) {
      final match = await widget.repository.searchByBarcode(code);
      if (!mounted) return;

      final updated = List<QuoteLineMatch>.from(_matches)..add(match);
      final total = await widget.repository.estimateTotal(updated);
      if (!mounted) return;

      setState(() {
        _matches = updated;
        _estimatedTotal = total;
        _eventId ??= widget.repository.newEventId();
      });
      return;
    }

    setState(() => _step = _ScanStep.analyzing);
    try {
      final match = await widget.repository.searchByBarcode(code);
      if (!mounted) return;
      final candidates = match.selected != null
          ? [match.selected!]
          : match.candidates;
      final searchError = candidates.isEmpty
          ? (match.searchError ?? 'Sin coincidencias para código escaneado')
          : null;
      if (searchError != null) {
        await FirebaseMonitoringService.instance.logPhotoSearchFailed(
          reason: searchError,
        );
      }
      setState(() {
        _step = _ScanStep.searchResult;
        _classification = null;
        _photoResponse = null;
        _detectedProducts = candidates.isEmpty
            ? const []
            : [
                DetectedProductMatch(
                  identification: ProductIdentificationResult(
                    nombre: 'Código escaneado',
                    marca: '',
                    sku: code,
                    categoria: '',
                    descripcion: '',
                    keywords: const [],
                    confianza: 'alta',
                  ),
                  candidates: candidates,
                  selected: match.selected ?? candidates.first,
                ),
              ];
        _activeDetectionIndex = 0;
        _searchQuantity = 1;
        _addedToCart = false;
        _error = searchError;
      });
    } on Object catch (e) {
      if (!mounted) return;
      final message = friendlyErrorMessage(e);
      await FirebaseMonitoringService.instance.logPhotoSearchFailed(
        reason: message,
      );
      setState(() {
        _step = _ScanStep.capture;
        _error = message;
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source, {int? replaceIndex}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (file == null) return;
      setState(() {
        if (replaceIndex != null && replaceIndex < _photos.length) {
          _photos[replaceIndex] = file.path;
        } else if (_photos.length < _maxPhotos) {
          _photos.add(file.path);
        }
        _error = null;
        _confirmResult = null;
      });
    } on Object catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    }
  }

  void _showPhotoSourceDialog({int? index}) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera, replaceIndex: index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery, replaceIndex: index);
              },
            ),
            if (index != null && index < _photos.length)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Quitar foto', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photos.removeAt(index));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerSheet.show(context);
    if (code == null || !mounted) return;
    await _processBarcode(code);
  }

  void _openProductDetail(ProductCard product) {
    context.push(
      '/home/products/detail/${product.idProducto}',
      extra: product,
    );
  }

  Future<void> _analyzePhotos() async {
    if (_photos.isEmpty) {
      setState(() => _error = 'Agrega al menos una foto o escanea un código.');
      return;
    }

    await FirebaseMonitoringService.instance.logPhotoSearchStarted();
    setState(() {
      _step = _ScanStep.analyzing;
      _error = null;
      _loadingMessage = 'Clasificando imagen…';
    });

    try {
      setState(() => _loadingMessage = 'Clasificando tipo de imagen…');
      final classification = await widget.repository.classifyImage(_photos.first);
      if (!mounted) return;

      if (classification.isDocumento) {
        setState(() => _loadingMessage = 'Extrayendo líneas de cotización…');
        _eventId ??= widget.repository.newEventId();
        final extraction =
            await widget.repository.extractFromImagePaths(_photos);
        final matches =
            await widget.repository.searchMatches(extraction.lineas);
        final total = await widget.repository.estimateTotal(matches);
        if (!mounted) return;
        setState(() {
          _step = _ScanStep.quoteReview;
          _classification = classification;
          _matches = matches;
          _observaciones = extraction.observaciones;
          _estimatedTotal = total;
        });
      } else {
        setState(() => _loadingMessage = 'Identificando productos…');
        final search = await widget.repository.identifyAndSearch(_photos);
        if (!mounted) return;
        setState(() {
          _step = _ScanStep.searchResult;
          _classification = classification;
          _photoResponse = search.response;
          _detectedProducts = search.detected;
          _activeDetectionIndex = 0;
          _searchQuantity = 1;
          _addedToCart = false;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      final message = friendlyErrorMessage(e);
      await FirebaseMonitoringService.instance.logPhotoSearchFailed(
        reason: message,
      );
      setState(() {
        _step = _ScanStep.capture;
        _error = message;
      });
    }
  }

  Future<void> _addSearchToCart() async {
    final product = _selectedProduct;
    if (product == null) return;
    setState(() {
      _addingToCart = true;
      _error = null;
    });
    try {
      final ok = await widget.repository.agregarAlCarrito(
        idProducto: product.idProducto,
        cantidad: _searchQuantity,
      );
      if (!mounted) return;
      setState(() {
        _addingToCart = false;
        _addedToCart = ok;
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agregado al carrito')),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _addingToCart = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _confirmQuote() async {
    final confirmed = _matches.where((m) => m.hasMatch).toList();
    if (confirmed.isEmpty) {
      setState(() => _error = 'Selecciona al menos un producto para cotizar.');
      return;
    }

    setState(() {
      _step = _ScanStep.confirming;
      _error = null;
    });

    try {
      final result = await widget.repository.confirmQuote(
        matches: _matches,
        idEvento: _eventId ?? widget.repository.newEventId(),
      );
      if (!mounted) return;
      setState(() {
        _step = _ScanStep.quoteSuccess;
        _confirmResult = result;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _ScanStep.quoteReview;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  void _updateLineQuantity(int index, int cantidad) {
    if (cantidad < 1) return;
    setState(() {
      final m = _matches[index];
      _matches[index] = m.copyWith(line: m.line.copyWith(cantidad: cantidad));
    });
  }

  void _selectProduct(int index, ProductCard product) {
    setState(() {
      final m = _matches[index];
      _matches[index] = m.copyWith(selected: product);
    });
    _refreshTotal();
  }

  Future<void> _refreshTotal() async {
    try {
      final total = await widget.repository.estimateTotal(_matches);
      if (mounted) setState(() => _estimatedTotal = total);
    } on Object {
      // ignore
    }
  }

  Future<void> _showCandidatePicker(int index) async {
    final match = _matches[index];
    if (match.candidates.length <= 1) return;

    final picked = await showModalBottomSheet<ProductCard>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Elegir producto',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: match.candidates.length,
                  itemBuilder: (context, i) {
                    final p = match.candidates[i];
                    return ListTile(
                      title: Text(p.descripcion),
                      subtitle: Text('${p.idProducto} · ${p.marca}'),
                      onTap: () => Navigator.pop(ctx, p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) _selectProduct(index, picked);
  }

  void _reset() {
    setState(() {
      _step = _ScanStep.capture;
      _photos.clear();
      _error = null;
      _photoResponse = null;
      _detectedProducts = const [];
      _activeDetectionIndex = 0;
      _matches = const [];
      _observaciones = null;
      _estimatedTotal = null;
      _confirmResult = null;
      _addedToCart = false;
      _classification = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppMeshBackground(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingStep
                  ? _buildLoading(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: _buildBody(context),
                    ),
            ),
            if (_step == _ScanStep.capture ||
                _step == _ScanStep.quoteReview ||
                (_step == _ScanStep.searchResult && _selectedProduct != null))
              _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_step) {
      _ScanStep.searchResult => _buildSearchResult(context),
      _ScanStep.quoteReview => _buildQuoteReview(context),
      _ScanStep.quoteSuccess => _buildQuoteSuccess(context),
      _ => _buildCapture(context),
    };
  }

  Widget _buildCapture(BuildContext context) {
    final theme = Theme.of(context);
    final allowPhoto = widget.allowPhotoCapture;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Buscar y cotizar',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          allowPhoto
              ? 'Toma o sube una foto y la IA detectará si es un producto '
                  'o una lista para cotizar. También puedes escanear un código.'
              : 'Escanea códigos de barras para buscar productos o armar una cotización.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        if (allowPhoto) ...[
          if (_photos.isEmpty)
            _buildEmptyPhotoPlaceholder(context)
          else
            ...List.generate(_photos.length, (i) => _buildPhotoTile(context, i)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ] else
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_scanner, size: 48),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _scanBarcode,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear código de barras'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyPhotoPlaceholder(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Center(
        child: Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildPhotoTile(BuildContext context, int index) {
    final path = _photos[index];
    final hint = _photoSlotHints[index.clamp(0, _photoSlotHints.length - 1)];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showPhotoSourceDialog(index: index),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            border: Border.all(color: AppColors.catalogAccent.withValues(alpha: 0.4), width: 2),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDecorations.radiusLg - 2),
                child: Image.file(File(path), fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Imagen ${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);

    if (_step == _ScanStep.searchResult && _selectedProduct != null) {
      return Material(
        elevation: 8,
        color: AppColors.cardWhite,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _selectedProduct!.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      onPressed: _searchQuantity > 1
                          ? () => setState(() => _searchQuantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text('$_searchQuantity', style: theme.textTheme.titleMedium),
                    IconButton(
                      onPressed: () => setState(() => _searchQuantity++),
                      icon: const Icon(Icons.add_circle_outline),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => _openProductDetail(_selectedProduct!),
                      child: const Text('Detalle'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addingToCart || _addedToCart ? null : _addSearchToCart,
                      icon: _addingToCart
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_addedToCart ? Icons.check : Icons.shopping_cart_outlined),
                      label: Text(_addedToCart ? 'Agregado' : 'Agregar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == _ScanStep.capture && widget.allowPhotoCapture)
            FilledButton.icon(
              onPressed: _canAnalyzePhotos ? _analyzePhotos : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analizar imagen'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            )
          else if (_step == _ScanStep.quoteReview) ...[
            FilledButton(
              onPressed: _confirmQuote,
              child: const Text('Registrar y agregar al carrito'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _reset,
              child: const Text('Nueva captura'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    final message = _step == _ScanStep.confirming
        ? 'Registrando cotización y agregando al carrito…'
        : _loadingMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_step == _ScanStep.analyzing) ...[
              const SizedBox(height: 8),
              Text(
                'Primero intenta con el modelo rápido.\n'
                'Si no detecta nada, escala al modelo avanzado.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onActiveDetectionChanged(int index) {
    setState(() {
      _activeDetectionIndex = index;
      _searchQuantity = 1;
      _addedToCart = false;
    });
  }

  void _selectCatalogProduct(int detectionIndex, ProductCard product) {
    setState(() {
      _activeDetectionIndex = detectionIndex;
      _detectedProducts = [
        for (var i = 0; i < _detectedProducts.length; i++)
          if (i == detectionIndex)
            _detectedProducts[i].copyWith(selected: product)
          else
            _detectedProducts[i],
      ];
      _addedToCart = false;
    });
  }

  Widget _buildSearchResult(BuildContext context) {
    final response = _photoResponse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_classification != null) ...[
          _InfoChip(
            label: _classification!.isProducto
                ? 'Detectado: producto'
                : 'Detectado: lista/cotización',
            icon: _classification!.isProducto
                ? Icons.inventory_2_outlined
                : Icons.description_outlined,
            color: AppColors.catalogAccent,
          ),
          const SizedBox(height: 12),
        ],
        if (response != null) ...[
          PhotoIdentificationInfoChips(
            response: response,
            detectedCount: _detectedProducts.length,
          ),
          const SizedBox(height: 16),
        ],

        DetectedProductsPager(
          detectedProducts: _detectedProducts,
          activeIndex: _activeDetectionIndex,
          onActiveIndexChanged: _onActiveDetectionChanged,
          onSelectCandidate: _selectCatalogProduct,
          onOpenDetail: _openProductDetail,
          showDetailedIdentification: true,
          emptyMessage: _error ?? 'No se detectaron productos en la imagen.',
          bottomPadding: _selectedProduct != null ? 80 : 0,
        ),

        if (_error != null && _detectedProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: AppColors.error)),
        ],

        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('Nueva búsqueda'),
        ),
      ],
    );
  }

  Widget _buildQuoteReview(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_classification != null) ...[
          _InfoChip(
            label: 'Detectado: lista/cotización',
            icon: Icons.description_outlined,
            color: AppColors.catalogAccent,
          ),
          const SizedBox(height: 12),
        ],
        if (_photos.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                child: Image.file(File(_photos[i]), width: 100, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_observaciones != null && _observaciones!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            ),
            child: Text(
              _observaciones!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        if (_estimatedTotal != null && _estimatedTotal! > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Total estimado: ${formatCurrency(_estimatedTotal)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.catalogAccent,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: AppSectionLabel(text: 'Líneas detectadas')),
            TextButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Añadir código'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_matches.length, (i) => _buildLineCard(context, i)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildLineCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final match = _matches[index];
    final line = match.line;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.texto,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (line.sku.isNotEmpty)
                        Text('Código: ${line.sku}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _QuantityStepper(
                  value: line.cantidad,
                  onChanged: (v) => _updateLineQuantity(index, v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (match.searching)
              const LinearProgressIndicator(minHeight: 2)
            else if (match.selected != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _openProductDetail(match.selected!),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    match.selected!.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.inventory_2),
                  ),
                ),
                title: Text(
                  match.selected!.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(match.selected!.idProducto),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (match.candidates.length > 1)
                      IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _showCandidatePicker(index),
                      ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.searchError ?? 'Sin coincidencias',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteSuccess(BuildContext context) {
    final theme = Theme.of(context);
    final result = _confirmResult;
    final config = AppRuntimeEndpoints.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 64, color: AppColors.catalogAccent),
        const SizedBox(height: 16),
        Text(
          'Cotización registrada',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (result != null)
          Text(
            '${result.addedCount} producto(s) agregados al carrito.'
            '${result.skippedLines > 0 ? ' ${result.skippedLines} línea(s) sin match.' : ''}'
            '${result.failedAdds > 0 ? ' ${result.failedAdds} no se pudieron agregar.' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.push('/home/cart'),
          child: const Text('Ver carrito'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => openInAppUrl(context, config.miCarritoUrl),
          child: const Text('Continuar en XLStore'),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: _reset, child: const Text('Nueva cotización')),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: Theme.of(context).textTheme.titleSmall),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
