import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/vuelo_admin.dart';
import '../../services/admin_vuelo_service.dart';
import 'admin_ui.dart';

/// Pide confirmación (escribir CANCELAR) y cancela el vuelo.
/// Devuelve el resultado, o null si el administrador se arrepiente.
Future<CancelacionVuelo?> confirmarCancelacionVuelo(
    BuildContext context, VueloAdmin vuelo) {
  return showDialog<CancelacionVuelo>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _DialogoCancelar(vuelo: vuelo),
  );
}

class _DialogoCancelar extends StatefulWidget {
  final VueloAdmin vuelo;

  const _DialogoCancelar({required this.vuelo});

  @override
  State<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends State<_DialogoCancelar> {
  static const _palabra = 'CANCELAR';
  final _texto = TextEditingController();
  bool _enviando = false;
  String? _error;

  bool get _listo => _texto.text.trim().toUpperCase() == _palabra;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _cancelar() async {
    if (!_listo || _enviando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final r = await AdminVueloService().cancelar(widget.vuelo.id);
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = mensajeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vuelo;
    final partes = <TextSpan>[];
    const negrita =
        TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary);

    if (v.reservasActivas > 0) {
      partes.addAll([
        const TextSpan(text: 'Se cancelarán las '),
        TextSpan(
            text: '${v.reservasActivas} '
                '${v.reservasActivas == 1 ? 'reserva activa' : 'reservas activas'}'
                ' (${v.vendidos} ${v.vendidos == 1 ? 'asiento' : 'asientos'})',
            style: negrita),
        const TextSpan(text: ', '),
      ]);
    } else {
      partes.add(const TextSpan(text: 'El vuelo no tiene reservas activas; '));
    }
    if (v.enCarritos > 0) {
      partes.add(TextSpan(
          text: 'se liberarán los ${v.enCarritos} asientos que están en '
              'carritos, '));
    }
    partes.add(const TextSpan(
        text: 'y el vuelo dejará de aparecer en la búsqueda de los clientes. '
            'Podrás reactivarlo más tarde, pero las reservas canceladas no '
            'se recuperan.'));

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Cancelar el vuelo #${v.id}?',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 4),
              Text('${v.ruta} · ${v.datos.aerolinea}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(children: partes),
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Escribe '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(_palabra,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ),
                  const TextSpan(text: ' para confirmar'),
                ]),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _texto,
                autofocus: true,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _cancelar(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.error)),
              ],
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  BotonSecundarioAdmin(
                    texto: 'Volver',
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                  ),
                  BotonAdmin(
                    texto: 'Cancelar vuelo',
                    color: AppColors.error,
                    cargando: _enviando,
                    onPressed: _listo ? _cancelar : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
