import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/carrito.dart';
import '../models/reserva.dart';
import '../utils/formato.dart';
import '../widgets/dialogo_factura.dart';
import 'carrito_page.dart';
import 'reservas_page.dart';

const _bordeSuave = Color(0xFFE6DED6);
const _fondoSuave = Color(0xFFF7F2EC);

/// Pantalla que aparece después de "Confirmar y pagar".
class CompraConfirmadaPage extends StatelessWidget {
  final ResultadoCompra resultado;

  const CompraConfirmadaPage({super.key, required this.resultado});

  void _irAReservas(BuildContext context) => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReservasPage()),
      );

  void _irAVuelos(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  void _volverAlCarrito(BuildContext context) => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CarritoPage()),
      );

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final parcial = r.fallidas.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 38, color: AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    parcial
                        ? '¡Compra confirmada en parte!'
                        : '¡Compra confirmada!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.confirmadas.length == 1
                        ? 'Tu reserva quedó registrada. Puedes verla en Mis reservas.'
                        : 'Tus ${r.confirmadas.length} reservas quedaron registradas. Puedes verlas en Mis reservas.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Reservas creadas + totales
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _bordeSuave),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < r.confirmadas.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF0EAE3)),
                          _FilaReserva(reserva: r.confirmadas[i]),
                        ],
                        Container(
                          color: _fondoSuave,
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                          child: Column(
                            children: [
                              _Linea('Subtotal', Formato.dinero(r.subtotal)),
                              const SizedBox(height: 6),
                              _Linea('IVA (${r.porcentajeIva} %)',
                                  Formato.dinero(r.iva)),
                              const SizedBox(height: 8),
                              _Linea('Total pagado', Formato.dinero(r.total),
                                  fuerte: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Vuelos que no se pudieron comprar
                  if (parcial) ...[
                    const SizedBox(height: 18),
                    _AvisoFallidas(
                      fallidas: r.fallidas,
                      onVolver: () => _volverAlCarrito(context),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 290,
                        height: 50,
                        child: FilledButton(
                          onPressed: () => _irAReservas(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Ir a Mis reservas'),
                        ),
                      ),
                      SizedBox(
                        width: 290,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => _irAVuelos(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Buscar otro vuelo'),
                        ),
                      ),
                    ],
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

class _FilaReserva extends StatelessWidget {
  final Reserva reserva;

  const _FilaReserva({required this.reserva});

  @override
  Widget build(BuildContext context) {
    final v = reserva.vuelo;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${reserva.origen} → ${reserva.destino}',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          '${Formato.fechaCorta(v.dia)} · ${v.horaSalidaCorta} · ${reserva.textoAsientos}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );

    Widget codigo(CrossAxisAlignment alineacion) => Column(
          crossAxisAlignment: alineacion,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Código',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            SelectableText(
              reserva.codigoReserva,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        );

    final boton = OutlinedButton.icon(
      onPressed: () => mostrarFactura(context, reserva),
      icon: const Icon(Icons.receipt_long_outlined, size: 18),
      label: const Text('Factura'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.secondary,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, c) {
          // Móvil: datos arriba; código y botón abajo.
          if (c.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: codigo(CrossAxisAlignment.start)),
                    const SizedBox(width: 12),
                    boton,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              codigo(CrossAxisAlignment.end),
              const SizedBox(width: 12),
              boton,
            ],
          );
        },
      ),
    );
  }
}

class _AvisoFallidas extends StatelessWidget {
  final List<CompraFallida> fallidas;
  final VoidCallback onVolver;

  const _AvisoFallidas({required this.fallidas, required this.onVolver});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3DFA2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: Color(0xFF8A6D00)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fallidas.length == 1
                      ? 'Un vuelo no se pudo comprar y no se te cobró:'
                      : '${fallidas.length} vuelos no se pudieron comprar y no se te cobraron:',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in fallidas)
            Padding(
              padding: const EdgeInsets.only(left: 30, bottom: 6),
              child: Text(
                '${f.ruta}${f.asientos.isNotEmpty ? ' (${f.asientos.join(', ')})' : ''}: ${f.motivo}',
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.primary),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: TextButton(
              onPressed: onVolver,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Volver al carrito'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final String izquierda;
  final String derecha;
  final bool fuerte;

  const _Linea(this.izquierda, this.derecha, {this.fuerte = false});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: fuerte ? 17 : 14,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w400,
      color: fuerte ? AppColors.primary : AppColors.textSecondary,
    );
    return Row(
      children: [
        Text(izquierda, style: estilo),
        const Spacer(),
        Text(derecha,
            style: estilo.copyWith(
                color: AppColors.primary,
                fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}
