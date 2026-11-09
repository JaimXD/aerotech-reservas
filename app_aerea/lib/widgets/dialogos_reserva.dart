import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/vuelos_service.dart';
import '../utils/formato.dart';
import 'custom_toast.dart';

const _fondoDatos = Color(0xFFF7F2EC);

// ════════════════════════════════════════════════════════════════
//  ¿Cancelar esta reserva?
// ════════════════════════════════════════════════════════════════

/// Devuelve true si el usuario confirma la cancelación.
Future<bool> confirmarCancelacion(BuildContext context, Reserva r) async {
  final v = r.vuelo;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.primary.withValues(alpha: 0.45),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.background),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '¿Cancelar esta reserva?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Los asientos se liberarán y otras personas podrán reservarlos. '
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: _fondoDatos,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${r.origen} → ${r.destino}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          r.codigoReserva,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${Formato.fechaLarga(v.dia)} · ${v.horaSalidaCorta} – ${v.horaLlegadaCorta} · ${r.aerolinea}',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 24, color: Color(0xFFE6DED6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Asientos ${r.textoAsientos}',
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.primary),
                          ),
                        ),
                        Text(
                          Formato.dinero(r.total),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Mantener reserva',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sí, cancelar',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}

// ════════════════════════════════════════════════════════════════
//  Cambiar de vuelo: elegir otro vuelo de la misma ruta
// ════════════════════════════════════════════════════════════════

/// Muestra los demás vuelos de la misma ruta y devuelve el elegido.
Future<Vuelo?> elegirNuevoVuelo(BuildContext context, Reserva r) {
  return showDialog<Vuelo>(
    context: context,
    barrierColor: AppColors.primary.withValues(alpha: 0.45),
    builder: (_) => _DialogoNuevoVuelo(reserva: r),
  );
}

class _DialogoNuevoVuelo extends StatefulWidget {
  final Reserva reserva;

  const _DialogoNuevoVuelo({required this.reserva});

  @override
  State<_DialogoNuevoVuelo> createState() => _DialogoNuevoVueloState();
}

class _DialogoNuevoVueloState extends State<_DialogoNuevoVuelo> {
  late Future<List<Vuelo>> _vuelos;

  @override
  void initState() {
    super.initState();
    _vuelos = _cargar();
  }

  Future<List<Vuelo>> _cargar() async {
    final r = widget.reserva;
    final hoy = Formato.soloFecha(DateTime.now());
    final vuelos = await VuelosService().buscarVuelos(
      origen: r.origen,
      destino: r.destino,
      fechaInicio: Formato.iso(hoy),
      fechaFin: Formato.iso(Formato.sumarDias(hoy, 365)),
    );
    final ahora = DateTime.now();
    return vuelos
        .where((v) =>
            v.id != r.vueloId &&
            v.asientosDisponibles > 0 &&
            v.salida.isAfter(ahora))
        .toList()
      ..sort((a, b) => a.salida.compareTo(b.salida));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reserva;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cambiar de vuelo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r.origen} → ${r.destino} · elige otro horario',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: FutureBuilder<List<Vuelo>>(
                future: _vuelos,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.secondary),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return _Aviso(
                      texto: CustomToast.parseError(snap.error),
                      boton: 'Reintentar',
                      onTap: () => setState(() => _vuelos = _cargar()),
                    );
                  }
                  final vuelos = snap.data ?? [];
                  if (vuelos.isEmpty) {
                    return const _Aviso(
                      texto: 'No hay otros vuelos disponibles en esta ruta.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: vuelos.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 24, endIndent: 24),
                    itemBuilder: (context, i) => _OpcionVuelo(
                      vuelo: vuelos[i],
                      onTap: () => Navigator.pop(context, vuelos[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionVuelo extends StatelessWidget {
  final Vuelo vuelo;
  final VoidCallback onTap;

  const _OpcionVuelo({required this.vuelo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = vuelo;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                Formato.fechaConDia(v.dia),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${v.horaSalidaCorta} – ${v.horaLlegadaCorta}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${v.aerolinea} · ${Formato.duracion(v.duracionMinutos)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formato.dinero(v.precio),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'por asiento',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final String? boton;
  final VoidCallback? onTap;

  const _Aviso({required this.texto, this.boton, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          if (boton != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onTap, child: Text(boton!)),
          ],
        ],
      ),
    );
  }
}
