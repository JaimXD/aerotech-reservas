import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/asiento.dart';

import 'session_manager.dart';

class AsientoService {
  Future<List<Asiento>> listarAsientos(int vueloId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/vuelos/$vueloId/asientos");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => Asiento.fromJson(item)).toList();
    }

    if (response.statusCode == 401) {
      throw Exception("Sesión expirada o token inválido");
    }

    throw Exception(response.body);
  }

  Future<Map<String, dynamic>> reservarAsientos({
    required int vueloId,
    required List<String> asientos,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/reservas/asientos");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
      body: jsonEncode({
        "vuelo_id": vueloId,
        "asientos": asientos,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      throw Exception("Sesión expirada o token inválido");
    }

    throw Exception(response.body);
  }
}