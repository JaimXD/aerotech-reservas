import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/usuario_registro.dart';
import '../services/registro_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/registro_layout.dart';
import 'registro_correo_page.dart';
import 'vuelos_page.dart';

class RegistroPage extends StatefulWidget {
  final String correo;
  final String tokenRegistro;

  const RegistroPage(
      {super.key, required this.correo, required this.tokenRegistro});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _formKey = GlobalKey<FormState>();
  final usuarioCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmarCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final cedulaCtrl = TextEditingController();
  final RegistroService registroService = RegistroService();

  final _nombreFocus = FocusNode();
  final _usuarioFocus = FocusNode();
  final _cedulaFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmarFocus = FocusNode();

  // Igual que el login mejorado: sin espacios, emojis ni simbolos ajenos.
  static final RegExp _caracterUsuario =
      RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9._-]');
  static final RegExp _usuarioValido =
      RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9._-]+$');

  // Nombres en espanol: letras, espacios, apostrofes y guiones.
  static final RegExp _caracterNombre = RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ '’\-]");
  static final RegExp _nombreValido =
      RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:[ '’\-]+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$");

  // Evita emojis, controles e invisibles. Coincide con el login mejorado.
  // Se conservan letras, numeros, espacios y simbolos de contrasena.
  static final RegExp _passwordInvalido = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0E}\u{FE0F}\u{20E3}]',
    unicode: true,
  );

  bool cargando = false;
  bool _mostrarPassword = false;
  bool _mostrarConfirmar = false;
  String mensaje = '';
  AutovalidateMode _modoValidacion = AutovalidateMode.onUserInteraction;

  @override
  void dispose() {
    usuarioCtrl.dispose();
    passwordCtrl.dispose();
    confirmarCtrl.dispose();
    nombreCtrl.dispose();
    cedulaCtrl.dispose();
    _nombreFocus.dispose();
    _usuarioFocus.dispose();
    _cedulaFocus.dispose();
    _passwordFocus.dispose();
    _confirmarFocus.dispose();
    super.dispose();
  }

  void _alEditar(String _) {
    if (mensaje.isNotEmpty) setState(() => mensaje = '');
  }

  String? _validarNombre(String? valor) {
    final nombre = (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nombre.isEmpty) return 'Ingresa tu nombre completo.';
    if (nombre.length < 3) return 'Escribe al menos 3 caracteres.';
    if (nombre.length > 80) return 'Máximo 80 caracteres.';
    if (!_nombreValido.hasMatch(nombre)) {
      return 'Usa letras y separadores normales (espacio, guion o apóstrofe).';
    }
    return null;
  }

  String? _validarUsuario(String? valor) {
    final usuario = (valor ?? '').trim();
    if (usuario.isEmpty) return 'Ingresa un nombre de usuario.';
    if (usuario.length < 3) return 'Mínimo 3 caracteres.';
    if (usuario.length > 40) return 'Máximo 40 caracteres.';
    if (!_usuarioValido.hasMatch(usuario)) {
      return 'Solo letras, números, puntos, guiones y guion bajo.';
    }
    return null;
  }

  String? _validarCedula(String? valor) {
    final cedula = (valor ?? '').trim();
    if (cedula.isEmpty) return 'Ingresa tu cédula.';
    if (cedula.length != 10) return 'La cédula debe tener 10 dígitos.';
    if (!_cedulaEcuatorianaValida(cedula)) {
      return 'La cédula ecuatoriana no supera la validación.';
    }
    return null;
  }

  bool _cedulaEcuatorianaValida(String cedula) {
    if (!RegExp(r'^\d{10}$').hasMatch(cedula)) return false;
    final provincia = int.parse(cedula.substring(0, 2));
    if (!((provincia >= 1 && provincia <= 24) || provincia == 30)) {
      return false;
    }
    if (int.parse(cedula[2]) >= 6) return false;

    int suma = 0;
    for (var i = 0; i < 9; i++) {
      var digito = int.parse(cedula[i]);
      if (i.isEven) {
        digito *= 2;
        if (digito > 9) digito -= 9;
      }
      suma += digito;
    }
    final verificador = (10 - (suma % 10)) % 10;
    return verificador == int.parse(cedula[9]);
  }

  String? _validarPassword(String? valor) {
    final password = valor ?? '';
    if (password.isEmpty) return 'Ingresa una contraseña.';
    if (password.trim().isEmpty) return 'No uses solo espacios.';
    if (password.length < 8) return 'Mínimo 8 caracteres.';
    if (password.length > 128) return 'Máximo 128 caracteres.';
    if (_passwordInvalido.hasMatch(password)) {
      return 'No se permiten emojis ni caracteres invisibles.';
    }
    if (!RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Incluye al menos una letra y un número.';
    }
    return null;
  }

  String? _validarConfirmacion(String? valor) {
    if ((valor ?? '').isEmpty) return 'Confirma tu contraseña.';
    if (_passwordInvalido.hasMatch(valor!)) return 'No se permiten emojis.';
    if (valor != passwordCtrl.text) return 'Las contraseñas no coinciden.';
    return null;
  }

  Future<void> registrar() async {
    if (cargando) return;
    FocusScope.of(context).unfocus();
    final valido = _formKey.currentState?.validate() ?? false;
    if (!valido) {
      setState(() {
        _modoValidacion = AutovalidateMode.onUserInteraction;
        mensaje = 'Revisa los campos marcados antes de crear tu cuenta.';
      });
      return;
    }

    setState(() {
      cargando = true;
      mensaje = '';
    });

    try {
      await registroService.completar(
        UsuarioRegistro(
          tokenRegistro: widget.tokenRegistro,
          usuario: usuarioCtrl.text.trim(),
          // IMPORTANTE: no hacer trim() a una contraseña.
          password: passwordCtrl.text,
          nombreCompleto:
              nombreCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          cedula: cedulaCtrl.text.trim(),
        ),
      );

      if (!mounted) return;
      CustomToast.showSuccess(context, '¡Bienvenido! Tu cuenta fue creada.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const VuelosPage()),
        (_) => false,
      );
    } on RegistroException catch (e) {
      if (!mounted) return;
      if (e.verificacionExpirada) {
        await _reiniciarPorExpiracion();
        return;
      }
      // 409: usuario o cédula en uso. El token sigue válido para corregir y reintentar.
      setState(() => mensaje = e.mensaje);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _cancelarRegistro() async {
    if (cargando) return;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el registro?'),
        content: const Text(
          'Tu cuenta aún no se ha creado. Si sales ahora, tendrás que verificar tu correo de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir registrándome'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _reiniciarPorExpiracion() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificación expirada'),
        content: const Text(
          'Pasó demasiado tiempo desde que verificaste tu correo. '
          'Por seguridad, vuelve a verificarlo para crear tu cuenta.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido')),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => RegistroCorreoPage(correoInicial: widget.correo)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelarRegistro();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final escritorio = constraints.maxWidth >= 1080;
            return Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF3EDE7),
                    Color(0xFFFAF8F5),
                    Color(0xFFECE1D6),
                  ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: escritorio ? 34 : 16,
                    vertical: escritorio ? 26 : 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1230),
                      child: escritorio
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 8, child: _panelPresentacion()),
                                const SizedBox(width: 28),
                                Expanded(flex: 12, child: _tarjetaRegistro()),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _encabezadoCompacto(),
                                const SizedBox(height: 22),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 650),
                                  child: _tarjetaRegistro(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _encabezadoCompacto() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'AEROTECH',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _panelPresentacion() {
    return Container(
      constraints: const BoxConstraints(minHeight: 680),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34241C), Color(0xFF674435), Color(0xFF966B50)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.16),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -115,
            right: -130,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.13), width: 2),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -45,
            child: Icon(
              Icons.flight_takeoff_rounded,
              size: 220,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'AEROTECH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 105),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Text(
                    'TU PRÓXIMA AVENTURA EMPIEZA AQUÍ',
                    style: TextStyle(
                      color: Color(0xFFF2DDD0),
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Crea tu cuenta.\nDescubre el mundo.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Un solo lugar para buscar vuelos, elegir tus asientos y gestionar tus reservas.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 36),
                _ventaja(
                    Icons.verified_user_outlined, 'Tu cuenta, tus reservas'),
                const SizedBox(height: 17),
                _ventaja(Icons.travel_explore_rounded, 'Explora destinos'),
                const SizedBox(height: 17),
                _ventaja(Icons.airline_seat_recline_normal_outlined,
                    'Selecciona tu asiento'),
                const SizedBox(height: 80),
                Text(
                  'AeroTech Reservas  ·  Gestión de vuelos',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.66),
                    fontSize: 12,
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
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icono, color: const Color(0xFFFFE8D8), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaRegistro() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PasosRegistro(actual: 3),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EDE6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: cargando ? null : _cancelarRegistro,
                    icon: const Icon(Icons.arrow_back_rounded, size: 17),
                    label: const Text('Volver'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Completa tu perfil',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Último paso: tus datos personales y una contraseña.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _tituloSeccion(Icons.badge_outlined, 'Datos personales'),
              const SizedBox(height: 17),
              _etiqueta('Nombre completo'),
              const SizedBox(height: 8),
              TextFormField(
                controller: nombreCtrl,
                focusNode: _nombreFocus,
                enabled: !cargando,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                maxLength: 80,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_caracterNombre),
                ],
                onChanged: _alEditar,
                onFieldSubmitted: (_) => _usuarioFocus.requestFocus(),
                validator: _validarNombre,
                decoration: _decoracionCampo(
                  'Nombres y apellidos',
                  Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 11),
              _filaAdaptable(
                izquierda: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _etiqueta('Usuario'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: usuarioCtrl,
                      focusNode: _usuarioFocus,
                      enabled: !cargando,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      maxLength: 40,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(_caracterUsuario),
                      ],
                      onChanged: _alEditar,
                      onFieldSubmitted: (_) => _cedulaFocus.requestFocus(),
                      validator: _validarUsuario,
                      decoration: _decoracionCampo(
                        'Ej.: viajero_123',
                        Icons.alternate_email_rounded,
                      ),
                    ),
                  ],
                ),
                derecha: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _etiqueta('Cédula ecuatoriana'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: cedulaCtrl,
                      focusNode: _cedulaFocus,
                      enabled: !cargando,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _alEditar,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      validator: _validarCedula,
                      decoration: _decoracionCampo(
                        '10 dígitos',
                        Icons.credit_card_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              _etiqueta('Correo electrónico'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFCFE3C8)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.correo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Text(
                      'Verificado',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _tituloSeccion(
                  Icons.lock_outline_rounded, 'Seguridad de la cuenta'),
              const SizedBox(height: 17),
              _etiqueta('Contraseña'),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordCtrl,
                focusNode: _passwordFocus,
                enabled: !cargando,
                autofillHints: const [AutofillHints.newPassword],
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: !_mostrarPassword,
                maxLength: 128,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(_passwordInvalido),
                ],
                onChanged: _alEditar,
                onFieldSubmitted: (_) => _confirmarFocus.requestFocus(),
                validator: _validarPassword,
                decoration: _decoracionCampo(
                  'Mínimo 8 caracteres',
                  Icons.lock_outline_rounded,
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
                'Usa al menos 8 caracteres, una letra y un número. Se permiten símbolos, no emojis.',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 15),
              _etiqueta('Confirmar contraseña'),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmarCtrl,
                focusNode: _confirmarFocus,
                enabled: !cargando,
                autofillHints: const [AutofillHints.newPassword],
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: !_mostrarConfirmar,
                maxLength: 128,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(_passwordInvalido),
                ],
                onChanged: _alEditar,
                onFieldSubmitted: (_) => registrar(),
                validator: _validarConfirmacion,
                decoration: _decoracionCampo(
                  'Vuelve a escribir tu contraseña',
                  Icons.verified_user_outlined,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _mostrarConfirmar
                        ? 'Ocultar confirmación'
                        : 'Mostrar confirmación',
                    onPressed: () =>
                        setState(() => _mostrarConfirmar = !_mostrarConfirmar),
                    icon: Icon(
                      _mostrarConfirmar
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (mensaje.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.23)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mensaje,
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
              const SizedBox(height: 23),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: cargando ? null : registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: cargando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Crear mi cuenta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: cargando ? null : _cancelarRegistro,
                  child: const Text('Cancelar registro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tituloSeccion(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, color: AppColors.secondary, size: 18),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _filaAdaptable({
    required Widget izquierda,
    required Widget derecha,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 490) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [izquierda, const SizedBox(height: 13), derecha],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: izquierda),
            const SizedBox(width: 16),
            Expanded(child: derecha),
          ],
        );
      },
    );
  }

  InputDecoration _decoracionCampo(String sugerencia, IconData icono) {
    return InputDecoration(
      hintText: sugerencia,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
      prefixIcon: Icon(icono, color: AppColors.secondary, size: 20),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFFCFAF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2D8D0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.error, width: 1.7),
      ),
    );
  }
}
