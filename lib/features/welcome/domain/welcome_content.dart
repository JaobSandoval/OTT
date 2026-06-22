import 'package:exel_ott/features/welcome/domain/welcome_banner.dart';
import 'package:exel_ott/features/welcome/domain/welcome_marca.dart';

class WelcomeContent {
  const WelcomeContent({
    required this.marcas,
    required this.squares,
  });

  static const empty = WelcomeContent(marcas: [], squares: []);

  final List<WelcomeMarca> marcas;
  final List<WelcomeBanner> squares;

  bool get hasContent => marcas.isNotEmpty || squares.isNotEmpty;

  static const _squareOrder = [
    'Square - Centro',
    'Square - Izquierda - Top',
    'Square - Izquierda - Down',
    'Square - Derecha - Top',
    'Square - Derecha - Down',
  ];

  WelcomeBanner? squareAt(String posicion) {
    for (final square in squares) {
      if (square.posicion == posicion) return square;
    }
    return null;
  }

  List<WelcomeBanner> get orderedSquares {
    final used = <String>{};
    final ordered = <WelcomeBanner>[];

    for (final posicion in _squareOrder) {
      final square = squareAt(posicion);
      if (square != null) {
        ordered.add(square);
        used.add(square.idContenido);
      }
    }

    for (final square in squares) {
      if (!used.contains(square.idContenido)) {
        ordered.add(square);
      }
    }

    return ordered;
  }

  WelcomeBanner? get featuredSquare {
    for (final square in orderedSquares) {
      if (square.isFeatured) return square;
    }
    return null;
  }

  List<WelcomeBanner> get gridSquares {
    final featured = featuredSquare;
    if (featured == null) return orderedSquares;
    return orderedSquares
        .where((square) => square.idContenido != featured.idContenido)
        .toList();
  }

  WelcomeBanner? get centerSquare => featuredSquare ?? squareAt('Square - Centro');

  List<WelcomeBanner> get sideSquares => gridSquares;
}
