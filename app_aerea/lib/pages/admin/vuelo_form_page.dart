import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../models/vuelo.dart';
import '../../models/vuelo_admin.dart';
import '../../services/admin_vuelo_service.dart';
import '../../utils/entradas.dart';
import '../../utils/formato.dart';
import '../../widgets/admin/admin_ui.dart';
import '../../widgets/admin/selector_fecha_hora.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/vuelo_card.dart';

/// Formulario para crear, editar o duplicar un vuelo.
/// Al guardar, cierra la página devolviendo el [VueloAdmin] guardado.
class VueloFormPage extends StatefulWidget {
  /// Vuelo que se edita (null para crear uno nuevo).
  final VueloAdmin? vuelo;

  /// Vuelo que se copia al duplicar (sin las fechas).
  final VueloAdmin? copia;

  /// Sugerencias para los campos de texto.
  final List<String> aerolineas;
  final List<String> ciudades;

  const VueloFormPage({
    super.key,
    this.vuelo,
    this.copia,
    this.aerolineas = const [],
    this.ciudades = const [],
  });

  @override
  State<VueloFormPage> createState() => _VueloFormPageState();
}

class _VueloFormPageState extends State<VueloFormPage> {
  static const _letras = 'ABCDEF';
  static const _maxFilas = 60;

  final _service = AdminVueloService();
  final _aerolinea = TextEditingController();
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _precio = TextEditingController();
  final _filas = TextEditingController(text: '5');

  DateTime? _fechaSalida;
  TimeOfDay? _horaSalida;
  DateTime? _fechaLlegada;
  TimeOfDay? _horaLlegada;
  int _porFila = 4;

  bool _guardando = false;
  String? _error;

  bool get _editando => widget.vuelo != null;

  /// Con reservas activas no se cambia la ruta (los pasajeros ya pagaron).
  bool get _rutaBloqueada => (widget.vuelo?.reservasActivas ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final base = widget.vuelo ?? widget.copia;
    if (base != null) {
      final d = base.datos;
      _aerolinea.text = d.aerolinea;
      _origen.text = d.origen;
      _destino.text = d.destino;
      _precio.text = d.precio.toStringAsFixed(2);
      _horaSalida = _hora(d.horaSalida);
      _horaLlegada = _hora(d.horaLlegada);
      if (base.filas > 0) _filas.text = '${base.filas}';
      if (base.asientosPorFila >= 2) _porFila = base.asientosPorFila;
      if (_editando) {
        _fechaSalida = Formato.soloFecha(d.salida);
        _fechaLlegada = Formato.soloFecha(d.llegada);
      }
    }
    for (final c in [_aerolinea, _origen, _destino, _precio, _filas]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_aerolinea, _origen, _destino, _precio, _filas]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Datos calculados ─────────────────────────────────────────────

  static TimeOfDay _hora(String hhmmss) {
    final p = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static DateTime? _unir(DateTime? f, TimeOfDay? h) => f == null || h == null
      ? null
      : DateTime(f.year, f.month, f.day, h.hour, h.minute);

  DateTime? get _salida => _unir(_fechaSalida, _horaSalida);
  DateTime? get _llegada => _unir(_fechaLlegada, _horaLlegada);
  double? get _precioValor => double.tryParse(_precio.text.trim());
  int? get _filasValor => int.tryParse(_filas.text.trim());
  int get _totalAsientos => (_filasValor ?? 0) * _porFila;

  /// Un nombre válido tiene al menos 2 letras ("Quito", no "Q" ni "-").
  static bool _nombreValido(TextEditingController c) =>
      Entradas.letras(c.text) >= 2;

  bool get _okRuta =>
      _nombreValido(_origen) &&
      _nombreValido(_destino) &&
      _origen.text.trim().toLowerCase() != _destino.text.trim().toLowerCase();
  bool get _okFecha => _salida != null && _salida!.isAfter(DateTime.now());
  bool get _okLlegada =>
      _salida != null &&
      _llegada != null &&
      _llegada!.isAfter(_salida!) &&
      _llegada!.difference(_salida!) <= const Duration(hours: 24);
  bool get _okPrecio =>
      (_precioValor ?? 0) > 0 &&
      (_precioValor ?? 0) <= Entradas.precioMaximo;
  bool get _okCabina =>
      (_filasValor ?? 0) >= 1 && (_filasValor ?? 0) <= _maxFilas;
  bool get _okAerolinea => _nombreValido(_aerolinea);

  bool get _listo =>
      _okAerolinea &&
      _okRuta &&
      _okFecha &&
      _okLlegada &&
      _okPrecio &&
      _okCabina;

  String _letrasFila(int n) {
    final l = _letras.substring(0, n).split('');
    final mitad = (n / 2).ceil();
    return '${l.sublist(0, mitad).join(' ')} · ${l.sublist(mitad).join(' ')}';
  }

  // ── Acciones ─────────────────────────────────────────────────────

  Future<void> _elegirFechaSalida() async {
    final hoy = DateTime.now();
    final f = await elegirFecha(context,
        titulo: 'Fecha de salida',
        inicial: _fechaSalida,
        primera: hoy,
        ultima: DateTime(hoy.year + 2, hoy.month, hoy.day));
    if (f == null) return;
    setState(() {
      // La llegada acompaña a la salida si quedaba antes
      if (_fechaLlegada == null ||
          _fechaLlegada!.isBefore(f) ||
          _fechaLlegada == _fechaSalida) {
        _fechaLlegada = f;
      }
      _fechaSalida = f;
    });
  }

  Future<void> _elegirFechaLlegada() async {
    final hoy = DateTime.now();
    final f = await elegirFecha(context,
        titulo: 'Fecha de llegada',
        inicial: _fechaLlegada ?? _fechaSalida,
        primera: _fechaSalida ?? hoy,
        ultima: Formato.sumarDias(_fechaSalida ?? hoy, 1));
    if (f != null) setState(() => _fechaLlegada = f);
  }

  Future<void> _elegirHoraSalida() async {
    final h = await elegirHora(context,
        titulo: 'Hora de salida', inicial: _horaSalida);
    if (h != null) setState(() => _horaSalida = h);
  }

  Future<void> _elegirHoraLlegada() async {
    final h = await elegirHora(context,
        titulo: 'Hora de llegada', inicial: _horaLlegada ?? _horaSalida);
    if (h != null) setState(() => _horaLlegada = h);
  }

  Future<void> _guardar() async {
    if (!_listo || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = {
      'aerolinea': _aerolinea.text.trim(),
      'origen': _origen.text.trim(),
      'destino': _destino.text.trim(),
      'fecha': Formato.iso(_fechaSalida!),
      'fecha_llegada': Formato.iso(_fechaLlegada!),
      'hora_salida': _hhmm(_horaSalida!),
      'hora_llegada': _hhmm(_horaLlegada!),
      'precio': _precioValor,
      'filas': _filasValor,
      'asientos_por_fila': _porFila,
    };
    try {
      final guardado = _editando
          ? await _service.actualizar(widget.vuelo!.id, datos)
          : await _service.crear(datos);
      if (!mounted) return;
      CustomToast.showSuccess(
          context,
          _editando
              ? 'Cambios guardados en el vuelo #${guardado.id}'
              : 'Vuelo #${guardado.id} creado con ${guardado.totalAsientos} asientos');
      Navigator.pop(context, guardado);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeError(e);
      });
    }
  }

  // ── Interfaz ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final titulo = _editando
        ? 'Editar vuelo #${widget.vuelo!.id}'
        : (widget.copia != null ? 'Duplicar vuelo' : 'Nuevo vuelo');

    return PaginaAdmin(
      children: [
        EncabezadoAdmin(
          migas: [
            MigaAdmin('Vuelos',
                onTap: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst)),
            if (_editando)
              MigaAdmin('#${widget.vuelo!.id}',
                  onTap: () => Navigator.pop(context)),
            MigaAdmin(_editando ? 'Editar' : titulo),
          ],
          titulo: titulo,
          subtitulo: widget.copia != null
              ? Text('Copia del vuelo #${widget.copia!.id}. Elige las nuevas '
                  'fechas.')
              : null,
          acciones: [
            BotonSecundarioAdmin(
              texto: 'Cancelar',
              onPressed: _guardando ? null : () => Navigator.pop(context),
            ),
            BotonAdmin(
              texto: _editando ? 'Guardar cambios' : 'Guardar vuelo',
              icono: Icons.check_rounded,
              cargando: _guardando,
              onPressed: _listo ? _guardar : null,
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _AvisoError(texto: _error!),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final lateral = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _vistaPrevia(),
              const SizedBox(height: 16),
              _listaRevision(),
            ],
          );
          if (c.maxWidth < 980) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_formulario(), const SizedBox(height: 16), lateral],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _formulario()),
              const SizedBox(width: 18),
              SizedBox(width: 380, child: lateral),
            ],
          );
        }),
      ],
    );
  }

  Widget _formulario() {
    final v = widget.vuelo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Seccion(
          titulo: 'Ruta',
          campos: [
            _CampoSugerencias(
              controller: _aerolinea,
              etiqueta: 'Aerolínea',
              icono: Icons.airlines_rounded,
              opciones: widget.aerolineas,
              formatos: Entradas.aerolinea,
            ),
            _CampoSugerencias(
              controller: _origen,
              etiqueta: 'Origen',
              icono: Icons.flight_takeoff_rounded,
              opciones: widget.ciudades,
              formatos: Entradas.ciudad,
              habilitado: !_rutaBloqueada,
            ),
            _CampoSugerencias(
              controller: _destino,
              etiqueta: 'Destino',
              icono: Icons.flight_land_rounded,
              opciones: widget.ciudades,
              formatos: Entradas.ciudad,
              habilitado: !_rutaBloqueada,
            ),
          ],
          nota: _rutaBloqueada
              ? 'El vuelo tiene ${v!.reservasActivas} reserva(s) activa(s): '
                  'la ruta no se puede cambiar.'
              : null,
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Horario',
          campos: [
            _CampoToque(
              etiqueta: 'Fecha de salida',
              valor: _fechaSalida == null
                  ? null
                  : Formato.fechaConAnio(_fechaSalida!),
              icono: Icons.event_rounded,
              onTap: _elegirFechaSalida,
            ),
            _CampoToque(
              etiqueta: 'Hora de salida',
              valor: _horaSalida == null ? null : _hhmm(_horaSalida!),
              icono: Icons.schedule_rounded,
              onTap: _elegirHoraSalida,
            ),
            _CampoToque(
              etiqueta: 'Fecha de llegada',
              valor: _fechaLlegada == null
                  ? null
                  : Formato.fechaConAnio(_fechaLlegada!),
              icono: Icons.event_available_rounded,
              onTap: _elegirFechaLlegada,
            ),
            _CampoToque(
              etiqueta: 'Hora de llegada',
              valor: _horaLlegada == null ? null : _hhmm(_horaLlegada!),
              icono: Icons.schedule_rounded,
              onTap: _elegirHoraLlegada,
            ),
          ],
          nota: _salida != null && _llegada != null && !_okLlegada
              ? (_llegada!.isAfter(_salida!)
                  ? 'Un vuelo no puede durar más de 24 horas.'
                  : 'La llegada debe ser después de la salida '
                      '(${_hhmm(_horaSalida!)}).')
              : (_salida != null && _llegada != null
                  ? 'Duración: ${Formato.duracion(_llegada!.difference(_salida!).inMinutes)}'
                  : null),
          notaError: _salida != null && _llegada != null && !_okLlegada,
        ),
        const SizedBox(height: 16),
        _Seccion(
          titulo: 'Precio y cabina',
          campos: [
            TextField(
              controller: _precio,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Solo números, hasta 2 decimales y máximo \$10,000
              inputFormatters: Entradas.precio,
              decoration: const InputDecoration(
                labelText: 'Precio por asiento (sin IVA)',
                helperText: 'Hasta \$10,000 · 2 decimales',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            TextField(
              controller: _filas,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(
                labelText: 'Filas',
                helperText: 'De 1 a $_maxFilas',
                prefixIcon: Icon(Icons.table_rows_outlined),
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _porFila,
              decoration: const InputDecoration(
                labelText: 'Asientos por fila',
                prefixIcon: Icon(Icons.event_seat_outlined),
              ),
              items: [
                for (var n = 2; n <= _letras.length; n++)
                  DropdownMenuItem(
                      value: n, child: Text('$n  (${_letrasFila(n)})')),
              ],
              onChanged: (n) => setState(() => _porFila = n ?? 4),
            ),
          ],
          pie: _resumenCabina(),
        ),
      ],
    );
  }

  Widget _resumenCabina() {
    final filas = _filasValor ?? 0;
    final ultimo = filas > 0 ? '$filas${_letras[_porFila - 1]}' : '';
    final v = widget.vuelo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCabeceraAdmin,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.airline_seat_recline_normal_rounded,
              color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _okCabina
                        ? '$_totalAsientos asientos'
                        : 'Indica entre 1 y $_maxFilas filas',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(
                  _editando
                      ? 'Hoy tiene ${v!.totalAsientos} (${v.vendidos} vendidos). '
                          'Puedes agregar filas; solo se quitan asientos que '
                          'no estén vendidos ni en un carrito.'
                      : (_okCabina
                          ? '1A … $ultimo · se crean automáticamente al guardar'
                          : ''),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaPrevia() {
    final completo = _okAerolinea &&
        _origen.text.trim().isNotEmpty &&
        _destino.text.trim().isNotEmpty &&
        _salida != null &&
        _llegada != null;

    return TarjetaAdmin(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Así lo verá el cliente',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          if (!completo)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              decoration: BoxDecoration(
                color: kCabeceraAdmin,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Completa la aerolínea, la ruta y el horario para ver la '
                'tarjeta del vuelo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            IgnorePointer(
              child: VueloCard(
                vuelo: Vuelo(
                  id: widget.vuelo?.id ?? 0,
                  aerolinea: _aerolinea.text.trim(),
                  origen: _origen.text.trim(),
                  destino: _destino.text.trim(),
                  fecha: Formato.iso(_fechaSalida!),
                  fechaLlegada: Formato.iso(_fechaLlegada!),
                  horaSalida: '${_hhmm(_horaSalida!)}:00',
                  horaLlegada: '${_hhmm(_horaLlegada!)}:00',
                  precio: _precioValor ?? 0,
                  asientosDisponibles: _editando
                      ? (_totalAsientos - widget.vuelo!.vendidos)
                          .clamp(0, 9999)
                      : _totalAsientos,
                ),
                onReservar: () {},
              ),
            ),
        ],
      ),
    );
  }

  Widget _listaRevision() {
    Widget item(bool ok, String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: ok ? AppColors.success : AppColors.textHint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto,
                    style: TextStyle(
                        fontSize: 14,
                        color: ok
                            ? AppColors.primary
                            : AppColors.textSecondary)),
              ),
            ],
          ),
        );

    return TarjetaAdmin(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Antes de guardar',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          item(_okAerolinea, 'Aerolínea indicada (mín. 2 letras)'),
          item(_okRuta, 'Origen y destino distintos (mín. 2 letras)'),
          item(_okFecha, 'Salida en el futuro'),
          item(_okLlegada, 'Llegada después de la salida'),
          item(_okPrecio, 'Precio mayor a \$0 y hasta \$10,000'),
          item(_okCabina, 'Entre 1 y $_maxFilas filas'),
        ],
      ),
    );
  }
}

// ───────────────────────── Piezas ─────────────────────────

/// Tarjeta con título y campos en dos columnas (una en pantallas estrechas).
class _Seccion extends StatelessWidget {
  final String titulo;
  final List<Widget> campos;
  final String? nota;
  final bool notaError;
  final Widget? pie;

  const _Seccion({
    required this.titulo,
    required this.campos,
    this.nota,
    this.notaError = false,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaAdmin(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final columnas = c.maxWidth >= 520 ? 2 : 1;
            const espacio = 14.0;
            final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
            return Wrap(
              spacing: espacio,
              runSpacing: 16,
              children: [
                for (final h in campos) SizedBox(width: ancho, child: h),
              ],
            );
          }),
          if (nota != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                    notaError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color:
                        notaError ? AppColors.error : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nota!,
                      style: TextStyle(
                          fontSize: 13,
                          color: notaError
                              ? AppColors.error
                              : AppColors.textSecondary)),
                ),
              ],
            ),
          ],
          if (pie != null) ...[const SizedBox(height: 16), pie!],
        ],
      ),
    );
  }
}

/// Campo de solo lectura que abre un selector (fecha u hora).
class _CampoToque extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final IconData icono;
  final VoidCallback onTap;

  const _CampoToque({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(valor ?? '',
            style: const TextStyle(fontSize: 16, color: AppColors.primary)),
      ),
    );
  }
}

/// Campo de texto con sugerencias (aerolíneas y ciudades ya usadas).
class _CampoSugerencias extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final IconData icono;
  final List<String> opciones;

  /// Qué se puede escribir (ver [Entradas]).
  final List<TextInputFormatter> formatos;
  final bool habilitado;

  const _CampoSugerencias({
    required this.controller,
    required this.etiqueta,
    required this.icono,
    required this.opciones,
    required this.formatos,
    this.habilitado = true,
  });

  @override
  State<_CampoSugerencias> createState() => _CampoSugerenciasState();
}

class _CampoSugerenciasState extends State<_CampoSugerencias> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _foco,
      optionsBuilder: (valor) {
        final t = valor.text.trim().toLowerCase();
        return widget.opciones.where((o) =>
            o.toLowerCase().contains(t) && o.toLowerCase() != t);
      },
      fieldViewBuilder: (context, controller, foco, alEnviar) => TextField(
        controller: controller,
        focusNode: foco,
        enabled: widget.habilitado,
        textCapitalization: TextCapitalization.words,
        inputFormatters: widget.formatos,
        onSubmitted: (_) => alEnviar(),
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          prefixIcon: Icon(widget.icono),
          suffixIcon:
              widget.habilitado ? null : const Icon(Icons.lock_outline_rounded),
        ),
      ),
      optionsViewBuilder: (context, alElegir, opciones) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: [
                for (final o in opciones)
                  ListTile(
                    dense: true,
                    title: Text(o),
                    onTap: () => alElegir(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String texto;

  const _AvisoError({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2B8B5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
