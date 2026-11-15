import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/reserva_admin.dart';
import '../../services/admin_reserva_service.dart';
import '../../utils/descarga.dart';
import '../../utils/formato.dart';
import '../../widgets/admin/admin_ui.dart';
import '../../widgets/custom_toast.dart';
import '../../widgets/dialogo_factura.dart';

/// Sección "Reservas" del administrador: todas las compras de los clientes.
class ReservasAdminPage extends StatefulWidget {
  /// Abre el detalle de un vuelo en la sección Vuelos.
  final ValueChanged<int>? onVerVuelo;

  const ReservasAdminPage({super.key, this.onVerVuelo});

  @override
  State<ReservasAdminPage> createState() => _ReservasAdminPageState();
}

class _ReservasAdminPageState extends State<ReservasAdminPage> {
  final _service = AdminReservaService();
  final _busqueda = TextEditingController();
  Timer? _espera;

  EstadoReservaFiltro _estado = EstadoReservaFiltro.todas;
  PeriodoReservas _periodo = PeriodoReservas.todo;
  int? _vuelo;
  int _pagina = 1;

  ListaReservasAdmin? _datos;
  bool _cargando = true;
  bool _exportando = false;
  String? _error;
  int _consulta = 0; // descarta respuestas viejas si llegan tarde

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _service.listar(
        estado: _estado,
        busqueda: _busqueda.text,
        periodo: _periodo,
        vueloId: _vuelo,
        pagina: _pagina,
      );
      if (!mounted || consulta != _consulta) return;
      if (datos.reservas.isEmpty && _pagina > 1) {
        _pagina = datos.paginas;
        await _cargar();
        return;
      }
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e);
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

  bool get _hayFiltros =>
      _estado != EstadoReservaFiltro.todas ||
      _periodo != PeriodoReservas.todo ||
      _vuelo != null ||
      _busqueda.text.trim().isNotEmpty;

  // ── Acciones ─────────────────────────────────────────────────────

  void _factura(ReservaAdmin r) {
    mostrarFacturaAdmin(context,
        codigo: r.codigo, cargar: () => _service.facturaXml(r.id));
  }

  Future<void> _cancelar(ReservaAdmin r) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DialogoCancelar(reserva: r),
    );
    if (ok != true || !mounted) return;
    try {
      final liberados = await _service.cancelar(r.id);
      if (!mounted) return;
      CustomToast.showSuccess(
          context,
          'Reserva ${r.codigo} cancelada'
          '${liberados.isEmpty ? '' : ' · asientos ${liberados.join(', ')} libres'}');
      _cargar();
    } catch (e) {
      if (mounted) CustomToast.showError(context, mensajeError(e));
    }
  }

  Future<void> _exportar() async {
    setState(() => _exportando = true);
    try {
      final todo = await _service.listar(
        estado: _estado,
        busqueda: _busqueda.text,
        periodo: _periodo,
        vueloId: _vuelo,
        exportar: true,
      );
      String celda(Object v) => '"${v.toString().replaceAll('"', '""')}"';
      String hora(DateTime d) =>
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      final filas = [
        [
          'Código', 'Fecha de compra', 'Cliente', 'Usuario', 'Correo',
          'Vuelo', 'Ruta', 'Salida', 'Asientos', 'Cantidad',
          'Total con IVA', 'Estado'
        ],
        for (final r in todo.reservas)
          [
            r.codigo,
            '${Formato.iso(r.fecha)} ${hora(r.fecha)}',
            r.cliente.nombre,
            r.cliente.usuario,
            r.cliente.correo,
            '#${r.vuelo.id}',
            '${r.vuelo.origen} - ${r.vuelo.destino}',
            '${Formato.iso(r.vuelo.fecha)} ${r.vuelo.hora}',
            r.asientos,
            r.cantidad,
            r.total.toStringAsFixed(2),
            r.estado,
          ],
      ];
      // BOM + punto y coma: Excel en español lo abre con columnas y tildes.
      final csv =
          '﻿${filas.map((f) => f.map(celda).join(';')).join('\r\n')}';
      descargarArchivo(
          'reservas_${Formato.iso(DateTime.now())}.csv', csv,
          tipo: 'text/csv');
      if (mounted) {
        CustomToast.showSuccess(
            context, '${todo.reservas.length} reserva(s) exportada(s)');
      }
    } catch (e) {
      if (mounted) CustomToast.showError(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ── Interfaz ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _cargar,
          child: PaginaAdmin(
            children: [
              EncabezadoAdmin(
                titulo: 'Reservas',
                subtitulo: Text(d == null
                    ? 'Todas las compras hechas por los clientes'
                    : 'Todas las compras hechas por los clientes · '
                        '${dineroAdmin(d.vendido)} en reservas activas'),
                acciones: [
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.textSecondary,
                  ),
                  BotonSecundarioAdmin(
                    texto: _exportando ? 'Exportando…' : 'Exportar',
                    icono: Icons.download_rounded,
                    onPressed: d == null || d.total == 0 || _exportando
                        ? null
                        : _exportar,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _pestanas(d),
              const SizedBox(height: 14),
              _filtros(d),
              const SizedBox(height: 14),
              if (d == null && _error != null)
                ErrorAdmin(mensaje: _error!, onReintentar: _cargar)
              else if (d == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.secondary)),
                )
              else ...[
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 10),
                ],
                _tabla(d),
              ],
            ],
          ),
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

  Widget _pestanas(ListaReservasAdmin? d) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in EstadoReservaFiltro.values) ...[
            _Pestana(
              texto: e.etiqueta,
              cantidad: d?.conteo(e),
              activa: _estado == e,
              onTap: () => _filtrar(() => _estado = e),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _filtros(ListaReservasAdmin? d) {
    final buscador = TextField(
      controller: _busqueda,
      onChanged: _alEscribir,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _filtrar(() {}),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por código, cliente o correo',
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

    final periodo = _Selector<PeriodoReservas>(
      valor: _periodo,
      opciones: {
        for (final p in PeriodoReservas.values)
          p: p == PeriodoReservas.todo ? 'Fecha de compra: Todas' : p.etiqueta,
      },
      onChanged: (p) => _filtrar(() => _periodo = p ?? PeriodoReservas.todo),
    );

    final vuelos = d?.vuelos ?? const <VueloFiltro>[];
    final vuelo = _Selector<int?>(
      valor: vuelos.any((v) => v.id == _vuelo) ? _vuelo : null,
      opciones: {
        null: 'Vuelo: Todos',
        for (final v in vuelos)
          v.id: '#${v.id} · ${v.origen} → ${v.destino} · '
              '${Formato.fechaCorta(v.fecha)}',
      },
      onChanged: (v) => _filtrar(() => _vuelo = v),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return Column(children: [
          buscador,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: periodo),
            const SizedBox(width: 10),
            Expanded(child: vuelo),
          ]),
        ]);
      }
      return Row(children: [
        Expanded(child: buscador),
        const SizedBox(width: 12),
        SizedBox(width: 220, child: periodo),
        const SizedBox(width: 12),
        SizedBox(width: 260, child: vuelo),
      ]);
    });
  }

  Widget _tabla(ListaReservasAdmin d) {
    if (d.reservas.isEmpty) {
      return TarjetaAdmin(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  size: 40, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text(
                _hayFiltros
                    ? 'No hay reservas con estos filtros.'
                    : 'Todavía no hay reservas.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (_hayFiltros) ...[
                const SizedBox(height: 12),
                BotonSecundarioAdmin(
                  texto: 'Quitar filtros',
                  onPressed: () => _filtrar(() {
                    _estado = EstadoReservaFiltro.todas;
                    _periodo = PeriodoReservas.todo;
                    _vuelo = null;
                    _busqueda.clear();
                  }),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final desde = (d.pagina - 1) * d.porPagina + 1;
    final hasta = desde + d.reservas.length - 1;

    return TarjetaAdmin(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ancho) const _Cabecera(),
            for (final r in d.reservas)
              _FilaReserva(
                reserva: r,
                ancho: ancho,
                onFactura: r.activa ? () => _factura(r) : null,
                onCancelar: r.cancelable ? () => _cancelar(r) : null,
                onVerVuelo: widget.onVerVuelo == null
                    ? null
                    : () => widget.onVerVuelo!(r.vuelo.id),
              ),
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

/// "Hoy 18:50", "Ayer 09:10" o "13 nov 18:50".
String _cuando(DateTime d) {
  final hoy = Formato.soloFecha(DateTime.now());
  final dia = Formato.soloFecha(d);
  final hora =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (dia == hoy) return 'Hoy $hora';
  if (dia == Formato.sumarDias(hoy, -1)) return 'Ayer $hora';
  final anio = dia.year == hoy.year ? '' : ' ${dia.year}';
  return '${Formato.fechaCorta(dia)}$anio $hora';
}

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
                            color:
                                activa ? Colors.white : AppColors.textSecondary)),
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

/// Lista desplegable con el estilo de los filtros.
class _Selector<T> extends StatelessWidget {
  final T valor;
  final Map<T, String> opciones;
  final ValueChanged<T?> onChanged;

  const _Selector({
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          style: const TextStyle(fontSize: 14, color: AppColors.primary),
          items: [
            for (final e in opciones.entries)
              DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

const _anchoAsientos = 110.0;
const _anchoTotal = 100.0;
const _anchoEstado = 100.0;
const _anchoAcciones = 96.0;

class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary);
    return Container(
      color: kCabeceraAdmin,
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('CÓDIGO', style: estilo)),
          Expanded(flex: 3, child: Text('CLIENTE', style: estilo)),
          Expanded(flex: 3, child: Text('VUELO', style: estilo)),
          SizedBox(
              width: _anchoAsientos, child: Text('ASIENTOS', style: estilo)),
          SizedBox(
              width: _anchoTotal,
              child: Text('TOTAL (IVA INCL.)',
                  style: estilo, textAlign: TextAlign.right)),
          SizedBox(width: 18),
          SizedBox(width: _anchoEstado, child: Text('ESTADO', style: estilo)),
          SizedBox(
              width: _anchoAcciones,
              child: Text('ACCIONES',
                  style: estilo, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _FilaReserva extends StatelessWidget {
  final ReservaAdmin reserva;
  final bool ancho;
  final VoidCallback? onFactura;
  final VoidCallback? onCancelar;
  final VoidCallback? onVerVuelo;

  const _FilaReserva({
    required this.reserva,
    required this.ancho,
    required this.onFactura,
    required this.onCancelar,
    required this.onVerVuelo,
  });

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final tenue = !r.activa;
    final color = tenue ? AppColors.textHint : AppColors.primary;
    const gris = TextStyle(fontSize: 12, color: AppColors.textSecondary);

    final codigo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.codigo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(_cuando(r.fecha), style: gris),
      ],
    );
    final cliente = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.cliente.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        Text(r.cliente.correo,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: gris),
      ],
    );
    final vuelo = InkWell(
      onTap: onVerVuelo,
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#${r.vuelo.id} · ${r.vuelo.ruta}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: onVerVuelo == null ? color : AppColors.secondary)),
          Text(
              '${Formato.fechaConDia(r.vuelo.fecha)} · ${r.vuelo.hora}'
              '${r.vuelo.cancelado ? ' · vuelo cancelado' : (r.vuelo.salio ? ' · ya salió' : '')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: gris),
        ],
      ),
    );
    final asientos = Text(
      r.asientos.isNotEmpty
          ? r.asientos
          : '${r.cantidad} ${r.cantidad == 1 ? 'asiento' : 'asientos'}',
      style: TextStyle(fontWeight: FontWeight.w600, color: color),
    );
    final total = Text(dineroAdmin(r.total),
        textAlign: TextAlign.right,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            decoration: tenue ? TextDecoration.lineThrough : null));
    final estado = _ChipEstado(reserva: r);
    final acciones = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: onFactura == null
              ? 'Las reservas canceladas no tienen factura'
              : 'Factura XML',
          onPressed: onFactura,
          icon: const Icon(Icons.receipt_long_outlined),
          color: AppColors.secondary,
        ),
        IconButton(
          tooltip: onCancelar != null
              ? 'Cancelar reserva'
              : (r.activa ? 'El vuelo ya salió' : 'Ya está cancelada'),
          onPressed: onCancelar,
          icon: const Icon(Icons.cancel_outlined),
          color: AppColors.error,
        ),
      ],
    );

    return Container(
      padding: ancho
          ? const EdgeInsets.fromLTRB(18, 10, 10, 10)
          : const EdgeInsets.fromLTRB(16, 12, 6, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBordeFilaAdmin)),
      ),
      child: ancho
          ? Row(
              children: [
                Expanded(flex: 3, child: codigo),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: cliente),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: vuelo),
                SizedBox(width: _anchoAsientos, child: asientos),
                SizedBox(width: _anchoTotal, child: total),
                const SizedBox(width: 18),
                SizedBox(
                  width: _anchoEstado,
                  child: Align(alignment: Alignment.centerLeft, child: estado),
                ),
                SizedBox(width: _anchoAcciones, child: Center(child: acciones)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: cliente),
                  const SizedBox(width: 8),
                  total,
                ]),
                const SizedBox(height: 6),
                vuelo,
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.event_seat_outlined,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  asientos,
                  const SizedBox(width: 10),
                  estado,
                  const Spacer(),
                  acciones,
                ]),
                Text(r.codigo,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: gris),
              ],
            ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final ReservaAdmin reserva;

  const _ChipEstado({required this.reserva});

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final (texto, fondo, color) = !r.activa
        ? ('Cancelada', AppColors.errorLight, AppColors.error)
        : r.vuelo.salio
            ? ('Volada', const Color(0xFFECEFF1), const Color(0xFF455A64))
            : ('Activa', AppColors.successLight, const Color(0xFF1B5E20));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(99)),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DialogoCancelar extends StatelessWidget {
  final ReservaAdmin reserva;

  const _DialogoCancelar({required this.reserva});

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    const negrita =
        TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary);
    final asientos = r.asientos.isEmpty
        ? '${r.cantidad} asiento(s)'
        : 'los asientos ${r.asientos}';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('¿Cancelar esta reserva?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'La reserva '),
                  TextSpan(text: r.codigo, style: negrita),
                  const TextSpan(text: ' de '),
                  TextSpan(text: r.cliente.nombre, style: negrita),
                  TextSpan(
                      text: ' (${dineroAdmin(r.total)}) quedará cancelada y '
                          '$asientos del vuelo #${r.vuelo.id} '
                          '${r.vuelo.ruta} volverán a estar a la venta. '
                          'El cliente la verá como "Cancelada".'),
                ]),
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  BotonSecundarioAdmin(
                      texto: 'Volver',
                      onPressed: () => Navigator.pop(context, false)),
                  BotonAdmin(
                    texto: 'Cancelar reserva',
                    color: AppColors.error,
                    onPressed: () => Navigator.pop(context, true),
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
