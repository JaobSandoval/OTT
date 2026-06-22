/// Acción de navegación resuelta desde linkContenido del CMS (linkUrl).
sealed class WelcomeBannerAction {
  const WelcomeBannerAction();
}

/// Abre ficha técnica nativa: `/catalog/detail/{idProducto}`.
final class WelcomeBannerProductoAction extends WelcomeBannerAction {
  const WelcomeBannerProductoAction(this.idProducto);

  final String idProducto;
}

/// Abre catálogo con búsqueda: `/catalog?q=...`.
final class WelcomeBannerBuscarAction extends WelcomeBannerAction {
  const WelcomeBannerBuscarAction(this.query);

  final String query;
}

/// Abre buscador filtrando por id de marca.
final class WelcomeBannerMarcaAction extends WelcomeBannerAction {
  const WelcomeBannerMarcaAction(this.idMarca);

  final String idMarca;
}

/// Abre buscador filtrando por id de categoría.
final class WelcomeBannerCategoriaAction extends WelcomeBannerAction {
  const WelcomeBannerCategoriaAction(this.idCategoria);

  final String idCategoria;
}

/// Abre buscador filtrando por id de subcategoría.
final class WelcomeBannerSubcategoriaAction extends WelcomeBannerAction {
  const WelcomeBannerSubcategoriaAction(this.idSubcategoria);

  final String idSubcategoria;
}

/// Abre URL en WebView embebido (comportamiento anterior).
final class WelcomeBannerExternalUrlAction extends WelcomeBannerAction {
  const WelcomeBannerExternalUrlAction(this.url);

  final String url;
}

/// linkContenido vacío o ausente.
final class WelcomeBannerNoneAction extends WelcomeBannerAction {
  const WelcomeBannerNoneAction();
}

/// linkContenido con formato no reconocido.
final class WelcomeBannerInvalidAction extends WelcomeBannerAction {
  const WelcomeBannerInvalidAction(this.raw);

  final String raw;
}
