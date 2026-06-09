import 'dart:io';

import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/quote_from_photo/data/quote_from_photo_repository.dart';
import 'package:exel_ott/features/quote_from_photo/domain/quote_match_result.dart';
import 'package:exel_ott/features/quote_from_photo/ui/barcode_scanner_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

enum _QuoteStep { capture, analyzing, review, confirming, success }

class QuoteFromPhotoScreen extends StatefulWidget {
  const QuoteFromPhotoScreen({
    super.key,
    required this.repository,
    required this.productsRepository,
    this.allowPhotoCapture = true,
  });

  final QuoteFromPhotoRepository repository;
  final ProductsRepository productsRepository;
  final bool allowPhotoCapture;

  @override
  State<QuoteFromPhotoScreen> createState() => _QuoteFromPhotoScreenState();
}

class _QuoteFromPhotoScreenState extends State<QuoteFromPhotoScreen> {
  final _picker = ImagePicker();
  _QuoteStep _step = _QuoteStep.capture;
  String? _imagePath;
  String? _error;
  String? _observaciones;
  String? _eventId;
  List<QuoteLineMatch> _matches = const [];
  double? _estimatedTotal;
  QuoteConfirmResult? _confirmResult;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
      _confirmResult = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
      if (file == null) return;
      setState(() {
        _imagePath = file.path;
        _step = _QuoteStep.capture;
        _matches = const [];
        _observaciones = null;
        _estimatedTotal = null;
      });
    } on Object catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    }
  }

  Future<void> _analyze() async {
    final path = _imagePath;
    if (path == null) {
      setState(() => _error = 'Selecciona o toma una foto primero.');
      return;
    }

    setState(() {
      _step = _QuoteStep.analyzing;
      _error = null;
      _eventId = widget.repository.newEventId();
    });

    try {
      final extraction = await widget.repository.extractFromImagePath(path);
      final matches = await widget.repository.searchMatches(extraction.lineas);
      final total = await widget.repository.estimateTotal(matches);
      if (!mounted) return;
      setState(() {
        _step = _QuoteStep.review;
        _matches = matches;
        _observaciones = extraction.observaciones;
        _estimatedTotal = total;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _QuoteStep.capture;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _confirm() async {
    final confirmed = _matches.where((m) => m.hasMatch).toList();
    if (confirmed.isEmpty) {
      setState(() => _error = 'Selecciona al menos un producto para cotizar.');
      return;
    }

    setState(() {
      _step = _QuoteStep.confirming;
      _error = null;
    });

    try {
      final result = await widget.repository.confirmQuote(
        matches: _matches,
        idEvento: _eventId ?? widget.repository.newEventId(),
      );
      if (!mounted) return;
      setState(() {
        _step = _QuoteStep.success;
        _confirmResult = result;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _QuoteStep.review;
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

  /// Abre el escáner de código de barras y agrega el producto encontrado
  /// a la lista de coincidencias (en revisión) o inicia la revisión (en captura).
  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerSheet.show(context);
    if (code == null || !mounted) return;

    // Mostrar loading breve mientras busca
    setState(() => _error = null);
    final match = await widget.repository.searchByBarcode(code);
    if (!mounted) return;

    final updatedMatches = List<QuoteLineMatch>.from(_matches)..add(match);
    final total = await widget.repository.estimateTotal(updatedMatches);
    if (!mounted) return;

    setState(() {
      _matches = updatedMatches;
      _estimatedTotal = total;
      _eventId ??= widget.repository.newEventId();
      // Si estábamos en captura sin foto, pasamos a revisión directamente.
      if (_step == _QuoteStep.capture) {
        _step = _QuoteStep.review;
      }
    });
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
            if (_step == _QuoteStep.capture || _step == _QuoteStep.review)
              _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_step == _QuoteStep.success) {
      return _buildSuccess(context);
    }
    if (_step == _QuoteStep.analyzing || _step == _QuoteStep.confirming) {
      return _buildLoading(context);
    }
    if (_step == _QuoteStep.review) {
      return _buildReview(context);
    }
    return _buildCapture(context);
  }

  Widget _buildCapture(BuildContext context) {
    final theme = Theme.of(context);
    final allowPhoto = widget.allowPhotoCapture;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          allowPhoto ? 'Cotizar desde foto' : 'Cotizar con código de barras',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          allowPhoto
              ? 'Toma una foto clara de tu lista o cotización manuscrita. '
                  'Detectaremos productos y cantidades.'
              : 'Escanea los códigos de barras de tus productos para armar la cotización.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        if (allowPhoto) ...[
          if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
              child: Image.file(
                File(_imagePath!),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Center(
                child: Icon(Icons.document_scanner_outlined, size: 48),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ] else
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_scanner, size: 48),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _scanBarcode,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear código de barras'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
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

  Widget _buildLoading(BuildContext context) {
    final message = _step == _QuoteStep.confirming
        ? 'Registrando cotización y agregando al carrito…'
        : 'Analizando imagen y buscando productos…';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'es_MX');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_imagePath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            child: Image.file(
              File(_imagePath!),
              height: 120,
              fit: BoxFit.cover,
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (_estimatedTotal != null && _estimatedTotal! > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Total estimado: ${currency.format(_estimatedTotal)}',
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
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (line.sku.isNotEmpty)
                        Text(
                          'Código: ${line.sku}',
                          style: theme.textTheme.bodySmall,
                        ),
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
            else if (match.selected != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
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
                trailing: match.candidates.length > 1
                    ? IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        tooltip: 'Cambiar producto',
                        onPressed: () => _showCandidatePicker(index),
                      )
                    : null,
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.searchError ?? 'Sin coincidencias',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
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
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (result != null)
          Text(
            '${result.addedCount} producto(s) agregados al carrito.'
            '${result.skippedLines > 0 ? ' ${result.skippedLines} línea(s) sin match.' : ''}'
            '${result.failedAdds > 0 ? ' ${result.failedAdds} no se pudieron agregar.' : ''}'
            '${!result.registered ? ' (El registro en servidor no se confirmó.)' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
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
        TextButton(
          onPressed: () {
            setState(() {
              _step = _QuoteStep.capture;
              _imagePath = null;
              _matches = const [];
              _confirmResult = null;
              _error = null;
            });
          },
          child: const Text('Nueva cotización'),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == _QuoteStep.capture && widget.allowPhotoCapture)
            FilledButton(
              onPressed: _imagePath != null ? _analyze : null,
              child: const Text('Analizar foto'),
            )
          else if (_step == _QuoteStep.capture && !widget.allowPhotoCapture)
            const SizedBox.shrink()
          else ...[
            FilledButton(
              onPressed: _confirm,
              child: const Text('Registrar y agregar al carrito'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _step = _QuoteStep.capture;
                  _matches = const [];
                  _error = null;
                });
              },
              child: const Text('Volver a captura'),
            ),
          ],
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
