import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/session_manager.dart';

/// Secciones del panel del administrador.
enum SeccionAdmin {
  panel('Panel', Icons.dashboard_outlined, Icons.dashboard),
  vuelos('Vuelos', Icons.flight_outlined, Icons.flight),
  reservas('Reservas', Icons.confirmation_number_outlined,
      Icons.confirmation_number),
  usuarios('Usuarios', Icons.people_outline, Icons.people);

  final String titulo;
  final IconData icono;
  final IconData iconoActivo;

  const SeccionAdmin(this.titulo, this.icono, this.iconoActivo);
}

const _textoSuave = Color(0xFFE8DCD2);
const _acento = Color(0xFFD9B8A0);

/// Menú lateral oscuro del administrador (logo, secciones y cuenta).
class MenuLateralAdmin extends StatelessWidget {
  final SeccionAdmin actual;
  final ValueChanged<SeccionAdmin> onSeleccionar;
  final VoidCallback onCerrarSesion;

  const MenuLateralAdmin({
    super.key,
    required this.actual,
    required this.onSeleccionar,
    required this.onCerrarSesion,
  });

  static const double ancho = 248;

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    final nombre = (session.nombreCompleto?.trim().isNotEmpty ?? false)
        ? session.nombreCompleto!.trim()
        : (session.username ?? 'Administrador');

    return Material(
      color: AppColors.primary,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: ancho,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Logo(),
                const SizedBox(height: 26),
                for (final s in SeccionAdmin.values) ...[
                  _ItemMenu(
                    seccion: s,
                    activo: s == actual,
                    onTap: () => onSeleccionar(s),
                  ),
                  const SizedBox(height: 4),
                ],
                const Spacer(),
                Divider(color: Colors.white.withValues(alpha: 0.14)),
                const SizedBox(height: 8),
                _Cuenta(nombre: nombre, usuario: session.username),
                const SizedBox(height: 6),
                _BotonSalir(onTap: onCerrarSesion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AeroTech',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text('ADMINISTRADOR',
                  style: TextStyle(
                      color: _acento,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final SeccionAdmin seccion;
  final bool activo;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.seccion,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      child: Material(
        color: activo ? _acento.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(activo ? seccion.iconoActivo : seccion.icono,
                      size: 20, color: activo ? Colors.white : _textoSuave),
                  const SizedBox(width: 12),
                  Text(
                    seccion.titulo,
                    style: TextStyle(
                      color: activo ? Colors.white : _textoSuave,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cuenta extends StatelessWidget {
  final String nombre;
  final String? usuario;

  const _Cuenta({required this.nombre, required this.usuario});

  String get _iniciales {
    final partes =
        nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      final p = partes.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: _acento,
            child: Text(_iniciales,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (usuario != null)
                  Text('@$usuario',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textoSuave, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSalir extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonSalir({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: const SizedBox(
        height: 44,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Color(0xFFFFB4A9)),
              SizedBox(width: 10),
              Text('Cerrar sesión',
                  style: TextStyle(
                      color: Color(0xFFFFB4A9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
