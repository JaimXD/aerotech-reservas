import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/reserva.dart';

import 'session_manager.dart';

class ReservasService {
  Future<void> crearReserva(int vueloId, int cantidadAsientos) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/reservas");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
      body: jsonEncode({
        "vuelo_id": vueloId,
        "cantidad_asientos": cantidadAsientos,
      }),
    );

    if (response.statusCode != 201) {
      final mensaje = _obtenerMensajeError(response.body);

      throw Exception(mensaje);
    }
  }

  Future<List<Reserva>> listarMisReservas() async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/reservas/mis-reservas");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Reserva.fromJson(e)).toList();
    }

    throw Exception("No se pudieron cargar las reservas");
  }

  Future<void> cancelarReserva(int reservaId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/reservas/$reservaId/cancelar");

    final response = await http.put(
      url,
      headers: {
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
    );

    if (response.statusCode != 200) {
      final mensaje = _obtenerMensajeError(response.body);

      throw Exception(mensaje);
    }
  }

  Future<void> editarReserva(int reservaId, int? nuevoVueloId, List<String> asientos) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/reservas/$reservaId");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${SessionManager().token ?? ApiConfig.token}",
      },
      body: jsonEncode({
        if (nuevoVueloId != null) "vuelo_id": nuevoVueloId,
        "asientos": asientos,
      }),
    );

    if (response.statusCode != 200) {
      final mensaje = _obtenerMensajeError(response.body);
      throw Exception(mensaje);
    }
  }

  String _obtenerMensajeError(String body) {
    try {
      final data = jsonDecode(body);

      final detalle = data["detalle"]?.toString() ?? "";
      final error = data["error"]?.toString() ?? "";

      if (detalle.contains("Uno o más asientos ya no están disponibles") ||
          error.contains("No se pudo registrar la reserva")) {
        return "Concurrencia detectada: uno o más asientos ya fueron reservados por otro usuario. Actualice la lista e intente nuevamente.";
      }

      if (error.isNotEmpty) {
        return error;
      }

      if (detalle.isNotEmpty) {
        return detalle;
      }

      return "Ocurrió un error al procesar la reserva.";
    } catch (e) {
      if (body.contains("Uno o más asientos ya no están disponibles")) {
        return "Concurrencia detectada: uno o más asientos ya fueron reservados por otro usuario. Actualice la lista e intente nuevamente.";
      }

      return "Ocurrió un error al procesar la reserva.";
    }
  }
}