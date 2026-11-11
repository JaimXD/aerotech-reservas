/// Datos de la cuenta del usuario que inició sesión.
class Perfil {
  final int id;
  final String usuario;
  final String nombreCompleto;
  final String correo;
  final String rol;
  final bool correoVerificado;
  final DateTime? fechaCreacion;

  const Perfil({
    required this.id,
    required this.usuario,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.correoVerificado,
    required this.fechaCreacion,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
        id: json['id'],
        usuario: json['usuario'] ?? '',
        nombreCompleto: json['nombre_completo'] ?? '',
        correo: json['correo'] ?? '',
        rol: json['rol'] ?? 'cliente',
        correoVerificado: json['correo_verificado'] == true,
        fechaCreacion: DateTime.tryParse(json['fecha_creacion'] ?? ''),
      );

  bool get esAdmin => rol.toLowerCase() == 'admin';

  String get tipoCuenta => esAdmin ? 'Administrador' : 'Cliente';

  /// "JM" a partir de "Jaim Mariño".
  String get iniciales {
    final base = nombreCompleto.trim().isEmpty ? usuario : nombreCompleto;
    final partes =
        base.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      final p = partes.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }
}
