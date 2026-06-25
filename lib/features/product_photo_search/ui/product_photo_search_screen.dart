import 'dart:io';

import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/product_photo_search/data/product_photo_search_repository.dart';
import 'package:exel_ott/features/product_photo_search/domain/detected_product_match.dart';
import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/product_photo_search/ui/detected_products_pager.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

enum _SearchStep { capture, analyzing, result }

/// Descripción de cada slot de foto.
final _slots = [
  (label: 'Frente / etiqueta', icon: Icons.photo_camera_outlined, hint: 'Foto principal con código o nombre visible'),
  (label: 'Reverso / otro lado', icon: Icons.flip_outlined, hint: 'Otro ángulo del producto'),
  (label: 'Ángulo lateral', icon: Icons.view_in_ar_outlined, hint: 'Vista adicional'),
];

class ProductPhotoSearchScreen extends StatefulWidget {
  const ProductPhotoSearchScreen({super.key, required this.repository});

  final ProductPhotoSearchRepository repository;

  @override
  State<ProductPhotoSearchScreen> createState() => _ProductPhotoSearchScreenState();
}

class _ProductPhotoSearchScreenState extends State<ProductPhotoSearchScreen> {
  final _picker = ImagePicker();
  _SearchStep _step = _SearchStep.capture;

  // Hasta 3 fotos. El índice 0 es obligatorio.
  final List<String?> _photos = [null, null, null];

  String? _error;
  PhotoIdentificationResponse? _photoResponse;
  List<DetectedProductMatch> _detectedProducts = const [];
  int _activeDetectionIndex = 0;
  int _quantity = 1;
  bool _addingToCart = false;
  bool _addedToCart = false;

  bool get _canAnalyze => _photos[0] != null;

  ProductCard? get _selected {
    if (_detectedProducts.isEmpty) return null;
    final index = _activeDetectionIndex.clamp(0, _detectedProducts.length - 1);
    return _detectedProducts[index].selected;
  }

  Future<void> _pickPhoto(int slot, ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (file == null) return;
      setState(() {
        _photos[slot] = file.path;
        _error = null;
      });
    } on Object catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    }
  }

  void _showPhotoSourceDialog(int slot) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () { Navigator.pop(ctx); _pickPhoto(slot, ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () { Navigator.pop(ctx); _pickPhoto(slot, ImageSource.gallery); },
            ),
            if (_photos[slot] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Quitar foto', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photos[slot] = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    final filePaths = _photos.whereType<String>().toList();
    setState(() { _step = _SearchStep.analyzing; _error = null; });

    try {
      final result = await widget.repository.identifyAndSearch(filePaths);
      if (!mounted) return;
      setState(() {
        _step = _SearchStep.result;
        _photoResponse = result.response;
        _detectedProducts = result.detected;
        _activeDetectionIndex = 0;
        _quantity = 1;
        _addedToCart = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() { _step = _SearchStep.capture; _error = friendlyErrorMessage(e); });
    }
  }

  Future<void> _addToCart() async {
    final product = _selected;
    if (product == null) return;
    setState(() { _addingToCart = true; _error = null; });
    try {
      final ok = await widget.repository.agregarAlCarrito(
        idProducto: product.idProducto,
        cantidad: _quantity,
      );
      if (!mounted) return;
      setState(() { _addingToCart = false; _addedToCart = ok; });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agregado al carrito')),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() { _addingToCart = false; _error = friendlyErrorMessage(e); });
    }
  }

  void _reset() {
    setState(() {
      _step = _SearchStep.capture;
      _photos.fillRange(0, 3, null);
      _photoResponse = null;
      _detectedProducts = const [];
      _activeDetectionIndex = 0;
      _error = null;
      _addedToCart = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppMeshBackground(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildBody(context),
              ),
            ),
            if (_step == _SearchStep.capture)
              _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_step) {
      _SearchStep.analyzing => _buildLoading(),
      _SearchStep.result    => _buildResult(context),
      _                     => _buildCapture(context),
    };
  }

  // ── Captura ────────────────────────────────────────────────────────────────

  Widget _buildCapture(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Buscar producto por foto',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Toma hasta 3 fotos del producto desde distintos ángulos. '
          'Con la foto frontal suele ser suficiente.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Slots de fotos
        ...List.generate(3, (i) => _buildPhotoSlot(context, i)),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _buildPhotoSlot(BuildContext context, int slot) {
    final theme = Theme.of(context);
    final photoPath = _photos[slot];
    final info = _slots[slot];
    final isRequired = slot == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => _showPhotoSourceDialog(slot),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Container(
          height: photoPath != null ? 140 : 88,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            border: Border.all(
              color: photoPath != null
                  ? AppColors.catalogAccent.withValues(alpha: 0.5)
                  : isRequired
                      ? AppColors.borderLight
                      : AppColors.borderLight.withValues(alpha: 0.5),
              width: photoPath != null ? 2 : 1,
            ),
          ),
          child: photoPath != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDecorations.radiusLg - 2),
                      child: Image.file(File(photoPath), fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          info.label,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      info.icon,
                      size: 32,
                      color: isRequired ? AppColors.catalogAccent : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                info.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isRequired ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                              if (isRequired) ...[
                                const SizedBox(width: 4),
                                const Text(
                                  '(requerida)',
                                  style: TextStyle(fontSize: 11, color: AppColors.catalogAccent),
                                ),
                              ] else ...[
                                const SizedBox(width: 4),
                                const Text(
                                  '(opcional)',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            info.hint,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                    const SizedBox(width: 16),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: FilledButton.icon(
        onPressed: _canAnalyze ? _analyze : null,
        icon: const Icon(Icons.image_search),
        label: const Text('Identificar producto'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    final count = _photos.whereType<String>().length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            count == 1
                ? 'Analizando foto con IA…'
                : 'Analizando $count fotos con IA…',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Primero intenta con el modelo rápido.\nSi no detecta nada, escala al modelo avanzado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _onActiveDetectionChanged(int index) {
    setState(() {
      _activeDetectionIndex = index;
      _quantity = 1;
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

  // ── Resultado ──────────────────────────────────────────────────────────────

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final response = _photoResponse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        ),

        if (_selected != null) ...[
          Row(
            children: [
              const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantity', style: theme.textTheme.titleMedium),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addingToCart || _addedToCart ? null : _addToCart,
            icon: _addingToCart
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_addedToCart ? Icons.check : Icons.shopping_cart_outlined),
            label: Text(
              _addedToCart ? 'Agregado al carrito' : 'Agregar al carrito',
            ),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (_addedToCart) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push('/home/cart'),
              child: const Text('Ver carrito'),
            ),
          ],
        ],

        if (_error != null) ...[
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
}
