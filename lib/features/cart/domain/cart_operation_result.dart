/// Resultado de operaciones de carrito (AgregarProducto, Ajustar, Establecer).
class CartOperationResult {
  const CartOperationResult({
    required this.ok,
    this.mensaje = '',
    this.cantidadFinal,
  });

  final bool ok;
  final String mensaje;
  final int? cantidadFinal;
}
