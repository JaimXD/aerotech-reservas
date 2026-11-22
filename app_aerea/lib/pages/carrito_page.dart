import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/carrito.dart';
import '../models/perfil.dart';
import '../services/carrito_service.dart';
import '../services/perfil_service.dart';
import '../services/session_manager.dart';
import '../utils/formato.dart';
import '../widgets/barra_superior.dart';
import '../widgets/custom_toast.dart';
import 'compra_confirmada_page.dart';
import '../widgets/acceso.dart';
import 'perfil_page.dart';
import 'reservas_page.dart';
import 'seleccion_asientos_page.dart';

const _bordeSuave = Color(0xFFE6DED6);
const _fondoSuave = Color(0xFFF7F2EC);

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final CarritoService _carrito = CarritoService();
  late final Future<Perfil> _perfil;

  Timer? _reloj;
  bool _cargando = true;
  bool _pagando = false;
  bool _revisandoVencidos = false;
  String? _error;

  /// Vuelo que se está quitando (para mostrar su indicador de carga).
  int? _quitando;

  @override
  void initState() {
    super.initState();
    _perfil = PerfilService().obtenerPerfil();
    _cargar();
    // Cada segundo se actualiza la cuenta regresiva.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  //  Datos
  // ════════════════════════════════════════════════════════════════

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _carrito.cargar();
    } catch (e) {
      if (mounted) setState(() => _error = CustomToast.parseError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _tic() {
    if (!mounted || _carrito.carrito.estaVacio) return;
    setState(() {});

    final vencidos = _carrito.carrito.items.where((i) => i.vencido).toList();
    if (vencidos.isEmpty || _revisandoVencidos) return;

    // Se acabó el tiempo: el servidor ya liberó esos asientos.
    _revisandoVencidos = true;
    final rutas = vencidos.map((i) => i.ruta).join(', ');
    CustomToast.showWarning(
        context, 'Se acabó el tiempo de $rutas. Los asientos se liberaron.');
    _cargar().whenComplete(() => _revisandoVencidos = false);
  }

  // ════════════════════════════════════════════════════════════════
  //  Acciones
  // ════════════════════════════════════════════════════════════════

  void _irAVuelos() => Navigator.of(context).popUntil((route) => route.isFirst);

  void _irAReservas() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReservasPage()),
      );

  void _irAPerfil() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PerfilPage()),
      );

  Future<void> _cerrarSesion() => Acceso.cerrarSesion(context);

  void _cambiarAsientos(ItemCarrito item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SeleccionAsientosPage(vuelo: item.vuelo, desdeCarrito: true),
      ),
    ).then((_) => _cargar());
  }

  Future<void> _quitar(ItemCarrito item) async {
    setState(() => _quitando = item.vuelo.id);
    try {
      await _carrito.quitar(item.vuelo.id);
      if (!mounted) return;
      CustomToast.showSuccess(context, '${item.ruta} se quitó del carrito');
    } catch (e) {
      if (mounted) CustomToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _quitando = null);
    }
  }

  Future<void> _pagar() async {
    setState(() => _pagando = true);
    try {
      final resultado = await _carrito.confirmar();
      if (!mounted) return;

      if (resultado.confirmadas.isEmpty) {
        final motivo = resultado.fallidas.isNotEmpty
            ? resultado.fallidas.first.motivo
            : 'No se pudo completar la compra.';
        CustomToast.showError(context, motivo);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompraConfirmadaPage(resultado: resultado),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, e);
      _cargar();
    } finally {
      if (mounted) setState(() => _pagando = false);
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
            actual: null,
            mostrarCarrito: false,
            onVuelos: _irAVuelos,
            onReservas: _irAReservas,
            onPerfil: _irAPerfil,
            onCerrarSesion: _cerrarSesion,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _carrito,
              builder: (context, _) => _contenido(_carrito.carrito),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(Carrito carrito) {
    if (carrito.estaVacio) {
      if (_cargando) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        );
      }
      if (_error != null) {
        return _Mensaje(
          icono: Icons.cloud_off_rounded,
          titulo: 'No pudimos cargar tu carrito',
          texto: _error!,
          boton: 'Reintentar',
          onBoton: _cargar,
        );
      }
      return _Mensaje(
        icono: Icons.shopping_cart_outlined,
        titulo: 'Tu carrito está vacío',
        texto:
            'Elige un vuelo y tus asientos. Los apartamos por ${carrito.minutosBloqueo} minutos mientras completas la compra.',
        boton: 'Buscar vuelos',
        onBoton: _irAVuelos,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth >= 900;

        final lista = _Lista(
          carrito: carrito,
          compacto: !ancho,
          quitando: _quitando,
          bloqueado: _pagando,
          onCambiar: _cambiarAsientos,
          onQuitar: _quitar,
          onAgregarOtro: _irAVuelos,
        );

        if (ancho) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 64),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: lista),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 380,
                      child: _Resumen(
                        carrito: carrito,
                        perfil: _perfil,
                        pagando: _pagando,
                        onPagar: _pagar,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Móvil: lista arriba y barra fija con el total abajo.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: lista,
              ),
            ),
            _BarraTotal(carrito: carrito, pagando: _pagando, onPagar: _pagar),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Lista de vuelos
// ════════════════════════════════════════════════════════════════

class _Lista extends StatelessWidget {
  final Carrito carrito;
  final bool compacto;
  final int? quitando;
  final bool bloqueado;
  final ValueChanged<ItemCarrito> onCambiar;
  final ValueChanged<ItemCarrito> onQuitar;
  final VoidCallback onAgregarOtro;

  const _Lista({
    required this.carrito,
    required this.compacto,
    required this.quitando,
    required this.bloqueado,
    required this.onCambiar,
    required this.onQuitar,
    required this.onAgregarOtro,
  });

  /// IDA / REGRESO cuando hay un vuelo y su vuelta; si no, VUELO.
  String _etiqueta(int i) {
    final items = carrito.items;
    final v = items[i].vuelo;
    bool esInverso(ItemCarrito o) =>
        o.vuelo.origen == v.destino && o.vuelo.destino == v.origen;

    for (var j = 0; j < items.length; j++) {
      if (j == i || !esInverso(items[j])) continue;
      return items[j].vuelo.salida.isBefore(v.salida) ? 'REGRESO' : 'IDA';
    }
    return 'VUELO';
  }

  @override
  Widget build(BuildContext context) {
    final n = carrito.items.length;
    final proximo = carrito.proximoAVencer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          children: [
            Text(
              'Tu carrito',
              style: TextStyle(
                fontSize: compacto ? 24 : 30,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '$n vuelo${n == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (proximo != null) ...[
          _AvisoTiempo(item: proximo, varios: n > 1),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < n; i++) ...[
          _TarjetaItem(
            item: carrito.items[i],
            etiqueta: _etiqueta(i),
            compacto: compacto,
            quitando: quitando == carrito.items[i].vuelo.id,
            bloqueado: bloqueado || quitando != null,
            onCambiar: () => onCambiar(carrito.items[i]),
            onQuitar: () => onQuitar(carrito.items[i]),
          ),
          const SizedBox(height: 14),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: bloqueado ? null : onAgregarOtro,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar otro vuelo'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
      ],
    );
  }
}

/// "09:42"
String _reloj(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _AvisoTiempo extends StatelessWidget {
  final ItemCarrito item;
  final bool varios;

  const _AvisoTiempo({required this.item, required this.varios});

  @override
  Widget build(BuildContext context) {
    final urgente = item.restante.inSeconds < 120;
    final texto = varios
        ? 'Tus asientos están apartados. Los de ${item.ruta} se liberan en '
        : 'Tus asientos están apartados. Se liberan en ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: urgente ? AppColors.errorLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: urgente ? const Color(0xFFF2B8B5) : const Color(0xFFF3DFA2)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              size: 20,
              color: urgente ? AppColors.error : const Color(0xFF8A6D00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: texto,
                children: [
                  TextSpan(
                    text: _reloj(item.restante),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const TextSpan(text: '. Confirma la compra antes de eso.'),
                ],
              ),
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: urgente ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaItem extends StatelessWidget {
  final ItemCarrito item;
  final String etiqueta;
  final bool compacto;
  final bool quitando;
  final bool bloqueado;
  final VoidCallback onCambiar;
  final VoidCallback onQuitar;

  const _TarjetaItem({
    required this.item,
    required this.etiqueta,
    required this.compacto,
    required this.quitando,
    required this.bloqueado,
    required this.onCambiar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final v = item.vuelo;
    final n = item.asientos.length;

    return Container(
      padding: EdgeInsets.all(compacto ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiqueta, aerolínea y tiempo restante
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v.aerolinea,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              _ChipTiempo(restante: item.restante),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.ruta,
            style: TextStyle(
              fontSize: compacto ? 18 : 21,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formato.fechaLarga(v.dia)} · ${v.horaSalidaCorta} – ${v.horaLlegadaCorta}',
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Asientos',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              for (final a in item.asientos)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    a,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _bordeSuave),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$n × ${Formato.dinero(v.precio)}',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                Formato.dinero(item.subtotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: bloqueado ? null : onCambiar,
                icon: const Icon(Icons.event_seat_outlined, size: 18),
                label: const Text('Cambiar asientos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              TextButton.icon(
                onPressed: bloqueado ? null : onQuitar,
                icon: quitando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.error),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Quitar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipTiempo extends StatelessWidget {
  final Duration restante;

  const _ChipTiempo({required this.restante});

  @override
  Widget build(BuildContext context) {
    final urgente = restante.inSeconds < 120;
    final color = urgente ? AppColors.error : AppColors.textSecondary;

    return Semantics(
      label: 'Apartado por ${restante.inMinutes} minutos más',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: urgente ? AppColors.errorLight : _fondoSuave,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              _reloj(restante),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Resumen de compra (escritorio)
// ════════════════════════════════════════════════════════════════

class _Resumen extends StatelessWidget {
  final Carrito carrito;
  final Future<Perfil> perfil;
  final bool pagando;
  final VoidCallback onPagar;

  const _Resumen({
    required this.carrito,
    required this.perfil,
    required this.pagando,
    required this.onPagar,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bordeSuave),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen de compra',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          for (final i in carrito.items) ...[
            _Linea(
              izquierda: '${i.ruta} · ${i.asientos.length}',
              derecha: Formato.dinero(i.subtotal),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          const Divider(height: 1, color: _bordeSuave),
          const SizedBox(height: 12),
          _Totales(carrito: carrito),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _fondoSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FutureBuilder<Perfil>(
              future: perfil,
              builder: (context, snap) {
                final nombre = snap.data?.nombreCompleto ??
                    session.nombreCompleto ??
                    session.username ??
                    '';
                final detalle = snap.data?.correo ??
                    (session.username != null ? '@${session.username}' : '');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Facturado a',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    if (detalle.isNotEmpty)
                      Text(detalle,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _BotonPagar(total: carrito.total, pagando: pagando, onPagar: onPagar),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tus asientos están apartados por ${carrito.minutosBloqueo} minutos y nadie más puede tomarlos. Se reservan definitivamente al confirmar.',
                  style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Totales extends StatelessWidget {
  final Carrito carrito;
  final bool compacto;

  const _Totales({required this.carrito, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Linea(
            izquierda: 'Subtotal', derecha: Formato.dinero(carrito.subtotal)),
        SizedBox(height: compacto ? 4 : 8),
        _Linea(
          izquierda: 'IVA (${carrito.porcentajeIva} %)',
          derecha: Formato.dinero(carrito.iva),
        ),
        SizedBox(height: compacto ? 6 : 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Total',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            const Spacer(),
            Text(
              Formato.dinero(carrito.total),
              style: TextStyle(
                fontSize: compacto ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  final String izquierda;
  final String derecha;

  const _Linea({required this.izquierda, required this.derecha});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(izquierda,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 12),
        Text(derecha,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ],
    );
  }
}

class _BotonPagar extends StatelessWidget {
  final double total;
  final bool pagando;
  final VoidCallback onPagar;

  const _BotonPagar({
    required this.total,
    required this.pagando,
    required this.onPagar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: pagando ? null : onPagar,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: pagando
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text('Procesando pago...',
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            : Text(total > 0
                ? 'Confirmar y pagar ${Formato.dinero(total)}'
                : 'Confirmar y pagar'),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Barra fija con el total (móvil)
// ════════════════════════════════════════════════════════════════

class _BarraTotal extends StatelessWidget {
  final Carrito carrito;
  final bool pagando;
  final VoidCallback onPagar;

  const _BarraTotal({
    required this.carrito,
    required this.pagando,
    required this.onPagar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _bordeSuave)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Totales(carrito: carrito, compacto: true),
            const SizedBox(height: 12),
            _BotonPagar(total: 0, pagando: pagando, onPagar: onPagar),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Carrito vacío / error
// ════════════════════════════════════════════════════════════════

class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final VoidCallback onBoton;

  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onBoton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 34, color: AppColors.secondary),
              ),
              const SizedBox(height: 18),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onBoton,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(boton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
