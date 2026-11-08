class LoginResponse {
  final String token;
  final String expiracion;
  final String usuario;
  final String nombreCompleto;

  LoginResponse({
    required this.token,
    required this.expiracion,
    required this.usuario,
    required this.nombreCompleto,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json["token"],
      expiracion: json["expiracion"],
      usuario: json["usuario"]["usuario"],
      nombreCompleto: json["usuario"]["nombre_completo"],
    );
  }
}
