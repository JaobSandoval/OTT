import 'package:exel_ott/core/firebase/firebase_monitoring_service.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/core/utils/currency_format.dart';
import 'package:exel_ott/core/utils/friendly_error_message.dart';
import 'package:exel_ott/features/cart/data/cart_repository.dart';
import 'package:exel_ott/features/products/data/products_repository.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/domain/product_detail.dart';
import 'package:exel_ott/features/products/ui/widgets/zoomable_product_image.dart';
import 'package:flutter/material.dart';
import 'package:exel_ott/features/products/ui/product_add_to_cart_helpers.dart';
import 'package:go_router/go_router.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.idProducto,
    required this.repository,
    this.cartRepository,
    this.initialProduct,
    this.catalogOnly = false,
  });

  final String idProducto;
  final ProductsRepository repository;
  final CartRepository? cartRepository;
  final ProductCard? initialProduct;
  final bool catalogOnly;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _detail;
  bool _loading = true;
  bool _addingToCart = false;
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
      final detail = widget.catalogOnly
          ? await widget.repository.fetchPublicDetail(
              widget.idProducto,
              card: widget.initialProduct,
            )
          : await widget.repository.fetchDetail(widget.idProducto);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      await FirebaseMonitoringService.instance.logViewItem(
        itemId: detail.idProducto,
        itemName: detail.descripcion.isNotEmpty
            ? detail.descripcion
            : detail.marca,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _onExistenciaTap(ExistenciaSucursal existencia) async {
    final detail = _detail;
    final cartRepository = widget.cartRepository;
    if (detail == null || _addingToCart || widget.catalogOnly || cartRepository == null) {
      return;
    }

    final idSucursal = await cartRepository.readIdSucursalUsuario();
    final pickable = cartRepository.pickableLocations(detail, idSucursal);
    if (pickable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay sucursal con stock para agregar.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    ({ExistenciaSucursal row, String locationId}) selected;
    final match = pickable.where((p) => p.row.localidad == existencia.localidad);
    if (match.length == 1) {
      selected = match.first;
    } else if (pickable.length == 1) {
      selected = pickable.first;
    } else {
      if (!mounted) return;
      final picked = await showModalBottomSheet<({ExistenciaSucursal row, String locationId})>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Elegir sucursal',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              ...pickable.map(
                (p) => ListTile(
                  title: Text(p.row.localidad),
                  subtitle: Text('${p.row.existencia} disponibles'),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              ),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      selected = picked;
    }

    if (!mounted) return;
    setState(() => _addingToCart = true);
    try {
      await addProductToCart(
        context: context,
        cartRepository: cartRepository,
        idProducto: detail.idProducto,
        selected: selected,
      );
    } finally {
      if (mounted) setState(() => _addingToCart = false);
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
                    color: AppColors.catalogAccent,
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
                        addingToCart: _addingToCart,
                        onExistenciaTap: _onExistenciaTap,
                        catalogOnly: widget.catalogOnly,
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
                _InfoColumn(
                  detail: detail,
                  loading: _loading,
                  addingToCart: _addingToCart,
                  onExistenciaTap: _onExistenciaTap,
                  catalogOnly: widget.catalogOnly,
                ),
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
            formatCurrency(precio),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.catalogAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (id.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'ID producto: $id',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

}

class _ProductZoomGallery extends StatefulWidget {
  const _ProductZoomGallery({required this.urls});

  final List<String> urls;

  @override
  State<_ProductZoomGallery> createState() => _ProductZoomGalleryState();
}

class _ProductZoomGalleryState extends State<_ProductZoomGallery> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urls = widget.urls;

    return Container(
      decoration: AppDecorations.softCard(radius: AppDecorations.radiusLg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: PageView.builder(
                controller: _pageController,
                itemCount: urls.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ZoomableProductImage(
                        url: urls[index],
                        galleryUrls: urls,
                        galleryIndex: index,
                        fit: BoxFit.contain,
                        highQuality: true,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.catalogAccent,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            if (urls.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 10 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.catalogAccent
                          : AppColors.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 12),
                child: Text(
                  '${_currentPage + 1} / ${urls.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.detail,
    required this.loading,
    required this.addingToCart,
    required this.onExistenciaTap,
    this.catalogOnly = false,
  });

  final ProductDetail? detail;
  final bool loading;
  final bool addingToCart;
  final void Function(ExistenciaSucursal) onExistenciaTap;
  final bool catalogOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ficha = detail?.fichaTecnica ?? const [];
    final existencias = detail?.existencias ?? const [];
    final showFicha = ficha.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFicha) ...[
          const AppSectionLabel(text: 'Información del producto'),
          const SizedBox(height: 12),
          AppSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.catalogAccent,
                    ),
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
                _FichaTable(rows: ficha),
              ],
            ),
          ),
        ],
        if (catalogOnly) ...[
          if (showFicha) const SizedBox(height: 20),
          AppSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Inicia sesión para ver precios, existencia y comprar.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ] else ...[
          if (showFicha) const SizedBox(height: 20),
          const AppSectionLabel(text: 'Existencia'),
          const SizedBox(height: 12),
          AppSoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading && existencias.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (existencias.isEmpty)
                  Text(
                    'Sin información de existencias.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ...existencias.map(
                    (e) => _ExistenciaCard(
                      existencia: e,
                      canAdd: (parseStockQuantity(e.existencia) ?? 0) > 0,
                      addingToCart: addingToCart,
                      onTap: () => onExistenciaTap(e),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppColors.surface,
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
          ...rows.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final row = entry.value;
              final alt = index.isOdd;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: alt ? AppColors.surface.withValues(alpha: 0.5) : null,
                  border: Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
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
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExistenciaCard extends StatelessWidget {
  const _ExistenciaCard({
    required this.existencia,
    required this.canAdd,
    required this.addingToCart,
    required this.onTap,
  });

  final ExistenciaSucursal existencia;
  final bool canAdd;
  final bool addingToCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = parseStockQuantity(existencia.existencia) ?? 0;
    final label = units == 1
        ? '1 unidad disponible'
        : '$units unidades disponibles';

    final content = Column(
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.catalogAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Tu sucursal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.catalogAccent,
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
            color: AppColors.textSecondary,
          ),
        ),
        if (canAdd) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.add_shopping_cart_outlined,
                size: 18,
                color: AppColors.catalogAccent,
              ),
              const SizedBox(width: 6),
              Text(
                addingToCart ? 'Agregando…' : 'Toca para agregar al carrito',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.catalogAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: existencia.esSucursalUsuario
            ? AppColors.catalogAccent.withValues(alpha: 0.06)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: existencia.esSucursalUsuario
                ? AppColors.catalogAccent.withValues(alpha: 0.4)
                : AppColors.borderLight,
          ),
        ),
        child: InkWell(
          onTap: canAdd && !addingToCart ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: content,
          ),
        ),
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
