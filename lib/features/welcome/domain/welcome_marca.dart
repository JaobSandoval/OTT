import 'package:exel_ott/features/welcome/domain/welcome_link_resolver.dart';

class WelcomeMarca {
  const WelcomeMarca({
    required this.nombre,
    required this.imageUrl,
    required this.linkUrl,
    this.idMarca = '',
  });

  final String idMarca;
  final String nombre;
  final String imageUrl;
  final String linkUrl;

  bool get hasLink {
    if (WelcomeLinkResolver.isNavigable(linkUrl)) return true;
    return nombre.trim().isNotEmpty;
  }

  /// Enlace efectivo al tocar: linkUrl del CMS/API o búsqueda por marca/nombre.
  String get effectiveLinkUrl {
    if (WelcomeLinkResolver.isNavigable(linkUrl)) return linkUrl;
    final id = idMarca.trim();
    if (id.isNotEmpty) return 'marca|$id';
    final name = nombre.trim();
    if (name.isNotEmpty) return 'buscar|$name';
    return '';
  }
}
