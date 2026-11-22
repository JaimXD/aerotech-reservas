import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/panel_admin.dart';
import '../../services/admin_service.dart';
import '../../services/cambios_admin.dart';
import '../../services/session_manager.dart';
import '../../utils/formato.dart';
import '../../widgets/admin/menu_lateral_admin.dart';

const _borde = Color(0xFFE6DED6);
const _bordeFila = Color(0xFFF0EAE3);
const _fondoCabecera = Color(0xFFF7F2EC);
const _barraFondo = Color(0xFFEFE8E1);
const _barraClara = Color(0xFFD9B8A0);

/// "$1,284.80"
String _dinero(double v) {
  final partes = v.toStringAsFixed(2).split('.');
  final entero =
      partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '\$$entero.${partes[1]}';
}

/// Panel de inicio del administrador.
class PanelAdminPage extends StatefulWidget {
  /// Para que los enlaces del panel abran otra sección del menú.
  final ValueChanged<SeccionAdmin> onIrA;

  /// Abre el detalle de un vuelo (filas de "Próximas salidas").
  final ValueChanged<int> onVerVuelo;

  const PanelAdminPage({
    super.key,
    required this.onIrA,
    required this.onVerVuelo,
  });

  @override
  State<PanelAdminPage> createState() => _PanelAdminPageState();
}

class _PanelAdminPageState extends State<PanelAdminPage> {
  final AdminService _service = AdminService();

  PanelAdmin? _panel;
  String? _error;
  int _consulta = 0; // descarta respuestas viejas si llegan tarde

  /// El panel resume todo: se recarga solo con cualquier cambio.
  late final VoidCallback _dejarDeEscuchar;

  @override
  void initState() {
    super.initState();
    _cargar();
    _dejarDeEscuchar = CambiosAdmin.instancia.escuchar(
      DatoAdmin.values.toSet(),
      () => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _dejarDeEscuchar();
    super.dispose();
  }

  /// [silencioso]: recarga automática; conserva lo que se ve y no muestra errores.
  Future<void> _cargar({bool silencioso = false}) async {
    final consulta = ++_consulta;
    if (!silencioso && _error != null) setState(() => _error = null);
    try {
      final panel = await _service.obtenerPanel();
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _panel = panel;
        _error = null;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta || silencioso) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = _panel;
    if (panel == null) {
      if (_error != null) {
        return _Error(mensaje: _error!, onReintentar: _cargar);
      }
      return const Center(
          child: CircularProgressIndicator(color: AppColors.secondary));
    }
    return _Contenido(
      panel: panel,
      onIrA: widget.onIrA,
      onVerVuelo: widget.onVerVuelo,
    );
  }
}

class _Contenido extends StatelessWidget {
  final PanelAdmin panel;
  final ValueChanged<SeccionAdmin> onIrA;
  final ValueChanged<int> onVerVuelo;

  const _Contenido({
    required this.panel,
    required this.onIrA,
    required this.onVerVuelo,
  });

  String _saludo() {
    final h = DateTime.now().hour;
    final parte =
        h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
    final completo = SessionManager().nombreCompleto?.trim() ?? '';
    final nombre =
        completo.isEmpty ? '' : ', ${completo.split(RegExp(r'\s+')).first}';
    return '$parte$nombre';
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();

    return LayoutBuilder(
      builder: (context, c) {
        final compacto = c.maxWidth < 700;
        final padding = compacto ? 16.0 : 32.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padding, 28, padding, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Formato.fechaLarga(hoy),
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_saludo(),
                          style: TextStyle(
                              fontSize: compacto ? 22 : 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _Indicadores(panel: panel),
                  const SizedBox(height: 18),
                  _FilaDoble(
                    apilar: c.maxWidth < 900,
                    izquierda: _VentasSemana(panel: panel),
                    derecha: _UltimasReservas(
                      reservas: panel.ultimasReservas,
                      onVerTodas: () => onIrA(SeccionAdmin.reservas),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ProximasSalidas(
                    salidas: panel.proximasSalidas,
                    onVerTodos: () => onIrA(SeccionAdmin.vuelos),
                    onVerVuelo: onVerVuelo,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dos tarjetas lado a lado (3:2) que se apilan en pantallas estrechas.
class _FilaDoble extends StatelessWidget {
  final bool apilar;
  final Widget izquierda;
  final Widget derecha;

  const _FilaDoble({
    required this.apilar,
    required this.izquierda,
    required this.derecha,
  });

  @override
  Widget build(BuildContext context) {
    if (apilar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [izquierda, const SizedBox(height: 18), derecha],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: izquierda),
        const SizedBox(width: 18),
        Expanded(flex: 2, child: derecha),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Indicadores
// ════════════════════════════════════════════════════════════════

class _Indicadores extends StatelessWidget {
  final PanelAdmin panel;

  const _Indicadores({required this.panel});

  @override
  Widget build(BuildContext context) {
    final variacion = panel.variacionVentas;
    final sube = (variacion ?? 0) >= 0;

    final tarjetas = <Widget>[
      _Indicador(
        titulo: 'Ventas de hoy',
        valor: _dinero(panel.ventasHoy),
        pie: Text(
          variacion == null
              ? 'Ayer no hubo ventas'
              : '${sube ? '▲' : '▼'} ${variacion.abs()} % frente a ayer',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: variacion == null
                ? AppColors.textSecondary
                : (sube ? AppColors.success : AppColors.error),
          ),
        ),
      ),
      _Indicador(
        titulo: 'Reservas de hoy',
        valor: '${panel.reservasHoy}',
        pie: Text(
          panel.canceladasHoy == 0
              ? 'Ninguna cancelada'
              : '${panel.canceladasHoy} cancelada${panel.canceladasHoy == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
      _Indicador(
        titulo: 'Ocupación de próximos vuelos',
        valor: '${panel.ocupacion} %',
        pie: _Barra(valor: panel.ocupacion / 100),
      ),
      _Indicador(
        titulo: 'En carritos ahora',
        destacado: true,
        punto: true,
        valor:
            '${panel.asientosEnCarritos} asiento${panel.asientosEnCarritos == 1 ? '' : 's'}',
        pie: Text(
          panel.asientosEnCarritos == 0
              ? 'Ningún asiento apartado'
              : 'Apartados por ${panel.clientesConCarrito} cliente${panel.clientesConCarrito == 1 ? '' : 's'} · se liberan en máx. 10 min',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
        const espacio = 14.0;
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final t in tarjetas) SizedBox(width: ancho, child: t),
          ],
        );
      },
    );
  }
}

class _Indicador extends StatelessWidget {
  final String titulo;
  final String valor;
  final Widget pie;
  final bool destacado;
  final bool punto;

  const _Indicador({
    required this.titulo,
    required this.valor,
    required this.pie,
    this.destacado = false,
    this.punto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: destacado ? AppColors.warningLight : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: destacado ? const Color(0xFFF3DFA2) : _borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (punto) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(valor,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 6),
          pie,
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  /// 0.0 – 1.0
  final double valor;
  final Color color;

  const _Barra({required this.valor, this.color = AppColors.secondary});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: valor.clamp(0, 1).toDouble(),
        minHeight: 8,
        backgroundColor: _barraFondo,
        color: color,
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Tarjeta({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borde),
      ),
      child: child,
    );
  }
}

class _TituloTarjeta extends StatelessWidget {
  final String texto;
  final Widget? accion;

  const _TituloTarjeta(this.texto, {this.accion});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(texto,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
        if (accion != null) accion!,
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Ventas de la semana (gráfico de barras)
// ════════════════════════════════════════════════════════════════

class _VentasSemana extends StatelessWidget {
  final PanelAdmin panel;

  const _VentasSemana({required this.panel});

  @override
  Widget build(BuildContext context) {
    final dias = panel.ventasSemana;
    final maximo = dias.fold<double>(0, (m, d) => d.total > m ? d.total : m);

    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TituloTarjeta(
            'Ventas de los últimos 7 días',
            accion: Text.rich(
              TextSpan(text: 'Total con IVA: ', children: [
                TextSpan(
                    text: _dinero(panel.totalSemana),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            label: 'Gráfico de ventas diarias de los últimos 7 días',
            child: SizedBox(
              height: 210,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < dias.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _BarraDia(
                        dia: dias[i],
                        esHoy: i == dias.length - 1,
                        proporcion: maximo == 0 ? 0 : dias[i].total / maximo,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraDia extends StatelessWidget {
  final VentaDia dia;
  final bool esHoy;

  /// 0.0 – 1.0 respecto al día con más ventas.
  final double proporcion;

  const _BarraDia({
    required this.dia,
    required this.esHoy,
    required this.proporcion,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 11,
      color: esHoy ? AppColors.primary : AppColors.textSecondary,
      fontWeight: esHoy ? FontWeight.w700 : FontWeight.w400,
    );

    return LayoutBuilder(
      builder: (context, c) {
        // Espacio para la cifra (arriba) y el día (abajo).
        final alturaMax = c.maxHeight - 56;
        final alto = (alturaMax * proporcion).clamp(4.0, alturaMax);

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dia.total == 0 ? '\$0' : _dinero(dia.total).split('.').first,
                style: estilo,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: alto,
              decoration: BoxDecoration(
                color: esHoy ? AppColors.secondary : _barraClara,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
            const SizedBox(height: 6),
            Text(esHoy ? 'hoy' : Formato.diaCorto(dia.fecha),
                style: estilo.copyWith(fontSize: 12)),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Últimas reservas
// ════════════════════════════════════════════════════════════════

class _UltimasReservas extends StatelessWidget {
  final List<ReservaReciente> reservas;
  final VoidCallback onVerTodas;

  const _UltimasReservas({required this.reservas, required this.onVerTodas});

  static String _hace(DateTime f) {
    final d = DateTime.now().difference(f);
    if (d.inMinutes < 1) return 'hace un momento';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    return Formato.fechaCorta(f);
  }

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TituloTarjeta('Últimas reservas'),
          const SizedBox(height: 12),
          if (reservas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Todavía no hay reservas.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          for (final r in reservas)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: r.cancelada ? AppColors.error : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: r.cancelada
                                ? 'Reserva cancelada'
                                : 'Compra confirmada',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' · ${r.cliente}\n'),
                          TextSpan(
                            text:
                                '${r.origen} → ${r.destino}${r.asientos.isEmpty ? '' : ' · ${r.asientos}'} · ${_hace(r.fecha)}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                          fontSize: 14, height: 1.4, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_dinero(r.total),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: r.cancelada
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        decoration:
                            r.cancelada ? TextDecoration.lineThrough : null,
                      )),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onVerTodas,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                minimumSize: const Size(0, 44),
                padding: EdgeInsets.zero,
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Ver todas las reservas'),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Próximas salidas
// ════════════════════════════════════════════════════════════════

class _ProximasSalidas extends StatelessWidget {
  final List<SalidaProxima> salidas;
  final VoidCallback onVerTodos;
  final ValueChanged<int> onVerVuelo;

  const _ProximasSalidas({
    required this.salidas,
    required this.onVerTodos,
    required this.onVerVuelo,
  });

  static String _cuando(SalidaProxima s) {
    final hoy = Formato.soloFecha(DateTime.now());
    final dia = Formato.soloFecha(s.fecha);
    if (dia == hoy) return 'Hoy · ${s.hora}';
    if (dia == Formato.sumarDias(hoy, 1)) return 'Mañana · ${s.hora}';
    return '${Formato.fechaConDia(dia)} · ${s.hora}';
  }

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TituloTarjeta(
            'Próximas salidas',
            accion: TextButton(
              onPressed: onVerTodos,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                minimumSize: const Size(0, 44),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Ver todos los vuelos'),
            ),
          ),
          const SizedBox(height: 8),
          if (salidas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No hay vuelos programados.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                // En pantallas estrechas la tabla se desplaza de lado.
                const anchoMinimo = 640.0;
                final ancho =
                    c.maxWidth < anchoMinimo ? anchoMinimo : c.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: ancho,
                    child: Column(
                      children: [
                        const _FilaTabla(
                          cabecera: true,
                          celdas: [
                            Text('VUELO'),
                            Text('RUTA'),
                            Text('SALIDA'),
                            Text('OCUPACIÓN'),
                            Text('ESTADO'),
                          ],
                        ),
                        for (final s in salidas)
                          _FilaTabla(
                            onTap: () => onVerVuelo(s.id),
                            celdas: [
                              Text('#${s.id}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.ruta,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(s.aerolinea,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                              Text(_cuando(s)),
                              Row(
                                children: [
                                  Expanded(
                                    child: _Barra(
                                      valor: s.ocupacion,
                                      color: s.completo
                                          ? AppColors.primary
                                          : AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 48,
                                    child: Text('${s.vendidos}/${s.total}',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _ChipEstado(salida: s),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FilaTabla extends StatelessWidget {
  final List<Widget> celdas;
  final bool cabecera;
  final VoidCallback? onTap;

  const _FilaTabla({required this.celdas, this.cabecera = false, this.onTap});

  static const _flex = [1, 3, 2, 3, 2];

  @override
  Widget build(BuildContext context) {
    final fila = Container(
      padding: EdgeInsets.symmetric(vertical: cabecera ? 8 : 12),
      decoration: BoxDecoration(
        color: cabecera ? _fondoCabecera : null,
        border:
            cabecera ? null : const Border(top: BorderSide(color: _bordeFila)),
      ),
      child: DefaultTextStyle.merge(
        style: cabecera
            ? const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary)
            : const TextStyle(fontSize: 14, color: AppColors.primary),
        child: Row(
          children: [
            for (var i = 0; i < celdas.length; i++)
              Expanded(
                flex: _flex[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: celdas[i],
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return fila;
    return InkWell(onTap: onTap, child: fila);
  }
}

class _ChipEstado extends StatelessWidget {
  final SalidaProxima salida;

  const _ChipEstado({required this.salida});

  @override
  Widget build(BuildContext context) {
    final esHoy =
        Formato.soloFecha(salida.fecha) == Formato.soloFecha(DateTime.now());
    final (texto, fondo, color) = salida.completo
        ? ('Completo', _barraFondo, AppColors.primary)
        : esHoy
            ? ('Sale hoy', const Color(0xFFFFF3E0), const Color(0xFF8A4B00))
            : ('Programado', AppColors.successLight, const Color(0xFF1B5E20));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Error
// ════════════════════════════════════════════════════════════════

class _Error extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _Error({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onReintentar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(160, 44),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
