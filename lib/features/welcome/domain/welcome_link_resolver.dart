import 'package:exel_ott/features/welcome/domain/welcome_banner_action.dart';

/// Interpreta linkContenido del CMS según convención acordada con contenidos.
///
/// Formatos soportados:
/// - `producto|{idProducto}` → detalle nativo
/// - `buscar|{texto}` → catálogo con búsqueda
/// - `marca|{idMarca}` → catálogo/buscador con filtro marca
/// - `categoria|{id}` → catálogo/buscador con filtro categoría
/// - `subcategoria|{id}` → catálogo/buscador con filtro subcategoría
/// - `https://...` / `http://...` → WebView
class WelcomeLinkResolver {
  const WelcomeLinkResolver._();

  static const _tagProducto = 'producto';
  static const _tagBuscar = 'buscar';
  static const _tagMarca = 'marca';
  static const _tagCategoria = 'categoria';
  static const _tagSubcategoria = 'subcategoria';

  /// Tags reconocidas (case-insensitive).
  static const supportedTags = [
    _tagProducto,
    _tagBuscar,
    _tagMarca,
    _tagCategoria,
    _tagSubcategoria,
  ];

  static WelcomeBannerAction parse(String? linkUrl) {
    final trimmed = linkUrl?.trim() ?? '';
    if (trimmed.isEmpty) return const WelcomeBannerNoneAction();

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return WelcomeBannerExternalUrlAction(trimmed);
    }

    final pipeIndex = trimmed.indexOf('|');
    if (pipeIndex <= 0) return WelcomeBannerInvalidAction(trimmed);

    final tag = trimmed.substring(0, pipeIndex).trim().toLowerCase();
    final payload = trimmed.substring(pipeIndex + 1).trim();

    switch (tag) {
      case _tagProducto:
        if (payload.isEmpty) return WelcomeBannerInvalidAction(trimmed);
        return WelcomeBannerProductoAction(payload);
      case _tagBuscar:
        if (payload.isEmpty) return WelcomeBannerInvalidAction(trimmed);
        return WelcomeBannerBuscarAction(payload);
      case _tagMarca:
        if (payload.isEmpty) return WelcomeBannerInvalidAction(trimmed);
        return WelcomeBannerMarcaAction(payload);
      case _tagCategoria:
        if (payload.isEmpty) return WelcomeBannerInvalidAction(trimmed);
        return WelcomeBannerCategoriaAction(payload);
      case _tagSubcategoria:
        if (payload.isEmpty) return WelcomeBannerInvalidAction(trimmed);
        return WelcomeBannerSubcategoriaAction(payload);
      default:
        return WelcomeBannerInvalidAction(trimmed);
    }
  }

  static bool isNavigable(String? linkUrl) {
    return switch (parse(linkUrl)) {
      WelcomeBannerNoneAction() || WelcomeBannerInvalidAction() => false,
      _ => true,
    };
  }
}
