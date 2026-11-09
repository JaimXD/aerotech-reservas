import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/formato.dart';

const _franja = Color(0xFFEFE3D9); // rango ya elegido
const _franjaPrevia = Color(0xFFF6EEE7); // rango mientras se pasa el mouse
const _bordeSuave = Color(0xFFE6DED6);
const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Abre el selector de rango de fechas (estilo Booking / Airbnb / Google Flights).
/// Devuelve null si el usuario lo cierra sin aplicar.
Future<DateTimeRange?> mostrarSelectorFechas(
  BuildContext context, {
  DateTimeRange? inicial,
  required DateTime primeraFecha,
  required DateTime ultimaFecha,
  String titulo = 'Fechas de salida',
}) {
  return showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _SelectorFechas(
      inicial: inicial,
      primeraFecha: Formato.soloFecha(primeraFecha),
      ultimaFecha: Formato.soloFecha(ultimaFecha),
      titulo: titulo,
    ),
  );
}

class _SelectorFechas extends StatefulWidget {
  final DateTimeRange? inicial;
  final DateTime primeraFecha;
  final DateTime ultimaFecha;
  final String titulo;

  const _SelectorFechas({
    required this.inicial,
    required this.primeraFecha,
    required this.ultimaFecha,
    required this.titulo,
  });

  @override
  State<_SelectorFechas> createState() => _SelectorFechasState();
}

class _SelectorFechasState extends State<_SelectorFechas> {
  DateTime? _inicio;
  DateTime? _fin;
  DateTime? _hover;
  late DateTime _mes; // primer día del mes que se ve a la izquierda

  @override
  void initState() {
    super.initState();
    final ini = widget.inicial;
    if (ini != null) {
      _inicio = Formato.soloFecha(ini.start);
      _fin = Formato.soloFecha(ini.end);
    }
    final base = _inicio ?? widget.primeraFecha;
    _mes = DateTime(base.year, base.month);
  }

  // ── Lógica ───────────────────────────────────────────────────────

  bool get _eligiendoFin => _inicio != null && _fin == null;

  bool _seleccionable(DateTime d) =>
      !d.isBefore(widget.primeraFecha) && !d.isAfter(widget.ultimaFecha);

  /// Fin que se dibuja: el elegido o, mientras se elige, el día bajo el mouse.
  DateTime? get _finVisual {
    if (_fin != null) return _fin;
    if (_eligiendoFin && _hover != null && !_hover!.isBefore(_inicio!))
      return _hover;
    return null;
  }

  void _tocar(DateTime d) {
    setState(() {
      if (_inicio == null || _fin != null) {
        _inicio = d;
        _fin = null;
      } else if (d.isBefore(_inicio!)) {
        _inicio = d;
      } else {
        _fin = d;
      }
      _hover = null;
    });
  }

  void _borrar() => setState(() {
        _inicio = null;
        _fin = null;
        _hover = null;
      });

  void _aplicar() => Navigator.pop(
      context, DateTimeRange(start: _inicio!, end: _fin ?? _inicio!));

  DateTime _sumarMeses(DateTime m, int n) => DateTime(m.year, m.month + n);

  bool get _puedeRetroceder => _mes
      .isAfter(DateTime(widget.primeraFecha.year, widget.primeraFecha.month));

  bool _puedeAvanzar(int visibles) => _sumarMeses(_mes, visibles - 1)
      .isBefore(DateTime(widget.ultimaFecha.year, widget.ultimaFecha.month));

  // ── Interfaz ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: LayoutBuilder(
          builder: (context, c) {
            final visibles = c.maxWidth >= 640 ? 2 : 1;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _encabezado(),
                    const SizedBox(height: 16),
                    _resumen(),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < visibles; i++) ...[
                          if (i > 0) const SizedBox(width: 32),
                          Expanded(
                            child: _mesCalendario(
                              _sumarMeses(_mes, i),
                              flechaIzquierda: i == 0,
                              flechaDerecha: i == visibles - 1,
                              visibles: visibles,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _pie(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Elige desde qué día y hasta qué día quieres buscar vuelos.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _resumen() {
    return Row(
      children: [
        Expanded(
          child: _CajaFecha(
            etiqueta: 'Desde',
            valor: _inicio == null
                ? 'Elige una fecha'
                : Formato.fechaConDia(_inicio!),
            vacia: _inicio == null,
            activa: !_eligiendoFin,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CajaFecha(
            etiqueta: 'Hasta',
            valor: _fin != null
                ? Formato.fechaConDia(_fin!)
                : (_inicio == null ? '—' : 'Elige una fecha'),
            vacia: _fin == null,
            activa: _eligiendoFin,
          ),
        ),
      ],
    );
  }

  Widget _mesCalendario(
    DateTime mes, {
    required bool flechaIzquierda,
    required bool flechaDerecha,
    required int visibles,
  }) {
    final desfase = DateTime(mes.year, mes.month, 1).weekday - 1; // lunes = 0
    final diasDelMes = DateTime(mes.year, mes.month + 1, 0).day;

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              if (flechaIzquierda)
                _Flecha(
                  icono: Icons.chevron_left,
                  tooltip: 'Mes anterior',
                  onTap: _puedeRetroceder
                      ? () => setState(() => _mes = _sumarMeses(_mes, -1))
                      : null,
                )
              else
                const SizedBox(width: 40),
              Expanded(
                child: Text(
                  Formato.mesAnio(mes),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (flechaDerecha)
                _Flecha(
                  icono: Icons.chevron_right,
                  tooltip: 'Mes siguiente',
                  onTap: _puedeAvanzar(visibles)
                      ? () => setState(() => _mes = _sumarMeses(_mes, 1))
                      : null,
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final l in _diasSemana)
              Expanded(
                child: Center(
                  child: Text(
                    l,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Siempre 6 filas para que los dos meses tengan la misma altura
        for (var fila = 0; fila < 6; fila++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _celda(mes, fila * 7 + col - desfase + 1, diasDelMes),
                ),
            ],
          ),
      ],
    );
  }

  Widget _celda(DateTime mes, int numeroDia, int diasDelMes) {
    if (numeroDia < 1 || numeroDia > diasDelMes)
      return const SizedBox(height: 44);

    final d = DateTime(mes.year, mes.month, numeroDia);
    final seleccionable = _seleccionable(d);
    final finVisual = _finVisual;
    final esInicio = _inicio != null && d == _inicio;
    final esFin = finVisual != null && d == finVisual;
    final marcado = esInicio || esFin;
    final enRango = _inicio != null &&
        finVisual != null &&
        !d.isBefore(_inicio!) &&
        !d.isAfter(finVisual);
    final hayFranja = enRango && _inicio != finVisual;
    final colorFranja = _fin == null ? _franjaPrevia : _franja;
    final esHoy = d == Formato.soloFecha(DateTime.now());

    final colorTexto = marcado
        ? Colors.white
        : (seleccionable ? AppColors.primary : const Color(0xFFCBC1B9));

    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          if (hayFranja)
            Positioned.fill(
              top: 2,
              bottom: 2,
              child: Row(
                children: [
                  Expanded(
                      child: ColoredBox(
                          color: esInicio ? Colors.transparent : colorFranja)),
                  Expanded(
                      child: ColoredBox(
                          color: esFin ? Colors.transparent : colorFranja)),
                ],
              ),
            ),
          Center(
            child: MouseRegion(
              onEnter: _eligiendoFin && seleccionable
                  ? (_) => setState(() => _hover = d)
                  : null,
              child: Semantics(
                button: seleccionable,
                selected: marcado,
                label: Formato.fechaLarga(d),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: seleccionable ? () => _tocar(d) : null,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: marcado ? AppColors.primary : null,
                        border: esHoy && !marcado
                            ? Border.all(color: AppColors.secondary, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '$numeroDia',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: marcado || esHoy
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: colorTexto,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pie() {
    final String texto;
    if (_inicio == null) {
      texto = 'Elige la primera fecha de salida.';
    } else if (_fin == null) {
      texto =
          'Ahora elige la última fecha, o aplica solo el ${Formato.fechaConDia(_inicio!)}.';
    } else {
      final dias = (_fin!.difference(_inicio!).inHours / 24).round() + 1;
      texto = dias == 1 ? '1 día seleccionado' : '$dias días seleccionados';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: _inicio == null ? null : _borrar,
          style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
          child: const Text('Borrar'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _inicio == null ? null : _aplicar,
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

// ── Piezas pequeñas ───────────────────────────────────────────────

class _CajaFecha extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool vacia;
  final bool activa;

  const _CajaFecha({
    required this.etiqueta,
    required this.valor,
    required this.vacia,
    required this.activa,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: activa ? const Color(0xFFFBF7F3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activa ? AppColors.secondary : _bordeSuave,
          width: activa ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: vacia ? AppColors.textSecondary : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Flecha extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onTap;

  const _Flecha({required this.icono, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(icono),
        color: AppColors.secondary,
        disabledColor: AppColors.border,
        style: IconButton.styleFrom(
          shape: const CircleBorder(side: BorderSide(color: _bordeSuave)),
        ),
      ),
    );
  }
}
