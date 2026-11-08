class Reserva {
  final int id;
  final int vueloId;
  final String codigoReserva;
  final int cantidadAsientos;
  final double total;
  final String estado;
  final String fechaReserva;
  final String aerolinea;
  final String origen;
  final String destino;
  final String fechaVuelo;
  final String fechaLlegada;
  final String horaSalida;
  final String horaLlegada;
  final List<String> asientos;

  Reserva({
    required this.id,
    required this.vueloId,
    required this.codigoReserva,
    required this.cantidadAsientos,
    required this.total,
    required this.estado,
    required this.fechaReserva,
    required this.aerolinea,
    required this.origen,
    required this.destino,
    required this.fechaVuelo,
    required this.fechaLlegada,
    required this.horaSalida,
    required this.horaLlegada,
    required this.asientos,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      id: json["id"],
      vueloId: json["vuelo_id"],
      codigoReserva: json["codigo_reserva"],
      cantidadAsientos: json["cantidad_asientos"],
      total: (json["total"] as num).toDouble(),
      estado: json["estado"],
      fechaReserva: json["fecha_reserva"],
      aerolinea: json["aerolinea"],
      origen: json["origen"],
      destino: json["destino"],
      fechaVuelo: json["fecha_vuelo"],
      fechaLlegada: json["fecha_llegada"] ?? json["fecha_vuelo"],
      horaSalida: json["hora_salida"],
      horaLlegada: json["hora_llegada"],
      asientos: json["asientos"] == null
          ? []
          : List<String>.from(json["asientos"]),
    );
  }
}