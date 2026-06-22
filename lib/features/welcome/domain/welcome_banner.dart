import 'package:exel_ott/features/welcome/domain/welcome_link_resolver.dart';

class WelcomeBanner {
  const WelcomeBanner({
    required this.idContenido,
    required this.idSegmentacion,
    required this.imageUrl,
    required this.linkUrl,
    this.posicion = '',
    this.tipoContenido = '',
    this.titulo = '',
    this.orden = 0,
  });

  final String idContenido;
  final String idSegmentacion;
  final String imageUrl;
  final String linkUrl;
  final String posicion;
  final String tipoContenido;
  final String titulo;
  final int orden;

  bool get hasLink => WelcomeLinkResolver.isNavigable(linkUrl);

  bool get isCenter => posicion == 'Square - Centro';

  bool get isFeatured {
    if (isCenter) return true;
    final key = '${posicion}_${tipoContenido}_$titulo'.toLowerCase();
    return key.contains('centro')
        || key.contains('principal')
        || key.contains('hero')
        || key.contains('destac');
  }
}
