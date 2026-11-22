import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../config/reglas.dart';
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

  /// Cabinas como las de aviones reales: asientos por fila → filas posibles
  /// (igual que en el backend).
  static const _cabinas = {
    2: (min: 4, max: 10, ejemplo: 'Beechcraft 1900'),
    3: (min: 4, max: 10, ejemplo: 'Jetstream 32'),
    4: (min: 10, max: 25, ejemplo: 'ATR 72, Embraer 190'),
    5: (min: 20, max: 30, ejemplo: 'Airbus A220'),
    6: (min: 20, max: 40, ejemplo: 'Airbus A320, Boeing 737'),
  };

  final _service = AdminVueloService();
  final _aerolinea = TextEditingController();
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _precio = TextEditingController();
  final _filas = TextEditingController(text: '30');
  final _focoFilas = FocusNode();

  DateTime? _fechaSalida;
  TimeOfDay? _horaSalida;
  DateTime? _fechaLlegada;
  TimeOfDay? _horaLlegada;
  int _porFila = 6;

  bool _guardando = false;
  String? _error;

  /// Opciones de los selectores: las que recibe la página y, en cuanto
  /// llegan, las registradas en el servidor.
  late List<String> _aerolineas = widget.aerolineas;
  late List<String> _ciudades = widget.ciudades;

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
      if (_cabinas.containsKey(base.asientosPorFila)) {
        _porFila = base.asientosPorFila;
      }
      if (_editando) {
        _fechaSalida = Formato.soloFecha(d.salida);
        _fechaLlegada = Formato.soloFecha(d.llegada);
      }
    }
    _ajustarFilas();
    _cargarOpciones();
    for (final c in [_aerolinea, _origen, _destino, _precio, _filas]) {
      c.addListener(() => setState(() {}));
    }
    // Al salir del campo, las filas quedan dentro del rango de la cabina
    _focoFilas.addListener(() {
      if (!_focoFilas.hasFocus) setState(_ajustarFilas);
    });
  }

  @override
  void dispose() {
    for (final c in [_aerolinea, _origen, _destino, _precio, _filas]) {
      c.dispose();
    }
    _focoFilas.dispose();
    super.dispose();
  }

  Future<void> _cargarOpciones() async {
    try {
      final o = await _service.opciones();
      if (!mounted) return;
      setState(() {
        _aerolineas = o.aerolineas;
        _ciudades = o.ciudades;
      });
    } catch (_) {
      // Sin conexión se quedan las recibidas; igual se puede escribir
    }
  }

  ({int min, int max, String ejemplo}) get _cabina => _cabinas[_porFila]!;

  /// Lleva las filas al rango de la cabina elegida (vacío → el mínimo).
  void _ajustarFilas() {
    final n = (int.tryParse(_filas.text) ?? _cabina.min)
        .clamp(_cabina.min, _cabina.max);
    if (_filas.text != '$n') _filas.text = '$n';
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
      Entradas.clave(_origen.text) != Entradas.clave(_destino.text);
  bool get _okFecha => _salida != null && _salida!.isAfter(DateTime.now());
  bool get _okLlegada =>
      _salida != null &&
      _llegada != null &&
      _llegada!.difference(_salida!) >= _duracionMinima &&
      _llegada!.difference(_salida!) <= _duracionMaxima;
  bool get _okPrecio =>
      (_precioValor ?? 0) > 0 &&
      (_precioValor ?? 0) <= Entradas.precioMaximo;
  bool get _okCabina =>
      (_filasValor ?? 0) >= _cabina.min && (_filasValor ?? 0) <= _cabina.max;
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

  /// Horas de 5 en 5 minutos y vuelos de 30 min a 24 h (igual que el backend).
  static const _paso = 5;
  static const _duracionMinima = Duration(minutes: 30);
  static const _duracionMaxima = Duration(hours: 24);
  static const _ultimaHora = 23 * 60 + 55; // 23:55

  /// Sube los minutos al siguiente múltiplo de [_paso] (08:02 → 08:05).
  static int _redondear(int m) => (m + _paso - 1) ~/ _paso * _paso;

  static int _minutos(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _deMinutos(int m) =>
      TimeOfDay(hour: m ~/ 60, minute: m % 60);

  /// Cambia la salida sin dejar nunca un horario imposible:
  /// - una hora de hoy que ya pasó se borra;
  /// - si había una llegada válida, se mueve con la salida (misma duración);
  /// - si no, la llegada que ya no sirve se borra.
  void _cambiarSalida({DateTime? fecha, TimeOfDay? hora}) {
    final duracion = _okLlegada ? _llegada!.difference(_salida!) : null;
    _fechaSalida = fecha ?? _fechaSalida;
    _horaSalida = hora ?? _horaSalida;
    if (_salida != null && !_salida!.isAfter(DateTime.now())) {
      _horaSalida = null;
    }
    final salida = _salida;
    if (salida != null && duracion != null) {
      final llegada = salida.add(duracion);
      _fechaLlegada = Formato.soloFecha(llegada);
      _horaLlegada = TimeOfDay(hour: llegada.hour, minute: llegada.minute);
      return;
    }
    final f = _fechaSalida;
    if (f != null &&
        (_fechaLlegada == null ||
            _fechaLlegada!.isBefore(f) ||
            _fechaLlegada!.isAfter(Formato.sumarDias(f, 1)))) {
      _fechaLlegada = f;
    }
    if (_salida != null && _llegada != null && !_okLlegada) {
      _horaLlegada = null;
    }
  }

  Future<void> _elegirFechaSalida() async {
    final hoy = DateTime.now();
    final f = await elegirFecha(context,
        titulo: 'Fecha de salida',
        inicial: _fechaSalida,
        primera: hoy,
        ultima: Reglas.ultimaFechaVuelos());
    if (f != null) setState(() => _cambiarSalida(fecha: f));
  }

  /// Si la salida es hoy, solo desde los próximos 5 minutos en adelante.
  Future<void> _elegirHoraSalida() async {
    final ahora = DateTime.now();
    final esHoy = _fechaSalida == Formato.soloFecha(ahora);
    final desde = esHoy ? _redondear(ahora.hour * 60 + ahora.minute + 1) : 0;
    if (desde > _ultimaHora) return;
    final h = await elegirHora(context,
        titulo: 'Hora de salida',
        inicial: _horaSalida,
        desde: _deMinutos(desde),
        hasta: _deMinutos(_ultimaHora),
        paso: _paso);
    if (h != null) setState(() => _cambiarSalida(hora: h));
  }

  /// La llegada es el mismo día de la salida o el siguiente (máx. 24 h).
  Future<void> _elegirFechaLlegada() async {
    final salida = _fechaSalida!;
    // El mismo día solo si cabe la duración mínima antes de medianoche
    final mismoDiaPosible =
        _minutos(_horaSalida!) + _duracionMinima.inMinutes <= _ultimaHora;
    final f = await elegirFecha(context,
        titulo: 'Fecha de llegada',
        inicial: _fechaLlegada,
        primera: mismoDiaPosible ? salida : Formato.sumarDias(salida, 1),
        ultima: Formato.sumarDias(salida, 1));
    if (f == null) return;
    setState(() {
      _fechaLlegada = f;
      if (_llegada != null && !_okLlegada) _horaLlegada = null;
    });
  }

  /// Al menos 30 min después de la salida y como máximo 24 h después.
  Future<void> _elegirHoraLlegada() async {
    final salida = _minutos(_horaSalida!);
    final minima = _duracionMinima.inMinutes;
    final mismoDia = _fechaLlegada == _fechaSalida;
    final desde = _redondear(mismoDia
        ? salida + minima
        : (salida + minima - 24 * 60).clamp(0, 24 * 60));
    final hasta = mismoDia ? _ultimaHora : salida;
    if (desde > hasta) return;
    final h = await elegirHora(context,
        titulo: 'Hora de llegada',
        inicial: _horaLlegada ?? _deMinutos(desde),
        desde: _deMinutos(desde),
        hasta: _deMinutos(hasta),
        paso: _paso);
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
      // Para saber si otro administrador lo cambió mientras se editaba
      if (_editando) 'huella': widget.vuelo!.huella,
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
              opciones: _aerolineas,
              formatos: Entradas.aerolinea,
            ),
            // El origen y el destino no pueden ser la misma ciudad:
            // ni se puede escribir ni aparece entre las sugerencias.
            _CampoSugerencias(
              controller: _origen,
              etiqueta: 'Origen',
              icono: Icons.flight_takeoff_rounded,
              opciones: _ciudades,
              excluir: _destino.text,
              formatos: [
                ...Entradas.ciudad,
                Entradas.distintoDe(() => _destino.text),
              ],
              habilitado: !_rutaBloqueada,
            ),
            _CampoSugerencias(
              controller: _destino,
              etiqueta: 'Destino',
              icono: Icons.flight_land_rounded,
              opciones: _ciudades,
              excluir: _origen.text,
              formatos: [
                ...Entradas.ciudad,
                Entradas.distintoDe(() => _origen.text),
              ],
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
            // Cada campo se habilita cuando el anterior tiene valor
            _CampoToque(
              etiqueta: 'Hora de salida',
              valor: _horaSalida == null ? null : _hhmm(_horaSalida!),
              icono: Icons.schedule_rounded,
              onTap: _fechaSalida == null ? null : _elegirHoraSalida,
            ),
            _CampoToque(
              etiqueta: 'Fecha de llegada',
              valor: _fechaLlegada == null
                  ? null
                  : Formato.fechaConAnio(_fechaLlegada!),
              icono: Icons.event_available_rounded,
              onTap: _salida == null ? null : _elegirFechaLlegada,
            ),
            _CampoToque(
              etiqueta: 'Hora de llegada',
              valor: _horaLlegada == null ? null : _hhmm(_horaLlegada!),
              icono: Icons.schedule_rounded,
              onTap: _salida == null || _fechaLlegada == null
                  ? null
                  : _elegirHoraLlegada,
            ),
          ],
          nota: _okLlegada
              ? 'Duración: ${Formato.duracion(_llegada!.difference(_salida!).inMinutes)}'
              : null,
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
            // Solo deja escribir hasta el máximo de la cabina elegida
            TextField(
              controller: _filas,
              focusNode: _focoFilas,
              keyboardType: TextInputType.number,
              inputFormatters: Entradas.filas(_cabina.max),
              decoration: InputDecoration(
                labelText: 'Filas',
                helperText: 'De ${_cabina.min} a ${_cabina.max} '
                    '(${_cabina.ejemplo})',
                prefixIcon: const Icon(Icons.table_rows_outlined),
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _porFila,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Asientos por fila',
                prefixIcon: Icon(Icons.event_seat_outlined),
              ),
              items: [
                for (final n in _cabinas.keys)
                  DropdownMenuItem(
                      value: n,
                      child: Text(
                          '$n  (${_letrasFila(n)})  ·  '
                          '${_cabinas[n]!.min} a ${_cabinas[n]!.max} filas',
                          overflow: TextOverflow.ellipsis)),
              ],
              // Al cambiar la cabina, las filas se ajustan a su rango
              onChanged: (n) => setState(() {
                _porFila = n ?? _porFila;
                _ajustarFilas();
              }),
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
                        : 'Indica entre ${_cabina.min} y ${_cabina.max} filas',
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
          item(_okLlegada, 'Duración entre 30 min y 24 h'),
          item(_okPrecio, 'Precio mayor a \$0 y hasta \$10,000'),
          item(_okCabina, 'Entre ${_cabina.min} y ${_cabina.max} filas'),
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
  final Widget? pie;

  const _Seccion({
    required this.titulo,
    required this.campos,
    this.nota,
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
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nota!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
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

  /// null: deshabilitado (falta elegir el campo anterior).
  final VoidCallback? onTap;

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
          enabled: onTap != null,
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

/// Selector de aerolínea o ciudad: la flecha despliega todas las registradas
/// y al escribir se filtran (sin importar tildes ni mayúsculas). También se
/// puede escribir una nueva; el backend la registra al guardar.
class _CampoSugerencias extends StatelessWidget {
  final TextEditingController controller;
  final String etiqueta;
  final IconData icono;
  final List<String> opciones;

  /// Opción que no se ofrece (la ciudad elegida en el otro campo).
  final String? excluir;

  /// Qué se puede escribir (ver [Entradas]).
  final List<TextInputFormatter> formatos;
  final bool habilitado;

  const _CampoSugerencias({
    required this.controller,
    required this.etiqueta,
    required this.icono,
    required this.opciones,
    required this.formatos,
    this.excluir,
    this.habilitado = true,
  });

  /// Escribiendo "cue" quedan las que contienen "cue". Si el texto ya es una
  /// opción completa (o está vacío), se muestran todas para poder cambiarla.
  List<DropdownMenuEntry<String>> _filtrar(
      List<DropdownMenuEntry<String>> entradas, String texto) {
    final t = Entradas.clave(texto);
    if (t.isEmpty || entradas.any((e) => Entradas.clave(e.value) == t)) {
      return entradas;
    }
    return entradas.where((e) => Entradas.clave(e.value).contains(t)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fuera = Entradas.clave(excluir ?? '');
    final entradas = [
      for (final o in opciones)
        if (fuera.isEmpty || Entradas.clave(o) != fuera)
          DropdownMenuEntry(value: o, label: o),
    ];
    return DropdownMenu<String>(
      controller: controller,
      enabled: habilitado,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: true,
      enableFilter: true,
      enableSearch: false,
      filterCallback: _filtrar,
      inputFormatters: formatos,
      menuHeight: 260,
      label: Text(etiqueta),
      leadingIcon: Icon(icono),
      trailingIcon: Icon(habilitado
          ? Icons.arrow_drop_down_rounded
          : Icons.lock_outline_rounded),
      selectedTrailingIcon: const Icon(Icons.arrow_drop_up_rounded),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        )),
      ),
      dropdownMenuEntries: entradas,
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
