import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/session_manager.dart';

enum SeccionApp { vuelos, reservas }

/// Barra superior de la app (logo, navegación y menú de cuenta).
class BarraSuperior extends StatelessWidget {
  final SeccionApp actual;
  final VoidCallback? onVuelos;
  final VoidCallback? onReservas;
  final VoidCallback onCerrarSesion;

  /// Solo se pasa cuando el usuario es administrador (temporal, hasta
  /// que diseñemos la vista del administrador).
  final VoidCallback? onCrearVuelo;

  const BarraSuperior({
    super.key,
    required this.actual,
    required this.onCerrarSesion,
    this.onVuelos,
    this.onReservas,
    this.onCrearVuelo,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    final completo = session.nombreCompleto?.trim() ?? '';
    final nombre =
        completo.isNotEmpty ? completo : (session.username ?? 'Usuario');

    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1248),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 64,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final compacto = c.maxWidth < 620;
                    return Row(
                      children: [
                        _Logo(compacto: compacto, onTap: onVuelos),
                        SizedBox(width: compacto ? 12 : 32),
                        _EnlaceNav(
                          texto: 'Vuelos',
                          activo: actual == SeccionApp.vuelos,
                          onTap: onVuelos,
                        ),
                        const SizedBox(width: 20),
                        _EnlaceNav(
                          texto: compacto ? 'Reservas' : 'Mis reservas',
                          activo: actual == SeccionApp.reservas,
                          onTap: onReservas,
                        ),
                        if (onCrearVuelo != null) ...[
                          const SizedBox(width: 20),
                          _EnlaceNav(
                              texto: 'Crear vuelo',
                              activo: false,
                              onTap: onCrearVuelo),
                        ],
                        const Spacer(),
                        _MenuCuenta(
                          nombre: nombre,
                          usuario: session.username,
                          compacto: compacto,
                          onReservas: onReservas,
                          onCerrarSesion: onCerrarSesion,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final bool compacto;
  final VoidCallback? onTap;

  const _Logo({required this.compacto, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          if (!compacto) ...[
            const SizedBox(width: 10),
            const Text(
              'AeroTech',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnlaceNav extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback? onTap;

  const _EnlaceNav({required this.texto, required this.activo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      selected: activo,
      child: InkWell(
        onTap: activo ? null : onTap,
        hoverColor: Colors.white.withValues(alpha: 0.06),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: activo ? const Color(0xFFD9B8A0) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? Colors.white : const Color(0xFFE8DCD2),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCuenta extends StatelessWidget {
  final String nombre;
  final String? usuario;
  final bool compacto;
  final VoidCallback? onReservas;
  final VoidCallback onCerrarSesion;

  const _MenuCuenta({
    required this.nombre,
    required this.usuario,
    required this.compacto,
    required this.onCerrarSesion,
    this.onReservas,
  });

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

  String get _primerNombre {
    final p = nombre.split(RegExp(r'\s+')).first;
    if (p.isEmpty) return nombre;
    return p[0].toUpperCase() + p.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menú de cuenta',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (valor) {
        if (valor == 'reservas') onReservas?.call();
        if (valor == 'salir') onCerrarSesion();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (usuario != null)
                Text(
                  '@$usuario',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (onReservas != null)
          const PopupMenuItem<String>(
            value: 'reservas',
            child: Row(
              children: [
                Icon(Icons.confirmation_number_outlined,
                    size: 20, color: AppColors.secondary),
                SizedBox(width: 12),
                Text('Mis reservas'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'salir',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: AppColors.error),
              SizedBox(width: 12),
              Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.fromLTRB(5, 5, compacto ? 5 : 12, 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFD9B8A0),
              child: Text(
                _iniciales,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!compacto) ...[
              const SizedBox(width: 10),
              Text(
                _primerNombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
