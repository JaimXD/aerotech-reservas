import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../services/registro_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/registro_layout.dart';
import 'registro_page.dart';

/// Registro · Paso 2 de 3: el usuario escribe el código que recibió.
class VerificarCorreoPage extends StatefulWidget {
  final String correo;
  final int reenviarEn;

  const VerificarCorreoPage({
    super.key,
    required this.correo,
    this.reenviarEn = 60,
  });

  @override
  State<VerificarCorreoPage> createState() => _VerificarCorreoPageState();
}

class _VerificarCorreoPageState extends State<VerificarCorreoPage> {
  final _codigoCtrl = TextEditingController();
  final _registro = RegistroService();

  bool _cargando = false;
  bool _reenviando = false;
  String _error = '';
  int _segundos = 0;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _iniciarEspera(widget.reenviarEn);
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _iniciarEspera(int segundos) {
    _temporizador?.cancel();
    _segundos = segundos;
    if (segundos <= 0) return;
    _temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _segundos--);
      if (_segundos <= 0) timer.cancel();
    });
  }

  Future<void> _verificar() async {
    if (_cargando || _reenviando) return;
    final codigo = _codigoCtrl.text;
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _error = 'Ingresa los seis dígitos del código.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = '';
    });

    try {
      final token = await _registro.verificarCodigo(widget.correo, codigo);
      if (!mounted) return;
      _temporizador?.cancel();
      // Se reemplaza esta pantalla: volver atrás desde el paso 3 no regresa al código.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RegistroPage(correo: widget.correo, tokenRegistro: token),
        ),
      );
    } on RegistroException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _codigoCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviar() async {
    if (_cargando || _reenviando || _segundos > 0) return;
    setState(() {
      _reenviando = true;
      _error = '';
    });
    try {
      final espera = await _registro.enviarCodigo(widget.correo);
      if (!mounted) return;
      CustomToast.showSuccess(context, 'Te enviamos un código nuevo.');
      setState(() {
        _codigoCtrl.clear();
        _iniciarEspera(espera);
      });
    } on RegistroException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        if (e.reintentarEn != null) _iniciarEspera(e.reintentarEn!);
      });
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando || _reenviando;

    return RegistroLayout(
      paso: 2,
      icono: Icons.mark_email_read_outlined,
      titulo: 'Revisa tu correo',
      subtitulo:
          'Enviamos un código de 6 dígitos a\n${widget.correo}\nSi no lo ves, revisa la carpeta de spam.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codigoCtrl,
            enabled: !ocupado,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            onChanged: (valor) {
              if (_error.isNotEmpty) setState(() => _error = '');
              if (valor.length == 6) _verificar();
            },
            onSubmitted: (_) => _verificar(),
            decoration: InputDecoration(
              hintText: '••••••',
              counterText: '',
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
              onPressed: ocupado ? null : _verificar,
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
                  : const Text('Verificar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: ocupado || _segundos > 0 ? null : _reenviar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_segundos > 0
                ? 'Reenviar código en $_segundos s'
                : (_reenviando ? 'Enviando...' : 'Reenviar código')),
          ),
          TextButton(
            onPressed: ocupado ? null : () => Navigator.pop(context),
            child: const Text('¿No es tu correo? Cámbialo'),
          ),
        ],
      ),
    );
  }
}
