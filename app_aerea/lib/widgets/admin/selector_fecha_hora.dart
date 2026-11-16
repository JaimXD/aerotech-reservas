import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/formato.dart';

const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _franja = Color(0xFFEFE3D9);

/// Calendario de un solo día, en español. Devuelve null si se cierra.
Future<DateTime?> elegirFecha(
  BuildContext context, {
  required String titulo,
  DateTime? inicial,
  required DateTime primera,
  required DateTime ultima,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _Calendario(
      titulo: titulo,
      inicial: inicial == null ? null : Formato.soloFecha(inicial),
      primera: Formato.soloFecha(primera),
      ultima: Formato.soloFecha(ultima),
    ),
  );
}

/// Reloj de 24 horas con los textos en español.
Future<TimeOfDay?> elegirHora(
  BuildContext context, {
  required String titulo,
  TimeOfDay? inicial,
}) {
  return showTimePicker(
    context: context,
    initialTime: inicial ?? const TimeOfDay(hour: 8, minute: 0),
    helpText: titulo,
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    hourLabelText: 'Hora',
    minuteLabelText: 'Minutos',
    errorInvalidText: 'Hora no válida',
    // Solo el reloj: el modo teclado de Flutter deja escribir letras en la web
    initialEntryMode: TimePickerEntryMode.dialOnly,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}

class _Calendario extends StatefulWidget {
  final String titulo;
  final DateTime? inicial;
  final DateTime primera;
  final DateTime ultima;

  const _Calendario({
    required this.titulo,
    required this.inicial,
    required this.primera,
    required this.ultima,
  });

  @override
  State<_Calendario> createState() => _CalendarioState();
}

class _CalendarioState extends State<_Calendario> {
  late DateTime _mes;
  DateTime? _elegido;

  @override
  void initState() {
    super.initState();
    _elegido = widget.inicial;
    final base = _elegido ?? widget.primera;
    _mes = DateTime(base.year, base.month);
  }

  bool _valido(DateTime d) =>
      !d.isBefore(widget.primera) && !d.isAfter(widget.ultima);

  bool get _puedeAtras =>
      _mes.isAfter(DateTime(widget.primera.year, widget.primera.month));

  bool get _puedeAdelante =>
      _mes.isBefore(DateTime(widget.ultima.year, widget.ultima.month));

  @override
  Widget build(BuildContext context) {
    final dias = DateTime(_mes.year, _mes.month + 1, 0).day;
    final vacios = DateTime(_mes.year, _mes.month, 1).weekday - 1;
    final hoy = Formato.soloFecha(DateTime.now());

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                _elegido == null
                    ? 'Elige un día'
                    : Formato.fechaLarga(_elegido!),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mes anterior',
                    onPressed: _puedeAtras
                        ? () => setState(
                            () => _mes = DateTime(_mes.year, _mes.month - 1))
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(Formato.mesAnio(_mes),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    onPressed: _puedeAdelante
                        ? () => setState(
                            () => _mes = DateTime(_mes.year, _mes.month + 1))
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                children: [
                  for (final d in _diasSemana)
                    Center(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHint)),
                    ),
                  for (var i = 0; i < vacios; i++) const SizedBox.shrink(),
                  for (var n = 1; n <= dias; n++)
                    _dia(DateTime(_mes.year, _mes.month, n), hoy),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondary),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: _elegido == null
                        ? null
                        : () => Navigator.pop(context, _elegido),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dia(DateTime d, DateTime hoy) {
    final valido = _valido(d);
    final elegido = _elegido == d;
    final esHoy = d == hoy;
    return Semantics(
      button: valido,
      selected: elegido,
      label: Formato.fechaLarga(d),
      excludeSemantics: true,
      child: InkWell(
        onTap: valido ? () => setState(() => _elegido = d) : null,
        customBorder: const CircleBorder(),
        hoverColor: _franja,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: elegido ? AppColors.primary : null,
            border: esHoy && !elegido
                ? Border.all(color: AppColors.secondary)
                : null,
          ),
          child: Text('${d.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: elegido ? FontWeight.w800 : FontWeight.w500,
                color: elegido
                    ? Colors.white
                    : (valido ? AppColors.primary : AppColors.border),
              )),
        ),
      ),
    );
  }
}
