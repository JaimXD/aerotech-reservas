import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../services/session_manager.dart';
import '../../widgets/admin/menu_lateral_admin.dart';
import '../login_page.dart';
import 'panel_admin_page.dart';

/// Estructura del administrador: menú lateral + la sección elegida.
///
/// En pantallas anchas el menú queda fijo a la izquierda; en el móvil se
/// abre desde el botón ☰ de la barra superior.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const double _anchoMinimoMenuFijo = 900;

  SeccionAdmin _seccion = SeccionAdmin.panel;

  void _ir(SeccionAdmin seccion) => setState(() => _seccion = seccion);

  Future<void> _cerrarSesion() async {
    await SessionManager().cerrarSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _contenido() {
    switch (_seccion) {
      case SeccionAdmin.panel:
        return PanelAdminPage(onIrA: _ir);
      case SeccionAdmin.vuelos:
      case SeccionAdmin.reservas:
      case SeccionAdmin.usuarios:
        // Se reemplazan en las siguientes secciones.
        return _EnConstruccion(seccion: _seccion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final menuFijo = c.maxWidth >= _anchoMinimoMenuFijo;

        if (menuFijo) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuLateralAdmin(
                  actual: _seccion,
                  onSeleccionar: _ir,
                  onCerrarSesion: _cerrarSesion,
                ),
                Expanded(child: _contenido()),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text(_seccion.titulo),
          ),
          drawer: Drawer(
            width: MenuLateralAdmin.ancho,
            backgroundColor: AppColors.primary,
            child: Builder(
              builder: (drawerContext) => MenuLateralAdmin(
                actual: _seccion,
                onSeleccionar: (s) {
                  Navigator.pop(drawerContext); // cierra el menú
                  _ir(s);
                },
                onCerrarSesion: _cerrarSesion,
              ),
            ),
          ),
          body: _contenido(),
        );
      },
    );
  }
}

/// Marcador temporal para las secciones que aún no se implementan.
class _EnConstruccion extends StatelessWidget {
  final SeccionAdmin seccion;

  const _EnConstruccion({required this.seccion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(seccion.icono, size: 44, color: AppColors.secondary),
            const SizedBox(height: 14),
            Text(
              seccion.titulo,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Esta sección se agregará en el siguiente paso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
