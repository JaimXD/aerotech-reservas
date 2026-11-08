/// Datos del paso 3 del registro. El correo no se envía:
/// el backend lo toma del registro verificado asociado al token.
class UsuarioRegistro {
  final String tokenRegistro;
  final String usuario;
  final String password;
  final String nombreCompleto;
  final String cedula;

  UsuarioRegistro({
    required this.tokenRegistro,
    required this.usuario,
    required this.password,
    required this.nombreCompleto,
    required this.cedula,
  });

  Map<String, dynamic> toJson() => {
        "token_registro": tokenRegistro,
        "usuario": usuario,
        "password": password,
        "nombre_completo": nombreCompleto,
        "cedula": cedula,
      };
}
