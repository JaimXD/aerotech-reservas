import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/vuelo.dart';
import '../services/vuelos_service.dart';
import '../services/session_manager.dart';
import '../widgets/vuelo_card.dart';
import '../widgets/custom_toast.dart';
import 'login_page.dart';
import 'reservas_page.dart';
import 'seleccion_asientos_page.dart';
import 'crear_vuelo_page.dart';

class VuelosPage extends StatefulWidget {
  const VuelosPage({super.key});

  @override
  State<VuelosPage> createState() => _VuelosPageState();
}

class _VuelosPageState extends State<VuelosPage> {
  final origenCtrl = TextEditingController(text: "Quito");
  final destinoCtrl = TextEditingController(text: "Guayaquil");
  final fechaCtrl = TextEditingController();

  final VuelosService vuelosService = VuelosService();
  final SessionManager sessionManager = SessionManager();

  List<Vuelo> vuelos = [];
  bool cargando = false;
  String mensaje = "";
  DateTimeRange? selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Start with a default search if we have dates, but by default we force the user to pick a range.
    // So we don't automatically trigger buscar() unless there is a range.
    // For convenience we can prepopulate a range: from today to 10 days later
    final today = DateTime.now();
    selectedDateRange = DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 10)),
    );
    fechaCtrl.text = "${_formatFecha(selectedDateRange!.start)} - ${_formatFecha(selectedDateRange!.end)}";
    buscar();
  }

  @override
  void dispose() {
    origenCtrl.dispose();
    destinoCtrl.dispose();
    fechaCtrl.dispose();
    super.dispose();
  }

  String _formatFecha(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatIso(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _seleccionarRangoFechas() async {
    final today = DateTime.now();
    final initialRange = selectedDateRange ?? DateTimeRange(start: today, end: today.add(const Duration(days: 7)));
    
    // HU-04: showDateRangePicker with past dates disabled
    final rangePicked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day), // past dates disabled
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.secondary,
              onSecondary: Colors.white,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (rangePicked != null) {
      // Validation: end date must be equal or after start date (enforced by the picker natively, but we can do explicit checks)
      if (rangePicked.end.isBefore(rangePicked.start)) {
        CustomToast.showError(context, "La fecha de fin no puede ser anterior al inicio.");
        return;
      }
      
      setState(() {
        selectedDateRange = rangePicked;
        fechaCtrl.text = "${_formatFecha(rangePicked.start)} - ${_formatFecha(rangePicked.end)}";
      });
    }
  }

  Future<void> buscar() async {
    if (selectedDateRange == null) {
      setState(() {
        mensaje = "Debe seleccionar un rango de fechas para buscar vuelos.";
      });
      return;
    }

    setState(() {
      cargando = true;
      mensaje = "";
      vuelos = [];
    });

    try {
      final data = await vuelosService.buscarVuelos(
        origen: origenCtrl.text.trim(),
        destino: destinoCtrl.text.trim(),
        fechaInicio: _formatIso(selectedDateRange!.start),
        fechaFin: _formatIso(selectedDateRange!.end),
      );

      setState(() {
        vuelos = data;
      });
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, e);
      setState(() {
        mensaje = CustomToast.parseError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  void abrirSeleccionAsientos(Vuelo vuelo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionAsientosPage(vuelo: vuelo),
      ),
    ).then((_) {
      buscar();
    });
  }

  void abrirMisReservas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReservasPage(),
      ),
    ).then((_) {
      buscar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vuelos disponibles"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.appBar),
        ),
        actions: [
          IconButton(
            onPressed: abrirMisReservas,
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: "Mis reservas",
          ),
          
          // HU-06 admin menu item visibility
          if (sessionManager.isAdmin)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CrearVueloPage(),
                  ),
                ).then((_) {
                  buscar();
                });
              },
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Crear vuelo",
            ),
            
          IconButton(
            onPressed: () async {
              await sessionManager.cerrarSesion();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.pageBackground),
        child: SafeArea(
          child: Column(
            children: [
              // ── Barra de búsqueda ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: origenCtrl,
                            decoration: const InputDecoration(
                              labelText: "Origen",
                              prefixIcon: Icon(Icons.flight_takeoff_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: destinoCtrl,
                            decoration: const InputDecoration(
                              labelText: "Destino",
                              prefixIcon: Icon(Icons.flight_land_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // HU-04 Date Field (Tap to open picker)
                    TextField(
                      controller: fechaCtrl,
                      readOnly: true,
                      onTap: _seleccionarRangoFechas,
                      decoration: const InputDecoration(
                        labelText: "Rango de fechas",
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        hintText: "Seleccionar rango de fechas",
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // HU-04: Button disabled if no range selected
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: (cargando || selectedDateRange == null) ? null : buscar,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: (cargando || selectedDateRange == null)
                                ? null
                                : AppGradients.primaryButton,
                            color: (cargando || selectedDateRange == null) ? AppColors.border : null,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: (cargando || selectedDateRange == null)
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
                              const Icon(Icons.search, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                cargando ? "Buscando..." : "Buscar vuelos",
                                style: AppTextStyles.buttonText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (mensaje.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mensaje,
                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              
              Expanded(
                child: cargando
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.secondary),
                            const SizedBox(height: 12),
                            Text("Buscando vuelos...", style: AppTextStyles.body),
                          ],
                        ),
                      )
                    : vuelos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_outlined, size: 56, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                Text(
                                  "No hay vuelos disponibles.",
                                  style: AppTextStyles.body.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Intente con otros criterios de búsqueda",
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: vuelos.length,
                            itemBuilder: (context, index) {
                              final vuelo = vuelos[index];
                              return VueloCard(
                                vuelo: vuelo,
                                onReservar: () {
                                  abrirSeleccionAsientos(vuelo);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}