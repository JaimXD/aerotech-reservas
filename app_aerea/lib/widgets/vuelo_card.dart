import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/vuelo.dart';
import '../utils/formato.dart';

const _bordeTarjeta = Color(0xFFE6DED6);

/// Tarjeta de vuelo con estilo de boleto.
class VueloCard extends StatefulWidget {
  final Vuelo vuelo;
  final VoidCallback onReservar;
  final bool masBarato;
  final bool masTemprano;

  const VueloCard({
    super.key,
    required this.vuelo,
    required this.onReservar,
    this.masBarato = false,
    this.masTemprano = false,
  });

  @override
  State<VueloCard> createState() => _VueloCardState();
}

class _VueloCardState extends State<VueloCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bordeTarjeta),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: _hover ? 0.12 : 0.04),
              blurRadius: _hover ? 32 : 8,
              offset: Offset(0, _hover ? 14 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: LayoutBuilder(
            builder: (context, c) {
              final info = _InfoVuelo(
                vuelo: widget.vuelo,
                masBarato: widget.masBarato,
                masTemprano: widget.masTemprano,
              );
              final precio = _PanelPrecio(
                  vuelo: widget.vuelo, onReservar: widget.onReservar);

              if (c.maxWidth >= 640) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: info),
                      const _LineaPunteada(vertical: true),
                      SizedBox(width: 240, child: precio),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [info, const _LineaPunteada(vertical: false), precio],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Parte izquierda: aerolínea, horas y trayecto ────────────────────

class _InfoVuelo extends StatelessWidget {
  final Vuelo vuelo;
  final bool masBarato;
  final bool masTemprano;

  const _InfoVuelo(
      {required this.vuelo,
      required this.masBarato,
      required this.masTemprano});

  @override
  Widget build(BuildContext context) {
    final v = vuelo;
    final diasExtra = Formato.soloFecha(v.llegada).difference(v.dia).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _LogoAerolinea(nombre: v.aerolinea),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.aerolinea,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formato.fechaLarga(v.dia),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (masBarato)
                const _Etiqueta(
                  texto: 'Más barato',
                  color: Color(0xFF1E6B2A),
                  fondo: Color(0xFFE5F2E6),
                ),
              if (masTemprano)
                const _Etiqueta(
                  texto: 'Más temprano',
                  color: AppColors.textSecondary,
                  fondo: Color(0xFFF1E8E1),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HoraCiudad(
                  hora: v.horaSalidaCorta, ciudad: v.origen, alFinal: false),
              const SizedBox(width: 18),
              Expanded(
                  child:
                      _Trayecto(duracion: Formato.duracion(v.duracionMinutos))),
              const SizedBox(width: 18),
              _HoraCiudad(
                hora: v.horaLlegadaCorta,
                ciudad: v.destino,
                alFinal: true,
                diasExtra: diasExtra,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoAerolinea extends StatelessWidget {
  final String nombre;

  const _LogoAerolinea({required this.nombre});

  static const _colores = [
    Color(0xFF8A5A44),
    Color(0xFF5B6B4E),
    Color(0xFF3D2A1E),
    Color(0xFF6D4C41),
    Color(0xFF7A5C3E),
  ];

  @override
  Widget build(BuildContext context) {
    final partes =
        nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciales = partes.length >= 2
        ? partes[0][0] + partes[1][0]
        : (nombre.length >= 2 ? nombre.substring(0, 2) : nombre);
    final color = _colores[
        nombre.codeUnits.fold<int>(0, (a, b) => a + b) % _colores.length];

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        iniciales.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;

  const _Etiqueta(
      {required this.texto, required this.color, required this.fondo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HoraCiudad extends StatelessWidget {
  final String hora;
  final String ciudad;
  final bool alFinal;
  final int diasExtra;

  const _HoraCiudad({
    required this.hora,
    required this.ciudad,
    required this.alFinal,
    this.diasExtra = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alFinal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hora,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                height: 1,
                color: AppColors.primary,
              ),
            ),
            if (diasExtra > 0)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '+$diasExtra',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(ciudad,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _Trayecto extends StatelessWidget {
  final String duracion;

  const _Trayecto({required this.duracion});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(duracion,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 2),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
                child:
                    _LineaPunteada(vertical: false, color: AppColors.border)),
            const SizedBox(width: 6),
            const RotatedBox(
              quarterTurns: 1,
              child: Icon(Icons.flight, size: 18, color: AppColors.secondary),
            ),
            const SizedBox(width: 6),
            const Expanded(
                child:
                    _LineaPunteada(vertical: false, color: AppColors.border)),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.secondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Directo',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.success),
        ),
      ],
    );
  }
}

// ── Parte derecha: precio, asientos y botón ────────────────────────

class _PanelPrecio extends StatelessWidget {
  final Vuelo vuelo;
  final VoidCallback onReservar;

  const _PanelPrecio({required this.vuelo, required this.onReservar});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFBF9F6),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Formato.dinero(vuelo.precio),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.primary,
            ),
          ),
          const Text('por asiento',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          _EtiquetaAsientos(cantidad: vuelo.asientosDisponibles),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onReservar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Elegir asientos'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaAsientos extends StatelessWidget {
  final int cantidad;

  const _EtiquetaAsientos({required this.cantidad});

  @override
  Widget build(BuildContext context) {
    final pocos = cantidad <= 5;
    final texto = pocos
        ? (cantidad == 1 ? '¡Solo queda 1!' : '¡Solo quedan $cantidad!')
        : '$cantidad asientos libres';
    final color = pocos ? const Color(0xFF8A4B00) : const Color(0xFF1E6B2A);
    final fondo = pocos ? const Color(0xFFFFF1D6) : const Color(0xFFE5F2E6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_seat_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

// ── Línea punteada (horizontal o vertical) ─────────────────────────

class _LineaPunteada extends StatelessWidget {
  final bool vertical;
  final Color color;

  const _LineaPunteada({required this.vertical, this.color = _bordeTarjeta});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: vertical
          ? const Size(2, double.infinity)
          : const Size(double.infinity, 2),
      painter: _PintorPunteado(vertical: vertical, color: color),
    );
  }
}

class _PintorPunteado extends CustomPainter {
  final bool vertical;
  final Color color;

  _PintorPunteado({required this.vertical, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 2;
    const trazo = 6.0;
    const hueco = 5.0;
    final largo = vertical ? size.height : size.width;

    for (double i = 0; i < largo; i += trazo + hueco) {
      final fin = (i + trazo).clamp(0.0, largo);
      if (vertical) {
        canvas.drawLine(
            Offset(size.width / 2, i), Offset(size.width / 2, fin), pincel);
      } else {
        canvas.drawLine(
            Offset(i, size.height / 2), Offset(fin, size.height / 2), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorPunteado old) =>
      old.vertical != vertical || old.color != color;
}
