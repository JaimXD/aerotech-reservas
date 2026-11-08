class LoginRequest {
  final String usuario;
  final String password;

  LoginRequest({required this.usuario, required this.password});

  Map<String, dynamic> toJson() => {
        "usuario": usuario,
        "password": password,
      };
}
