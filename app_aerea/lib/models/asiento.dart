class Asiento {
  final int id;
  final int vueloId;
  final String numeroAsiento;
  final String estado;
  final int? reservaId;

  /// true si este asiento está apartado en MI carrito.
  final bool enMiCarrito;

  Asiento({
    required this.id,
    required this.vueloId,
    required this.numeroAsiento,
    required this.estado,
    this.reservaId,
    this.enMiCarrito = false,
  });

  factory Asiento.fromJson(Map<String, dynamic> json) {
    return Asiento(
      id: json["id"],
      vueloId: json["vuelo_id"],
      numeroAsiento: json["numero_asiento"],
      estado: json["estado"],
      reservaId: json["reserva_id"],
      enMiCarrito: json["en_mi_carrito"] == true,
    );
  }

  bool get disponible => estado == "DISPONIBLE";
  bool get reservado => estado == "RESERVADO";

  /// Apartado por otra persona en su carrito (se libera en máximo 10 min).
  bool get bloqueado => estado == "BLOQUEADO";
}
