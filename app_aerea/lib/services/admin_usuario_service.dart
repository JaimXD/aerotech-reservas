import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/usuario_admin.dart';
import 'admin_vuelo_service.dart' show AdminVueloException;
import 'session_manager.dart';

/// Cuentas de la aplicación (/api/admin/usuarios).
class AdminUsuarioService {
  static String get _base => "${ApiConfig.baseUrl}/api/admin/usuarios";

  Map<String, String> get _headers => {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
        "Content-Type": "application/json",
      };

  Future<ListaUsuariosAdmin> listar({
    String? busqueda,
    RolFiltro rol = RolFiltro.todos,
    EstadoCuentaFiltro estado = EstadoCuentaFiltro.todos,
    int pagina = 1,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      if (busqueda != null && busqueda.trim().isNotEmpty)
        "q": busqueda.trim(),
      if (rol.api != null) "rol": rol.api!,
      if (estado.api != null) "estado": estado.api!,
      "pagina": "$pagina",
    });
    final r = await http.get(uri, headers: _headers);
    return ListaUsuariosAdmin.fromJson(
        jsonDecode(_cuerpo(r, "cargar los usuarios")));
  }

  /// Hace administradora a la cuenta (true) o la deja como cliente (false).
  Future<void> cambiarRol(int id, {required bool admin}) async {
    final r = await http.put(
      Uri.parse("$_base/$id/rol"),
      headers: _headers,
      body: jsonEncode({"rol": admin ? "admin" : "user"}),
    );
    _cuerpo(r, "cambiar el rol");
  }

  /// Reactiva (true) o suspende (false) la cuenta.
  Future<void> cambiarEstado(int id, {required bool activo}) async {
    final r = await http.put(
      Uri.parse("$_base/$id/estado"),
      headers: _headers,
      body: jsonEncode({"activo": activo}),
    );
    _cuerpo(r, activo ? "reactivar la cuenta" : "suspender la cuenta");
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
