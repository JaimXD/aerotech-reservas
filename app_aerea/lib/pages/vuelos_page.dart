import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/vuelo.dart';
import '../services/session_manager.dart';
import '../services/vuelos_service.dart';
import '../utils/formato.dart';
import '../widgets/barra_superior.dart';
import '../widgets/custom_toast.dart';
import '../widgets/selector_fechas.dart';
import '../widgets/vuelo_card.dart';
import 'crear_vuelo_page.dart';
import 'login_page.dart';
import 'reservas_page.dart';
import 'seleccion_asientos_page.dart';
import '../models/ruta.dart';
import '../widgets/selector_ciudad.dart';

const _bordeSuave = Color(0xFFE6DED6);

enum OrdenVuelos { precio, temprano, rapido }

/// Franjas horarias del filtro "Hora de salida".
enum Franja {
  manana('Mañana', '00:00 – 11:59', Icons.wb_sunny_outlined),
  tarde('Tarde', '12:00 – 17:59', Icons.wb_twilight),
  noche('Noche', '18:00 – 23:59', Icons.nightlight_outlined);

  const Franja(this.nombre, this.rango, this.icono);

  final String nombre;
  final String rango;
  final IconData icono;

  static Franja de(Vuelo v) {
    final h = v.salida.hour;
    if (h < 12) return manana;
    if (h < 18) return tarde;
    return noche;
  }
}

class _Sugerencia {
  final DateTime dia;
  final int cantidad;
  final double desde;

  const _Sugerencia(this.dia, this.cantidad, this.desde);
}

class VuelosPage extends StatefulWidget {
  const VuelosPage({super.key});

  @override
  State<VuelosPage> createState() => _VuelosPageState();
}

class _VuelosPageState extends State<VuelosPage> {
  final _vuelosService = VuelosService();
  final _session = SessionManager();

  // Ciudades que se pueden elegir (vienen del backend)
  List<Ruta> _rutas = [];
  bool _cargandoRutas = true;
  String? _origen;
  String? _destino;

  // Lo que el usuario tiene escrito / elegido en el buscador
  late DateTimeRange _rango;

  // Lo que realmente se buscó (para títulos y recargas)
  late DateTimeRange _rangoBuscado;
  String _origenBuscado = '';
  String _destinoBuscado = '';

  List<Vuelo> _todos = [];
  bool _cargando = false;
  String? _error;
  int _peticion = 0; // evita que una respuesta vieja pise a una nueva

  // Filtros y orden
  DateTime? _diaSeleccionado;
  late DateTime _inicioTira;
  final Set<Franja> _franjasOcultas = {};
  final Set<String> _aerolineasOcultas = {};
  OrdenVuelos _orden = OrdenVuelos.precio;

  List<_Sugerencia> _sugerencias = [];
  bool _cargandoSugerencias = false;

  @override
  void initState() {
    super.initState();
    final hoy = Formato.soloFecha(DateTime.now());
    _rango = DateTimeRange(start: hoy, end: Formato.sumarDias(hoy, 10));
    _rangoBuscado = _rango;
    _inicioTira = hoy;
    _inicializar();
  }

  // ════════════════════════════════════════════════════════════════
  //  Datos
  // ════════════════════════════════════════════════════════════════

  /// Carga las ciudades, elige una ruta por defecto y hace la primera búsqueda.
  Future<void> _inicializar() async {
    setState(() {
      _cargandoRutas = true;
      _error = null;
    });
    try {
      final rutas = await _vuelosService.obtenerRutas();
      if (!mounted) return;
      setState(() {
        _rutas = rutas;
        _cargandoRutas = false;
        final origenes = _origenesDisponibles;
        _origen = origenes.contains('Quito')
            ? 'Quito'
            : (origenes.isEmpty ? null : origenes.first);
        final destinos = _destinosDesde(_origen);
        _destino = destinos.contains('Guayaquil')
            ? 'Guayaquil'
            : (destinos.isEmpty ? null : destinos.first);
      });
      _buscar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoRutas = false;
        _error = CustomToast.parseError(e);
      });
    }
  }

  List<String> get _origenesDisponibles =>
      _rutas.map((r) => r.origen).toSet().toList()..sort();

  List<String> _destinosDesde(String? origen) => _rutas
      .where((r) => origen == null || r.origen == origen)
      .map((r) => r.destino)
      .toSet()
      .toList()
    ..sort();

  bool _existeRuta(String origen, String destino) =>
      _rutas.any((r) => r.origen == origen && r.destino == destino);

  bool get _puedeBuscar =>
      !_cargandoRutas && _origen != null && _destino != null;

  /// [recargar] = true vuelve a pedir la misma búsqueda sin borrar filtros
  /// (se usa al volver de reservar asientos).
  Future<void> _buscar({bool recargar = false}) async {
    final peticion = ++_peticion;
    final origen = recargar ? _origenBuscado : (_origen ?? '');
    final destino = recargar ? _destinoBuscado : (_destino ?? '');
    final rango = recargar ? _rangoBuscado : _rango;

    setState(() {
      _error = null;
      if (!recargar) {
        _cargando = true;
        _todos = [];
        _sugerencias = [];
        _diaSeleccionado = null;
        _inicioTira = rango.start;
        _franjasOcultas.clear();
        _aerolineasOcultas.clear();
        _origenBuscado = origen;
        _destinoBuscado = destino;
        _rangoBuscado = rango;
      }
    });

    try {
      final data = await _vuelosService.buscarVuelos(
        origen: origen,
        destino: destino,
        fechaInicio: Formato.iso(rango.start),
        fechaFin: Formato.iso(rango.end),
      );
      if (!mounted || peticion != _peticion) return;

      setState(() {
        _todos = data;
        if (_diaSeleccionado != null &&
            !data.any((v) => v.dia == _diaSeleccionado)) {
          _diaSeleccionado = null;
        }
      });

      if (data.isEmpty) _buscarSugerencias(peticion);
    } catch (e) {
      if (!mounted || peticion != _peticion) return;
      setState(() => _error = CustomToast.parseError(e));
    } finally {
      if (mounted && peticion == _peticion) setState(() => _cargando = false);
    }
  }

  /// Si no hay vuelos, busca las fechas más cercanas con vuelos en la misma ruta.
  Future<void> _buscarSugerencias(int peticion) async {
    setState(() => _cargandoSugerencias = true);
    try {
      final hoy = Formato.soloFecha(DateTime.now());
      final data = await _vuelosService.buscarVuelos(
        origen: _origenBuscado,
        destino: _destinoBuscado,
        fechaInicio: Formato.iso(hoy),
        fechaFin: Formato.iso(Formato.sumarDias(hoy, 365)),
      );
      if (!mounted || peticion != _peticion) return;

      final porDia = <DateTime, List<Vuelo>>{};
      for (final v in data) {
        porDia.putIfAbsent(v.dia, () => []).add(v);
      }
      final referencia = _rangoBuscado.start;
      final dias = porDia.keys.toList()
        ..sort((a, b) => a
            .difference(referencia)
            .inDays
            .abs()
            .compareTo(b.difference(referencia).inDays.abs()));
      final elegidos = dias.take(3).toList()..sort();

      setState(() {
        _sugerencias = elegidos.map((d) {
          final lista = porDia[d]!;
          return _Sugerencia(
              d, lista.length, lista.map((v) => v.precio).reduce(math.min));
        }).toList();
      });
    } catch (_) {
      // Las sugerencias son opcionales: si fallan, no se muestran.
    } finally {
      if (mounted && peticion == _peticion) {
        setState(() => _cargandoSugerencias = false);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Acciones
  // ════════════════════════════════════════════════════════════════

  Future<void> _seleccionarFechas() async {
    final hoy = Formato.soloFecha(DateTime.now());
    final elegido = await mostrarSelectorFechas(
      context,
      inicial: _rango.start.isBefore(hoy) ? null : _rango,
      primeraFecha: hoy,
      ultimaFecha: Formato.sumarDias(hoy, 365),
    );

    if (elegido != null) {
      setState(() => _rango = elegido);
      _buscar();
    }
  }

  void _elegirOrigen(String ciudad) {
    setState(() {
      _origen = ciudad;
      // Si el destino actual no tiene vuelos desde el nuevo origen, se limpia
      if (_destino != null && !_existeRuta(ciudad, _destino!)) {
        final destinos = _destinosDesde(ciudad);
        _destino = destinos.length == 1 ? destinos.first : null;
      }
    });
  }

  void _elegirDestino(String ciudad) => setState(() => _destino = ciudad);

  void _intercambiar() {
    final nuevoOrigen = _destino;
    final nuevoDestino = _origen;
    if (nuevoOrigen == null || nuevoDestino == null) return;

    if (!_origenesDisponibles.contains(nuevoOrigen)) {
      CustomToast.showError(
          context, 'No hay vuelos que salgan de $nuevoOrigen.');
      return;
    }
    setState(() {
      _origen = nuevoOrigen;
      _destino = _existeRuta(nuevoOrigen, nuevoDestino) ? nuevoDestino : null;
    });
  }

  String _textoDestinos(String origen) {
    final n = _destinosDesde(origen).length;
    return n == 1 ? '1 destino' : '$n destinos';
  }

  void _buscarDia(DateTime dia) {
    setState(() => _rango = DateTimeRange(start: dia, end: dia));
    _buscar();
  }

  void _buscarProximos30() {
    final hoy = Formato.soloFecha(DateTime.now());
    setState(() =>
        _rango = DateTimeRange(start: hoy, end: Formato.sumarDias(hoy, 30)));
    _buscar();
  }

  void _verRutaInversa() {
    setState(() {
      _origen = _destinoBuscado;
      _destino = _origenBuscado;
    });
    _buscar();
  }

  void _limpiarFiltros() {
    setState(() {
      _franjasOcultas.clear();
      _aerolineasOcultas.clear();
      _diaSeleccionado = null;
    });
  }

  void _moverTira(int dias) {
    final inicio = _rangoBuscado.start;
    final ultimo = Formato.sumarDias(_rangoBuscado.end, -6);
    var nuevo = Formato.sumarDias(_inicioTira, dias);
    if (nuevo.isAfter(ultimo)) nuevo = ultimo;
    if (nuevo.isBefore(inicio)) nuevo = inicio;
    setState(() => _inicioTira = nuevo);
  }

  void _abrirSeleccionAsientos(Vuelo vuelo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SeleccionAsientosPage(vuelo: vuelo)),
    ).then((_) => _buscar(recargar: true));
  }

  void _abrirMisReservas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReservasPage()),
    ).then((_) => _buscar(recargar: true));
  }

  void _abrirCrearVuelo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CrearVueloPage()),
    ).then((_) => _buscar(recargar: true));
  }

  Future<void> _cerrarSesion() async {
    await _session.cerrarSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  Textos de apoyo
  // ════════════════════════════════════════════════════════════════

  String? _primerNombre() {
    final completo = (_session.nombreCompleto ?? '').trim();
    if (completo.isEmpty) return null;
    final p = completo.split(RegExp(r'\s+')).first;
    return p[0].toUpperCase() + p.substring(1).toLowerCase();
  }

  String _ruta(String origen, String destino) =>
      '${origen.isEmpty ? 'Cualquier origen' : origen} → ${destino.isEmpty ? 'cualquier destino' : destino}';

  String _textoRango(DateTimeRange r) => r.start == r.end
      ? Formato.fechaConDia(r.start)
      : '${Formato.fechaConDia(r.start)} – ${Formato.fechaConDia(r.end)}';

  int _comparar(Vuelo a, Vuelo b) {
    switch (_orden) {
      case OrdenVuelos.precio:
        final c = a.precio.compareTo(b.precio);
        return c != 0 ? c : a.salida.compareTo(b.salida);
      case OrdenVuelos.temprano:
        return a.salida.compareTo(b.salida);
      case OrdenVuelos.rapido:
        final c = a.duracionMinutos.compareTo(b.duracionMinutos);
        return c != 0 ? c : a.precio.compareTo(b.precio);
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Interfaz
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BarraSuperior(
            actual: SeccionApp.vuelos,
            onReservas: _abrirMisReservas,
            onCerrarSesion: _cerrarSesion,
            onCrearVuelo: _session.isAdmin ? _abrirCrearVuelo : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _construirEncabezado(),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1248),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 64),
                        child: _construirContenido(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Saludo + buscador + recientes ────────────────────────────────

  Widget _construirEncabezado() {
    final nombre = _primerNombre();

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre == null
                    ? '¿A dónde quieres volar?'
                    : '¿A dónde quieres volar, $nombre?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Compara horarios y precios, y elige tu asiento en un solo lugar.',
                style: TextStyle(color: Color(0xFFE8DCD2), fontSize: 16),
              ),
              const SizedBox(height: 20),
              _construirBuscador(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBuscador() {
    final origen = SelectorCiudad(
      etiqueta: 'Origen',
      icono: Icons.trip_origin,
      valor: _origen,
      cargando: _cargandoRutas,
      opciones: [
        for (final c in _origenesDisponibles)
          OpcionCiudad(c, detalle: _textoDestinos(c)),
      ],
      onElegir: _elegirOrigen,
      mensajeSinOpciones: 'Por ahora no hay vuelos disponibles',
    );
    final destino = SelectorCiudad(
      etiqueta: 'Destino',
      icono: Icons.place_outlined,
      valor: _destino,
      cargando: _cargandoRutas,
      textoVacio: 'Elige un destino',
      opciones: [
        for (final c in _destinosDesde(_origen)) OpcionCiudad(c),
      ],
      onElegir: _elegirDestino,
      mensajeSinOpciones: _origen == null
          ? 'Primero elige un origen'
          : 'No hay destinos desde $_origen',
    );
    final fechas =
        _CampoFechas(texto: _textoRango(_rango), onTap: _seleccionarFechas);
    final buscar = _BotonBuscar(
      cargando: _cargando,
      onTap: _puedeBuscar ? () => _buscar() : null,
    );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 880) {
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(child: origen),
                      _BotonIntercambiar(vertical: false, onTap: _intercambiar),
                      Expanded(child: destino),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: AppColors.divider,
                ),
                Expanded(child: fechas),
                const SizedBox(width: 8),
                buscar,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [origen, const Divider(height: 1), destino],
                    ),
                  ),
                  _BotonIntercambiar(vertical: true, onTap: _intercambiar),
                  const SizedBox(width: 8),
                ],
              ),
              const Divider(height: 1),
              fechas,
              const SizedBox(height: 8),
              buscar,
            ],
          );
        },
      ),
    );
  }

  // ── Contenido según el estado ────────────────────────────────────

  Widget _construirContenido() {
    if (_cargando || _cargandoRutas) {
      return Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _TarjetaEsqueleto(),
          ),
        ),
      );
    }

    if (_error != null) {
      return _EstadoMensaje(
        icono: Icons.cloud_off_outlined,
        titulo: 'No pudimos cargar los vuelos',
        mensaje: _error!,
        accion: 'Reintentar',
        onAccion: _rutas.isEmpty ? _inicializar : () => _buscar(),
      );
    }

    if (_todos.isEmpty) return _construirVacio();

    final delDia = _diaSeleccionado == null
        ? _todos
        : _todos.where((v) => v.dia == _diaSeleccionado).toList();
    final filtrados = delDia
        .where((v) =>
            !_franjasOcultas.contains(Franja.de(v)) &&
            !_aerolineasOcultas.contains(v.aerolinea))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _construirTira(),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) {
            final filtros = _construirFiltros(delDia);
            final resultados = _construirResultados(filtrados, delDia.length);
            if (c.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 270, child: filtros),
                  const SizedBox(width: 24),
                  Expanded(child: resultados),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [filtros, const SizedBox(height: 24), resultados],
            );
          },
        ),
      ],
    );
  }

  Widget _construirTira() {
    final inicio = _rangoBuscado.start;
    final fin = _rangoBuscado.end;

    final dias = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      final d = Formato.sumarDias(_inicioTira, i);
      if (d.isAfter(fin)) break;
      dias.add(d);
    }

    final precios = <DateTime, double>{};
    for (final v in _todos) {
      final p = precios[v.dia];
      if (p == null || v.precio < p) precios[v.dia] = v.precio;
    }
    final minimo = precios.values.reduce(math.min);

    return _TiraCalendario(
      dias: dias,
      precios: precios,
      minimo: minimo,
      seleccionado: _diaSeleccionado,
      onElegir: (d) =>
          setState(() => _diaSeleccionado = _diaSeleccionado == d ? null : d),
      onAnterior: _inicioTira.isAfter(inicio) ? () => _moverTira(-7) : null,
      onSiguiente: Formato.sumarDias(_inicioTira, 6).isBefore(fin)
          ? () => _moverTira(7)
          : null,
    );
  }

  Widget _construirFiltros(List<Vuelo> delDia) {
    final nombres = _todos.map((v) => v.aerolinea).toSet().toList()..sort();
    final hayFiltros = _franjasOcultas.isNotEmpty ||
        _aerolineasOcultas.isNotEmpty ||
        _diaSeleccionado != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: hayFiltros ? _limpiarFiltros : null,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.secondary),
                child: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _TituloFiltro('Hora de salida'),
          const SizedBox(height: 10),
          for (final f in Franja.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OpcionFranja(
                franja: f,
                activa: !_franjasOcultas.contains(f),
                onTap: () => setState(() {
                  if (!_franjasOcultas.remove(f)) _franjasOcultas.add(f);
                }),
              ),
            ),
          const SizedBox(height: 14),
          const _TituloFiltro('Aerolíneas'),
          const SizedBox(height: 4),
          for (final n in nombres)
            _OpcionAerolinea(
              nombre: n,
              activa: !_aerolineasOcultas.contains(n),
              onTap: () => setState(() {
                if (!_aerolineasOcultas.remove(n)) _aerolineasOcultas.add(n);
              }),
            ),
        ],
      ),
    );
  }

  Widget _construirResultados(List<Vuelo> filtrados, int totalDelDia) {
    final ordenados = [...filtrados]..sort(_comparar);

    Vuelo? barato;
    Vuelo? temprano;
    Vuelo? rapido;
    for (final v in filtrados) {
      if (barato == null || v.precio < barato.precio) barato = v;
      if (temprano == null || v.salida.isBefore(temprano.salida)) temprano = v;
      if (rapido == null || v.duracionMinutos < rapido.duracionMinutos) {
        rapido = v;
      }
    }
    final idBarato = barato?.id;
    final idTemprano = temprano?.id;
    final n = filtrados.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${n == 1 ? '1 vuelo' : '$n vuelos'} · ${_ruta(_origenBuscado, _destinoBuscado)}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PestanaOrden(
                titulo: 'Más barato',
                valor: barato == null ? '—' : Formato.dinero(barato.precio),
                seleccionada: _orden == OrdenVuelos.precio,
                onTap: () => setState(() => _orden = OrdenVuelos.precio),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PestanaOrden(
                titulo: 'Más temprano',
                valor: temprano == null
                    ? '—'
                    : '${temprano.horaSalidaCorta} · ${Formato.fechaConDia(temprano.dia)}',
                seleccionada: _orden == OrdenVuelos.temprano,
                onTap: () => setState(() => _orden = OrdenVuelos.temprano),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PestanaOrden(
                titulo: 'Más rápido',
                valor: rapido == null
                    ? '—'
                    : Formato.duracion(rapido.duracionMinutos),
                seleccionada: _orden == OrdenVuelos.rapido,
                onTap: () => setState(() => _orden = OrdenVuelos.rapido),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (ordenados.isEmpty)
          _EstadoMensaje(
            icono: Icons.filter_alt_off_outlined,
            titulo: 'Ningún vuelo coincide con tus filtros',
            mensaje: totalDelDia == 1
                ? 'Hay 1 vuelo en esta búsqueda. Quita algún filtro para verlo.'
                : 'Hay $totalDelDia vuelos en esta búsqueda. Quita algún filtro para verlos.',
            accion: 'Limpiar filtros',
            onAccion: _limpiarFiltros,
          )
        else
          for (final v in ordenados)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VueloCard(
                vuelo: v,
                masBarato: v.id == idBarato,
                masTemprano: v.id == idTemprano && v.id != idBarato,
                onReservar: () => _abrirSeleccionAsientos(v),
              ),
            ),
      ],
    );
  }

  Widget _construirVacio() {
    final r = _rangoBuscado;
    final cuando = r.start == r.end
        ? 'el ${Formato.fechaLarga(r.start).toLowerCase()}'
        : 'del ${Formato.fechaLarga(r.start).toLowerCase()} al ${Formato.fechaLarga(r.end).toLowerCase()}';
    final minimoSugerido = _sugerencias.isEmpty
        ? null
        : _sugerencias.map((s) => s.desde).reduce(math.min);
    final rutaCompleta = _existeRuta(_destinoBuscado, _origenBuscado);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.travel_explore,
                size: 48, color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          Text(
            'No hay vuelos ${_ruta(_origenBuscado, _destinoBuscado)} en esas fechas',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buscamos $cuando.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (_cargandoSugerencias)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else if (_sugerencias.isNotEmpty) ...[
            const Text(
              'Prueba con alguna de estas fechas cercanas:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _sugerencias)
                  _TarjetaSugerencia(
                    sugerencia: s,
                    esLaMasBarata: s.desde == minimoSugerido,
                    onTap: () => _buscarDia(s.dia),
                  ),
              ],
            ),
          ] else
            const Text(
              'Tampoco encontramos vuelos en esta ruta durante el próximo año. ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _buscarProximos30,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                child: const Text('Buscar en los próximos 30 días'),
              ),
              if (rutaCompleta)
                OutlinedButton(
                  onPressed: _verRutaInversa,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  child: Text('Ver vuelos $_destinoBuscado → $_origenBuscado'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Widgets privados de la página
// ══════════════════════════════════════════════════════════════════

class _CampoFechas extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _CampoFechas({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  color: AppColors.secondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Fechas de salida',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      texto,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonIntercambiar extends StatelessWidget {
  final bool vertical;
  final VoidCallback onTap;

  const _BotonIntercambiar({required this.vertical, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Intercambiar origen y destino',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              vertical ? Icons.swap_vert : Icons.swap_horiz,
              size: 20,
              color: AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonBuscar extends StatelessWidget {
  final bool cargando;
  final VoidCallback? onTap; // null = deshabilitado

  const _BotonBuscar({required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: cargando ? null : onTap,
        icon: cargando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.search, size: 20),
        label: const Text('Buscar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ── Calendario de precios ─────────────────────────────────────────

class _TiraCalendario extends StatelessWidget {
  final List<DateTime> dias;
  final Map<DateTime, double> precios;
  final double minimo;
  final DateTime? seleccionado;
  final ValueChanged<DateTime> onElegir;
  final VoidCallback? onAnterior;
  final VoidCallback? onSiguiente;

  const _TiraCalendario({
    required this.dias,
    required this.precios,
    required this.minimo,
    required this.seleccionado,
    required this.onElegir,
    this.onAnterior,
    this.onSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BotonFlecha(
              icono: Icons.chevron_left,
              tooltip: 'Días anteriores',
              onTap: onAnterior),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i < dias.length
                        ? _CeldaDia(
                            dia: dias[i],
                            precio: precios[dias[i]],
                            esMinimo: precios[dias[i]] == minimo,
                            seleccionada: dias[i] == seleccionado,
                            onTap: precios[dias[i]] == null
                                ? null
                                : () => onElegir(dias[i]),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BotonFlecha(
              icono: Icons.chevron_right,
              tooltip: 'Días siguientes',
              onTap: onSiguiente),
        ],
      ),
    );
  }
}

class _CeldaDia extends StatelessWidget {
  final DateTime dia;
  final double? precio;
  final bool esMinimo;
  final bool seleccionada;
  final VoidCallback? onTap;

  const _CeldaDia({
    required this.dia,
    required this.precio,
    required this.esMinimo,
    required this.seleccionada,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sinVuelos = precio == null;
    final fondo = seleccionada
        ? AppColors.primary
        : (sinVuelos ? Colors.transparent : Colors.white);
    final colorTexto = seleccionada
        ? Colors.white
        : (sinVuelos ? AppColors.textSecondary : AppColors.primary);
    final colorPrecio = seleccionada
        ? Colors.white
        : sinVuelos
            ? AppColors.textSecondary
            : (esMinimo ? AppColors.success : AppColors.primary);

    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: fondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: seleccionada
                ? AppColors.primary
                : (sinVuelos ? AppColors.border : _bordeSuave),
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formato.diaCorto(dia),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorTexto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formato.fechaCorta(dia),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorTexto.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sinVuelos ? 'Sin vuelos' : Formato.dinero(precio!),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorPrecio,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonFlecha extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onTap;

  const _BotonFlecha({required this.icono, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Icon(
              icono,
              color: onTap == null ? AppColors.border : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filtros ───────────────────────────────────────────────────────

class _TituloFiltro extends StatelessWidget {
  final String texto;

  const _TituloFiltro(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _OpcionFranja extends StatelessWidget {
  final Franja franja;
  final bool activa;
  final VoidCallback onTap;

  const _OpcionFranja({
    required this.franja,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: activa,
      child: Material(
        color: activa ? const Color(0xFFF7EFE8) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: activa ? AppColors.secondary : _bordeSuave,
            width: activa ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(franja.icono, size: 20, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        franja.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        franja.rango,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcionAerolinea extends StatelessWidget {
  final String nombre;
  final bool activa;
  final VoidCallback onTap;

  const _OpcionAerolinea({
    required this.nombre,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Checkbox(
            value: activa,
            onChanged: (_) => onTap(),
            activeColor: AppColors.secondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Orden ─────────────────────────────────────────────────────────

class _PestanaOrden extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool seleccionada;
  final VoidCallback onTap;

  const _PestanaOrden({
    required this.titulo,
    required this.valor,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = seleccionada ? Colors.white : AppColors.primary;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: seleccionada ? AppColors.primary : _bordeSuave,
        width: seleccionada ? 2 : 1,
      ),
    );

    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada ? AppColors.primary : Colors.white,
        shape: forma,
        child: InkWell(
          onTap: onTap,
          customBorder: forma,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: colorTexto.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Estados: vacío, error, carga ──────────────────────────────────

class _TarjetaSugerencia extends StatelessWidget {
  final _Sugerencia sugerencia;
  final bool esLaMasBarata;
  final VoidCallback onTap;

  const _TarjetaSugerencia({
    required this.sugerencia,
    required this.esLaMasBarata,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = sugerencia;
    return Material(
      color: const Color(0xFFFBF9F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 170),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formato.fechaConDia(s.dia),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                          text: s.cantidad == 1
                              ? '1 vuelo · desde '
                              : '${s.cantidad} vuelos · desde '),
                      TextSpan(
                        text: Formato.dinero(s.desde),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: esLaMasBarata
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoMensaje extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final String accion;
  final VoidCallback onAccion;

  const _EstadoMensaje({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.accion,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 44, color: AppColors.secondary),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAccion,
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            child: Text(accion),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta gris que "respira" mientras se cargan los vuelos.
class _TarjetaEsqueleto extends StatefulWidget {
  const _TarjetaEsqueleto();

  @override
  State<_TarjetaEsqueleto> createState() => _TarjetaEsqueletoState();
}

class _TarjetaEsqueletoState extends State<_TarjetaEsqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bloque(double ancho, double alto, {double radio = 8}) => Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          color: const Color(0xFFEFE8E0),
          borderRadius: BorderRadius.circular(radio),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bordeSuave),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _bloque(40, 40, radio: 12),
                      const SizedBox(width: 12),
                      _bloque(160, 14),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _bloque(double.infinity, 28),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bloque(90, 26),
                  const SizedBox(height: 10),
                  _bloque(double.infinity, 44, radio: 999),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
