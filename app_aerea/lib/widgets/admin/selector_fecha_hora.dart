import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Hora de 24 horas escrita con el teclado: dos casillas "HH : MM" que solo
/// aceptan números (máximo 2 dígitos). Devuelve null si se cancela.
Future<TimeOfDay?> elegirHora(
  BuildContext context, {
  required String titulo,
  TimeOfDay? inicial,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _DialogoHora(
      titulo: titulo,
      inicial: inicial ?? const TimeOfDay(hour: 8, minute: 0),
    ),
  );
}

class _DialogoHora extends StatefulWidget {
  final String titulo;
  final TimeOfDay inicial;

  const _DialogoHora({required this.titulo, required this.inicial});

  @override
  State<_DialogoHora> createState() => _DialogoHoraState();
}

class _DialogoHoraState extends State<_DialogoHora> {
  late final _hora = TextEditingController(text: _dos(widget.inicial.hour));
  late final _minutos =
      TextEditingController(text: _dos(widget.inicial.minute));
  final _focoHora = FocusNode();
  final _focoMinutos = FocusNode();

  static String _dos(int n) => n.toString().padLeft(2, '0');

  int? get _h => int.tryParse(_hora.text);
  int? get _m => int.tryParse(_minutos.text);
  bool get _horaOk => _h != null && _h! <= 23;
  bool get _minutosOk => _m != null && _m! <= 59;

  @override
  void initState() {
    super.initState();
    // Al entrar a una casilla se selecciona su contenido para reemplazarlo
    for (final (foco, c) in [(_focoHora, _hora), (_focoMinutos, _minutos)]) {
      foco.addListener(() {
        if (foco.hasFocus) {
          c.selection =
              TextSelection(baseOffset: 0, extentOffset: c.text.length);
        }
        setState(() {});
      });
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focoHora.requestFocus());
  }

  @override
  void dispose() {
    _hora.dispose();
    _minutos.dispose();
    _focoHora.dispose();
    _focoMinutos.dispose();
    super.dispose();
  }

  void _aceptar() {
    if (!_horaOk || !_minutosOk) return;
    Navigator.pop(context, TimeOfDay(hour: _h!, minute: _m!));
  }

  @override
  Widget build(BuildContext context) {
    // Vacía: solo se desactiva Aceptar. Fuera de rango: se avisa en rojo.
    final error = _h != null && !_horaOk
        ? 'La hora va de 00 a 23'
        : (_m != null && !_minutosOk ? 'Los minutos van de 00 a 59' : null);
    final lista = _horaOk && _minutosOk;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Casilla(
                      controller: _hora,
                      foco: _focoHora,
                      etiqueta: 'Hora',
                      valida: _hora.text.isEmpty || _horaOk,
                      // Con 2 dígitos válidos pasa sola a los minutos
                      onChanged: (t) {
                        setState(() {});
                        if (t.length == 2 && _horaOk) {
                          _focoMinutos.requestFocus();
                        }
                      },
                      onSubmitted: (_) => _focoMinutos.requestFocus(),
                    ),
                  ),
                  const SizedBox(
                    width: 28,
                    height: 80,
                    child: Center(
                      child: Text(':',
                          style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary)),
                    ),
                  ),
                  Expanded(
                    child: _Casilla(
                      controller: _minutos,
                      foco: _focoMinutos,
                      etiqueta: 'Minutos',
                      valida: _minutos.text.isEmpty || _minutosOk,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _aceptar(),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 22,
                child: error == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(error,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.error)),
                      ),
              ),
              const SizedBox(height: 6),
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
                    onPressed: lista ? _aceptar : null,
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
}

/// Casilla grande de 2 dígitos (solo números).
class _Casilla extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode foco;
  final String etiqueta;
  final bool valida;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _Casilla({
    required this.controller,
    required this.foco,
    required this.etiqueta,
    required this.valida,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final activa = foco.hasFocus;
    final borde = !valida
        ? AppColors.error
        : (activa ? AppColors.primary : AppColors.border);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          // Resaltado de la selección acorde a la casilla (no el morado por defecto)
          child: TextSelectionTheme(
            data: TextSelectionThemeData(
              selectionColor: activa
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.secondary.withValues(alpha: 0.25),
            ),
            child: TextField(
              controller: controller,
              focusNode: foco,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              textAlign: TextAlign.center,
              // Solo números y como máximo 2
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: activa ? Colors.white : AppColors.primary,
              style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  color: activa
                      ? Colors.white
                      : (valida ? AppColors.primary : AppColors.error)),
              decoration: InputDecoration(
                filled: true,
                // Fuera de rango: rojo (oscuro si está activa, claro si no)
                fillColor: !valida
                    ? (activa ? AppColors.error : AppColors.errorLight)
                    : (activa ? AppColors.primary : const Color(0xFFF4EDE6)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borde, width: valida ? 1 : 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borde, width: 2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(etiqueta,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
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
