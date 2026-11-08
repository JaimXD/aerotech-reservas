import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../models/vuelo.dart';
import '../services/reservas_service.dart';
import '../widgets/reserva_card.dart';
import '../widgets/custom_toast.dart';
import 'seleccion_asientos_page.dart';

class ReservasPage extends StatefulWidget {
  const ReservasPage({super.key});

  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage> {
  final ReservasService reservasService = ReservasService();
  List<Reserva> reservas = [];
  bool cargando = true;
  String mensaje = "";

  Future<void> cargar() async {
    setState(() { cargando = true; mensaje = ""; });
    try {
      final data = await reservasService.listarMisReservas();
      setState(() => reservas = data);
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, e);
      setState(() => mensaje = CustomToast.parseError(e));
    } finally {
      setState(() => cargando = false);
    }
  }

  Future<void> cancelar(int id) async {
    try {
      await reservasService.cancelarReserva(id);
      if (!mounted) return;
      CustomToast.showSuccess(context, "Reserva cancelada");
      cargar();
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, e);
    }
  }

  void editar(Reserva reserva) {
    final precio = reserva.cantidadAsientos > 0 ? (reserva.total / reserva.cantidadAsientos) : 0.0;
    final vuelo = Vuelo(
      id: reserva.vueloId,
      aerolinea: reserva.aerolinea,
      origen: reserva.origen,
      destino: reserva.destino,
      fecha: reserva.fechaVuelo,
      fechaLlegada: reserva.fechaLlegada,
      horaSalida: reserva.horaSalida,
      horaLlegada: reserva.horaLlegada,
      precio: precio,
      asientosDisponibles: 10,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionAsientosPage(vuelo: vuelo, reserva: reserva),
      ),
    ).then((_) {
      cargar();
    });
  }

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis reservas"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.appBar),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBackground),
        child: SafeArea(
          child: cargando
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.secondary),
                      const SizedBox(height: 12),
                      Text("Cargando reservas...", style: AppTextStyles.body),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (mensaje.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  mensaje,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (reservas.isEmpty && mensaje.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.confirmation_number_outlined, size: 56, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                Text(
                                  "No tiene reservas registradas.",
                                  style: AppTextStyles.body.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Reserve un vuelo para empezar",
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: reservas.length,
                            itemBuilder: (context, index) => ReservaCard(
                              reserva: reservas[index],
                              onCancelar: () => cancelar(reservas[index].id),
                              onEditar: () => editar(reservas[index]),
                            ),
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
