import 'package:exel_ott/features/products/domain/product_card.dart';

class ProductSearchFilters {
  const ProductSearchFilters({
    this.idCategoria = '',
    this.idSubcategoria = '',
    this.idMarca = '',
  });

  final String idCategoria;
  final String idSubcategoria;
  final String idMarca;

  bool get hasAny =>
      idCategoria.isNotEmpty ||
      idSubcategoria.isNotEmpty ||
      idMarca.isNotEmpty;

  ProductSearchFilters copyWith({
    String? idCategoria,
    String? idSubcategoria,
    String? idMarca,
    bool clearCategoria = false,
    bool clearSubcategoria = false,
    bool clearMarca = false,
  }) {
    return ProductSearchFilters(
      idCategoria: clearCategoria ? '' : (idCategoria ?? this.idCategoria),
      idSubcategoria:
          clearSubcategoria ? '' : (idSubcategoria ?? this.idSubcategoria),
      idMarca: clearMarca ? '' : (idMarca ?? this.idMarca),
    );
  }
}

class FilterOption {
  const FilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ProductFilterOptions {
  const ProductFilterOptions({
    this.categorias = const [],
    this.subcategoriasByCategoria = const {},
    this.marcas = const [],
  });

  final List<FilterOption> categorias;
  final Map<String, List<FilterOption>> subcategoriasByCategoria;
  final List<FilterOption> marcas;

  static const empty = ProductFilterOptions();

  List<FilterOption> subcategoriasFor(String idCategoria) {
    if (idCategoria.isEmpty) {
      final all = <String, FilterOption>{};
      for (final list in subcategoriasByCategoria.values) {
        for (final item in list) {
          all[item.id] = item;
        }
      }
      return all.values.toList()
        ..sort((a, b) => a.label.compareTo(b.label));
    }
    return subcategoriasByCategoria[idCategoria] ?? const [];
  }

  bool get hasSubcategorias => subcategoriasByCategoria.values.any((l) => l.isNotEmpty);

  bool get hasOptions =>
      categorias.isNotEmpty || hasSubcategorias || marcas.isNotEmpty;
}

/// Claves de filtro: usa id numérico si existe; si no, el nombre visible.
String categoriaFilterKey(ProductCard product) {
  if (product.idCategoria.isNotEmpty) return product.idCategoria;
  return product.categoria.trim();
}

String subcategoriaFilterKey(ProductCard product) {
  if (product.idSubcategoria.isNotEmpty) return product.idSubcategoria;
  return product.subCategoria.trim();
}

ProductFilterOptions buildFilterOptionsFromCatalog(List<ProductCard> products) {
  final catMap = <String, FilterOption>{};
  final subMap = <String, Map<String, FilterOption>>{};
  final marcaMap = <String, FilterOption>{};

  for (final p in products) {
    if (p.categoria.trim().isNotEmpty) {
      final catId = categoriaFilterKey(p);
      catMap[catId] = FilterOption(id: catId, label: p.categoria.trim());
    }
    if (p.subCategoria.trim().isNotEmpty) {
      final catKey = categoriaFilterKey(p);
      if (catKey.isEmpty) continue;
      final subId = subcategoriaFilterKey(p);
      subMap.putIfAbsent(catKey, () => {});
      subMap[catKey]![subId] = FilterOption(
        id: subId,
        label: p.subCategoria.trim(),
      );
    }
    if (p.marca.trim().isNotEmpty) {
      marcaMap[p.marca.trim()] = FilterOption(id: p.marca.trim(), label: p.marca.trim());
    }
  }

  final cats = catMap.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  final subs = subMap.map(
    (key, value) => MapEntry(
      key,
      value.values.toList()..sort((a, b) => a.label.compareTo(b.label)),
    ),
  );
  final brandList = marcaMap.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));

  return ProductFilterOptions(
    categorias: cats,
    subcategoriasByCategoria: subs,
    marcas: brandList,
  );
}

List<ProductCard> applyProductFilters(
  List<ProductCard> catalog,
  ProductSearchFilters filters,
) {
  if (!filters.hasAny) return catalog;

  return catalog.where((p) => _productMatchesFilters(p, filters)).toList();
}

bool _productMatchesFilters(ProductCard p, ProductSearchFilters filters) {
  if (filters.idMarca.isNotEmpty && p.marca.trim() != filters.idMarca) {
    return false;
  }
  if (filters.idCategoria.isNotEmpty &&
      categoriaFilterKey(p) != filters.idCategoria) {
    return false;
  }
  if (filters.idSubcategoria.isNotEmpty &&
      subcategoriaFilterKey(p) != filters.idSubcategoria) {
    return false;
  }
  return true;
}

List<ProductCard> filterCatalogForOptions(
  List<ProductCard> catalog,
  ProductSearchFilters filters, {
  bool applyMarca = true,
  bool applyCategoria = true,
  bool applySubcategoria = true,
}) {
  return catalog.where((p) {
    if (applyMarca &&
        filters.idMarca.isNotEmpty &&
        p.marca.trim() != filters.idMarca) {
      return false;
    }
    if (applyCategoria &&
        filters.idCategoria.isNotEmpty &&
        categoriaFilterKey(p) != filters.idCategoria) {
      return false;
    }
    if (applySubcategoria &&
        filters.idSubcategoria.isNotEmpty &&
        subcategoriaFilterKey(p) != filters.idSubcategoria) {
      return false;
    }
    return true;
  }).toList();
}

/// Opciones disponibles según los otros filtros ya seleccionados.
ProductFilterOptions buildContextualFilterOptions(
  List<ProductCard> catalog,
  ProductSearchFilters filters,
) {
  final forMarcas = filterCatalogForOptions(
    catalog,
    filters,
    applyMarca: false,
  );
  final forCategorias = filterCatalogForOptions(
    catalog,
    filters,
    applyCategoria: false,
    applySubcategoria: false,
  );
  final forSubcategorias = filterCatalogForOptions(
    catalog,
    filters,
    applySubcategoria: false,
  );

  final marcasOpts = buildFilterOptionsFromCatalog(forMarcas);
  final catOpts = buildFilterOptionsFromCatalog(forCategorias);
  final subOpts = buildFilterOptionsFromCatalog(forSubcategorias);

  return ProductFilterOptions(
    categorias: catOpts.categorias,
    subcategoriasByCategoria: subOpts.subcategoriasByCategoria,
    marcas: marcasOpts.marcas,
  );
}

ProductSearchFilters sanitizeFilters(
  List<ProductCard> catalog,
  ProductSearchFilters filters,
) {
  var current = filters;

  final marcas = buildContextualFilterOptions(
    catalog,
    current.copyWith(clearMarca: true),
  ).marcas;
  if (current.idMarca.isNotEmpty &&
      !marcas.any((m) => m.id == current.idMarca)) {
    current = current.copyWith(clearMarca: true);
  }

  final categorias = buildContextualFilterOptions(
    catalog,
    current.copyWith(clearCategoria: true, clearSubcategoria: true),
  ).categorias;
  if (current.idCategoria.isNotEmpty &&
      !categorias.any((c) => c.id == current.idCategoria)) {
    current = current.copyWith(clearCategoria: true, clearSubcategoria: true);
  }

  final subs = buildContextualFilterOptions(
    catalog,
    current.copyWith(clearSubcategoria: true),
  ).subcategoriasFor(current.idCategoria);
  if (current.idSubcategoria.isNotEmpty &&
      !subs.any((s) => s.id == current.idSubcategoria)) {
    current = current.copyWith(clearSubcategoria: true);
  }

  return current;
}
