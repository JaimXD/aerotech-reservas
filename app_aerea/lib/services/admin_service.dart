import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/panel_admin.dart';
import 'session_manager.dart';

/// Servicios del panel del administrador (/api/admin/...).
class AdminService {
  Map<String, String> get _headers => {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      };

  Future<PanelAdmin> obtenerPanel() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/admin/panel"),
      headers: _headers,
    );
    final cuerpo = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return PanelAdmin.fromJson(jsonDecode(cuerpo));
    }
    if (response.statusCode == 401) {
      throw Exception("Tu sesión expiró. Vuelve a iniciar sesión.");
    }
    if (response.statusCode == 403) {
      throw Exception("Tu cuenta no tiene permisos de administrador.");
    }
    throw Exception("No se pudo cargar el panel.");
  }
}
