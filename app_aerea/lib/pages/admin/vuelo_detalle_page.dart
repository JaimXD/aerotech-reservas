import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/vuelo_admin.dart';
import '../../services/admin_vuelo_service.dart';
import '../../utils/descarga.dart';
import '../../utils/formato.dart';
import '../../widgets/admin/admin_ui.dart';
import '../../widgets/admin/dialogo_cancelar_vuelo.dart';
import '../../widgets/admin/mapa_avion_admin.dart';
import '../../widgets/custom_toast.dart';
import 'vuelo_form_page.dart';

/// Detalle de un vuelo: ocupación, mapa de asientos y pasajeros.
class VueloDetallePage extends StatefulWidget {
  final int vueloId;
  final List<String> aerolineas;
  final List<String> ciudades;

  const VueloDetallePage({
    super.key,
    required this.vueloId,
    this.aerolineas = const [],
    this.ciudades = const [],
  });

  @override
  State<VueloDetallePage> createState() => _VueloDetallePageState();
}

class _VueloDetallePageState extends State<VueloDetallePage> {
  final _service = AdminVueloService();

  DetalleVueloAdmin? _detalle;
  String? _error;
  bool _cargando = true;
  bool _reactivando = false;
  String? _codigoResaltado;

  /// Momento en que se libera el primer asiento apartado en un carrito.
  DateTime? _vencimiento;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await _service.detalle(widget.vueloId);
      if (!mounted) return;
      setState(() {
        _detalle = d;
        _cargando = false;
        if (_codigoResaltado != null &&
            !d.asientos.any((a) => a.codigo == _codigoResaltado)) {
          _codigoResaltado = null;
        }
      });
      _iniciarReloj(d.primerVencimiento);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e);
      });
    }
  }

  /// Cuenta regresiva del primer carrito; al llegar a cero se recarga.
  void _iniciarReloj(int? segundos) {
    _reloj?.cancel();
    _vencimiento = segundos == null
        ? null
        : DateTime.now().add(Duration(seconds: segundos));
    if (_vencimiento == null) return;
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(_vencimiento!)) {
        _reloj?.cancel();
        _cargar();
      } else {
        setState(() {});
      }
    });
  }

  String get _cuentaRegresiva {
    final s = _vencimiento == null
        ? 0
        : _vencimiento!.difference(DateTime.now()).inSeconds.clamp(0, 3600);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ── Acciones ─────────────────────────────────────────────────────

  Future<void> _editar() async {
    final guardado = await Navigator.push<VueloAdmin>(
      context,
      MaterialPageRoute(
        builder: (_) => VueloFormPage(
          vuelo: _detalle!.vuelo,
          aerolineas: widget.aerolineas,
          ciudades: widget.ciudades,
        ),
      ),
    );
    if (guardado != null) _cargar();
  }

  Future<void> _duplicar() async {
    final nuevo = await Navigator.push<VueloAdmin>(
      context,
      MaterialPageRoute(
        builder: (_) => VueloFormPage(
          copia: _detalle!.vuelo,
          aerolineas: widget.aerolineas,
          ciudades: widget.ciudades,
        ),
      ),
    );
    if (nuevo != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VueloDetallePage(
            vueloId: nuevo.id,
            aerolineas: widget.aerolineas,
            ciudades: widget.ciudades,
          ),
        ),
      );
    }
  }

  Future<void> _cancelar() async {
    final r = await confirmarCancelacionVuelo(context, _detalle!.vuelo);
    if (r == null || !mounted) return;
    CustomToast.showSuccess(
        context,
        r.reservasCanceladas == 0
            ? 'Vuelo #${widget.vueloId} cancelado'
            : 'Vuelo #${widget.vueloId} cancelado · ${r.reservasCanceladas} '
                'reserva(s) cancelada(s)');
    _cargar();
  }

  Future<void> _reactivar() async {
    setState(() => _reactivando = true);
    try {
      await _service.reactivar(widget.vueloId);
      if (!mounted) return;
      CustomToast.showSuccess(
          context, 'El vuelo #${widget.vueloId} vuelve a estar a la venta');
      await _cargar();
    } catch (e) {
      if (mounted) CustomToast.showError(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _reactivando = false);
    }
  }

  void _descargarLista() {
    final d = _detalle!;
    String celda(Object v) => '"${v.toString().replaceAll('"', '""')}"';
    final filas = [
      ['Código', 'Cliente', 'Usuario', 'Correo', 'Asientos', 'Total con IVA',
          'Estado', 'Fecha de compra'],
      for (final p in d.pasajeros)
        [
          p.codigo,
          p.cliente,
          p.usuario,
          p.correo,
          p.asientos,
          p.total.toStringAsFixed(2),
          p.estado,
          '${Formato.iso(p.fecha)} ${p.fecha.hour.toString().padLeft(2, '0')}:'
              '${p.fecha.minute.toString().padLeft(2, '0')}',
        ],
    ];
    // BOM + punto y coma: Excel en español lo abre con columnas y tildes.
    final csv = '﻿${filas.map((f) => f.map(celda).join(';')).join('\r\n')}';
    try {
      descargarArchivo('pasajeros_vuelo_${d.vuelo.id}.csv', csv,
          tipo: 'text/csv');
    } catch (e) {
      CustomToast.showError(context, 'No se pudo descargar la lista');
    }
  }

  // ── Interfaz ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = _detalle;
    if (d == null) {
      return Material(
        color: AppColors.background,
        child: Center(
          child: _error != null
              ? ErrorAdmin(mensaje: _error!, onReintentar: _cargar)
              : const CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    final v = d.vuelo;
    final datos = v.datos;

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _cargar,
          child: PaginaAdmin(
            children: [
              EncabezadoAdmin(
                migas: [
                  MigaAdmin('Vuelos', onTap: () => Navigator.pop(context)),
                  MigaAdmin('#${v.id}'),
                ],
                titulo: v.ruta,
                chip: ChipEstadoVuelo(estado: v.estado),
                subtitulo: Text(
                  'Vuelo #${v.id} · ${datos.aerolinea} · '
                  '${Formato.fechaLarga(datos.salida).toLowerCase()} · '
                  '${datos.horaSalidaCorta} → ${datos.horaLlegadaCorta} · '
                  '${dineroAdmin(datos.precio)} por asiento',
                ),
                acciones: [
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.textSecondary,
                  ),
                  if (v.modificable)
                    BotonSecundarioAdmin(
                        texto: 'Editar',
                        icono: Icons.edit_outlined,
                        onPressed: _editar),
                  BotonSecundarioAdmin(
                      texto: 'Duplicar',
                      icono: Icons.copy_rounded,
                      onPressed: _duplicar),
                  if (v.modificable)
                    BotonSecundarioAdmin(
                        texto: 'Cancelar vuelo',
                        peligro: true,
                        onPressed: _cancelar),
                  if (v.reactivable)
                    BotonAdmin(
                      texto: 'Reactivar',
                      icono: Icons.replay_rounded,
                      cargando: _reactivando,
                      onPressed: _reactivar,
                    ),
                ],
              ),
              if (v.cancelado) ...[
                const SizedBox(height: 16),
                _Aviso(
                  texto: v.reactivable
                      ? 'Este vuelo está cancelado y no aparece en la búsqueda. '
                          'Puedes reactivarlo para volver a venderlo.'
                      : 'Este vuelo está cancelado.',
                ),
              ] else if (v.yaSalio) ...[
                const SizedBox(height: 16),
                const _Aviso(
                    texto:
                        'Este vuelo ya salió: solo se puede consultar o duplicar.'),
              ],
              const SizedBox(height: 20),
              FilaIndicadores(children: [
                IndicadorAdmin(
                  titulo: 'Vendidos',
                  valor: '${v.vendidos}',
                  detalle: 'de ${v.totalAsientos}',
                  pie: '${(v.ocupacion * 100).round()} % de ocupación',
                ),
                IndicadorAdmin(
                  titulo: 'En carritos',
                  valor: '${v.enCarritos}',
                  destacado: v.enCarritos > 0,
                  pie: v.enCarritos > 0
                      ? 'el primero se libera en $_cuentaRegresiva'
                      : 'Nadie lo tiene apartado',
                ),
                IndicadorAdmin(
                  titulo: 'Libres',
                  valor: '${d.libres}',
                  pie: d.libres == 0 ? 'Sin asientos a la venta' : null,
                ),
                IndicadorAdmin(
                  titulo: 'Ingresos (con IVA)',
                  valor: dineroAdmin(v.ingresos),
                  pie: '${v.reservasActivas} reserva(s) activa(s)',
                ),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final mapa = _tarjetaMapa(d);
                final pasajeros = _TarjetaPasajeros(
                  pasajeros: d.pasajeros,
                  codigoResaltado: _codigoResaltado,
                  onTap: (p) => setState(() => _codigoResaltado =
                      _codigoResaltado == p.codigo || !p.activa
                          ? null
                          : p.codigo),
                  onDescargar: d.pasajeros.isEmpty ? null : _descargarLista,
                );
                if (c.maxWidth < 1000) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [mapa, const SizedBox(height: 18), pasajeros],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: mapa),
                    const SizedBox(width: 18),
                    Expanded(flex: 6, child: pasajeros),
                  ],
                );
              }),
            ],
          ),
        ),
        if (_cargando)
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

  Widget _tarjetaMapa(DetalleVueloAdmin d) {
    return TarjetaAdmin(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mapa de asientos',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              MuestraAsiento(
                  estado: EstadoAsientoAdmin.vendido, texto: 'Vendido'),
              MuestraAsiento(
                  estado: EstadoAsientoAdmin.carrito, texto: 'En un carrito'),
              MuestraAsiento(estado: EstadoAsientoAdmin.libre, texto: 'Libre'),
            ],
          ),
          const SizedBox(height: 20),
          MapaAvionAdmin(
            asientos: d.asientos,
            codigoResaltado: _codigoResaltado,
            onTapVendido: (a) => setState(() => _codigoResaltado =
                _codigoResaltado == a.codigo ? null : a.codigo),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pasa el mouse sobre un asiento para ver de quién es. '
            'Púlsalo para resaltar su reserva.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Pasajeros ─────────────────────────

class _TarjetaPasajeros extends StatelessWidget {
  final List<PasajeroVuelo> pasajeros;
  final String? codigoResaltado;
  final ValueChanged<PasajeroVuelo> onTap;
  final VoidCallback? onDescargar;

  const _TarjetaPasajeros({
    required this.pasajeros,
    required this.codigoResaltado,
    required this.onTap,
    required this.onDescargar,
  });

  @override
  Widget build(BuildContext context) {
    final activas = pasajeros.where((p) => p.activa).length;
    return TarjetaAdmin(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Pasajeros ($activas ${activas == 1 ? 'reserva activa' : 'reservas activas'})',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              BotonSecundarioAdmin(
                texto: 'Descargar lista',
                icono: Icons.download_rounded,
                onPressed: onDescargar,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pasajeros.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text('Todavía nadie ha comprado este vuelo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final ancho = c.maxWidth >= 560;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ancho) const _CabeceraPasajeros(),
                  for (final p in pasajeros)
                    _FilaPasajero(
                      pasajero: p,
                      ancho: ancho,
                      resaltado: p.codigo == codigoResaltado,
                      onTap: () => onTap(p),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _CabeceraPasajeros extends StatelessWidget {
  const _CabeceraPasajeros();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary);
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('CLIENTE', style: estilo)),
          Expanded(flex: 3, child: Text('ASIENTOS', style: estilo)),
          Expanded(flex: 4, child: Text('CÓDIGO', style: estilo)),
          SizedBox(
              width: 90,
              child: Text('TOTAL', style: estilo, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _FilaPasajero extends StatelessWidget {
  final PasajeroVuelo pasajero;
  final bool ancho;
  final bool resaltado;
  final VoidCallback onTap;

  const _FilaPasajero({
    required this.pasajero,
    required this.ancho,
    required this.resaltado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = pasajero;
    final tenue = !p.activa;
    final colorTexto = tenue ? AppColors.textHint : AppColors.primary;

    final cliente = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(p.cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: colorTexto)),
            ),
            if (tenue) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(99)),
                child: const Text('Cancelada',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              ),
            ],
          ],
        ),
        Text(p.correo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
    final asientos = Text(p.asientos.isEmpty ? '—' : p.asientos,
        style: TextStyle(fontWeight: FontWeight.w600, color: colorTexto));
    final codigo = Text(p.codigo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
    final total = Text(dineroAdmin(p.total),
        textAlign: TextAlign.right,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorTexto,
            decoration: tenue ? TextDecoration.lineThrough : null));

    return Material(
      color: resaltado ? AppColors.successLight : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBordeFilaAdmin)),
          ),
          child: ancho
              ? Row(
                  children: [
                    Expanded(flex: 5, child: cliente),
                    Expanded(flex: 3, child: asientos),
                    Expanded(flex: 4, child: codigo),
                    SizedBox(width: 90, child: total),
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
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.event_seat_outlined,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      asientos,
                      const SizedBox(width: 12),
                      Expanded(child: codigo),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCabeceraAdmin,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBordeAdmin),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
