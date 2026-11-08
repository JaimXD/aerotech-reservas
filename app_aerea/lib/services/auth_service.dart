import 'dart:convert';

import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import 'session_manager.dart';

class AuthService {
  String _mensajeError(http.Response response, String alternativa) {
    try {
      final datos = jsonDecode(utf8.decode(response.bodyBytes));
      if (datos is Map<String, dynamic> && datos['error'] is String) {
        return datos['error'] as String;
      }
    } catch (_) {/* Respuesta no JSON */}
    return alternativa;
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw Exception('No se pudo conectar con el servidor');
    }
    if (response.statusCode != 200) {
      throw Exception(
          _mensajeError(response, 'Usuario o contraseña incorrectos'));
    }
    final loginResponse =
        LoginResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    ApiConfig.token = loginResponse.token;
    await SessionManager().guardarSesion(loginResponse.token);
    return loginResponse;
  }
}
