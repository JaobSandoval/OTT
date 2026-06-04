/// Línea del carrito devuelta por ConsultaCarrito (IA_Sel_Carrito).
class CartItem {
  const CartItem({
    required this.idProducto,
    required this.idLocalidad,
    required this.cantidad,
    this.descripcion = '',
    this.codigoProveedor = '',
    this.precioUnitario = 0,
    this.cantidadSurtida,
    this.localidad = '',
  });

  final String idProducto;
  final String idLocalidad;
  final int cantidad;
  final String descripcion;
  final String codigoProveedor;
  final double precioUnitario;
  final int? cantidadSurtida;
  final String localidad;

  bool get isBackorder =>
      cantidadSurtida != null &&
      cantidad > 0 &&
      cantidadSurtida! > 0 &&
      cantidadSurtida! < cantidad;

  double get lineSubtotal => precioUnitario * cantidad;

  double get lineTotal =>
      isBackorder ? 0 : lineSubtotal;

  String get imageUrl =>
      'https://contenidos.exel.com.mx/imgProducto/$idProducto.png';

  CartItem copyWith({
    String? localidad,
    double? precioUnitario,
  }) {
    return CartItem(
      idProducto: idProducto,
      idLocalidad: idLocalidad,
      cantidad: cantidad,
      descripcion: descripcion,
      codigoProveedor: codigoProveedor,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      cantidadSurtida: cantidadSurtida,
      localidad: localidad ?? this.localidad,
    );
  }
}
