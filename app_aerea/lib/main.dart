import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'pages/admin/admin_page.dart';
import 'pages/vuelos_page.dart';
import 'services/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Si quedó una sesión guardada (y no venció), se recupera antes de abrir.
  final session = SessionManager();
  await session.inicializarSesion();
  runApp(AeroTechApp(admin: session.isAdmin));
}

class AeroTechApp extends StatelessWidget {
  final bool admin;

  const AeroTechApp({super.key, this.admin = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroTech Reservas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Sin login de entrada: el visitante busca vuelos y la cuenta se
      // pide al elegir asientos. El administrador va directo a su panel.
      home: admin ? const AdminPage() : const VuelosPage(),
    );
  }
}
