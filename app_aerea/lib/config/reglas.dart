/// Reglas del negocio que deben coincidir en todas las pantallas.
class Reglas {
  Reglas._();

  /// Sin límite de años: el administrador puede programar, y el cliente
  /// buscar, vuelos en cualquier año futuro. Los calendarios necesitan un
  /// último día; el 31/12/9999 no es un límite real.
  static final ultimaFecha = DateTime(9999, 12, 31);

  static DateTime ultimaFechaVuelos() => ultimaFecha;
}
