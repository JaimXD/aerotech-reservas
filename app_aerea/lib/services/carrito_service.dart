import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/carrito.dart';
import 'session_manager.dart';

/// Error del carrito con un mensaje listo para mostrar.
class CarritoException implements Exception {
  final String mensaje;

  /// true cuando otra persona tomó el asiento (HTTP 409).
  final bool conflicto;

  /// Asientos que ya no están libres.
  final List<String> asientosTomados;

  CarritoException(this.mensaje,
      {this.conflicto = false, this.asientosTomados = const []});

  @override
  String toString() => mensaje;
}

/// Carrito de compras. Los asientos quedan apartados en el servidor durante
/// 10 minutos, así que nadie más puede tomarlos mientras están aquí.
///
/// Es un singleton: la barra superior y la página del carrito escuchan
/// los mismos datos.
class CarritoService extends ChangeNotifier {
  static final CarritoService _instancia = CarritoService._();
  factory CarritoService() => _instancia;
  CarritoService._();

  Carrito _carrito = Carrito.vacio;
  Carrito get carrito => _carrito;

  /// Número de vuelos en el carrito (para el contador de la barra).
  int get cantidad => _carrito.items.length;

  String get _base => "${ApiConfig.baseUrl}/api/carrito";

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      };

  // ───────────────────────── Operaciones ─────────────────────────

  Future<Carrito> cargar() async {
    final r = await http.get(Uri.parse(_base), headers: _headers);
    return _guardar(r);
  }

  /// Aparta los [asientos] del vuelo. Si el vuelo ya estaba en el carrito,
  /// sus asientos se reemplazan por estos.
  Future<Carrito> agregar(int vueloId, List<String> asientos) async {
    final r = await http.post(
      Uri.parse("$_base/items"),
      headers: _headers,
      body: jsonEncode({"vuelo_id": vueloId, "asientos": asientos}),
    );
    return _guardar(r);
  }

  /// Quita un vuelo del carrito y libera sus asientos al instante.
  Future<Carrito> quitar(int vueloId) async {
    final r = await http.delete(Uri.parse("$_base/items/$vueloId"),
        headers: _headers);
    return _guardar(r);
  }

  /// Libera todo (al cerrar sesión). Nunca lanza errores: si falla,
  /// los asientos se liberan solos al pasar los 10 minutos.
  Future<void> liberarTodo() async {
    try {
      await http
          .delete(Uri.parse(_base), headers: _headers)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Sin conexión: no importa, el bloqueo vence solo.
    }
    _carrito = Carrito.vacio;
    notifyListeners();
  }

  /// Crea una reserva por cada vuelo del carrito.
  Future<ResultadoCompra> confirmar() async {
    final antes = _carrito;
    final r = await http.post(
      Uri.parse("$_base/confirmar"),
      headers: _headers,
      body: jsonEncode({
        "vuelo_ids": [for (final i in antes.items) i.vuelo.id],
      }),
    );

    final datos = _leerJson(r);

    // 201 = se compró al menos un vuelo, 409 = no se pudo comprar ninguno.
    if (r.statusCode != 201 && r.statusCode != 409) {
      throw CarritoException(_mensaje(datos, "No se pudo completar la compra"));
    }

    final resultado = ResultadoCompra.fromJson(datos, antes);

    // Lo que no se pudo comprar sigue en el carrito (si aún está apartado).
    try {
      await cargar();
    } catch (_) {
      _carrito = Carrito.vacio;
      notifyListeners();
    }
    return resultado;
  }

  // ───────────────────────── Ayudantes ─────────────────────────

  Carrito _guardar(http.Response r) {
    final datos = _leerJson(r);

    if (r.statusCode == 200) {
      _carrito = Carrito.fromJson(datos);
      notifyListeners();
      return _carrito;
    }

    if (r.statusCode == 401) {
      throw CarritoException("Tu sesión expiró. Vuelve a iniciar sesión.");
    }

    throw CarritoException(
      _mensaje(datos, "No se pudo actualizar el carrito"),
      conflicto: r.statusCode == 409,
      asientosTomados: datos["asientos"] is List
          ? List<String>.from(datos["asientos"])
          : const [],
    );
  }

  static Map<String, dynamic> _leerJson(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  static String _mensaje(Map<String, dynamic> datos, String porDefecto) {
    final e = datos["error"]?.toString() ?? '';
    return e.isNotEmpty ? e : porDefecto;
  }
}
