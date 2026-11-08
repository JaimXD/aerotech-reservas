import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';

class ReservaCard extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback onCancelar;
  final VoidCallback onEditar;

  const ReservaCard({
    super.key,
    required this.reserva,
    required this.onCancelar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final bool activa = reserva.estado == "ACTIVA";
    final String asientosTexto = reserva.asientos.isEmpty
        ? "No registrado"
        : reserva.asientos.join(", ");

    // Check if the flight date has already passed
    bool haPasado = false;
    try {
      final DateTime flightDate = DateTime.parse(reserva.fechaVuelo);
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      haPasado = flightDate.isBefore(today);
    } catch (_) {
      // In case date parsing fails, default to false
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppDecorations.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ícono de estado ──
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: activa
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.confirmation_number,
                color: activa ? AppColors.success : AppColors.error,
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reserva.codigoReserva,
                    style: AppTextStyles.subheading.copyWith(fontSize: 16),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.flight, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        "${reserva.origen} → ${reserva.destino}",
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        "${reserva.fechaVuelo} | ${reserva.horaSalida}",
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Row(
                    children: [
                      Icon(Icons.event_seat, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Asientos: $asientosTexto",
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── Estado y total ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activa
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          reserva.estado,
                          style: TextStyle(
                            color: activa ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "\$${reserva.total.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Acciones ──
            if (activa)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: haPasado
                        ? AppColors.border.withOpacity(0.3)
                        : AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: haPasado ? null : onEditar,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.edit_outlined,
                          color: haPasado ? AppColors.textHint : AppColors.secondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onCancelar,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}