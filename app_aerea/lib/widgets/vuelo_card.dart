import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/vuelo.dart';

class VueloCard extends StatelessWidget {
  final Vuelo vuelo;
  final VoidCallback onReservar;

  const VueloCard({
    super.key,
    required this.vuelo,
    required this.onReservar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppDecorations.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Ícono con gradiente ──
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryButton,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.flight_takeoff,
                color: Colors.white,
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${vuelo.origen} → ${vuelo.destino}",
                    style: AppTextStyles.subheading.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vuelo.aerolinea,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        vuelo.fecha,
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        "${vuelo.horaSalida} - ${vuelo.horaLlegada}",
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.event_seat, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        "${vuelo.asientosDisponibles} disponibles",
                        style: AppTextStyles.caption.copyWith(
                          color: vuelo.asientosDisponibles > 3
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Precio como badge ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "\$${vuelo.precio.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Botón con gradiente ──
                GestureDetector(
                  onTap: onReservar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primaryButton,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      "Reservar",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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