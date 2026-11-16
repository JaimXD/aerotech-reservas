/// Filtro "Rol".
enum RolFiltro {
  todos(null, 'Rol: Todos'),
  clientes('user', 'Clientes'),
  administradores('admin', 'Administradores');

  final String? api;
  final String etiqueta;

  const RolFiltro(this.api, this.etiqueta);
}

/// Filtro "Estado".
enum EstadoCuentaFiltro {
  todos(null, 'Estado: Todos'),
  activos('activo', 'Activos'),
  suspendidos('suspendido', 'Suspendidos');

  final String? api;
  final String etiqueta;

  const EstadoCuentaFiltro(this.api, this.etiqueta);
}

/// Una cuenta vista por el administrador.
class UsuarioAdmin {
  final int id;
  final String usuario;
  final String nombre;
  final String correo;
  final String rol;
  final bool verificado;
  final bool activo;

  /// Reservas activas.
  final int reservas;
  final DateTime? desde;

  /// La cuenta del administrador que está usando la app.
  final bool esYo;

  UsuarioAdmin({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.verificado,
    required this.activo,
    required this.reservas,
    required this.desde,
    required this.esYo,
  });

  factory UsuarioAdmin.fromJson(Map<String, dynamic> j) => UsuarioAdmin(
        id: j['id'],
        usuario: j['usuario'] ?? '',
        nombre: j['nombre'] ?? '',
        correo: j['correo'] ?? '',
        rol: j['rol'] ?? 'user',
        verificado: j['verificado'] == true,
        activo: j['activo'] != false,
        reservas: (j['reservas'] as num? ?? 0).toInt(),
        desde: j['desde'] == null ? null : DateTime.parse(j['desde']),
        esYo: j['es_yo'] == true,
      );

  bool get esAdmin => rol == 'admin';

  /// "MG" para "María Gómez" y "AD" para "Administrador".
  String get iniciales {
    final partes =
        nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final base = partes.length >= 2
        ? '${partes[0][0]}${partes[1][0]}'
        : (partes.isNotEmpty ? partes[0] : usuario);
    if (base.isEmpty) return '?';
    return base.substring(0, base.length < 2 ? base.length : 2).toUpperCase();
  }
}

/// Respuesta de GET /api/admin/usuarios.
class ListaUsuariosAdmin {
  final List<UsuarioAdmin> usuarios;
  final int total;
  final int pagina;
  final int porPagina;

  ListaUsuariosAdmin({
    required this.usuarios,
    required this.total,
    required this.pagina,
    required this.porPagina,
  });

  factory ListaUsuariosAdmin.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num? ?? 0).toInt();
    return ListaUsuariosAdmin(
      usuarios: (j['usuarios'] as List)
          .map((e) => UsuarioAdmin.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: n(j['total']),
      pagina: n(j['pagina']),
      porPagina: n(j['por_pagina']),
    );
  }

  int get paginas => total == 0 ? 1 : (total / porPagina).ceil();
}
