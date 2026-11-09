import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_manager.dart';

class FacturaService {
  /// Pide al backend la factura de una reserva y devuelve el XML como texto.
  Future<String> obtenerFacturaXml(int reservaId) async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/api/reservas/$reservaId/factura"),
      headers: {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
        "Accept": "application/xml",
      },
    );

    // utf8.decode para que las tildes (Pérez, Galápagos) se vean bien
    final cuerpo = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) return cuerpo;

    if (response.statusCode == 401) {
      throw Exception("Sesión expirada o token inválido");
    }

    try {
      final data = jsonDecode(cuerpo);
      throw Exception(data["error"] ?? "No se pudo generar la factura");
    } on FormatException {
      throw Exception("No se pudo generar la factura");
    }
  }
}
