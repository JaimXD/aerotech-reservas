import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../services/reservas_service.dart';
import '../services/session_manager.dart';
import '../widgets/barra_superior.dart';
import '../widgets/custom_toast.dart';
import '../widgets/dialogos_reserva.dart';
import '../widgets/tarjeta_reserva.dart';
import '../widgets/dialogo_factura.dart';
import 'login_page.dart';
import 'seleccion_asientos_page.dart';

enum _Pestana {
  proximos('Próximos'),
  pasados('Pasados'),
  canceladas('Canceladas');

  const _Pestana(this.titulo);
  final String titulo;
}

class ReservasPage extends StatefulWidget {
  const ReservasPage({super.key});

  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage> {
  final _reservasService = ReservasService();
  final _busqueda = TextEditingController();

  List<Reserva> _reservas = [];
  bool _cargando = true;
  String? _error;
  _Pestana _pestana = _Pestana.proximos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
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
      final data = await _reservasService.listarMisReservas();
      if (!mounted) return;
      setState(() => _reservas = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CustomToast.parseError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Minúsculas y sin tildes, para buscar sin importar cómo se escriba.
  static String _normalizar(String s) {
    const con = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sin = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = con.indexOf(ch);
      b.write(i >= 0 ? sin[i] : ch);
    }
    return b.toString().trim();
  }

  List<Reserva> get _filtradas {
    final q = _normalizar(_busqueda.text);
    if (q.isEmpty) return _reservas;
    return _reservas.where((r) {
      final texto = _normalizar(
          '${r.codigoReserva} ${r.origen} ${r.destino} ${r.aerolinea}');
      return texto.contains(q);
    }).toList();
  }

  List<Reserva> _dePestana(_Pestana p, List<Reserva> lista) {
    switch (p) {
      case _Pestana.proximos:
        return lista.where((r) => r.esProxima).toList()
          ..sort((a, b) => a.vuelo.salida.compareTo(b.vuelo.salida));
      case _Pestana.pasados:
        return lista.where((r) => r.esPasada).toList()
          ..sort((a, b) => b.vuelo.salida.compareTo(a.vuelo.salida));
      case _Pestana.canceladas:
        return lista.where((r) => r.esCancelada).toList()
          ..sort((a, b) => b.vuelo.salida.compareTo(a.vuelo.salida));
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Acciones
  // ════════════════════════════════════════════════════════════════

  void _irAVuelos() => Navigator.of(context).maybePop();

  Future<void> _cerrarSesion() async {
    await SessionManager().cerrarSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _cambiarAsientos(Reserva r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionAsientosPage(vuelo: r.vuelo, reserva: r),
      ),
    ).then((_) => _cargar());
  }

  Future<void> _cambiarVuelo(Reserva r) async {
    final nuevo = await elegirNuevoVuelo(context, r);
    if (nuevo == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionAsientosPage(vuelo: nuevo, reserva: r),
      ),
    ).then((_) => _cargar());
  }

  Future<void> _cancelar(Reserva r) async {
    final confirmado = await confirmarCancelacion(context, r);
    if (!confirmado || !mounted) return;
    try {
      await _reservasService.cancelarReserva(r.id);
      if (!mounted) return;
      CustomToast.showSuccess(context, 'Reserva ${r.codigoReserva} cancelada');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, e);
    }
  }

  /// La tarjeta completa de una reserva. Los botones solo aparecen
  /// si el viaje todavía no ocurre. [enDialogo] cierra el diálogo
  /// antes de ejecutar la acción.
  Widget _tarjeta(Reserva r, {bool enDialogo = false}) {
    VoidCallback? accion(void Function(Reserva) f) {
      if (!r.esProxima) return null;
      return () {
        if (enDialogo) Navigator.pop(context);
        f(r);
      };
    }

    return TarjetaReserva(
      reserva: r,
      onCambiarAsientos: accion(_cambiarAsientos),
      onCambiarVuelo: accion(_cambiarVuelo),
      onCancelar: accion(_cancelar),
      // La factura se abre encima del detalle (no hace falta cerrarlo)
      onFactura: r.esCancelada ? null : () => mostrarFactura(context, r),
    );
  }

  void _verDetalle(Reserva r) {
    showDialog(
      context: context,
      barrierColor: AppColors.primary.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _tarjeta(r, enDialogo: true),
              ],
            ),
          ),
        ),
      ),
    );
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
            actual: SeccionApp.reservas,
            onVuelos: _irAVuelos,
            onCerrarSesion: _cerrarSesion,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _construirEncabezado(),
                        const SizedBox(height: 20),
                        _construirPestanas(),
                        const SizedBox(height: 28),
                        _construirContenido(),
                      ],
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

  Widget _construirEncabezado() {
    const titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis viajes',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Revisa, cambia o cancela tus reservas.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );

    final buscador = TextField(
      controller: _busqueda,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 14, color: AppColors.primary),
      decoration: InputDecoration(
        hintText: 'Buscar por código o ciudad',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: _busqueda.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(_busqueda.clear),
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titulo, const SizedBox(height: 16), buscador],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: titulo),
            const SizedBox(width: 16),
            SizedBox(width: 300, child: buscador),
          ],
        );
      },
    );
  }

  Widget _construirPestanas() {
    final lista = _filtradas;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final p in _Pestana.values)
              _BotonPestana(
                texto: p.titulo,
                cuenta: _cargando ? null : _dePestana(p, lista).length,
                activa: p == _pestana,
                onTap: () => setState(() => _pestana = p),
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirContenido() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    if (_error != null) {
      return _EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: 'No pudimos cargar tus reservas',
        texto: _error!,
        boton: 'Reintentar',
        onBoton: _cargar,
      );
    }

    final reservas = _dePestana(_pestana, _filtradas);
    final buscando = _busqueda.text.trim().isNotEmpty;

    if (reservas.isEmpty) {
      if (buscando) {
        return _EstadoVacio(
          icono: Icons.search_off,
          titulo: 'Sin resultados',
          texto:
              'No hay reservas que coincidan con "${_busqueda.text.trim()}" en ${_pestana.titulo.toLowerCase()}.',
          boton: 'Borrar búsqueda',
          onBoton: () => setState(_busqueda.clear),
        );
      }
      return switch (_pestana) {
        _Pestana.proximos => _EstadoVacio(
            icono: Icons.luggage_outlined,
            titulo: 'No tienes viajes próximos',
            texto: 'Cuando reserves un vuelo, aparecerá aquí.',
            boton: 'Buscar vuelos',
            onBoton: _irAVuelos,
          ),
        _Pestana.pasados => const _EstadoVacio(
            icono: Icons.history,
            titulo: 'Aún no tienes viajes pasados',
            texto: 'Los vuelos que ya realizaste aparecerán aquí.',
          ),
        _Pestana.canceladas => const _EstadoVacio(
            icono: Icons.event_busy_outlined,
            titulo: 'No tienes reservas canceladas',
            texto: 'Si cancelas una reserva, la verás aquí.',
          ),
      };
    }

    final filas = [
      for (final r in reservas.skip(_pestana == _Pestana.proximos ? 1 : 0))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilaReserva(reserva: r, onTap: () => _verDetalle(r)),
        ),
    ];

    if (_pestana != _Pestana.proximos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: filas,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TituloSeccion('Tu próximo viaje'),
        _tarjeta(reservas.first),
        if (filas.isNotEmpty) ...[
          const SizedBox(height: 32),
          const _TituloSeccion('Más adelante'),
          ...filas,
        ],
        const SizedBox(height: 20),
        _LlamadoBuscar(onTap: _irAVuelos),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets de la página
// ════════════════════════════════════════════════════════════════

class _BotonPestana extends StatelessWidget {
  final String texto;
  final int? cuenta;
  final bool activa;
  final VoidCallback onTap;

  const _BotonPestana({
    required this.texto,
    required this.cuenta,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: activa,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: activa ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                texto,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: activa ? FontWeight.bold : FontWeight.w500,
                  color: activa ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              if (cuenta != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activa ? AppColors.primary : const Color(0xFFE6DED6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$cuenta',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: activa ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _LlamadoBuscar extends StatelessWidget {
  final VoidCallback onTap;

  const _LlamadoBuscar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Planeas otro viaje?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Busca vuelos y elige tus asientos en minutos.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Buscar vuelos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String? boton;
  final VoidCallback? onBoton;

  const _EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.boton,
    this.onBoton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 16),
      child: Column(
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
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          if (boton != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBoton,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(boton!,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
