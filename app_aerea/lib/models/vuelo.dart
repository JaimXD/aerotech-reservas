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

  // ── Datos calculados para la interfaz ──────────────────────────

  /// Día de salida sin hora (sirve para agrupar y comparar días).
  DateTime get dia {
    final d = DateTime.parse(fecha);
    return DateTime(d.year, d.month, d.day);
  }

  /// Fecha y hora exactas de salida y de llegada.
  DateTime get salida => _combinar(fecha, horaSalida);
  DateTime get llegada => _combinar(fechaLlegada, horaLlegada);

  /// Duración del vuelo en minutos.
  int get duracionMinutos {
    final m = llegada.difference(salida).inMinutes;
    return m > 0 ? m : 0;
  }

  /// "08:00" en lugar de "08:00:00".
  String get horaSalidaCorta => _hhmm(horaSalida);
  String get horaLlegadaCorta => _hhmm(horaLlegada);

  static DateTime _combinar(String fecha, String hora) {
    final d = DateTime.parse(fecha);
    final p = hora.split(':');
    return DateTime(
      d.year,
      d.month,
      d.day,
      int.parse(p[0]),
      p.length > 1 ? int.parse(p[1]) : 0,
    );
  }

  static String _hhmm(String hora) =>
      hora.length >= 5 ? hora.substring(0, 5) : hora;
}
