import 'vuelo.dart';

/// Estado de un vuelo visto por el administrador.
enum EstadoVuelo {
  programado('PROGRAMADO', 'Programado', 'Programados'),
  completo('COMPLETO', 'Completo', 'Completos'),
  salio('SALIO', 'Ya salió', 'Ya salieron'),
  cancelado('CANCELADO', 'Cancelado', 'Cancelados');

  final String api;
  final String etiqueta;
  final String plural;

  const EstadoVuelo(this.api, this.etiqueta, this.plural);

  static EstadoVuelo desdeApi(String? valor) => EstadoVuelo.values.firstWhere(
      (e) => e.api == valor?.toUpperCase(),
      orElse: () => EstadoVuelo.programado);
}

/// Vuelo con los datos de gestión (ocupación, reservas, estado).
class VueloAdmin {
  /// Datos básicos (reutiliza salida, llegada, duración, etc.).
  final Vuelo datos;
  final EstadoVuelo estado;
  final int totalAsientos;
  final int vendidos;
  final int enCarritos;
  final int filas;
  final int asientosPorFila;
  final int reservasActivas;
  final int reservasCanceladas;

  /// Suma de las reservas activas, con IVA.
  final double ingresos;

  /// Resumen de los datos editables. Se envía al guardar para detectar si
  /// otro administrador modificó el vuelo mientras se editaba.
  final String huella;

  VueloAdmin({
    required this.datos,
    required this.estado,
    required this.totalAsientos,
    required this.vendidos,
    required this.enCarritos,
    required this.filas,
    required this.asientosPorFila,
    required this.reservasActivas,
    required this.reservasCanceladas,
    required this.ingresos,
    this.huella = '',
  });

  factory VueloAdmin.fromJson(Map<String, dynamic> json) {
    int n(String clave) => (json[clave] as num? ?? 0).toInt();
    return VueloAdmin(
      datos: Vuelo.fromJson(json),
      estado: EstadoVuelo.desdeApi(json['estado']),
      totalAsientos: n('total_asientos'),
      vendidos: n('vendidos'),
      enCarritos: n('en_carritos'),
      filas: n('filas'),
      asientosPorFila: n('asientos_por_fila'),
      reservasActivas: n('reservas_activas'),
      reservasCanceladas: n('reservas_canceladas'),
      ingresos: (json['ingresos'] as num? ?? 0).toDouble(),
      huella: json['huella'] as String? ?? '',
    );
  }

  int get id => datos.id;
  String get ruta => '${datos.origen} → ${datos.destino}';
  double get ocupacion => totalAsientos == 0 ? 0 : vendidos / totalAsientos;

  bool get cancelado => estado == EstadoVuelo.cancelado;
  bool get yaSalio => estado == EstadoVuelo.salio;

  /// Se puede editar o cancelar mientras no haya salido ni esté cancelado.
  bool get modificable => !cancelado && !yaSalio;

  /// Un vuelo cancelado se puede reactivar si todavía no llega su hora.
  bool get reactivable => cancelado && datos.salida.isAfter(DateTime.now());
}

/// Respuesta de GET /api/admin/vuelos.
class ListaVuelosAdmin {
  final List<VueloAdmin> vuelos;
  final int total;
  final int pagina;
  final int porPagina;

  /// Cantidad por pestaña: todos, programado, completo, salio, cancelado.
  final Map<String, int> conteos;
  final List<String> aerolineas;
  final List<String> ciudades;

  ListaVuelosAdmin({
    required this.vuelos,
    required this.total,
    required this.pagina,
    required this.porPagina,
    required this.conteos,
    required this.aerolineas,
    required this.ciudades,
  });

  factory ListaVuelosAdmin.fromJson(Map<String, dynamic> json) =>
      ListaVuelosAdmin(
        vuelos: (json['vuelos'] as List)
            .map((e) => VueloAdmin.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toInt(),
        pagina: (json['pagina'] as num).toInt(),
        porPagina: (json['por_pagina'] as num).toInt(),
        conteos: (json['conteos'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        aerolineas: List<String>.from(json['aerolineas'] ?? const []),
        ciudades: List<String>.from(json['ciudades'] ?? const []),
      );

  int conteo(EstadoVuelo? estado) =>
      conteos[estado == null ? 'todos' : estado.api.toLowerCase()] ?? 0;

  int get paginas => total == 0 ? 1 : (total / porPagina).ceil();
}

enum EstadoAsientoAdmin { vendido, carrito, libre }

class AsientoAdmin {
  final String numero;
  final EstadoAsientoAdmin estado;
  final String? cliente;
  final String? codigo;

  /// Segundos que faltan para que se libere (solo en carritos).
  final int? liberaEn;

  AsientoAdmin({
    required this.numero,
    required this.estado,
    this.cliente,
    this.codigo,
    this.liberaEn,
  });

  factory AsientoAdmin.fromJson(Map<String, dynamic> json) => AsientoAdmin(
        numero: json['numero'],
        estado: switch (json['estado']) {
          'VENDIDO' => EstadoAsientoAdmin.vendido,
          'CARRITO' => EstadoAsientoAdmin.carrito,
          _ => EstadoAsientoAdmin.libre,
        },
        cliente: json['cliente'],
        codigo: json['codigo'],
        liberaEn: (json['libera_en'] as num?)?.toInt(),
      );
}

class PasajeroVuelo {
  final int reservaId;
  final String codigo;
  final String estado;
  final double total;
  final int cantidad;
  final String asientos;
  final DateTime fecha;
  final String cliente;
  final String usuario;
  final String correo;

  PasajeroVuelo({
    required this.reservaId,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.cantidad,
    required this.asientos,
    required this.fecha,
    required this.cliente,
    required this.usuario,
    required this.correo,
  });

  factory PasajeroVuelo.fromJson(Map<String, dynamic> json) => PasajeroVuelo(
        reservaId: json['reserva_id'],
        codigo: json['codigo'],
        estado: json['estado'],
        total: (json['total'] as num).toDouble(),
        cantidad: (json['cantidad'] as num).toInt(),
        asientos: json['asientos'] ?? '',
        // Llega en UTC; se muestra en la hora del dispositivo.
        fecha: DateTime.parse(json['fecha']).toLocal(),
        cliente: json['cliente'] ?? '',
        usuario: json['usuario'] ?? '',
        correo: json['correo'] ?? '',
      );

  bool get activa => estado.toUpperCase() == 'ACTIVA';
}

/// Respuesta de GET /api/admin/vuelos/<id>.
class DetalleVueloAdmin {
  final VueloAdmin vuelo;
  final int libres;

  /// Segundos hasta que se libere el primer asiento apartado en un carrito.
  final int? primerVencimiento;
  final List<AsientoAdmin> asientos;
  final List<PasajeroVuelo> pasajeros;

  DetalleVueloAdmin({
    required this.vuelo,
    required this.libres,
    required this.primerVencimiento,
    required this.asientos,
    required this.pasajeros,
  });

  factory DetalleVueloAdmin.fromJson(Map<String, dynamic> json) =>
      DetalleVueloAdmin(
        vuelo: VueloAdmin.fromJson(json['vuelo']),
        libres: (json['libres'] as num).toInt(),
        primerVencimiento: (json['primer_vencimiento'] as num?)?.toInt(),
        asientos: (json['asientos'] as List)
            .map((e) => AsientoAdmin.fromJson(e as Map<String, dynamic>))
            .toList(),
        pasajeros: (json['pasajeros'] as List)
            .map((e) => PasajeroVuelo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<PasajeroVuelo> get activos => pasajeros.where((p) => p.activa).toList();
}

/// Resultado de cancelar un vuelo.
class CancelacionVuelo {
  final int reservasCanceladas;
  final int asientosLiberados;
  final int carritosLiberados;

  CancelacionVuelo({
    required this.reservasCanceladas,
    required this.asientosLiberados,
    required this.carritosLiberados,
  });

  factory CancelacionVuelo.fromJson(Map<String, dynamic> json) =>
      CancelacionVuelo(
        reservasCanceladas: (json['reservas_canceladas'] as num).toInt(),
        asientosLiberados: (json['asientos_liberados'] as num).toInt(),
        carritosLiberados: (json['carritos_liberados'] as num).toInt(),
      );
}
