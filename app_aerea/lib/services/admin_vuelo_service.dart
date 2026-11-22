import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/vuelo_admin.dart';
import 'session_manager.dart';

/// Error de la API con un mensaje listo para mostrar.
class AdminVueloException implements Exception {
  final String mensaje;
  final int codigo;

  AdminVueloException(this.mensaje, [this.codigo = 0]);

  @override
  String toString() => mensaje;
}

/// Gestión de vuelos del administrador (/api/admin/vuelos).
class AdminVueloService {
  static String get _base => "${ApiConfig.baseUrl}/api/admin/vuelos";

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      };

  Future<ListaVuelosAdmin> listar({
    EstadoVuelo? estado,
    String? busqueda,
    String? aerolinea,
    int pagina = 1,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      if (estado != null) "estado": estado.api,
      if (busqueda != null && busqueda.trim().isNotEmpty)
        "q": busqueda.trim(),
      if (aerolinea != null) "aerolinea": aerolinea,
      "pagina": "$pagina",
    });
    final r = await http.get(uri, headers: _headers);
    return ListaVuelosAdmin.fromJson(_procesar(r, "cargar los vuelos"));
  }

  /// Aerolíneas y ciudades registradas (selectores del formulario).
  Future<({List<String> aerolineas, List<String> ciudades})> opciones() async {
    final r = await http.get(Uri.parse("$_base/opciones"), headers: _headers);
    final datos = _procesar(r, "cargar las aerolíneas y ciudades");
    return (
      aerolineas: List<String>.from(datos['aerolineas'] ?? const []),
      ciudades: List<String>.from(datos['ciudades'] ?? const []),
    );
  }

  Future<DetalleVueloAdmin> detalle(int id) async {
    final r = await http.get(Uri.parse("$_base/$id"), headers: _headers);
    return DetalleVueloAdmin.fromJson(_procesar(r, "cargar el vuelo"));
  }

  /// [datos]: aerolinea, origen, destino, fecha, fecha_llegada, hora_salida,
  /// hora_llegada, precio, filas, asientos_por_fila.
  Future<VueloAdmin> crear(Map<String, dynamic> datos) async {
    final r = await http.post(Uri.parse(_base),
        headers: _headers, body: jsonEncode(datos));
    return VueloAdmin.fromJson(_procesar(r, "crear el vuelo"));
  }

  Future<VueloAdmin> actualizar(int id, Map<String, dynamic> datos) async {
    final r = await http.put(Uri.parse("$_base/$id"),
        headers: _headers, body: jsonEncode(datos));
    return VueloAdmin.fromJson(_procesar(r, "guardar los cambios"));
  }

  Future<CancelacionVuelo> cancelar(int id) async {
    final r =
        await http.put(Uri.parse("$_base/$id/cancelar"), headers: _headers);
    return CancelacionVuelo.fromJson(_procesar(r, "cancelar el vuelo"));
  }

  Future<VueloAdmin> reactivar(int id) async {
    final r =
        await http.put(Uri.parse("$_base/$id/reactivar"), headers: _headers);
    return VueloAdmin.fromJson(_procesar(r, "reactivar el vuelo"));
  }

  Map<String, dynamic> _procesar(http.Response r, String accion) {
    final cuerpo = utf8.decode(r.bodyBytes);
    if (r.statusCode == 200 || r.statusCode == 201) {
      return jsonDecode(cuerpo) as Map<String, dynamic>;
    }
    if (r.statusCode == 401) {
      throw AdminVueloException(
          "Tu sesión expiró. Vuelve a iniciar sesión.", 401);
    }
    if (r.statusCode == 403) {
      throw AdminVueloException(
          "Tu cuenta no tiene permisos de administrador.", 403);
    }
    String? mensaje;
    try {
      mensaje = (jsonDecode(cuerpo) as Map<String, dynamic>)["error"];
    } catch (_) {}
    throw AdminVueloException(
        mensaje ?? "No se pudo $accion.", r.statusCode);
  }
}
