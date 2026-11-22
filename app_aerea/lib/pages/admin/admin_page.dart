import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../widgets/admin/menu_lateral_admin.dart';
import '../../widgets/acceso.dart';
import 'panel_admin_page.dart';
import 'reservas_admin_page.dart';
import 'usuarios_admin_page.dart';
import 'vuelos_admin_page.dart';

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

  /// Cambia en cada visita para que la sección empiece desde su lista
  /// (por ejemplo, al pulsar "Vuelos" estando en el detalle de un vuelo).
  int _visita = 0;
  int? _vueloInicial;

  void _ir(SeccionAdmin seccion, {int? vuelo}) => setState(() {
        _seccion = seccion;
        _visita++;
        _vueloInicial = vuelo;
      });

  Future<void> _cerrarSesion() => Acceso.cerrarSesion(context);

  Widget _contenido() {
    switch (_seccion) {
      case SeccionAdmin.panel:
        return PanelAdminPage(
          onIrA: _ir,
          onVerVuelo: (id) => _ir(SeccionAdmin.vuelos, vuelo: id),
        );
      case SeccionAdmin.vuelos:
        return VuelosAdminPage(
          key: ValueKey('vuelos-$_visita'),
          vueloInicial: _vueloInicial,
        );
      case SeccionAdmin.reservas:
        return ReservasAdminPage(
          key: ValueKey('reservas-$_visita'),
          onVerVuelo: (id) => _ir(SeccionAdmin.vuelos, vuelo: id),
        );
      case SeccionAdmin.usuarios:
        return UsuariosAdminPage(key: ValueKey('usuarios-$_visita'));
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
