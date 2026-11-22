import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../pages/admin/admin_page.dart';
import '../pages/login_page.dart';
import '../pages/registro_correo_page.dart';
import '../pages/vuelos_page.dart';
import '../services/session_manager.dart';

/// Acceso por invitación, como en las aerolíneas o Booking: cualquiera
/// puede buscar vuelos y ver los asientos libres, y la cuenta se pide
/// solo cuando hace falta (elegir asientos, ver reservas o el perfil).
/// Al iniciar sesión se vuelve a donde estaba el usuario.
class Acceso {
  Acceso._();

  /// Nombre de la ruta del login, para volver a ella al terminar.
  static const rutaLogin = 'login';

  static bool get conSesion => SessionManager().token != null;

  /// Devuelve true si ya hay sesión o si el usuario la inicia ahora.
  /// [motivo] completa la frase «Para … necesitas una cuenta».
  static Future<bool> pedirSesion(BuildContext context,
      {required String motivo}) async {
    if (conSesion) return true;
    final opcion = await showDialog<_Opcion>(
      context: context,
      builder: (_) => _DialogoAcceso(motivo: motivo),
    );
    if (opcion == null || !context.mounted) return false;
    return abrirLogin(context, registrarse: opcion == _Opcion.registrarse);
  }

  /// Abre el login (y, si [registrarse], el registro encima).
  /// Termina en true cuando el usuario ya inició sesión.
  static Future<bool> abrirLogin(BuildContext context,
      {bool registrarse = false}) async {
    final nav = Navigator.of(context);
    final resultado = nav.push<bool>(MaterialPageRoute(
      settings: const RouteSettings(name: rutaLogin),
      builder: (_) => const LoginPage(),
    ));
    if (registrarse) {
      nav.push(MaterialPageRoute(builder: (_) => const RegistroCorreoPage()));
    }
    return await resultado == true && conSesion;
  }

  /// Tras iniciar sesión o crear la cuenta. El administrador va a su panel;
  /// el cliente vuelve a la pantalla desde la que abrió el login.
  static void alEntrar(BuildContext context) {
    final nav = Navigator.of(context);
    if (SessionManager().isAdmin) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminPage()),
        (_) => false,
      );
      return;
    }
    var hayLogin = false;
    nav.popUntil((r) {
      if (r.settings.name == rutaLogin) hayLogin = true;
      return hayLogin || r.isFirst;
    });
    if (hayLogin) {
      nav.pop(true);
    } else {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VuelosPage()),
        (_) => false,
      );
    }
  }

  /// Vuelve al login, si se llegó desde él (p. ej. «¿Ya tienes cuenta?»).
  static void volverAlLogin(BuildContext context) => Navigator.of(context)
      .popUntil((r) => r.settings.name == rutaLogin || r.isFirst);

  /// Cierra la sesión y vuelve a la búsqueda de vuelos como visitante.
  static Future<void> cerrarSesion(BuildContext context) async {
    final nav = Navigator.of(context);
    await SessionManager().cerrarSesion();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VuelosPage()),
      (_) => false,
    );
  }
}

enum _Opcion { entrar, registrarse }

class _DialogoAcceso extends StatelessWidget {
  final String motivo;

  const _DialogoAcceso({required this.motivo});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EDE6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_person_outlined,
                      color: AppColors.primary, size: 26),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Inicia sesión para continuar',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para $motivo necesitas una cuenta. Al entrar volverás '
                'aquí mismo para seguir con tu reserva.',
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _Opcion.entrar),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 19),
                  label: const Text('Iniciar sesión',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, _Opcion.registrarse),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
                  label: const Text('Crear una cuenta',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ahora no, seguir mirando'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
