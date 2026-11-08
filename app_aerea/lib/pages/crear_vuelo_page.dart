import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/admin_vuelo_service.dart';
import '../services/session_manager.dart';
import '../widgets/custom_toast.dart';

class CrearVueloPage extends StatefulWidget {
  const CrearVueloPage({super.key});

  @override
  State<CrearVueloPage> createState() => _CrearVueloPageState();
}

class _CrearVueloPageState extends State<CrearVueloPage> {
  @override
  void initState() {
    super.initState();
    // HU-06 client side role protection
    if (!SessionManager().isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Acceso denegado: se requieren permisos de administrador"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      });
    }
  }
  final aerolineaCtrl = TextEditingController(text: "AeroAndes");
  final origenCtrl = TextEditingController(text: "Quito");
  final destinoCtrl = TextEditingController(text: "Guayaquil");
  final fechaCtrl = TextEditingController(text: "2026-06-20");
  final fechaLlegadaCtrl = TextEditingController(text: "2026-06-20");
  final horaSalidaCtrl = TextEditingController(text: "08:00");
  final horaLlegadaCtrl = TextEditingController(text: "09:00");
  final precioCtrl = TextEditingController(text: "85.00");
  final cantidadAsientosCtrl = TextEditingController(text: "12");

  final AdminVueloService adminVueloService = AdminVueloService();

  bool guardando = false;
  String mensaje = "";
  bool exito = false;

  Future<void> crearVuelo() async {
    setState(() {
      guardando = true;
      mensaje = "";
      exito = false;
    });

    try {
      // 1. Validar asientos
      final cantidadAsientos = int.tryParse(cantidadAsientosCtrl.text.trim());
      if (cantidadAsientos == null || cantidadAsientos <= 0) {
        throw Exception("La cantidad de asientos debe ser mayor a cero");
      }

      // 2. Validar precio no negativo ni cero
      final precioVal = double.tryParse(precioCtrl.text.trim());
      if (precioVal == null || precioVal <= 0) {
        throw Exception("El precio del vuelo debe ser mayor a cero y no puede ser negativo");
      }

      // 3. Validar fechas
      final String fechaSalidaStr = fechaCtrl.text.trim();
      final String fechaLlegadaStr = fechaLlegadaCtrl.text.trim();
      
      final DateTime? fechaSalida = DateTime.tryParse(fechaSalidaStr);
      final DateTime? fechaLlegada = DateTime.tryParse(fechaLlegadaStr);
      
      if (fechaSalida == null) {
        throw Exception("La fecha de salida no tiene un formato válido (YYYY-MM-DD)");
      }
      if (fechaLlegada == null) {
        throw Exception("La fecha de llegada no tiene un formato válido (YYYY-MM-DD)");
      }
      
      final DateTime hoy = DateTime.now();
      final DateTime hoyPura = DateTime(hoy.year, hoy.month, hoy.day);
      
      if (fechaSalida.isBefore(hoyPura)) {
        throw Exception("No se puede crear un vuelo con fecha de salida anterior a hoy");
      }
      
      if (fechaLlegada.isBefore(fechaSalida)) {
        throw Exception("La fecha de llegada no puede ser anterior a la fecha de salida");
      }
      
      // 4. Validar horas en caso de ser el mismo día
      if (fechaSalida.isAtSameMomentAs(fechaLlegada)) {
        final List<String> salidaParts = horaSalidaCtrl.text.trim().split(":");
        final List<String> llegadaParts = horaLlegadaCtrl.text.trim().split(":");
        
        if (salidaParts.length >= 2 && llegadaParts.length >= 2) {
          final int hSalida = int.tryParse(salidaParts[0]) ?? 0;
          final int mSalida = int.tryParse(salidaParts[1]) ?? 0;
          final int hLlegada = int.tryParse(llegadaParts[0]) ?? 0;
          final int mLlegada = int.tryParse(llegadaParts[1]) ?? 0;
          
          if (hLlegada < hSalida || (hLlegada == hSalida && mLlegada <= mSalida)) {
            throw Exception("La hora de llegada debe ser posterior a la hora de salida para vuelos en el mismo día");
          }
        } else {
          throw Exception("Formato de hora de salida u hora de llegada inválido (debe ser HH:MM)");
        }
      }

      final respuesta = await adminVueloService.crearVuelo(
        aerolinea: aerolineaCtrl.text.trim(),
        origen: origenCtrl.text.trim(),
        destino: destinoCtrl.text.trim(),
        fecha: fechaCtrl.text.trim(),
        fechaLlegada: fechaLlegadaCtrl.text.trim(),
        horaSalida: horaSalidaCtrl.text.trim(),
        horaLlegada: horaLlegadaCtrl.text.trim(),
        precio: precioVal,
        cantidadAsientos: cantidadAsientos,
      );

      final vuelo = respuesta["vuelo"];

      if (!mounted) return;
      CustomToast.showSuccess(context, "Vuelo creado correctamente");

      setState(() {
        exito = true;
        mensaje =
            "Vuelo creado correctamente\n"
            "ID: ${vuelo["id"]}\n"
            "Asientos generados: ${vuelo["asientos_generados"].join(", ")}";
      });
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, e);
      setState(() {
        exito = false;
        mensaje = CustomToast.parseError(e);
      });
    } finally {
      setState(() {
        guardando = false;
      });
    }
  }

  @override
  void dispose() {
    aerolineaCtrl.dispose();
    origenCtrl.dispose();
    destinoCtrl.dispose();
    fechaCtrl.dispose();
    fechaLlegadaCtrl.dispose();
    horaSalidaCtrl.dispose();
    horaLlegadaCtrl.dispose();
    precioCtrl.dispose();
    cantidadAsientosCtrl.dispose();
    super.dispose();
  }

  Widget campo({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear vuelo"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.appBar),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBackground),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: SizedBox(
              width: 520,
              child: Container(
                decoration: AppDecorations.card,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryButton,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Registro de nuevo vuelo",
                              style: AppTextStyles.subheading.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Los asientos se generarán automáticamente.",
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    campo(
                      controller: aerolineaCtrl,
                      label: "Aerolínea",
                      icon: Icons.flight,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: campo(
                            controller: origenCtrl,
                            label: "Origen",
                            icon: Icons.location_on,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: campo(
                            controller: destinoCtrl,
                            label: "Destino",
                            icon: Icons.place,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: campo(
                            controller: fechaCtrl,
                            label: "Fecha salida YYYY-MM-DD",
                            icon: Icons.calendar_month,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: campo(
                            controller: fechaLlegadaCtrl,
                            label: "Fecha llegada YYYY-MM-DD",
                            icon: Icons.calendar_today,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: campo(
                            controller: horaSalidaCtrl,
                            label: "Hora salida HH:MM",
                            icon: Icons.schedule,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: campo(
                            controller: horaLlegadaCtrl,
                            label: "Hora llegada HH:MM",
                            icon: Icons.access_time,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: campo(
                            controller: precioCtrl,
                            label: "Precio",
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: campo(
                            controller: cantidadAsientosCtrl,
                            label: "Cantidad de asientos",
                            icon: Icons.event_seat,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Botón con gradiente ──
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: guardando ? null : crearVuelo,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: guardando ? null : AppGradients.primaryButton,
                            color: guardando ? AppColors.border : null,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: guardando
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                guardando ? "Guardando..." : "Crear vuelo",
                                style: AppTextStyles.buttonText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (mensaje.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: exito
                              ? AppColors.successLight
                              : AppColors.errorLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: exito
                                ? AppColors.success.withOpacity(0.4)
                                : AppColors.error.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              exito ? Icons.check_circle_outline : Icons.error_outline,
                              color: exito ? AppColors.success : AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                mensaje,
                                style: TextStyle(
                                  color: exito
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}