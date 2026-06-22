import 'package:exel_ott/core/utils/external_url.dart';
import 'package:exel_ott/features/products/domain/product_search_filters.dart';
import 'package:exel_ott/features/products/domain/product_search_launch.dart';
import 'package:exel_ott/features/products/ui/product_search_navigation.dart';
import 'package:exel_ott/features/welcome/domain/welcome_banner_action.dart';
import 'package:exel_ott/features/welcome/domain/welcome_link_resolver.dart';
import 'package:exel_ott/features/welcome/domain/welcome_marca.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navega según linkContenido del CMS (producto, buscar, filtros o URL externa).
void navigateWelcomeLink(BuildContext context, String? linkUrl) {
  final action = WelcomeLinkResolver.parse(linkUrl);

  switch (action) {
    case WelcomeBannerNoneAction():
      return;
    case WelcomeBannerProductoAction(:final idProducto):
      context.push('/catalog/detail/$idProducto');
    case WelcomeBannerBuscarAction(:final query):
      navigateProductSearch(
        context,
        ProductSearchLaunch(query: query),
      );
    case WelcomeBannerMarcaAction(:final idMarca):
      navigateProductSearch(
        context,
        launchForMarca(idMarca: idMarca),
      );
    case WelcomeBannerCategoriaAction(:final idCategoria):
      navigateProductSearch(
        context,
        ProductSearchLaunch(
          filters: ProductSearchFilters(idCategoria: idCategoria),
        ),
      );
    case WelcomeBannerSubcategoriaAction(:final idSubcategoria):
      navigateProductSearch(
        context,
        ProductSearchLaunch(
          filters: ProductSearchFilters(idSubcategoria: idSubcategoria),
        ),
      );
    case WelcomeBannerExternalUrlAction(:final url):
      openInAppUrl(context, url);
    case WelcomeBannerInvalidAction():
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace no válido.')),
      );
  }
}

/// Toca logo de marca en inicio (usa id de marca + nombre para el buscador).
void navigateWelcomeMarca(BuildContext context, WelcomeMarca marca) {
  final id = marca.idMarca.trim();
  if (id.isNotEmpty) {
    navigateProductSearch(context, launchForMarca(idMarca: id, nombre: marca.nombre));
    return;
  }

  navigateWelcomeLink(context, marca.effectiveLinkUrl);
}
