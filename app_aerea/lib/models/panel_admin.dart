/// Datos del panel de inicio del administrador (GET /api/admin/panel).
class PanelAdmin {
  final double ventasHoy;

  /// % frente a ayer. null cuando ayer no hubo ventas.
  final int? variacionVentas;
  final int reservasHoy;
  final int canceladasHoy;

  /// 0–100: asientos vendidos de los vuelos que aún no salen.
  final int ocupacion;
  final int asientosEnCarritos;
  final int clientesConCarrito;
  final List<VentaDia> ventasSemana;
  final List<SalidaProxima> proximasSalidas;
  final List<ReservaReciente> ultimasReservas;

  PanelAdmin({
    required this.ventasHoy,
    required this.variacionVentas,
    required this.reservasHoy,
    required this.canceladasHoy,
    required this.ocupacion,
    required this.asientosEnCarritos,
    required this.clientesConCarrito,
    required this.ventasSemana,
    required this.proximasSalidas,
    required this.ultimasReservas,
  });

  factory PanelAdmin.fromJson(Map<String, dynamic> json) {
    final carritos = json['en_carritos'] as Map<String, dynamic>? ?? const {};
    List<T> lista<T>(String clave, T Function(Map<String, dynamic>) crear) =>
        (json[clave] as List? ?? const [])
            .map((e) => crear(e as Map<String, dynamic>))
            .toList();

    return PanelAdmin(
      ventasHoy: (json['ventas_hoy'] as num? ?? 0).toDouble(),
      variacionVentas: (json['variacion_ventas'] as num?)?.round(),
      reservasHoy: (json['reservas_hoy'] as num? ?? 0).toInt(),
      canceladasHoy: (json['canceladas_hoy'] as num? ?? 0).toInt(),
      ocupacion: (json['ocupacion'] as num? ?? 0).toInt(),
      asientosEnCarritos: (carritos['asientos'] as num? ?? 0).toInt(),
      clientesConCarrito: (carritos['clientes'] as num? ?? 0).toInt(),
      ventasSemana: lista('ventas_semana', VentaDia.fromJson),
      proximasSalidas: lista('proximas_salidas', SalidaProxima.fromJson),
      ultimasReservas: lista('ultimas_reservas', ReservaReciente.fromJson),
    );
  }

  double get totalSemana => ventasSemana.fold(0, (s, v) => s + v.total);
}

class VentaDia {
  final DateTime fecha;
  final double total;

  VentaDia({required this.fecha, required this.total});

  factory VentaDia.fromJson(Map<String, dynamic> json) => VentaDia(
        fecha: DateTime.parse(json['fecha']),
        total: (json['total'] as num).toDouble(),
      );
}

class SalidaProxima {
  final int id;
  final String aerolinea;
  final String origen;
  final String destino;
  final DateTime fecha;
  final String horaSalida;
  final int vendidos;
  final int total;

  SalidaProxima({
    required this.id,
    required this.aerolinea,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
    required this.vendidos,
    required this.total,
  });

  factory SalidaProxima.fromJson(Map<String, dynamic> json) => SalidaProxima(
        id: json['id'],
        aerolinea: json['aerolinea'],
        origen: json['origen'],
        destino: json['destino'],
        fecha: DateTime.parse(json['fecha']),
        horaSalida: json['hora_salida'],
        vendidos: (json['vendidos'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  String get ruta => '$origen → $destino';
  String get hora =>
      horaSalida.length >= 5 ? horaSalida.substring(0, 5) : horaSalida;
  bool get completo => total > 0 && vendidos >= total;

  /// 0.0 – 1.0
  double get ocupacion => total == 0 ? 0 : vendidos / total;
}

class ReservaReciente {
  final int id;
  final String codigo;
  final String estado;
  final double total;
  final DateTime fecha;
  final String cliente;
  final String origen;
  final String destino;
  final String asientos;

  ReservaReciente({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.fecha,
    required this.cliente,
    required this.origen,
    required this.destino,
    required this.asientos,
  });

  factory ReservaReciente.fromJson(Map<String, dynamic> json) =>
      ReservaReciente(
        id: json['id'],
        codigo: json['codigo'],
        estado: json['estado'],
        total: (json['total'] as num).toDouble(),
        // Llega en UTC; se muestra en la hora del dispositivo.
        fecha: DateTime.parse(json['fecha']).toLocal(),
        cliente: json['cliente'],
        origen: json['origen'],
        destino: json['destino'],
        asientos: json['asientos'] ?? '',
      );

  bool get cancelada => estado.toUpperCase() == 'CANCELADA';
}
