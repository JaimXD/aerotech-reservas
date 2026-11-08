import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../services/registro_service.dart';
import '../widgets/registro_layout.dart';
import 'verificar_correo_page.dart';

/// Registro · Paso 1 de 3: el usuario indica su correo y recibe un código.
class RegistroCorreoPage extends StatefulWidget {
  final String correoInicial;

  const RegistroCorreoPage({super.key, this.correoInicial = ''});

  @override
  State<RegistroCorreoPage> createState() => _RegistroCorreoPageState();
}

class _RegistroCorreoPageState extends State<RegistroCorreoPage> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _registro = RegistroService();

  static final RegExp _caracterCorreo = RegExp(r'[A-Za-z0-9._%+@\-]');
  static final RegExp _correoValido = RegExp(
    r'^[A-Za-z0-9_%+\-]+(?:\.[A-Za-z0-9_%+\-]+)*@'
    r'[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
  );

  bool _cargando = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _correoCtrl.text = widget.correoInicial;
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  String? _validarCorreo(String? valor) {
    final correo = (valor ?? '').trim();
    if (correo.isEmpty) return 'Ingresa tu correo electrónico.';
    if (correo.length > 100) return 'Máximo 100 caracteres.';
    if (!_correoValido.hasMatch(correo)) {
      return 'Escribe un correo válido, por ejemplo nombre@dominio.com.';
    }
    return null;
  }

  Future<void> _continuar() async {
    if (_cargando) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final correo = _correoCtrl.text.trim().toLowerCase();
    setState(() {
      _cargando = true;
      _error = '';
    });

    try {
      final espera = await _registro.enviarCodigo(correo);
      _irAVerificar(correo, espera);
    } on RegistroException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429 && e.reintentarEn != null) {
        // Ya se envió un código hace unos segundos: se continúa con ese.
        _irAVerificar(correo, e.reintentarEn!);
      } else {
        setState(() => _error = e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irAVerificar(String correo, int espera) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificarCorreoPage(correo: correo, reenviarEn: espera),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegistroLayout(
      paso: 1,
      icono: Icons.mail_outline_rounded,
      titulo: 'Crea tu cuenta',
      subtitulo:
          'Empieza con tu correo electrónico. Te enviaremos un código para confirmar que es tuyo.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _correoCtrl,
              enabled: !_cargando,
              autofocus: widget.correoInicial.isEmpty,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              maxLength: 100,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_caracterCorreo),
                TextInputFormatter.withFunction((anterior, nuevo) {
                  final texto = nuevo.text;
                  if ('@'.allMatches(texto).length > 1 ||
                      texto.contains('..')) {
                    return anterior;
                  }
                  return nuevo;
                }),
              ],
              onChanged: (_) {
                if (_error.isNotEmpty) setState(() => _error = '');
              },
              onFieldSubmitted: (_) => _continuar(),
              validator: _validarCorreo,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'nombre@dominio.com',
                counterText: '',
                prefixIcon:
                    const Icon(Icons.mail_outline, color: AppColors.primary),
                filled: true,
                fillColor: const Color(0xFFFDFBF9),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0D5CC)),
                ),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              AvisoError(_error),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _cargando ? null : _continuar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _cargando
                    ? const SizedBox(
                        height: 21,
                        width: 21,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continuar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _cargando
                  ? null
                  : () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('¿Ya tienes cuenta? Inicia sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
