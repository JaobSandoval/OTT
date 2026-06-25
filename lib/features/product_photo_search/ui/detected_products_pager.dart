import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/theme/app_widgets.dart';
import 'package:exel_ott/features/product_photo_search/domain/detected_product_match.dart';
import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:flutter/material.dart';

/// Panel de resultados con navegación 1 de N cuando hay varios productos detectados.
class DetectedProductsPager extends StatelessWidget {
  const DetectedProductsPager({
    super.key,
    required this.detectedProducts,
    required this.activeIndex,
    required this.onActiveIndexChanged,
    required this.onSelectCandidate,
    this.onOpenDetail,
    this.showDetailedIdentification = false,
    this.emptyMessage = 'No se detectaron productos en la imagen.',
    this.bottomPadding = 0,
  });

  final List<DetectedProductMatch> detectedProducts;
  final int activeIndex;
  final ValueChanged<int> onActiveIndexChanged;
  final void Function(int detectionIndex, ProductCard product) onSelectCandidate;
  final void Function(ProductCard product)? onOpenDetail;
  final bool showDetailedIdentification;
  final String emptyMessage;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    if (detectedProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
        child: Text(emptyMessage, textAlign: TextAlign.center),
      );
    }

    final index = activeIndex.clamp(0, detectedProducts.length - 1);
    final match = detectedProducts[index];
    final multiple = detectedProducts.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (multiple) ...[
          _ProductPagerBar(
            current: index + 1,
            total: detectedProducts.length,
            onPrevious: index > 0
                ? () => onActiveIndexChanged(index - 1)
                : null,
            onNext: index < detectedProducts.length - 1
                ? () => onActiveIndexChanged(index + 1)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: _DetectedProductCard(
            match: match,
            title: multiple ? 'Producto ${index + 1}' : 'Producto detectado',
            showDetailedIdentification: showDetailedIdentification,
            onSelectCandidate: (product) => onSelectCandidate(index, product),
            onOpenDetail: onOpenDetail,
          ),
        ),
      ],
    );
  }
}

/// Chips informativos del análisis (modelo, fotos, productos detectados).
class PhotoIdentificationInfoChips extends StatelessWidget {
  const PhotoIdentificationInfoChips({
    super.key,
    required this.response,
    required this.detectedCount,
  });

  final PhotoIdentificationResponse response;
  final int detectedCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (response.modeloUsado.isNotEmpty)
          DetectedProductInfoChip(
            label: response.modeloUsado,
            icon: Icons.auto_awesome,
            color: response.modeloUsado.contains('mini')
                ? AppColors.catalogAccentAlt
                : AppColors.catalogAccent,
          ),
        DetectedProductInfoChip(
          label:
              '${response.imagenesAnalizadas} foto${response.imagenesAnalizadas > 1 ? 's' : ''}',
          icon: Icons.image_outlined,
          color: AppColors.textSecondary,
        ),
        DetectedProductInfoChip(
          label:
              '$detectedCount producto${detectedCount == 1 ? '' : 's'} detectado${detectedCount == 1 ? '' : 's'}',
          icon: Icons.inventory_2_outlined,
          color: AppColors.catalogAccent,
        ),
      ],
    );
  }
}

class DetectedProductInfoChip extends StatelessWidget {
  const DetectedProductInfoChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

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
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPagerBar extends StatelessWidget {
  const _ProductPagerBar({
    required this.current,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              'Producto $current de $total',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DetectedProductCard extends StatelessWidget {
  const _DetectedProductCard({
    required this.match,
    required this.title,
    required this.showDetailedIdentification,
    required this.onSelectCandidate,
    this.onOpenDetail,
  });

  final DetectedProductMatch match;
  final String title;
  final bool showDetailedIdentification;
  final void Function(ProductCard product) onSelectCandidate;
  final void Function(ProductCard product)? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = match.identification;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        side: const BorderSide(color: AppColors.catalogAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showDetailedIdentification)
                  DetectedProductInfoChip(
                    label: 'Confianza: ${id.confianza}',
                    icon: Icons.bar_chart,
                    color: id.confianza == 'alta'
                        ? const Color(0xFF16A34A)
                        : id.confianza == 'media'
                            ? const Color(0xFFCA8A04)
                            : AppColors.error,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              id.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (id.marca.isNotEmpty)
              Text(
                id.marca,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (id.sku.isNotEmpty) ...[
              const SizedBox(height: 4),
              _TagRow(label: 'SKU', value: id.sku),
            ],
            if (showDetailedIdentification && id.categoria.isNotEmpty) ...[
              const SizedBox(height: 2),
              _TagRow(label: 'Categoría', value: id.categoria),
            ],
            if (showDetailedIdentification && id.descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                id.descripcion,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (showDetailedIdentification && id.keywords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: id.keywords
                    .map(
                      (k) => Chip(
                        label: Text(k, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppSectionLabel(
                    text: match.candidates.isEmpty
                        ? 'Sin coincidencias en catálogo'
                        : 'Coincidencias en catálogo',
                  ),
                ),
                if (match.candidates.isNotEmpty)
                  Text(
                    '${match.candidates.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (match.candidates.isEmpty)
              Text(
                'No se encontró este producto en el catálogo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...match.candidates.map(
                (p) => DetectedProductCandidateTile(
                  product: p,
                  selected: match.selected?.idProducto == p.idProducto,
                  onSelect: () => onSelectCandidate(p),
                  onOpenDetail:
                      onOpenDetail != null ? () => onOpenDetail!(p) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class DetectedProductCandidateTile extends StatelessWidget {
  const DetectedProductCandidateTile({
    super.key,
    required this.product,
    required this.selected,
    required this.onSelect,
    this.onOpenDetail,
  });

  final ProductCard product;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        side: selected
            ? const BorderSide(color: AppColors.catalogAccent, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onOpenDetail ?? onSelect,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product.imageUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.inventory_2, size: 36),
          ),
        ),
        title: Text(
          product.descripcion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${product.idProducto} · ${product.marca}'),
        trailing: onOpenDetail != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.catalogAccent
                          : AppColors.borderLight,
                    ),
                    onPressed: onSelect,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              )
            : Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.catalogAccent : AppColors.borderLight,
              ),
      ),
    );
  }
}
