import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final _storage = const FlutterSecureStorage();
  
  String? _token;
  String? _role;
  String? _username;
  String? _nombreCompleto;
  
  String? get token => _token;
  String? get role => _role;
  String? get username => _username;
  String? get nombreCompleto => _nombreCompleto;
  bool get isAdmin => _role == 'admin';

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Formato de token inválido');
      }
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      return json.decode(resp);
    } catch (e) {
      debugPrint("Error decodificando JWT: $e");
      rethrow;
    }
  }

  // Initialize session from secure storage (HU-03)
  Future<bool> inicializarSesion() async {
    try {
      final storedToken = await _storage.read(key: "auth_token");
      if (storedToken == null) {
        return false;
      }
      
      final payload = _decodeJwt(storedToken);
      final exp = payload["exp"] as int?;
      
      if (exp != null) {
        final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expDate)) {
          // Token expired, clear it
          await cerrarSesion();
          return false;
        }
      }
      
      _token = storedToken;
      _role = payload["role"] ?? payload["tipo_usuario"] ?? "user";
      _username = payload["usuario"];
      _nombreCompleto = payload["nombre_completo"];
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error en inicializarSesion: $e");
      await cerrarSesion();
      return false;
    }
  }

  // Check if token in storage is expired
  Future<bool> isTokenExpired() async {
    try {
      final storedToken = await _storage.read(key: "auth_token");
      if (storedToken == null) return true;
      final payload = _decodeJwt(storedToken);
      final exp = payload["exp"] as int?;
      if (exp == null) return false;
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate);
    } catch (_) {
      return true;
    }
  }

  // Save session upon successful login (HU-03, HU-05)
  Future<void> guardarSesion(String token) async {
    final payload = _decodeJwt(token);
    
    // Ensure never two tokens coexist: delete first
    await _storage.delete(key: "auth_token");
    await _storage.write(key: "auth_token", value: token);
    
    _token = token;
    _role = payload["role"] ?? payload["tipo_usuario"] ?? "user";
    _username = payload["usuario"];
    _nombreCompleto = payload["nombre_completo"];
    
    notifyListeners();
  }

  // Clear session upon logout (HU-03)
  Future<void> cerrarSesion() async {
    await _storage.delete(key: "auth_token");
    _token = null;
    _role = null;
    _username = null;
    _nombreCompleto = null;
    notifyListeners();
  }
}
