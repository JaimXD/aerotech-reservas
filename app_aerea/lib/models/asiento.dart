class Asiento {
  final int id;
  final int vueloId;
  final String numeroAsiento;
  final String estado;
  final int? reservaId;

  Asiento({
    required this.id,
    required this.vueloId,
    required this.numeroAsiento,
    required this.estado,
    this.reservaId,
  });

  factory Asiento.fromJson(Map<String, dynamic> json) {
    return Asiento(
      id: json["id"],
      vueloId: json["vuelo_id"],
      numeroAsiento: json["numero_asiento"],
      estado: json["estado"],
      reservaId: json["reserva_id"],
    );
  }

  bool get disponible => estado == "DISPONIBLE";
  bool get reservado => estado == "RESERVADO";
}