import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Estados visuales de un asiento.
enum EstadoAsiento { disponible, seleccionado, ocupado }

/// Colores de cada estado. Se distinguen también por claridad,
/// no solo por tono (accesible para personas con daltonismo).
class _ColoresAsiento {
  final Color fondo;
  final Color borde;
  final Color icono;
  final Color? sombra;

  const _ColoresAsiento(this.fondo, this.borde, this.icono, this.sombra);

  static _ColoresAsiento de(EstadoAsiento estado) {
    switch (estado) {
      case EstadoAsiento.seleccionado:
        return const _ColoresAsiento(Color(0xFF2E7D32), Color(0xFF2E7D32),
            Colors.white, Color(0xFF1B5E20));
      case EstadoAsiento.ocupado:
        return const _ColoresAsiento(
            Color(0xFFE9E2DB), Color(0xFFD7CEC7), Color(0xFF8C7B6E), null);
      case EstadoAsiento.disponible:
        return const _ColoresAsiento(Colors.white, AppColors.secondary,
            AppColors.secondary, Color(0xFFE4D6CB));
    }
  }
}

const _radioAsiento = BorderRadius.only(
  topLeft: Radius.circular(16),
  topRight: Radius.circular(16),
  bottomLeft: Radius.circular(10),
  bottomRight: Radius.circular(10),
);

/// Asiento del mapa: 56 × 60, con respaldo, ícono de estado,
/// elevación al pasar el mouse, tooltip y soporte de teclado.
class AsientoBoton extends StatefulWidget {
  static const double ancho = 56;
  static const double alto = 60;

  final String numero;
  final EstadoAsiento estado;
  final bool ventana;
  final VoidCallback? onTap;

  const AsientoBoton({
    super.key,
    required this.numero,
    required this.estado,
    required this.ventana,
    this.onTap,
  });

  @override
  State<AsientoBoton> createState() => _AsientoBotonState();
}

class _AsientoBotonState extends State<AsientoBoton> {
  bool _hover = false;
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final c = _ColoresAsiento.de(widget.estado);
    final ocupado = widget.estado == EstadoAsiento.ocupado;
    final seleccionado = widget.estado == EstadoAsiento.seleccionado;
    final posicion = widget.ventana ? 'Ventana' : 'Pasillo';
    final estadoTexto =
        ocupado ? 'ocupado' : (seleccionado ? 'seleccionado' : 'disponible');

    return Tooltip(
      message:
          'Asiento ${widget.numero} · $posicion${ocupado ? ' · Ocupado' : ''}',
      waitDuration: const Duration(milliseconds: 300),
      child: Semantics(
        button: true,
        enabled: !ocupado,
        selected: seleccionado,
        label:
            'Asiento ${widget.numero}, ${posicion.toLowerCase()}, $estadoTexto',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: ocupado ? null : widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            onFocusChange: (v) => setState(() => _foco = v),
            mouseCursor: ocupado
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            borderRadius: _radioAsiento,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              transform:
                  Matrix4.translationValues(0, _hover && !ocupado ? -2 : 0, 0),
              width: AsientoBoton.ancho,
              height: AsientoBoton.alto,
              decoration: BoxDecoration(
                color: c.fondo,
                borderRadius: _radioAsiento,
                border: Border.all(color: c.borde, width: 2),
                boxShadow: [
                  if (c.sombra != null)
                    BoxShadow(color: c.sombra!, offset: const Offset(0, 4)),
                  // Anillo de foco para navegación con teclado
                  if (_foco)
                    const BoxShadow(
                        color: AppColors.secondary, spreadRadius: 3),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Respaldo
                  Positioned(
                    top: 5,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: c.icono.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  if (seleccionado)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child:
                          Icon(Icons.check_rounded, color: c.icono, size: 24),
                    ),
                  if (ocupado)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child:
                          Icon(Icons.close_rounded, color: c.icono, size: 20),
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

/// Versión pequeña y estática para la leyenda.
class AsientoMini extends StatelessWidget {
  final EstadoAsiento estado;

  const AsientoMini({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final c = _ColoresAsiento.de(estado);
    return Container(
      width: 18,
      height: 20,
      decoration: BoxDecoration(
        color: c.fondo,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: c.borde, width: 2),
      ),
      alignment: Alignment.center,
      child: switch (estado) {
        EstadoAsiento.seleccionado =>
          Icon(Icons.check_rounded, size: 12, color: c.icono),
        EstadoAsiento.ocupado =>
          Icon(Icons.close_rounded, size: 11, color: c.icono),
        EstadoAsiento.disponible => null,
      },
    );
  }
}
