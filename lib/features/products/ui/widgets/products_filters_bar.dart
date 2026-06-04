import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';
import 'package:flutter/material.dart';

class ProductsFiltersBar extends StatefulWidget {
  const ProductsFiltersBar({
    super.key,
    required this.options,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  final ProductFilterOptions options;
  final ProductSearchFilters filters;
  final ValueChanged<ProductSearchFilters> onChanged;
  final VoidCallback onClear;

  @override
  State<ProductsFiltersBar> createState() => _ProductsFiltersBarState();
}

class _ProductsFiltersBarState extends State<ProductsFiltersBar> {
  bool _expanded = false;

  int get _activeCount {
    var n = 0;
    if (widget.filters.idCategoria.isNotEmpty) n++;
    if (widget.filters.idSubcategoria.isNotEmpty) n++;
    if (widget.filters.idMarca.isNotEmpty) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.options.hasOptions) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final subOptions =
        widget.options.subcategoriasFor(widget.filters.idCategoria);

    return Container(
      decoration: AppDecorations.softCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppDecorations.brandGradientSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AppColors.catalogAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Filtros',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppDecorations.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_activeCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (widget.filters.hasAny && _expanded)
                    TextButton(
                      onPressed: widget.onClear,
                      child: const Text('Limpiar'),
                    ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.options.categorias.isNotEmpty) ...[
                    _FilterDropdown(
                      label: 'Categoría',
                      value: widget.filters.idCategoria,
                      items: widget.options.categorias,
                      onChanged: (id) {
                        widget.onChanged(
                          widget.filters.copyWith(
                            idCategoria: id ?? '',
                            clearCategoria: id == null,
                            clearSubcategoria: true,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.options.hasSubcategorias) ...[
                    _FilterDropdown(
                      label: 'Subcategoría',
                      value: widget.filters.idSubcategoria,
                      items: subOptions,
                      onChanged: (id) {
                        widget.onChanged(
                          widget.filters.copyWith(
                            idSubcategoria: id ?? '',
                            clearSubcategoria: id == null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.options.marcas.isNotEmpty)
                    _FilterDropdown(
                      label: 'Marca',
                      value: widget.filters.idMarca,
                      items: widget.options.marcas,
                      onChanged: (id) {
                        widget.onChanged(
                          widget.filters.copyWith(
                            idMarca: id ?? '',
                            clearMarca: id == null,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<FilterOption> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${items.length}'),
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Todas'),
        ),
        ...items.map(
          (item) => DropdownMenuItem<String>(
            value: item.id,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
