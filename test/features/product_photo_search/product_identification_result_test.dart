import 'package:exel_ott/features/product_photo_search/domain/product_identification_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductIdentificationResult', () {
    test('incluye marca en searchQueries para Nextep auriculares', () {
      const result = ProductIdentificationResult(
        nombre: 'Auriculares USB',
        marca: 'Nextep',
        sku: '',
        categoria: 'audio',
        descripcion: 'Auriculares con micrófono',
        keywords: ['auriculares', 'Nextep', 'USB', 'audio', 'micrófono'],
        confianza: 'alta',
      );

      expect(result.searchQueries.first, 'Nextep Auriculares USB');
      expect(result.bestSearchQuery, 'Nextep Auriculares USB');
      expect(result.searchQueries, contains('Auriculares USB Nextep'));
      expect(result.searchQueries, contains('Nextep'));
    });

    test('SKU tiene prioridad sobre nombre y marca', () {
      const result = ProductIdentificationResult(
        nombre: 'Auriculares USB',
        marca: 'Nextep',
        sku: 'AUD-123',
        categoria: 'audio',
        descripcion: '',
        keywords: const [],
        confianza: 'alta',
      );

      expect(result.bestSearchQuery, 'AUD-123');
      expect(result.searchQueries.first, 'AUD-123');
    });

    test('busqueda_sugerida tiene máxima prioridad', () {
      const result = ProductIdentificationResult(
        nombre: 'Auriculares USB',
        marca: 'Nextep',
        sku: '',
        categoria: 'audio',
        descripcion: '',
        keywords: const [],
        confianza: 'alta',
        busquedaSugerida: 'Nextep auriculares USB con micrófono',
      );

      expect(result.bestSearchQuery, 'Nextep auriculares USB con micrófono');
      expect(result.searchQueries.first, 'Nextep auriculares USB con micrófono');
    });

    test('sin marca conserva nombre como query principal', () {
      const result = ProductIdentificationResult(
        nombre: 'Cable HDMI 2m',
        marca: '',
        sku: '',
        categoria: 'cables',
        descripcion: '',
        keywords: ['hdmi', 'cable'],
        confianza: 'media',
      );

      expect(result.bestSearchQuery, 'Cable HDMI 2m');
      expect(result.searchQueries, contains('Cable HDMI 2m'));
      expect(result.searchQueries, isNot(contains('')));
    });

    test('catalogSearchAttempts incluye filtro id_marca con nombre', () {
      const result = ProductIdentificationResult(
        nombre: 'Auriculares USB',
        marca: 'Nextep',
        sku: '',
        categoria: 'audio',
        descripcion: '',
        keywords: const [],
        confianza: 'alta',
      );

      final withMarcaFilter = result.catalogSearchAttempts.where(
        (a) => a.filters.idMarca == 'Nextep' && a.query == 'Auriculares USB',
      );
      expect(withMarcaFilter, isNotEmpty);
    });
  });

  group('PhotoIdentificationResponse', () {
    test('parsea múltiples productos del array productos', () {
      final response = PhotoIdentificationResponse.fromJson({
        'status': 'success',
        'modelo_usado': 'gpt-4o-mini',
        'imagenes_analizadas': 1,
        'productos': [
          {
            'nombre': 'Mouse inalámbrico',
            'marca': 'Logitech',
            'sku': '',
            'categoria': 'periféricos',
            'descripcion': '',
            'keywords': ['mouse', 'Logitech'],
            'confianza': 'alta',
          },
          {
            'nombre': 'Teclado USB',
            'marca': 'Nextep',
            'sku': '',
            'categoria': 'periféricos',
            'descripcion': '',
            'keywords': ['teclado', 'Nextep'],
            'confianza': 'media',
          },
        ],
      });

      expect(response.productos, hasLength(2));
      expect(response.productos[0].nombre, 'Mouse inalámbrico');
      expect(response.productos[1].marca, 'Nextep');
      expect(response.modeloUsado, 'gpt-4o-mini');
    });

    test('parsea respuesta legacy con un solo producto en raíz', () {
      final response = PhotoIdentificationResponse.fromJson({
        'status': 'success',
        'modelo_usado': 'gpt-4o-mini',
        'imagenes_analizadas': 1,
        'nombre': 'Auriculares USB',
        'marca': 'Nextep',
        'sku': '',
        'categoria': 'audio',
        'descripcion': '',
        'keywords': ['auriculares'],
        'confianza': 'alta',
      });

      expect(response.productos, hasLength(1));
      expect(response.productos.first.marca, 'Nextep');
    });
  });
}
