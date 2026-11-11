import 'reserva.dart';
import 'vuelo.dart';

/// Un vuelo dentro del carrito con los asientos que el usuario tiene apartados.
class ItemCarrito {
  final Vuelo vuelo;
  final List<String> asientos;
  final double subtotal;

  /// Momento en que se liberan los asientos (calculado con el reloj del
  /// servidor para no depender de la hora del computador).
  final DateTime expiraEn;

  ItemCarrito({
    required this.vuelo,
    required this.asientos,
    required this.subtotal,
    required this.expiraEn,
  });

  factory ItemCarrito.fromJson(Map<String, dynamic> json, DateTime recibido) {
    return ItemCarrito(
      vuelo: Vuelo.fromJson(json["vuelo"]),
      asientos: List<String>.from(json["asientos"] ?? const []),
      subtotal: (json["subtotal"] as num).toDouble(),
      expiraEn: recibido.add(
        Duration(seconds: (json["segundos_restantes"] as num?)?.toInt() ?? 0),
      ),
    );
  }

  /// Tiempo que falta para que se liberen los asientos (nunca negativo).
  Duration get restante {
    final d = expiraEn.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get vencido => restante == Duration.zero;

  String get ruta => '${vuelo.origen} → ${vuelo.destino}';
  String get textoAsientos => asientos.join(', ');
}

class Carrito {
  final List<ItemCarrito> items;
  final double subtotal;
  final double iva;
  final double total;
  final int porcentajeIva;
  final int minutosBloqueo;

  const Carrito({
    required this.items,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.porcentajeIva,
    required this.minutosBloqueo,
  });

  static const vacio = Carrito(
    items: [],
    subtotal: 0,
    iva: 0,
    total: 0,
    porcentajeIva: 15,
    minutosBloqueo: 10,
  );

  factory Carrito.fromJson(Map<String, dynamic> json) {
    final recibido = DateTime.now();
    return Carrito(
      items: (json["items"] as List? ?? const [])
          .map((e) => ItemCarrito.fromJson(e, recibido))
          .toList(),
      subtotal: (json["subtotal"] as num? ?? 0).toDouble(),
      iva: (json["iva"] as num? ?? 0).toDouble(),
      total: (json["total"] as num? ?? 0).toDouble(),
      porcentajeIva: (json["porcentaje_iva"] as num? ?? 15).toInt(),
      minutosBloqueo: (json["minutos_bloqueo"] as num? ?? 10).toInt(),
    );
  }

  bool get estaVacio => items.isEmpty;

  /// El primer vuelo cuyos asientos se liberan.
  ItemCarrito? get proximoAVencer {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => a.expiraEn.isBefore(b.expiraEn) ? a : b);
  }
}

/// Un vuelo que no se pudo comprar al confirmar el carrito.
class CompraFallida {
  final int vueloId;
  final String ruta;
  final List<String> asientos;
  final String motivo;

  CompraFallida({
    required this.vueloId,
    required this.ruta,
    required this.asientos,
    required this.motivo,
  });
}

/// Respuesta de "Confirmar y pagar".
class ResultadoCompra {
  final List<Reserva> confirmadas;
  final List<CompraFallida> fallidas;
  final double subtotal;
  final double iva;
  final double total;
  final int porcentajeIva;

  ResultadoCompra({
    required this.confirmadas,
    required this.fallidas,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.porcentajeIva,
  });

  /// [antes] es el carrito que veía el usuario: sirve para poner nombre a
  /// los vuelos que vencieron (el servidor ya no los tiene).
  factory ResultadoCompra.fromJson(Map<String, dynamic> json, Carrito antes) {
    final porVuelo = {for (final i in antes.items) i.vuelo.id: i};

    return ResultadoCompra(
      confirmadas: (json["confirmadas"] as List? ?? const [])
          .map((e) => Reserva.fromJson(e))
          .toList(),
      fallidas: (json["fallidas"] as List? ?? const []).map((e) {
        final id = (e["vuelo_id"] as num).toInt();
        final previo = porVuelo[id];
        final origen = e["origen"] ?? previo?.vuelo.origen;
        final destino = e["destino"] ?? previo?.vuelo.destino;
        return CompraFallida(
          vueloId: id,
          ruta: origen != null ? '$origen → $destino' : 'Vuelo #$id',
          asientos: e["asientos"] != null
              ? List<String>.from(e["asientos"])
              : (previo?.asientos ?? const []),
          motivo: e["motivo"]?.toString() ?? 'No se pudo confirmar.',
        );
      }).toList(),
      subtotal: (json["subtotal"] as num? ?? 0).toDouble(),
      iva: (json["iva"] as num? ?? 0).toDouble(),
      total: (json["total"] as num? ?? 0).toDouble(),
      porcentajeIva: (json["porcentaje_iva"] as num? ?? 15).toInt(),
    );
  }
}
