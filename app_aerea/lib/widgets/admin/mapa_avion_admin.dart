import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/vuelo_admin.dart';

const _vendidoFondo = AppColors.primary;
const _carritoFondo = Color(0xFFF3DFA2);
const _carritoBorde = Color(0xFF8A6D00);
const _carritoTexto = Color(0xFF5C4500);
const _libreBorde = AppColors.border;

/// Mapa de asientos del vuelo dibujado como el avión del cliente
/// (fuselaje, ventanillas y alas), con los estados del administrador.
class MapaAvionAdmin extends StatelessWidget {
  final List<AsientoAdmin> asientos;

  /// Código de reserva resaltado (sus asientos se marcan con un anillo).
  final String? codigoResaltado;

  /// Se llama al pulsar un asiento vendido.
  final ValueChanged<AsientoAdmin>? onTapVendido;

  const MapaAvionAdmin({
    super.key,
    required this.asientos,
    this.codigoResaltado,
    this.onTapVendido,
  });

  static const double _anchoVentana = 14;
  static const double _anchoPasillo = 36;
  static const double _separacion = 8;
  static const double _margenFuselaje = 3 + 6 + 16; // borde + borde interior + relleno
  static final RegExp _formato = RegExp(r'^(\d+)([A-Z])$');

  Map<int, Map<String, AsientoAdmin>> _agruparPorFila() {
    final filas = <int, Map<String, AsientoAdmin>>{};
    for (final a in asientos) {
      final m = _formato.firstMatch(a.numero.trim().toUpperCase());
      if (m == null) continue;
      filas.putIfAbsent(int.parse(m.group(1)!), () => {})[m.group(2)!] = a;
    }
    final orden = filas.keys.toList()..sort();
    return {for (final f in orden) f: filas[f]!};
  }

  @override
  Widget build(BuildContext context) {
    final filas = _agruparPorFila();
    if (filas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text('Este vuelo no tiene asientos configurados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final letras = <String>{for (final f in filas.values) ...f.keys}.toList()
      ..sort();
    final mitad = (letras.length / 2).ceil();
    final izquierda = letras.sublist(0, mitad);
    final derecha = letras.sublist(mitad);

    final anchos = <double>[
      _anchoVentana,
      for (final _ in izquierda) AsientoAdminBoton.ancho,
      _anchoPasillo,
      for (final _ in derecha) AsientoAdminBoton.ancho,
      _anchoVentana,
    ];
    final anchoContenido = anchos.fold<double>(0, (a, b) => a + b) +
        _separacion * (anchos.length - 1);
    final anchoFuselaje = anchoContenido + _margenFuselaje * 2;

    Widget asiento(int fila, String letra) {
      final a = filas[fila]![letra];
      if (a == null) return const SizedBox.shrink();
      return AsientoAdminBoton(
        asiento: a,
        resaltado: codigoResaltado != null && a.codigo == codigoResaltado,
        onTap: a.estado == EstadoAsientoAdmin.vendido && onTapVendido != null
            ? () => onTapVendido!(a)
            : null,
      );
    }

    Widget etiqueta(String texto) => Text(texto,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary));

    final fuselaje = Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(150), bottom: Radius.circular(44)),
        border: Border.all(color: const Color(0xFFE3D6CA), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(147), bottom: Radius.circular(41)),
          border: Border.all(color: const Color(0xFFF6EFE7), width: 6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: AppColors.textSecondary, size: 20),
            const Text('FRENTE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            _fila(anchos, [
              const SizedBox.shrink(),
              for (final l in izquierda) etiqueta(l),
              const Text('FILA',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary)),
              for (final l in derecha) etiqueta(l),
              const SizedBox.shrink(),
            ]),
            const SizedBox(height: 10),
            CustomPaint(
                size: Size(anchoContenido, 1), painter: _LineaPunteada()),
            const SizedBox(height: 12),
            for (final fila in filas.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _fila(anchos, [
                  const _Ventanilla(),
                  for (final l in izquierda) asiento(fila, l),
                  Text('$fila',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary)),
                  for (final l in derecha) asiento(fila, l),
                  const _Ventanilla(),
                ]),
              ),
          ],
        ),
      ),
    );

    // Las alas van detrás del fuselaje. Si no cabe, el avión se desplaza
    // horizontalmente en lugar de encogerse.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
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
      ),
    );
  }

  Widget _fila(List<double> anchos, List<Widget> celdas) {
    final hijos = <Widget>[];
    for (var i = 0; i < celdas.length; i++) {
      if (i > 0) hijos.add(const SizedBox(width: _separacion));
      hijos.add(SizedBox(width: anchos[i], child: Center(child: celdas[i])));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: hijos);
  }
}

/// Asiento del mapa del administrador. Muestra su número y, al pasar el
/// mouse, a quién se vendió o cuándo se libera.
class AsientoAdminBoton extends StatefulWidget {
  static const double ancho = 44;
  static const double alto = 46;

  final AsientoAdmin asiento;
  final bool resaltado;
  final VoidCallback? onTap;

  const AsientoAdminBoton({
    super.key,
    required this.asiento,
    this.resaltado = false,
    this.onTap,
  });

  @override
  State<AsientoAdminBoton> createState() => _AsientoAdminBotonState();
}

class _AsientoAdminBotonState extends State<AsientoAdminBoton> {
  bool _hover = false;

  String get _detalle {
    final a = widget.asiento;
    switch (a.estado) {
      case EstadoAsientoAdmin.vendido:
        return '${a.numero} · vendido a ${a.cliente ?? 'un cliente'}'
            '${a.codigo != null ? '\n${a.codigo}' : ''}';
      case EstadoAsientoAdmin.carrito:
        final s = a.liberaEn ?? 0;
        final mmss =
            '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
        return '${a.numero} · en el carrito de un cliente\nSe libera en $mmss';
      case EstadoAsientoAdmin.libre:
        return '${a.numero} · libre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asiento;
    final (fondo, borde, texto) = switch (a.estado) {
      EstadoAsientoAdmin.vendido => (_vendidoFondo, _vendidoFondo, Colors.white),
      EstadoAsientoAdmin.carrito => (_carritoFondo, _carritoBorde, _carritoTexto),
      EstadoAsientoAdmin.libre => (
          Colors.white,
          _libreBorde,
          AppColors.textSecondary
        ),
    };
    const radio = BorderRadius.only(
      topLeft: Radius.circular(13),
      topRight: Radius.circular(13),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(8),
    );
    final interactivo = widget.onTap != null;

    return Tooltip(
      message: _detalle,
      waitDuration: const Duration(milliseconds: 250),
      child: Semantics(
        button: interactivo,
        label: _detalle.replaceAll('\n', ', '),
        excludeSemantics: true,
        child: MouseRegion(
          cursor:
              interactivo ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              transform: Matrix4.translationValues(
                  0, _hover && interactivo ? -2 : 0, 0),
              width: AsientoAdminBoton.ancho,
              height: AsientoAdminBoton.alto,
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: radio,
                border: Border.all(color: borde, width: 1.5),
                boxShadow: [
                  if (widget.resaltado)
                    const BoxShadow(color: AppColors.success, spreadRadius: 3),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Respaldo
                  Positioned(
                    top: 4,
                    left: 7,
                    right: 7,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: texto.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(a.numero,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: texto)),
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

/// Muestra de color para la leyenda del mapa.
class MuestraAsiento extends StatelessWidget {
  final EstadoAsientoAdmin estado;
  final String texto;

  const MuestraAsiento({super.key, required this.estado, required this.texto});

  @override
  Widget build(BuildContext context) {
    final (fondo, borde) = switch (estado) {
      EstadoAsientoAdmin.vendido => (_vendidoFondo, _vendidoFondo),
      EstadoAsientoAdmin.carrito => (_carritoFondo, _carritoBorde),
      EstadoAsientoAdmin.libre => (Colors.white, _libreBorde),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borde, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto,
            style: const TextStyle(fontSize: 12, color: AppColors.primary)),
      ],
    );
  }
}

class _Ventanilla extends StatelessWidget {
  const _Ventanilla();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8EE),
        borderRadius: BorderRadius.circular(6),
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
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + 5).clamp(0, size.width), 0), pintura);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Alas decorativas detrás del fuselaje, a media altura del avión.
class _AlasPainter extends CustomPainter {
  final double anchoFuselaje;

  _AlasPainter({required this.anchoFuselaje});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.width / 2;
    final borde = anchoFuselaje / 2 - 4;
    final arriba = size.height * 0.42;
    const largo = 170.0;
    const alto = 120.0;
    final pintura = Paint()..color = const Color(0xFFEFE6DC);

    for (final lado in [-1.0, 1.0]) {
      final x = centro + lado * borde;
      canvas.drawPath(
        Path()
          ..moveTo(x, arriba)
          ..lineTo(x, arriba + alto * 0.62)
          ..lineTo(x + lado * largo, arriba + alto)
          ..lineTo(x + lado * largo * 0.92, arriba + alto * 0.64)
          ..close(),
        pintura,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AlasPainter old) =>
      old.anchoFuselaje != anchoFuselaje;
}
