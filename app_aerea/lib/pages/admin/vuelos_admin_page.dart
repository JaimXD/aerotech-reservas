import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/vuelo_admin.dart';
import '../../services/admin_vuelo_service.dart';
import '../../services/cambios_admin.dart';
import '../../utils/entradas.dart';
import '../../utils/formato.dart';
import '../../widgets/admin/admin_ui.dart';
import '../../widgets/admin/dialogo_cancelar_vuelo.dart';
import '../../widgets/custom_toast.dart';
import 'vuelo_detalle_page.dart';
import 'vuelo_form_page.dart';

/// Sección "Vuelos" del administrador.
///
/// Tiene su propio Navigator: la lista, el detalle y el formulario se abren
/// dentro del área de contenido y el menú lateral sigue visible.
class VuelosAdminPage extends StatelessWidget {
  /// Abre el detalle de este vuelo al entrar (próximas salidas del panel).
  final int? vueloInicial;

  const VuelosAdminPage({super.key, this.vueloInicial});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _ListaVuelos(vueloInicial: vueloInicial),
      ),
    );
  }
}

class _ListaVuelos extends StatefulWidget {
  final int? vueloInicial;

  const _ListaVuelos({required this.vueloInicial});

  @override
  State<_ListaVuelos> createState() => _ListaVuelosState();
}

class _ListaVuelosState extends State<_ListaVuelos> {
  final _service = AdminVueloService();
  final _busqueda = TextEditingController();
  Timer? _espera;

  EstadoVuelo? _estado; // null = todos
  String? _aerolinea;
  int _pagina = 1;

  ListaVuelosAdmin? _datos;
  bool _cargando = true;
  String? _error;
  int _consulta = 0; // descarta respuestas viejas si llegan tarde

  /// Recarga sola cuando cambian los datos en el servidor.
  late final VoidCallback _dejarDeEscuchar;

  @override
  void initState() {
    super.initState();
    _cargar();
    _dejarDeEscuchar = CambiosAdmin.instancia.escuchar(
      {DatoAdmin.vuelos, DatoAdmin.reservas, DatoAdmin.carritos},
      () => _cargar(silencioso: true),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.vueloInicial != null) _verDetalle(widget.vueloInicial!);
    });
  }

  @override
  void dispose() {
    _dejarDeEscuchar();
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  /// [silencioso]: recarga automática, sin indicador de carga ni errores.
  Future<void> _cargar({bool silencioso = false}) async {
    final consulta = ++_consulta;
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final datos = await _service.listar(
        estado: _estado,
        busqueda: _busqueda.text,
        aerolinea: _aerolinea,
        pagina: _pagina,
      );
      if (!mounted || consulta != _consulta) return;
      // Si la página quedó vacía (p. ej. tras cancelar), vuelve a la última
      if (datos.vuelos.isEmpty && _pagina > 1) {
        _pagina = datos.paginas;
        await _cargar(silencioso: silencioso);
        return;
      }
      setState(() {
        _datos = datos;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _cargando = false;
        if (!silencioso) _error = mensajeError(e);
      });
    }
  }

  void _filtrar(VoidCallback cambio) {
    setState(() {
      cambio();
      _pagina = 1;
    });
    _cargar();
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () => _filtrar(() {}));
  }

  List<String> get _aerolineas => _datos?.aerolineas ?? const [];
  List<String> get _ciudades => _datos?.ciudades ?? const [];

  // ── Acciones ─────────────────────────────────────────────────────

  Future<void> _verDetalle(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VueloDetallePage(
            vueloId: id, aerolineas: _aerolineas, ciudades: _ciudades),
      ),
    );
    if (mounted) _cargar();
  }

  Future<void> _abrirFormulario({VueloAdmin? vuelo, VueloAdmin? copia}) async {
    final guardado = await Navigator.push<VueloAdmin>(
      context,
      MaterialPageRoute(
        builder: (_) => VueloFormPage(
          vuelo: vuelo,
          copia: copia,
          aerolineas: _aerolineas,
          ciudades: _ciudades,
        ),
      ),
    );
    if (!mounted) return;
    _cargar();
    // Un vuelo nuevo o duplicado se abre para ver su mapa de asientos
    if (guardado != null && vuelo == null) _verDetalle(guardado.id);
  }

  void _nuevo() => _abrirFormulario();

  Future<void> _cancelar(VueloAdmin v) async {
    final r = await confirmarCancelacionVuelo(context, v);
    if (r == null || !mounted) return;
    CustomToast.showSuccess(
        context,
        r.reservasCanceladas == 0
            ? 'Vuelo #${v.id} cancelado'
            : 'Vuelo #${v.id} cancelado · ${r.reservasCanceladas} reserva(s) '
                'cancelada(s)');
    _cargar();
  }

  Future<void> _reactivar(VueloAdmin v) async {
    try {
      await _service.reactivar(v.id);
      if (!mounted) return;
      CustomToast.showSuccess(
          context, 'El vuelo #${v.id} vuelve a estar a la venta');
      _cargar();
    } catch (e) {
      if (mounted) CustomToast.showError(context, mensajeError(e));
    }
  }

  void _accion(_Accion accion, VueloAdmin v) {
    switch (accion) {
      case _Accion.ver:
        _verDetalle(v.id);
      case _Accion.editar:
        _abrirFormulario(vuelo: v);
      case _Accion.duplicar:
        _abrirFormulario(copia: v);
      case _Accion.cancelar:
        _cancelar(v);
      case _Accion.reactivar:
        _reactivar(v);
    }
  }

  // ── Interfaz ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = _datos;

    return Stack(
      children: [
        PaginaAdmin(
          children: [
            EncabezadoAdmin(
              titulo: 'Vuelos',
              acciones: [
                BotonAdmin(
                    texto: 'Nuevo vuelo',
                    icono: Icons.add_rounded,
                    onPressed: _nuevo),
              ],
            ),
            const SizedBox(height: 20),
            _pestanas(d),
            const SizedBox(height: 14),
            _filtros(),
            const SizedBox(height: 14),
            if (d == null && _error != null)
              ErrorAdmin(mensaje: _error!, onReintentar: _cargar)
            else if (d == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.secondary)),
              )
            else ...[
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 10),
              ],
              _tabla(d),
            ],
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Un vuelo con reservas no se borra: se cancela, sus '
                    'pasajeros quedan con la reserva "Cancelada" y el vuelo '
                    'deja de aparecer en la búsqueda de los clientes.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_cargando && d != null)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
                minHeight: 3, color: AppColors.secondary),
          ),
      ],
    );
  }

  Widget _pestanas(ListaVuelosAdmin? d) {
    final opciones = <(EstadoVuelo?, String)>[
      (null, 'Todos'),
      for (final e in EstadoVuelo.values) (e, e.plural),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (estado, texto) in opciones) ...[
            _Pestana(
              texto: texto,
              cantidad: d?.conteo(estado),
              activa: _estado == estado,
              onTap: () => _filtrar(() => _estado = estado),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _filtros() {
    final aerolineas = _aerolineas;
    final buscador = TextField(
      controller: _busqueda,
      onChanged: _alEscribir,
      // Sin emojis ni símbolos que no sirven para buscar
      inputFormatters: Entradas.busquedaVuelos,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _filtrar(() {}),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por ciudad, aerolínea o número de vuelo',
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        suffixIcon: _busqueda.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _filtrar(_busqueda.clear),
              ),
      ),
    );

    final selector = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: aerolineas.contains(_aerolinea) ? _aerolinea : null,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          style: const TextStyle(fontSize: 14, color: AppColors.primary),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Aerolínea: Todas')),
            for (final a in aerolineas)
              DropdownMenuItem<String?>(
                  value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (a) => _filtrar(() => _aerolinea = a),
        ),
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 620) {
        return Column(children: [
          buscador,
          const SizedBox(height: 10),
          selector,
        ]);
      }
      return Row(children: [
        Expanded(child: buscador),
        const SizedBox(width: 12),
        SizedBox(width: 240, child: selector),
      ]);
    });
  }

  Widget _tabla(ListaVuelosAdmin d) {
    if (d.vuelos.isEmpty) {
      final hayFiltros = _estado != null ||
          _aerolinea != null ||
          _busqueda.text.trim().isNotEmpty;
      return TarjetaAdmin(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              const Icon(Icons.flight_outlined,
                  size: 40, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text(
                hayFiltros
                    ? 'No hay vuelos con estos filtros.'
                    : 'Todavía no hay vuelos. Crea el primero.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (hayFiltros)
                BotonSecundarioAdmin(
                  texto: 'Quitar filtros',
                  onPressed: () => _filtrar(() {
                    _estado = null;
                    _aerolinea = null;
                    _busqueda.clear();
                  }),
                )
              else
                BotonAdmin(
                    texto: 'Nuevo vuelo',
                    icono: Icons.add_rounded,
                    onPressed: _nuevo),
            ],
          ),
        ),
      );
    }

    final desde = (d.pagina - 1) * d.porPagina + 1;
    final hasta = desde + d.vuelos.length - 1;

    return TarjetaAdmin(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ancho) const _CabeceraTabla(),
            for (final v in d.vuelos)
              ancho
                  ? _FilaVuelo(
                      vuelo: v,
                      onTap: () => _verDetalle(v.id),
                      onAccion: (a) => _accion(a, v))
                  : _TarjetaVuelo(
                      vuelo: v,
                      onTap: () => _verDetalle(v.id),
                      onAccion: (a) => _accion(a, v)),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBordeFilaAdmin)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Mostrando $desde–$hasta de ${d.total}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: d.pagina > 1 && !_cargando
                            ? () {
                                setState(() => _pagina = d.pagina - 1);
                                _cargar();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                      Text('${d.pagina} / ${d.paginas}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      TextButton.icon(
                        onPressed: d.pagina < d.paginas && !_cargando
                            ? () {
                                setState(() => _pagina = d.pagina + 1);
                                _cargar();
                              }
                            : null,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Siguiente'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ───────────────────────── Piezas ─────────────────────────

enum _Accion { ver, editar, duplicar, cancelar, reactivar }

class _Pestana extends StatelessWidget {
  final String texto;
  final int? cantidad;
  final bool activa;
  final VoidCallback onTap;

  const _Pestana({
    required this.texto,
    required this.cantidad,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      child: Material(
        color: activa ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                  color: activa ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(texto,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: activa ? Colors.white : AppColors.primary)),
                if (cantidad != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: activa
                          ? Colors.white.withValues(alpha: 0.2)
                          : kBarraFondoAdmin,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('$cantidad',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: activa
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _anchoNumero = 64.0;
const _anchoPrecio = 90.0;
const _anchoOcupacion = 150.0;
const _anchoEstado = 104.0;
const _anchoAcciones = 48.0;

class _CabeceraTabla extends StatelessWidget {
  const _CabeceraTabla();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary);
    return Container(
      color: kCabeceraAdmin,
      padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
      child: const Row(
        children: [
          SizedBox(width: _anchoNumero, child: Text('VUELO', style: estilo)),
          Expanded(flex: 3, child: Text('RUTA', style: estilo)),
          Expanded(flex: 3, child: Text('SALIDA → LLEGADA', style: estilo)),
          SizedBox(width: _anchoPrecio, child: Text('PRECIO', style: estilo)),
          SizedBox(
              width: _anchoOcupacion, child: Text('OCUPACIÓN', style: estilo)),
          SizedBox(width: 16),
          SizedBox(width: _anchoEstado, child: Text('ESTADO', style: estilo)),
          SizedBox(width: _anchoAcciones),
        ],
      ),
    );
  }
}

String _horario(VueloAdmin v) {
  final d = v.datos;
  return '${d.horaSalidaCorta} → ${d.horaLlegadaCorta} · '
      '${Formato.duracion(d.duracionMinutos)}';
}

Widget _ocupacion(VueloAdmin v) {
  if (v.cancelado) {
    return Text(
      v.reservasCanceladas == 0
          ? 'Sin reservas'
          : '${v.reservasCanceladas} reserva(s) cancelada(s)',
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      BarraOcupacion(vendidos: v.vendidos, total: v.totalAsientos),
      if (v.enCarritos > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('+${v.enCarritos} en carritos',
              style: const TextStyle(fontSize: 11, color: kCarritoTexto)),
        ),
    ],
  );
}

class _FilaVuelo extends StatelessWidget {
  final VueloAdmin vuelo;
  final VoidCallback onTap;
  final ValueChanged<_Accion> onAccion;

  const _FilaVuelo({
    required this.vuelo,
    required this.onTap,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final v = vuelo;
    final d = v.datos;
    final tenue = v.cancelado || v.yaSalio;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBordeFilaAdmin)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _anchoNumero,
              child: Text('#${v.id}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.ruta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tenue
                              ? AppColors.textSecondary
                              : AppColors.primary)),
                  Text(d.aerolinea,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Formato.fechaConDia(d.salida),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Text(_horario(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            SizedBox(
              width: _anchoPrecio,
              child: Text(dineroAdmin(d.precio),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            SizedBox(width: _anchoOcupacion, child: _ocupacion(v)),
            const SizedBox(width: 16),
            SizedBox(
              width: _anchoEstado,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChipEstadoVuelo(estado: v.estado),
              ),
            ),
            SizedBox(
                width: _anchoAcciones,
                child: _MenuAcciones(vuelo: v, onAccion: onAccion)),
          ],
        ),
      ),
    );
  }
}

/// Versión en tarjeta para pantallas estrechas.
class _TarjetaVuelo extends StatelessWidget {
  final VueloAdmin vuelo;
  final VoidCallback onTap;
  final ValueChanged<_Accion> onAccion;

  const _TarjetaVuelo({
    required this.vuelo,
    required this.onTap,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final v = vuelo;
    final d = v.datos;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBordeFilaAdmin)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('#${v.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(v.ruta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                ChipEstadoVuelo(estado: v.estado),
                _MenuAcciones(vuelo: v, onAccion: onAccion),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${d.aerolinea} · ${Formato.fechaConDia(d.salida)} · '
                '${_horario(v)} · ${dineroAdmin(d.precio)}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ocupacion(v),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAcciones extends StatelessWidget {
  final VueloAdmin vuelo;
  final ValueChanged<_Accion> onAccion;

  const _MenuAcciones({required this.vuelo, required this.onAccion});

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<_Accion> item(_Accion a, IconData icono, String texto,
            {Color color = AppColors.primary}) =>
        PopupMenuItem(
          value: a,
          child: Row(children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 12),
            Text(texto, style: TextStyle(color: color)),
          ]),
        );

    return PopupMenuButton<_Accion>(
      tooltip: 'Acciones del vuelo #${vuelo.id}',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onAccion,
      itemBuilder: (_) => [
        item(
            _Accion.ver, Icons.event_seat_outlined, 'Ver asientos y pasajeros'),
        if (vuelo.modificable)
          item(_Accion.editar, Icons.edit_outlined, 'Editar'),
        item(_Accion.duplicar, Icons.copy_rounded, 'Duplicar vuelo'),
        if (vuelo.reactivable)
          item(_Accion.reactivar, Icons.replay_rounded, 'Reactivar'),
        if (vuelo.modificable) ...[
          const PopupMenuDivider(),
          item(_Accion.cancelar, Icons.cancel_outlined, 'Cancelar vuelo…',
              color: AppColors.error),
        ],
      ],
    );
  }
}
