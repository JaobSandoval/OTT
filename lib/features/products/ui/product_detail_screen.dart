import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:flutter/material.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.idProducto,
    required this.repository,
    this.initialProduct,
  });

  final String idProducto;
  final ProductsRepository repository;
  final ProductCard? initialProduct;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository.fetchDetail(widget.idProducto);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = widget.initialProduct;
    final detail = _detail;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_loading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && detail == null) {
      return _ErrorBody(message: _error!, onRetry: _load);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth >= 700;
    final horizontalPad = 16.0;
    final codigoProveedor = detail?.codigoProveedor ?? '';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            horizontalPad,
            horizontalPad,
            bottomInset + 32,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (codigoProveedor.isNotEmpty)
                Text(
                  codigoProveedor,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              if (codigoProveedor.isNotEmpty) const SizedBox(height: 8),
              Text(
                detail?.descripcion.isNotEmpty == true
                    ? detail!.descripcion
                    : initial?.descripcion.isNotEmpty == true
                        ? initial!.descripcion
                        : 'Sin descripción',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: (screenWidth - horizontalPad * 2) * 0.35,
                      child: _SummaryColumn(
                        detail: detail,
                        initial: initial,
                        idProducto: widget.idProducto,
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: (screenWidth - horizontalPad * 2) * 0.6,
                      child: _InfoColumn(
                        detail: detail,
                        loading: _loading,
                      ),
                    ),
                  ],
                )
              else ...[
                _SummaryColumn(
                  detail: detail,
                  initial: initial,
                  idProducto: widget.idProducto,
                ),
                const SizedBox(height: 20),
                _InfoColumn(detail: detail, loading: _loading),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.detail,
    required this.initial,
    required this.idProducto,
  });

  final ProductDetail? detail;
  final ProductCard? initial;
  final String idProducto;

  List<String> get _galleryUrls {
    if (detail != null && detail!.imagenesZoom.isNotEmpty) {
      return detail!.imagenesZoom;
    }
    return [
      initial?.imageUrl ??
          'https://contenidos.exel.com.mx/imgProducto/$idProducto.png',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final precio = detail?.precio;
    final id = detail?.idProducto ?? idProducto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProductZoomGallery(urls: _galleryUrls),
        const SizedBox(height: 16),
        if (precio != null && precio.isNotEmpty)
          Text(
            _formatPrecio(precio),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (id.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'ID producto: $id',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _formatPrecio(String raw) {
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null) return raw.startsWith('\$') ? raw : '\$$raw';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _ProductZoomGallery extends StatefulWidget {
  const _ProductZoomGallery({required this.urls});

  final List<String> urls;

  @override
  State<_ProductZoomGallery> createState() => _ProductZoomGalleryState();
}

class _ProductZoomGalleryState extends State<_ProductZoomGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant _ProductZoomGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls != widget.urls) {
      _index = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urls = widget.urls;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _controller,
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.network(
                      urls[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) {
              final selected = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: selected ? 10 : 8,
                height: selected ? 10 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '${_index + 1} / ${urls.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.detail, required this.loading});

  final ProductDetail? detail;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ficha = detail?.fichaTecnica ?? const [];
    final existencias = detail?.existencias ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'INFORMACIÓN DEL PRODUCTO',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 3,
          width: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Detalles del producto',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading && ficha.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ficha.isEmpty)
          Text(
            'Sin ficha técnica disponible.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          _FichaTable(rows: ficha),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Existencia',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading && existencias.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (existencias.isEmpty)
          Text(
            'Sin información de existencias.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...existencias.map((e) => _ExistenciaCard(existencia: e)),
      ],
    );
  }
}

class _FichaTable extends StatelessWidget {
  const _FichaTable({required this.rows});

  final List<FichaTecnicaRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Característica',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Valor',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...rows.map(
            (row) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.caracteristica,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.valor,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistenciaCard extends StatelessWidget {
  const _ExistenciaCard({required this.existencia});

  final ExistenciaSucursal existencia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = int.tryParse(existencia.existencia) ?? 0;
    final label = units == 1
        ? '1 unidad disponible'
        : '$units unidades disponibles';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: existencia.esSucursalUsuario
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surface,
        border: Border.all(
          color: existencia.esSucursalUsuario
              ? theme.colorScheme.primary
              : theme.dividerColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  existencia.localidad.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (existencia.esSucursalUsuario)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tu sucursal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
