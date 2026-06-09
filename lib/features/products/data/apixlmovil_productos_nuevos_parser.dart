import 'package:exel_ott/features/products/domain/product_card.dart';
import 'package:exel_ott/features/products/data/apixlmovil_buscador_response_parser.dart';

/// Parsea respuesta SOAP de `ListadoProductosNuevos` (mismo JSON que Buscador).
class ApiXlMovilProductosNuevosParser {
  const ApiXlMovilProductosNuevosParser._();

  static List<ProductCard> parse(String xml) =>
      ApiXlMovilBuscadorResponseParser.parseWithResultTag(
        xml,
        'ListadoProductosNuevosResult',
      );
}
