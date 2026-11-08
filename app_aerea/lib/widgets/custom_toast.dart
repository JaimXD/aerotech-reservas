import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class CustomToast {
  CustomToast._();

  /// Parses a raw exception or error message.
  /// If the message is a JSON string, it extracts the "error" or "detalle" key.
  static String parseError(dynamic error) {
    if (error == null) return "Ocurrió un error inesperado";
    
    // Remove "Exception: " prefix if present
    String rawMessage = error.toString().replaceAll("Exception: ", "").trim();
    
    if (rawMessage.isEmpty) {
      return "Ocurrió un error inesperado";
    }

    String? extractedError;
    String? extractedDetalle;

    // Try parsing as JSON to extract friendly message from backend
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map) {
        extractedError = decoded["error"]?.toString();
        extractedDetalle = decoded["detalle"]?.toString();
        
        if (extractedError == null && extractedDetalle == null) {
          if (decoded.containsKey("mensaje")) {
            extractedError = decoded["mensaje"].toString();
          } else if (decoded.containsKey("message")) {
            extractedError = decoded["message"].toString();
          }
        }
      }
    } catch (_) {
      // If it's not JSON, we keep it as a raw string
    }

    // Format and map database/server errors to friendly descriptions
    String finalMessage = "";
    if (extractedDetalle != null && extractedDetalle.isNotEmpty) {
      finalMessage = _traducirDetalleBD(extractedDetalle);
      // Combine with high level error if helpful and not duplicate
      if (extractedError != null && extractedError.isNotEmpty && extractedError != extractedDetalle) {
        finalMessage = "$extractedError: $finalMessage";
      }
    } else if (extractedError != null && extractedError.isNotEmpty) {
      finalMessage = _traducirDetalleBD(extractedError);
    } else {
      finalMessage = _traducirDetalleBD(rawMessage);
    }

    // Handle common raw network errors
    if (rawMessage.contains("SocketException") || 
        rawMessage.contains("HttpException") || 
        rawMessage.contains("Connection failed") ||
        rawMessage.toLowerCase().contains("failed host lookup")) {
      return "Sin conexión con el servidor. Verifique su red.";
    }

    return finalMessage;
  }

  /// Translates technical/database details to user-friendly messages
  static String _traducirDetalleBD(String text) {
    String lower = text.toLowerCase();
    
    if (lower.contains("usuarios_usuario_key") || 
        lower.contains("usuario ya existe") || 
        lower.contains("usuario duplicado")) {
      return "El nombre de usuario ya está registrado.";
    }
    if (lower.contains("usuarios_correo_key") || 
        lower.contains("correo ya está registrado") || 
        lower.contains("correo electrónico duplicado")) {
      return "El correo electrónico ya está registrado.";
    }
    if (lower.contains("usuarios_cedula_key") || 
        lower.contains("cédula ya registrada") || 
        lower.contains("cédula duplicada")) {
      return "La cédula de identidad ya está registrada.";
    }
    if (lower.contains("uno o más asientos ya no están disponibles") || 
        lower.contains("uno o m\\u00e1s asientos ya no est\\u00e1n disponibles") ||
        lower.contains("asientos ya no est") ||
        lower.contains("concurrencia detectada")) {
      return "Concurrencia: Uno o más asientos seleccionados fueron reservados por otro usuario.";
    }
    if (lower.contains("credenciales incorrectas") || 
        lower.contains("credenciales inválidas") || 
        lower.contains("incorrectos") || 
        lower.contains("incorrectas")) {
      return "El usuario o la contraseña son incorrectos.";
    }
    if (lower.contains("foreign key constraint") || 
        lower.contains("restricción de clave foránea") ||
        lower.contains("viola la restricción de llave foránea")) {
      return "Referencia no válida: El registro relacionado no existe.";
    }
    
    return text;
  }

  /// Shows an error Toast (red floating pill)
  static void showError(BuildContext context, dynamic error) {
    final message = parseError(error);
    _showToast(
      context: context,
      message: message,
      backgroundColor: AppColors.error,
      icon: Icons.error_outline,
    );
  }

  /// Shows a success Toast (green floating pill)
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      backgroundColor: AppColors.success,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows a warning Toast (yellow/brown floating pill)
  static void showWarning(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      backgroundColor: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  /// Internal SnackBar-based Toast implementation
  static void _showToast({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    if (!context.mounted) return;

    // Clear previous toasts/snackbars immediately to avoid delay
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
