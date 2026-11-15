import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/reserva_admin.dart';
import 'admin_vuelo_service.dart' show AdminVueloException;
import 'session_manager.dart';

/// Reservas de todos los clientes (/api/admin/reservas).
class AdminReservaService {
  static String get _base => "${ApiConfig.baseUrl}/api/admin/reservas";

  Map<String, String> get _headers => {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      };

  Future<ListaReservasAdmin> listar({
    EstadoReservaFiltro estado = EstadoReservaFiltro.todas,
    String? busqueda,
    PeriodoReservas periodo = PeriodoReservas.todo,
    int? vueloId,
    int pagina = 1,
    bool exportar = false,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      if (estado.api != null) "estado": estado.api!,
      if (busqueda != null && busqueda.trim().isNotEmpty)
        "q": busqueda.trim(),
      "periodo": periodo.api,
      if (vueloId != null) "vuelo": "$vueloId",
      "pagina": "$pagina",
      if (exportar) "exportar": "1",
    });
    final r = await http.get(uri, headers: _headers);
    return ListaReservasAdmin.fromJson(
        jsonDecode(_cuerpo(r, "cargar las reservas")));
  }

  /// Devuelve la lista de asientos liberados.
  Future<List<String>> cancelar(int id) async {
    final r =
        await http.put(Uri.parse("$_base/$id/cancelar"), headers: _headers);
    final datos = jsonDecode(_cuerpo(r, "cancelar la reserva"));
    return List<String>.from(datos["asientos_liberados"] ?? const []);
  }

  /// XML de la factura de cualquier reserva activa.
  Future<String> facturaXml(int id) async {
    final r = await http.get(Uri.parse("$_base/$id/factura"), headers: {
      ..._headers,
      "Accept": "application/xml",
    });
    return _cuerpo(r, "generar la factura");
  }

  String _cuerpo(http.Response r, String accion) {
    // utf8.decode para que las tildes se vean bien
    final cuerpo = utf8.decode(r.bodyBytes);
    if (r.statusCode == 200) return cuerpo;
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
    throw AdminVueloException(mensaje ?? "No se pudo $accion.", r.statusCode);
  }
}
