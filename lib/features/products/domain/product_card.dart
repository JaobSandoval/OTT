class ProductCard {
  const ProductCard({
    required this.idProducto,
    required this.marca,
    required this.descripcion,
    required this.existencia,
    required this.existenciaNacional,
    required this.categoria,
    required this.subCategoria,
    this.idCategoria = '',
    this.idSubcategoria = '',
  });

  final String idProducto;
  final String marca;
  final String descripcion;
  final String existencia;
  final String existenciaNacional;
  final String categoria;
  final String subCategoria;
  final String idCategoria;
  final String idSubcategoria;

  String get imageUrl =>
      'https://contenidos.exel.com.mx/imgProducto/$idProducto.png';

  factory ProductCard.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    return ProductCard(
      idProducto: pick(['id_producto', 'Id_Producto']),
      marca: pick(['Marca', 'marca']),
      descripcion: pick(['descripcion', 'Descripcion']),
      existencia: pick(['Existencia', 'existencia']),
      existenciaNacional: pick([
        'ExistenciaNacional',
        'existenciaNacional',
        'existencia_MX',
      ]),
      categoria: pick(['Categoria', 'categoria']),
      subCategoria: pick(['SubCategoria', 'subcategoria']),
      idCategoria: pick(['id_categoria', 'Id_Categoria']),
      idSubcategoria: pick(['id_subcategoria', 'Id_Subcategoria']),
    );
  }
}
