import 'package:exel_ott/core/auth/session_store.dart';
import 'package:exel_ott/features/products/domain/product_search_launch.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abre catálogo público o buscador con sesión según haya token guardado.
Future<void> navigateProductSearch(
  BuildContext context,
  ProductSearchLaunch launch,
) async {
  if (!launch.shouldSearch) return;

  final token = await SessionStore().readToken();
  if (!context.mounted) return;

  final signedIn = token != null && token.trim().isNotEmpty;
  context.go(launch.uri(publicCatalog: !signedIn).toString());
}

ProductSearchLaunch launchForMarca({
  required String idMarca,
  String? nombre,
}) {
  final id = idMarca.trim();
  final name = nombre?.trim() ?? '';
  return ProductSearchLaunch(
    query: name.isNotEmpty ? name : null,
    filters: ProductSearchFilters(idMarca: id),
  );
}
