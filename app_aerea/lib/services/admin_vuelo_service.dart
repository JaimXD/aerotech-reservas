import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

import 'session_manager.dart';

class AdminVueloService {
  Future<Map<String, dynamic>> crearVuelo({
    required String aerolinea,
    required String origen,
    required String destino,
    required String fecha,
    required String fechaLlegada,
    required String horaSalida,
    required String horaLlegada,
    required double precio,
    required int cantidadAsientos,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/admin/vuelos");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
      body: jsonEncode({
        "aerolinea": aerolinea,
        "origen": origen,
        "destino": destino,
        "fecha": fecha,
        "fecha_llegada": fechaLlegada,
        "hora_salida": horaSalida,
        "hora_llegada": horaLlegada,
        "precio": precio,
        "cantidad_asientos": cantidadAsientos,
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