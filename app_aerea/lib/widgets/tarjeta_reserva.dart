import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../utils/formato.dart';
import 'custom_toast.dart';

const _bordeSuave = Color(0xFFE6DED6);
const _fondoTalon = Color(0xFFFFFCF8);
const _fondoDatos = Color(0xFFF7F2EC);

/// "Hoy", "Mañana" o "En 4 días".
String textoCuentaRegresiva(Reserva r) {
  final hoy = Formato.soloFecha(DateTime.now());
  final n = (r.vuelo.dia.difference(hoy).inHours / 24).round();
  if (n <= 0) return 'Hoy';
  if (n == 1) return 'Mañana';
  return 'En $n días';
}

/// Texto y color del estado de una reserva.
(String, Color, Color) _estado(Reserva r) {
  if (r.esCancelada) {
    return ('Cancelada', AppColors.error, AppColors.errorLight);
  }
  if (r.esPasada) {
    return ('Completado', AppColors.textSecondary, const Color(0xFFEFEAE4));
  }
  return ('Confirmada', AppColors.success, AppColors.successLight);
}

// ════════════════════════════════════════════════════════════════
//  Tarjeta grande (tipo pase de abordar)
// ════════════════════════════════════════════════════════════════

class TarjetaReserva extends StatelessWidget {
  final Reserva reserva;

  /// Si son null, no se muestran los botones (reservas pasadas o canceladas).
  final VoidCallback? onCambiarAsientos;
  final VoidCallback? onCambiarVuelo;
  final VoidCallback? onCancelar;

  const TarjetaReserva({
    super.key,
    required this.reserva,
    this.onCambiarAsientos,
    this.onCambiarVuelo,
    this.onCancelar,
  });

  bool get _hayAcciones =>
      onCambiarAsientos != null || onCambiarVuelo != null || onCancelar != null;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth >= 760;
          final principal = _Principal(reserva: reserva, compacto: !ancho);
          final talon = _Talon(
            reserva: reserva,
            acciones: _hayAcciones ? _acciones(ancho) : null,
          );

          if (ancho) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: principal),
                  const _LineaPunteada(vertical: true),
                  SizedBox(width: 300, child: talon),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              principal,
              const _LineaPunteada(vertical: false),
              talon,
            ],
          );
        },
      ),
    );
  }

  Widget _acciones(bool ancho) {
    final principal = onCambiarAsientos == null
        ? null
        : FilledButton.icon(
            onPressed: onCambiarAsientos,
            icon: const Icon(Icons.event_seat_outlined, size: 20),
            label: const Text('Cambiar asientos'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );

    final cambiarVuelo = onCambiarVuelo == null
        ? null
        : OutlinedButton(
            onPressed: onCambiarVuelo,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.border),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cambiar de vuelo'),
          );

    final cancelar = onCancelar == null
        ? null
        : TextButton(
            onPressed: onCancelar,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.error,
              ),
            ),
            child: const Text('Cancelar reserva'),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (principal != null) principal,
        if (cambiarVuelo != null) ...[
          const SizedBox(height: 10),
          cambiarVuelo,
        ],
        if (cancelar != null) ...[
          const SizedBox(height: 6),
          cancelar,
        ],
      ],
    );
  }
}

class _Principal extends StatelessWidget {
  final Reserva reserva;
  final bool compacto;

  const _Principal({required this.reserva, required this.compacto});

  @override
  Widget build(BuildContext context) {
    final v = reserva.vuelo;
    final (textoEstado, colorEstado, fondoEstado) = _estado(reserva);
    final tamHora = compacto ? 28.0 : 40.0;

    return Padding(
      padding: EdgeInsets.all(compacto ? 18 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiquetas
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (reserva.esProxima)
                _Chip(
                  texto: textoCuentaRegresiva(reserva),
                  color: Colors.white,
                  fondo: AppColors.primary,
                ),
              Text(
                Formato.fechaLarga(v.dia),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              _Chip(
                texto: textoEstado,
                color: colorEstado,
                fondo: fondoEstado,
                icono: reserva.esProxima ? Icons.check : null,
              ),
            ],
          ),
          SizedBox(height: compacto ? 16 : 24),

          // Ruta con horas
          Row(
            children: [
              _HoraCiudad(
                hora: v.horaSalidaCorta,
                ciudad: reserva.origen,
                tam: tamHora,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${Formato.duracion(v.duracionMinutos)} · Directo',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    const _Trayecto(),
                    const SizedBox(height: 6),
                    Text(
                      reserva.aerolinea,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _HoraCiudad(
                hora: v.horaLlegadaCorta,
                ciudad: reserva.destino,
                tam: tamHora,
                alFinal: true,
              ),
            ],
          ),
          SizedBox(height: compacto ? 16 : 24),

          // Código, asientos y fecha de reserva
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _fondoDatos,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              spacing: 40,
              runSpacing: 16,
              children: [
                _Dato(
                  titulo: 'Código de reserva',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reserva.codigoReserva,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BotonCopiar(codigo: reserva.codigoReserva),
                    ],
                  ),
                ),
                _Dato(
                  titulo: 'Asientos',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in reserva.asientos) _ChipAsiento(a),
                      if (reserva.asientos.isEmpty)
                        Text('${reserva.cantidadAsientos}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (reserva.reservadaEl != null)
                  _Dato(
                    titulo: 'Reservado el',
                    child: Text(
                      Formato.fechaConAnio(reserva.reservadaEl!),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Talon extends StatelessWidget {
  final Reserva reserva;
  final Widget? acciones;

  const _Talon({required this.reserva, this.acciones});

  @override
  Widget build(BuildContext context) {
    final n = reserva.cantidadAsientos;
    final etiqueta = reserva.esCancelada
        ? 'Total de la reserva'
        : 'Total pagado · $n ${n == 1 ? 'asiento' : 'asientos'}';

    return Container(
      color: _fondoTalon,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                Formato.dinero(reserva.total),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  decoration:
                      reserva.esCancelada ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (acciones != null) ...[
            const SizedBox(height: 20),
            acciones!,
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Fila compacta (para "Más adelante", Pasados y Canceladas)
// ════════════════════════════════════════════════════════════════

class FilaReserva extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback onTap;

  const FilaReserva({super.key, required this.reserva, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = reserva.vuelo;
    final (textoEstado, colorEstado, _) = _estado(reserva);
    final apagada = !reserva.esProxima;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _bordeSuave),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final ancho = c.maxWidth >= 640;
              final detalle = ancho
                  ? '${Formato.diaLargo(v.dia)} · ${v.horaSalidaCorta} – ${v.horaLlegadaCorta} · ${reserva.aerolinea}'
                  : '${v.horaSalidaCorta} · ${reserva.aerolinea} · ${reserva.textoAsientos}';

              return Row(
                children: [
                  _BloqueFecha(dia: v.dia, apagada: apagada),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reserva.origen} → ${reserva.destino}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detalle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (ancho) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 190,
                      child: _Dato(
                        titulo: 'Código · Asientos',
                        child: Text(
                          '${reserva.codigoReserva} · ${reserva.textoAsientos}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formato.dinero(reserva.total),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        textoEstado,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorEstado,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Piezas pequeñas
// ════════════════════════════════════════════════════════════════

class _BloqueFecha extends StatelessWidget {
  final DateTime dia;
  final bool apagada;

  const _BloqueFecha({required this.dia, required this.apagada});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Formato.mesCorto(dia),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: apagada ? AppColors.textSecondary : AppColors.secondary,
            ),
          ),
          Text(
            '${dia.day}'.padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoraCiudad extends StatelessWidget {
  final String hora;
  final String ciudad;
  final double tam;
  final bool alFinal;

  const _HoraCiudad({
    required this.hora,
    required this.ciudad,
    required this.tam,
    this.alFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alFinal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          hora,
          style: TextStyle(
            fontSize: tam,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.primary,
          ),
        ),
        Text(
          ciudad,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// ○ - - - ✈ - - - ●
class _Trayecto extends StatelessWidget {
  const _Trayecto();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.secondary, width: 2),
          ),
        ),
        const Expanded(child: _LineaPunteada(vertical: false, grosor: 2)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.flight, size: 20, color: AppColors.secondary),
        ),
        const Expanded(child: _LineaPunteada(vertical: false, grosor: 2)),
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  const _Chip({
    required this.texto,
    required this.color,
    required this.fondo,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _ChipAsiento extends StatelessWidget {
  final String asiento;

  const _ChipAsiento(this.asiento);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        asiento,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _Dato({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _BotonCopiar extends StatelessWidget {
  final String codigo;

  const _BotonCopiar({required this.codigo});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copiar código',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: codigo));
        if (!context.mounted) return;
        CustomToast.showSuccess(context, 'Código $codigo copiado');
      },
      icon: const Icon(Icons.copy_rounded, size: 16),
      color: AppColors.textSecondary,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _LineaPunteada extends StatelessWidget {
  final bool vertical;
  final double grosor;

  const _LineaPunteada({required this.vertical, this.grosor = 2});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: vertical
          ? Size(grosor, double.infinity)
          : Size(double.infinity, grosor),
      painter: _PintorPunteado(vertical: vertical, grosor: grosor),
    );
  }
}

class _PintorPunteado extends CustomPainter {
  final bool vertical;
  final double grosor;

  _PintorPunteado({required this.vertical, required this.grosor});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border
      ..strokeWidth = grosor;
    const trazo = 6.0, hueco = 5.0;
    final largo = vertical ? size.height : size.width;
    for (double i = 0; i < largo; i += trazo + hueco) {
      final fin = (i + trazo).clamp(0, largo).toDouble();
      if (vertical) {
        canvas.drawLine(Offset(grosor / 2, i), Offset(grosor / 2, fin), p);
      } else {
        canvas.drawLine(Offset(i, grosor / 2), Offset(fin, grosor / 2), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PintorPunteado old) =>
      old.vertical != vertical || old.grosor != grosor;
}
