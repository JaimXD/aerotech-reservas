import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/asiento.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/asiento_service.dart';
import '../services/reservas_service.dart';
import '../widgets/asiento_boton.dart';
import '../widgets/custom_toast.dart';

class SeleccionAsientosPage extends StatefulWidget {
  final Vuelo vuelo;
  final Reserva? reserva;

  const SeleccionAsientosPage({
    super.key,
    required this.vuelo,
    this.reserva,
  });

  @override
  State<SeleccionAsientosPage> createState() => _SeleccionAsientosPageState();
}

class _SeleccionAsientosPageState extends State<SeleccionAsientosPage> {
  static const int maxAsientos = 6;

  // Medidas del mapa
  static const double _anchoVentana = 18;
  static const double _anchoPasillo = 44;
  static const double _separacion = 12;
  static const double _margenFuselaje =
      3 + 8 + 22; // borde + borde interior + relleno

  static final RegExp _formatoAsiento = RegExp(r'^(\d+)([A-Z])$');

  static const _dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];
  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  final AsientoService asientoService = AsientoService();
  final ReservasService reservasService = ReservasService();

  List<Asiento> asientos = [];
  List<String> seleccionados = [];

  bool cargando = true;
  bool reservando = false;
  String mensaje = "";

  @override
  void initState() {
    super.initState();
    if (widget.reserva != null) {
      seleccionados = List<String>.from(widget.reserva!.asientos)
        ..sort(_ordenAsientos);
    }
    cargarAsientos();
  }

  // ───────────────────────── Datos ─────────────────────────

  Future<void> cargarAsientos({bool limpiarMensaje = true}) async {
    setState(() {
      cargando = true;
      if (limpiarMensaje) mensaje = "";
    });

    try {
      final data = await asientoService.listarAsientos(widget.vuelo.id);
      if (!mounted) return;

      // Al editar, los asientos de esta misma reserva se muestran como disponibles
      // para que el usuario pueda conservarlos o cambiarlos.
      final mapeados = data.map((asiento) {
        if (widget.reserva != null && asiento.reservaId == widget.reserva!.id) {
          return Asiento(
            id: asiento.id,
            vueloId: asiento.vueloId,
            numeroAsiento: asiento.numeroAsiento,
            estado: "DISPONIBLE",
            reservaId: asiento.reservaId,
          );
        }
        return asiento;
      }).toList();

      setState(() => asientos = mapeados);
    } catch (e) {
      if (!mounted) return;
      setState(() => mensaje = "No se pudieron cargar los asientos.");
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  int _ordenAsientos(String a, String b) {
    final ma = _formatoAsiento.firstMatch(a);
    final mb = _formatoAsiento.firstMatch(b);
    if (ma == null || mb == null) return a.compareTo(b);
    final porFila = int.parse(ma.group(1)!).compareTo(int.parse(mb.group(1)!));
    return porFila != 0 ? porFila : ma.group(2)!.compareTo(mb.group(2)!);
  }

  /// Agrupa los asientos por fila: {1: {A: asiento, B: asiento…}, 2: {…}}
  Map<int, Map<String, Asiento>> _agruparPorFila() {
    final filas = <int, Map<String, Asiento>>{};
    for (final asiento in asientos) {
      final m = _formatoAsiento
          .firstMatch(asiento.numeroAsiento.trim().toUpperCase());
      if (m == null) continue;
      filas.putIfAbsent(int.parse(m.group(1)!), () => {})[m.group(2)!] =
          asiento;
    }
    final ordenadas = filas.keys.toList()..sort();
    return {for (final f in ordenadas) f: filas[f]!};
  }

  void cambiarSeleccion(Asiento asiento) {
    if (!asiento.disponible || reservando) return;
    final numero = asiento.numeroAsiento;

    if (seleccionados.contains(numero)) {
      setState(() => seleccionados.remove(numero));
      return;
    }
    if (seleccionados.length >= maxAsientos) {
      CustomToast.showWarning(context,
          'Puedes seleccionar hasta $maxAsientos asientos por reserva.');
      return;
    }
    setState(() {
      seleccionados.add(numero);
      seleccionados.sort(_ordenAsientos);
    });
  }

  double get total => seleccionados.length * widget.vuelo.precio;

  Future<void> reservar() async {
    if (seleccionados.isEmpty) {
      setState(() => mensaje = "Debe seleccionar al menos un asiento.");
      return;
    }

    setState(() {
      reservando = true;
      mensaje = "";
    });

    try {
      if (widget.reserva != null) {
        await reservasService.editarReserva(
          widget.reserva!.id,
          widget.vuelo.id,
          seleccionados,
        );
        if (!mounted) return;
        CustomToast.showSuccess(context, "Reserva modificada correctamente");
      } else {
        final respuesta = await asientoService.reservarAsientos(
          vueloId: widget.vuelo.id,
          asientos: seleccionados,
        );
        final codigo = respuesta["reserva"]["codigo_reserva"];
        if (!mounted) return;
        CustomToast.showSuccess(
            context, "Reserva creada correctamente: $codigo");
      }

      Navigator.pop(context);
    } catch (e) {
      final textoError = e.toString();
      String mensajeLimpio;

      if (textoError.contains("Uno o más asientos ya no están disponibles") ||
          textoError.contains(
              "Uno o m\\u00e1s asientos ya no est\\u00e1n disponibles") ||
          textoError.contains("asientos ya no est") ||
          textoError.contains("No se pudo registrar la reserva")) {
        mensajeLimpio =
            "Concurrencia detectada: uno de los asientos ya fue reservado por otro usuario. Elige otro asiento.";
      } else {
        mensajeLimpio = CustomToast.parseError(e);
      }

      if (!mounted) return;
      CustomToast.showError(context, mensajeLimpio);

      setState(() {
        mensaje = mensajeLimpio;
        if (widget.reserva == null) seleccionados.clear();
        reservando = false;
      });

      // Se recarga el mapa para mostrar el estado real de los asientos.
      await cargarAsientos(limpiarMensaje: false);
    } finally {
      if (mounted) setState(() => reservando = false);
    }
  }

  // ─────────────────────── Formato ───────────────────────

  String _fechaLarga(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_dias[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]} de ${d.year}';
  }

  String _hora(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;

  String? _duracion(Vuelo v) {
    final salida = DateTime.tryParse('${v.fecha}T${v.horaSalida}');
    final llegada = DateTime.tryParse('${v.fechaLlegada}T${v.horaLlegada}');
    if (salida == null || llegada == null || !llegada.isAfter(salida))
      return null;
    final minutos = llegada.difference(salida).inMinutes;
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  // ───────────────────────── UI ─────────────────────────

  BoxDecoration get _tarjeta => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE4DC)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.075),
            blurRadius: 35,
            offset: const Offset(0, 14),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selecciona tus asientos"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.appBar),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3EDE7), Color(0xFFFAF8F5), Color(0xFFECE1D6)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pantallaAncha = constraints.maxWidth >= 980;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: pantallaAncha
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _tarjetaMapa()),
                            const SizedBox(width: 24),
                            SizedBox(width: 380, child: _panelResumen()),
                          ],
                        )
                      : Column(
                          children: [
                            _tarjetaMapa(),
                            const SizedBox(height: 24),
                            _panelResumen(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Tarjeta del mapa ──

  Widget _tarjetaMapa() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
      clipBehavior: Clip.antiAlias,
      decoration: _tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elige dónde quieres sentarte',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pulsa un asiento disponible para seleccionarlo. Máximo $maxAsientos por reserva.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipLeyenda(
                      estado: EstadoAsiento.disponible, texto: 'Disponible'),
                  _ChipLeyenda(
                      estado: EstadoAsiento.seleccionado,
                      texto: 'Seleccionado'),
                  _ChipLeyenda(estado: EstadoAsiento.ocupado, texto: 'Ocupado'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.secondary)),
            )
          else if (asientos.isEmpty)
            _sinAsientos()
          else
            _avion(),
        ],
      ),
    );
  }

  Widget _sinAsientos() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.event_seat_outlined,
              size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            mensaje.isNotEmpty
                ? mensaje
                : 'Este vuelo no tiene asientos configurados.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: cargarAsientos,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ── Avión ──

  Widget _avion() {
    final filas = _agruparPorFila();
    final letras = <String>{for (final f in filas.values) ...f.keys}.toList()
      ..sort();
    final mitad = (letras.length / 2).ceil();
    final izquierda = letras.sublist(0, mitad);
    final derecha = letras.sublist(mitad);
    final ventanas = {letras.first, letras.last};

    // Anchos de cada columna: ventana | asientos | pasillo | asientos | ventana
    final anchos = <double>[
      _anchoVentana,
      for (final _ in izquierda) AsientoBoton.ancho,
      _anchoPasillo,
      for (final _ in derecha) AsientoBoton.ancho,
      _anchoVentana,
    ];
    final anchoContenido = anchos.fold<double>(0, (a, b) => a + b) +
        _separacion * (anchos.length - 1);
    final anchoFuselaje = anchoContenido + _margenFuselaje * 2;

    Widget asiento(int fila, String letra) {
      final a = filas[fila]![letra];
      if (a == null) return const SizedBox.shrink();
      final estado = !a.disponible
          ? EstadoAsiento.ocupado
          : (seleccionados.contains(a.numeroAsiento)
              ? EstadoAsiento.seleccionado
              : EstadoAsiento.disponible);
      return AsientoBoton(
        numero: a.numeroAsiento,
        estado: estado,
        ventana: ventanas.contains(letra),
        onTap: () => cambiarSeleccion(a),
      );
    }

    final leyendaPosicion = letras.length >= 3
        ? '${letras.first} y ${letras.last}: ventana · ${izquierda.last} y ${derecha.first}: pasillo'
        : 'Los asientos junto a la ventanilla son de ventana';

    final fuselaje = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(190),
          bottom: Radius.circular(56),
        ),
        border: Border.all(color: const Color(0xFFE3D6CA), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(187),
            bottom: Radius.circular(53),
          ),
          border: Border.all(color: const Color(0xFFF6EFE7), width: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nariz
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: AppColors.textSecondary, size: 22),
            const Text(
              'FRENTE DEL AVIÓN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),

            // Encabezado de columnas
            _filaMapa(anchos, [
              const SizedBox.shrink(),
              for (final l in izquierda) _letraColumna(l),
              const Text(
                'FILA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              for (final l in derecha) _letraColumna(l),
              const SizedBox.shrink(),
            ]),
            const SizedBox(height: 12),
            CustomPaint(
                size: Size(anchoContenido, 1), painter: _LineaPunteada()),
            const SizedBox(height: 16),

            // Filas
            for (final fila in filas.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _filaMapa(anchos, [
                  const _Ventanilla(),
                  for (final l in izquierda) asiento(fila, l),
                  Text(
                    '$fila',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  for (final l in derecha) asiento(fila, l),
                  const _Ventanilla(),
                ]),
              ),

            const SizedBox(height: 8),
            Text(
              leyendaPosicion,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    // Las alas se dibujan detrás del fuselaje. Si la ventana es muy estrecha,
    // el avión se desplaza horizontalmente en lugar de encogerse.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                      painter: _AlasPainter(anchoFuselaje: anchoFuselaje)),
                ),
                fuselaje,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filaMapa(List<double> anchos, List<Widget> celdas) {
    final hijos = <Widget>[];
    for (var i = 0; i < celdas.length; i++) {
      if (i > 0) hijos.add(const SizedBox(width: _separacion));
      hijos.add(SizedBox(width: anchos[i], child: Center(child: celdas[i])));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: hijos);
  }

  Widget _letraColumna(String letra) => Text(
        letra,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary),
      );

  // ── Panel de resumen ──

  Widget _panelResumen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tarjetaVuelo(),
        const SizedBox(height: 18),
        _tarjetaSeleccion(),
      ],
    );
  }

  Widget _tarjetaVuelo() {
    final v = widget.vuelo;
    final duracion = _duracion(v);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5EDE6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              v.aerolinea,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text(v.origen, style: _estiloCiudad),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.secondary, size: 22),
              Text(v.destino, style: _estiloCiudad),
            ],
          ),
          const SizedBox(height: 4),
          Text('Vuelo #${v.id}',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _dato(Icons.calendar_today_outlined, _fechaLarga(v.fecha)),
          const SizedBox(height: 10),
          _dato(
            Icons.schedule_rounded,
            '${_hora(v.horaSalida)} – ${_hora(v.horaLlegada)}'
            '${duracion != null ? ' · $duracion de vuelo' : ''}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _LineaPunteada()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Precio por asiento',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(
                '\$${v.precio.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _estiloCiudad = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  Widget _dato(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, size: 18, color: AppColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto,
              style: const TextStyle(fontSize: 14, color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _tarjetaSeleccion() {
    final n = seleccionados.length;
    final haySeleccion = n > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.event_seat_outlined,
                  color: AppColors.secondary, size: 22),
              SizedBox(width: 10),
              Text(
                'Tu selección',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (haySeleccion)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final s in seleccionados) _chipAsiento(s)],
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Aún no has elegido asientos. Selecciónalos en el mapa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Asientos',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              Text(
                n == 0 ? 'Ninguno' : '$n asiento${n == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total de la reserva',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ],
          ),
          if (mensaje.isNotEmpty && asientos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _aviso(),
          ],
          const SizedBox(height: 18),
          _botonConfirmar(haySeleccion),
          const SizedBox(height: 10),
          const Text(
            'Si otra persona toma un asiento antes de confirmar, te avisaremos para que elijas otro.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, height: 1.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _chipAsiento(String numero) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 2, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EDE6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4D6CB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            numero,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Quitar asiento $numero',
            onPressed: reservando
                ? null
                : () => setState(() => seleccionados.remove(numero)),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ],
      ),
    );
  }

  Widget _aviso() {
    final concurrencia = mensaje.contains("Concurrencia detectada");
    final color = concurrencia ? AppColors.warning : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: concurrencia ? AppColors.warningLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(concurrencia ? Icons.warning_amber_rounded : Icons.error_outline,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                color: concurrencia ? const Color(0xFF5D4037) : AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonConfirmar(bool haySeleccion) {
    final activo = haySeleccion && !reservando;
    final texto = reservando
        ? 'Procesando...'
        : (widget.reserva != null ? 'Modificar reserva' : 'Confirmar reserva');
    final colorTexto =
        activo || reservando ? Colors.white : AppColors.textSecondary;

    return Semantics(
      button: true,
      enabled: activo,
      child: MouseRegion(
        cursor:
            activo ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: activo ? reservar : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              gradient:
                  activo || reservando ? AppGradients.primaryButton : null,
              color: activo || reservando ? null : AppColors.border,
              borderRadius: BorderRadius.circular(16),
              boxShadow: activo
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                reservando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.check_circle_outline_rounded,
                        color: colorTexto, size: 20),
                const SizedBox(width: 10),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: colorTexto,
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

// ───────────────────── Piezas visuales ─────────────────────

class _ChipLeyenda extends StatelessWidget {
  final EstadoAsiento estado;
  final String texto;

  const _ChipLeyenda({required this.estado, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFECE4DC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AsientoMini(estado: estado),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _Ventanilla extends StatelessWidget {
  const _Ventanilla();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8EE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3D6CA), width: 2),
      ),
    );
  }
}

class _LineaPunteada extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    const trazo = 5.0;
    const espacio = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + trazo).clamp(0, size.width), 0), pintura);
      x += trazo + espacio;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Alas decorativas detrás del fuselaje, a la altura media del avión.
class _AlasPainter extends CustomPainter {
  final double anchoFuselaje;

  _AlasPainter({required this.anchoFuselaje});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.width / 2;
    final borde = anchoFuselaje / 2 - 4;
    final arriba = size.height * 0.42;
    const largo = 220.0;
    const alto = 150.0;

    final pintura = Paint()..color = const Color(0xFFEFE6DC);

    final izquierda = Path()
      ..moveTo(centro - borde, arriba)
      ..lineTo(centro - borde, arriba + alto * 0.62)
      ..lineTo(centro - borde - largo, arriba + alto)
      ..lineTo(centro - borde - largo * 0.92, arriba + alto * 0.64)
      ..close();

    final derecha = Path()
      ..moveTo(centro + borde, arriba)
      ..lineTo(centro + borde, arriba + alto * 0.62)
      ..lineTo(centro + borde + largo, arriba + alto)
      ..lineTo(centro + borde + largo * 0.92, arriba + alto * 0.64)
      ..close();

    canvas.drawPath(izquierda, pintura);
    canvas.drawPath(derecha, pintura);
  }

  @override
  bool shouldRepaint(covariant _AlasPainter old) =>
      old.anchoFuselaje != anchoFuselaje;
}
