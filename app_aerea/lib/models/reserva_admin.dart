/// Filtro por fecha de compra.
enum PeriodoReservas {
  todo('todo', 'Todas las fechas'),
  hoy('hoy', 'Hoy'),
  semana('7d', 'Últimos 7 días'),
  mes('mes', 'Este mes');

  final String api;
  final String etiqueta;

  const PeriodoReservas(this.api, this.etiqueta);
}

/// Pestañas de la lista.
enum EstadoReservaFiltro {
  todas(null, 'Todas', 'todas'),
  activas('ACTIVA', 'Activas', 'activas'),
  canceladas('CANCELADA', 'Canceladas', 'canceladas');

  final String? api;
  final String etiqueta;
  final String clave;

  const EstadoReservaFiltro(this.api, this.etiqueta, this.clave);
}

class ClienteReserva {
  final int id;
  final String nombre;
  final String usuario;
  final String correo;

  ClienteReserva({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.correo,
  });

  factory ClienteReserva.fromJson(Map<String, dynamic> j) => ClienteReserva(
        id: j['id'],
        nombre: j['nombre'] ?? '',
        usuario: j['usuario'] ?? '',
        correo: j['correo'] ?? '',
      );
}

class VueloReserva {
  final int id;
  final String aerolinea;
  final String origen;
  final String destino;
  final DateTime fecha;
  final String horaSalida;
  final bool cancelado;
  final bool salio;

  VueloReserva({
    required this.id,
    required this.aerolinea,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
    required this.cancelado,
    required this.salio,
  });

  factory VueloReserva.fromJson(Map<String, dynamic> j) => VueloReserva(
        id: j['id'],
        aerolinea: j['aerolinea'] ?? '',
        origen: j['origen'],
        destino: j['destino'],
        fecha: DateTime.parse(j['fecha']),
        horaSalida: j['hora_salida'],
        cancelado: j['cancelado'] == true,
        salio: j['salio'] == true,
      );

  String get ruta => '$origen → $destino';
  String get hora =>
      horaSalida.length >= 5 ? horaSalida.substring(0, 5) : horaSalida;
}

/// Una reserva vista por el administrador.
class ReservaAdmin {
  final int id;
  final String codigo;
  final String estado;

  /// Con IVA.
  final double total;
  final int cantidad;
  final String asientos;
  final DateTime fecha;
  final ClienteReserva cliente;
  final VueloReserva vuelo;

  ReservaAdmin({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.cantidad,
    required this.asientos,
    required this.fecha,
    required this.cliente,
    required this.vuelo,
  });

  factory ReservaAdmin.fromJson(Map<String, dynamic> j) => ReservaAdmin(
        id: j['id'],
        codigo: j['codigo'],
        estado: j['estado'],
        total: (j['total'] as num).toDouble(),
        cantidad: (j['cantidad'] as num).toInt(),
        asientos: j['asientos'] ?? '',
        // Llega en UTC; se muestra en la hora del dispositivo.
        fecha: DateTime.parse(j['fecha']).toLocal(),
        cliente: ClienteReserva.fromJson(j['cliente']),
        vuelo: VueloReserva.fromJson(j['vuelo']),
      );

  bool get activa => estado.toUpperCase() == 'ACTIVA';

  /// Se cancela si está activa y su vuelo todavía no sale.
  bool get cancelable => activa && !vuelo.salio;
}

/// Opción del filtro "Vuelo".
class VueloFiltro {
  final int id;
  final String origen;
  final String destino;
  final DateTime fecha;
  final String horaSalida;

  VueloFiltro({
    required this.id,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.horaSalida,
  });

  factory VueloFiltro.fromJson(Map<String, dynamic> j) => VueloFiltro(
        id: j['id'],
        origen: j['origen'],
        destino: j['destino'],
        fecha: DateTime.parse(j['fecha']),
        horaSalida: j['hora_salida'],
      );
}

/// Respuesta de GET /api/admin/reservas.
class ListaReservasAdmin {
  final List<ReservaAdmin> reservas;
  final int total;
  final int pagina;
  final int porPagina;
  final Map<String, int> conteos;
  final List<VueloFiltro> vuelos;

  ListaReservasAdmin({
    required this.reservas,
    required this.total,
    required this.pagina,
    required this.porPagina,
    required this.conteos,
    required this.vuelos,
  });

  factory ListaReservasAdmin.fromJson(Map<String, dynamic> j) =>
      ListaReservasAdmin(
        reservas: (j['reservas'] as List)
            .map((e) => ReservaAdmin.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num).toInt(),
        pagina: (j['pagina'] as num).toInt(),
        porPagina: (j['por_pagina'] as num).toInt(),
        conteos: (j['conteos'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        vuelos: (j['vuelos'] as List)
            .map((e) => VueloFiltro.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  int conteo(EstadoReservaFiltro e) => conteos[e.clave] ?? 0;
  int get paginas => total == 0 ? 1 : (total / porPagina).ceil();
}
