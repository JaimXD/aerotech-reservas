import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/login_response.dart';
import '../models/usuario_registro.dart';
import 'session_manager.dart';

/// Error del flujo de registro con el código HTTP y datos extra del backend.
class RegistroException implements Exception {
  final String mensaje;
  final int? statusCode;
  final int? reintentarEn;

  const RegistroException(this.mensaje, {this.statusCode, this.reintentarEn});

  /// El token del paso 3 caducó o no es válido: hay que volver al paso 1.
  bool get verificacionExpirada => statusCode == 410 || statusCode == 401;

  @override
  String toString() => mensaje;
}

class RegistroService {
  static const _timeout = Duration(seconds: 25);

  Future<Map<String, dynamic>> _post(
      String ruta, Map<String, dynamic> cuerpo) async {
    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$ruta'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const RegistroException('No se pudo conectar con el servidor');
    }

    Map<String, dynamic> datos = {};
    try {
      // Se decodifica como UTF-8 para que las tildes lleguen bien.
      final decodificado = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (decodificado is Map<String, dynamic>) datos = decodificado;
    } catch (_) {/* Respuesta no JSON */}

    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      throw RegistroException(
        datos['error'] as String? ?? 'Ocurrió un error inesperado',
        statusCode: respuesta.statusCode,
        reintentarEn: (datos['reintentar_en'] as num?)?.toInt(),
      );
    }
    return datos;
  }

  /// Paso 1 y reenvío. Devuelve los segundos que hay que esperar para reenviar.
  Future<int> enviarCodigo(String correo) async {
    final datos =
        await _post('/api/registro/enviar-codigo', {'correo': correo});
    return (datos['reenviar_en_segundos'] as num?)?.toInt() ?? 60;
  }

  /// Paso 2. Devuelve el token temporal para completar el registro.
  Future<String> verificarCodigo(String correo, String codigo) async {
    final datos = await _post(
      '/api/registro/verificar-codigo',
      {'correo': correo, 'codigo': codigo},
    );
    final token = datos['token_registro'];
    if (token is! String || token.isEmpty) {
      throw const RegistroException('Respuesta inválida del servidor');
    }
    return token;
  }

  /// Paso 3. Crea la cuenta y deja la sesión iniciada.
  Future<LoginResponse> completar(UsuarioRegistro datos) async {
    final respuesta = await _post('/api/registro/completar', datos.toJson());
    final sesion = LoginResponse.fromJson(respuesta);
    ApiConfig.token = sesion.token;
    await SessionManager().guardarSesion(sesion.token);
    return sesion;
  }
}
