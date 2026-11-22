import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/perfil.dart';
import 'session_manager.dart';

class PerfilService {
  /// Datos de la cuenta del usuario que inició sesión.
  Future<Perfil> obtenerPerfil() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/usuarios/perfil"),
      headers: {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
    );

    final cuerpo = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return Perfil.fromJson(jsonDecode(cuerpo));
    }

    if (response.statusCode == 401) {
      throw Exception("Sesión expirada o token inválido");
    }

    throw Exception("No se pudo cargar tu perfil");
  }
}
