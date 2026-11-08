import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/login_request.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../widgets/custom_toast.dart';
import 'registro_correo_page.dart';
import 'vuelos_page.dart';

/// Pantalla de acceso de AeroTech Reservas.
///
/// Mantiene los servicios y la navegacion del proyecto original.
/// Los filtros son controles de interfaz: la API tambien debe validar entradas.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final usuarioCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final _usuarioFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final AuthService authService = AuthService();
  final SessionManager sessionManager = SessionManager();

  // Usuario: letras (incluidas tildes y enes), numeros, punto, _ y guion.
  static final RegExp _usuarioPermitido = RegExp(
    r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9._-]+$',
  );
  static final RegExp _caracterUsuarioPermitido = RegExp(
    r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9._-]',
  );

  // Contraseña: se permiten espacios, letras Unicode y simbolos habituales,
  // pero se bloquean controles, caracteres invisibles y emojis comunes.
  // No se aplica trim() a la contraseña antes de autenticar.
  static final RegExp _caracterPasswordInvalido = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0E}\u{FE0F}\u{20E3}]',
    unicode: true,
  );

  bool cargando = false;
  bool _mostrarPassword = false;
  String mensajeError = '';
  AutovalidateMode _modoValidacion = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    verificarSesionActiva();
  }

  @override
  void dispose() {
    usuarioCtrl.dispose();
    passwordCtrl.dispose();
    _usuarioFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> verificarSesionActiva() async {
    try {
      final tieneSesion = await sessionManager.inicializarSesion();
      if (!mounted) return;
      if (tieneSesion) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VuelosPage()),
        );
      }
      // No se muestra «Tu sesión ha expirado» cuando simplemente se abre
      // la pantalla sin haber iniciado sesión previamente.
    } catch (_) {
      // Si no hay sesión recuperable, se muestra el formulario normalmente.
    }
  }

  String? _validarUsuario(String? valor) {
    final usuario = (valor ?? '').trim();
    if (usuario.isEmpty) return 'Ingresa tu nombre de usuario.';
    if (usuario.length > 40) return 'Máximo 40 caracteres.';
    if (!_usuarioPermitido.hasMatch(usuario)) {
      return 'Utiliza letras, números, puntos, guiones o _.';
    }
    return null;
  }

  String? _validarPassword(String? valor) {
    final password = valor ?? '';
    if (password.trim().isEmpty) return 'Ingresa tu contraseña.';
    if (password.length > 128) return 'Máximo 128 caracteres.';
    if (_caracterPasswordInvalido.hasMatch(password)) {
      return 'No se permiten emojis ni caracteres invisibles.';
    }
    return null;
  }

  Future<void> iniciarSesion() async {
    if (cargando) return;
    FocusScope.of(context).unfocus();

    final formularioValido = _formKey.currentState?.validate() ?? false;
    if (!formularioValido) {
      setState(() {
        _modoValidacion = AutovalidateMode.onUserInteraction;
        mensajeError = '';
      });
      return;
    }

    setState(() {
      cargando = true;
      mensajeError = '';
    });

    try {
      await authService.login(
        LoginRequest(
          usuario: usuarioCtrl.text.trim(),
          // No modificar la contraseña: los espacios pueden ser significativos.
          password: passwordCtrl.text,
        ),
      );

      if (!mounted) return;
      CustomToast.showSuccess(context, 'Sesión iniciada correctamente');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VuelosPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => mensajeError = CustomToast.parseError(e));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void _limpiarError() {
    if (mensajeError.isNotEmpty) setState(() => mensajeError = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final esEscritorio = constraints.maxWidth >= 1050;

          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3EDE7),
                  Color(0xFFFAF8F5),
                  Color(0xFFECE1D6)
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: esEscritorio ? 38 : 20,
                  vertical: esEscritorio ? 30 : 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (esEscritorio ? 60 : 56),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: esEscritorio
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 11, child: _panelPresentacion()),
                                const SizedBox(width: 28),
                                Expanded(flex: 10, child: _tarjetaLogin()),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _encabezadoMovil(),
                                const SizedBox(height: 24),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 480),
                                  child: _tarjetaLogin(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _panelPresentacion() {
    return Container(
      height: 590,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34241C), Color(0xFF674435), Color(0xFF966B50)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -100,
            top: -100,
            child: Container(
              height: 330,
              width: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.12), width: 2),
              ),
            ),
          ),
          Positioned(
            right: -35,
            top: 40,
            child: Container(
              height: 195,
              width: 195,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.10), width: 2),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: 115,
            child: Transform.rotate(
              angle: -0.26,
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: 245,
                color: Colors.white.withOpacity(0.075),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _logoMarca(
                        tamano: 46, fondo: Colors.white.withOpacity(0.16)),
                    const SizedBox(width: 12),
                    const Text(
                      'AEROTECH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Text(
                    'TU EXPERIENCIA DE VIAJE COMIENZA AQUÍ',
                    style: TextStyle(
                      color: Color(0xFFF2DDD0),
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Tu próximo destino\nestá más cerca.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Descubre vuelos, selecciona tus asientos y administra tus reservas desde un solo lugar.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 30),
                _ventaja(Icons.travel_explore_outlined,
                    'Explora vuelos disponibles'),
                const SizedBox(height: 16),
                _ventaja(Icons.airline_seat_recline_normal_outlined,
                    'Elige tus asientos'),
                const SizedBox(height: 16),
                _ventaja(Icons.confirmation_number_outlined,
                    'Consulta tus reservas'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.17))),
                  ),
                  child: Text(
                    'AeroTech Reservas  ·  Sistema de gestión de vuelos',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.67),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ventaja(IconData icono, String texto) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, size: 19, color: const Color(0xFFFFE8D8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _encabezadoMovil() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _logoMarca(tamano: 42, fondo: AppColors.primary),
        const SizedBox(width: 12),
        const Text(
          'AEROTECH',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontSize: 21,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _logoMarca({required double tamano, required Color fondo}) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.flight_takeoff_rounded,
          color: Colors.white, size: 25),
    );
  }

  Widget _tarjetaLogin() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFECE4DC)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.075),
            blurRadius: 35,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _modoValidacion,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EDE6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: AppColors.primary,
                  size: 27,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '¡Bienvenido de nuevo!',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Ingresa a tu cuenta para continuar con tu próximo viaje.',
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 30),
              const Text(
                'Nombre de usuario',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: usuarioCtrl,
                focusNode: _usuarioFocus,
                enabled: !cargando,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 40,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_caracterUsuarioPermitido),
                ],
                onChanged: (_) => _limpiarError(),
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: _validarUsuario,
                decoration: _decoracionCampo(
                  sugerencia: 'Ej.: usuario_123',
                  icono: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Letras, números, punto, guion y guion bajo. Sin espacios ni emojis.',
                style: TextStyle(
                    color: AppColors.textHint, fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 20),
              const Text(
                'Contraseña',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: passwordCtrl,
                focusNode: _passwordFocus,
                enabled: !cargando,
                autofillHints: const [AutofillHints.password],
                obscureText: !_mostrarPassword,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 128,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(_caracterPasswordInvalido),
                ],
                onChanged: (_) => _limpiarError(),
                onFieldSubmitted: (_) => iniciarSesion(),
                validator: _validarPassword,
                decoration: _decoracionCampo(
                  sugerencia: 'Ingresa tu contraseña',
                  icono: Icons.lock_outline_rounded,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _mostrarPassword
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    onPressed: () =>
                        setState(() => _mostrarPassword = !_mostrarPassword),
                    icon: Icon(
                      _mostrarPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Se permiten símbolos habituales; no se admiten emojis ni caracteres invisibles.',
                style: TextStyle(
                    color: AppColors.textHint, fontSize: 11, height: 1.45),
              ),
              if (mensajeError.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(13),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.22)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mensajeError,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: cargando ? null : iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: cargando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 19),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE8E0D9))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 11),
                    child: Text(
                      '¿Primera vez aquí?',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE8E0D9))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 51,
                child: OutlinedButton.icon(
                  onPressed: cargando
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegistroCorreoPage()),
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
                  label: const Text(
                    'Crear una cuenta',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'AeroTech Reservas · Aplicación de vuelos',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo({
    required String sugerencia,
    required IconData icono,
  }) {
    return InputDecoration(
      hintText: sugerencia,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
      prefixIcon: Icon(icono, color: AppColors.secondary, size: 21),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFFCFAF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2D8D0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.7),
      ),
    );
  }
}
