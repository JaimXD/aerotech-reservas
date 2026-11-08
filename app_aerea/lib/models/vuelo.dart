class Vuelo {
  final int id;
  final String aerolinea;
  final String origen;
  final String destino;
  final String fecha;
  final String fechaLlegada;
  final String horaSalida;
  final String horaLlegada;
  final double precio;
  final int asientosDisponibles;

  Vuelo({
    required this.id,
    required this.aerolinea,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.fechaLlegada,
    required this.horaSalida,
    required this.horaLlegada,
    required this.precio,
    required this.asientosDisponibles,
  });

  factory Vuelo.fromJson(Map<String, dynamic> json) {
    return Vuelo(
      id: json["id"],
      aerolinea: json["aerolinea"],
      origen: json["origen"],
      destino: json["destino"],
      fecha: json["fecha"],
      fechaLlegada: json["fecha_llegada"] ?? json["fecha"],
      horaSalida: json["hora_salida"],
      horaLlegada: json["hora_llegada"],
      precio: (json["precio"] as num).toDouble(),
      asientosDisponibles: json["asientos_disponibles"],
    );
  }
}
