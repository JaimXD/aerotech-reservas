import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_manager.dart';

/// Grupos de datos que el servidor vigila (GET /api/admin/cambios).
enum DatoAdmin { vuelos, reservas, usuarios, carritos }

/// Actualización automática de las secciones del administrador.
///
/// Mientras alguna pantalla escucha, cada [intervalo] se pide al servidor
/// una "huella" de cada grupo de datos (unos pocos bytes). Cuando cambia la
/// huella de algo que una pantalla muestra, se le avisa para que recargue.
/// Si la pestaña del navegador está oculta, no consulta.
class CambiosAdmin with WidgetsBindingObserver {
  CambiosAdmin._();
  static final CambiosAdmin instancia = CambiosAdmin._();

  static const intervalo = Duration(seconds: 5);

  final List<_Oyente> _oyentes = [];
  Timer? _timer;
  Map<String, String>? _ultimo;
  bool _revisando = false;

  /// Llama a [alCambiar] cada vez que cambie alguno de los [datos].
  /// Devuelve la función para dejar de escuchar (llamarla en `dispose`).
  VoidCallback escuchar(Set<DatoAdmin> datos, VoidCallback alCambiar) {
    final oyente = _Oyente(datos, alCambiar);
    _oyentes.add(oyente);
    if (_timer == null) _iniciar();
    return () {
      _oyentes.remove(oyente);
      if (_oyentes.isEmpty) _detener();
    };
  }

  void _iniciar() {
    WidgetsBinding.instance.addObserver(this);
    _ultimo = null; // la primera consulta solo toma la referencia
    _revisar();
    _timer = Timer.periodic(intervalo, (_) => _revisar());
  }

  void _detener() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la pestaña se revisa de inmediato
    if (state == AppLifecycleState.resumed) _revisar();
  }

  bool get _visible {
    final estado = WidgetsBinding.instance.lifecycleState;
    return estado == null || estado == AppLifecycleState.resumed;
  }

  Future<void> _revisar() async {
    if (_revisando || _oyentes.isEmpty || !_visible) return;
    _revisando = true;
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/cambios'),
        headers: {
          'Authorization': 'Bearer ${SessionManager().token ?? ApiConfig.token}',
        },
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return; // se intenta en la siguiente vuelta

      final nuevo = (jsonDecode(r.body) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, '$v'));
      final anterior = _ultimo;
      _ultimo = nuevo;
      if (anterior == null) return;

      final cambiados = {
        for (final d in DatoAdmin.values)
          if (anterior[d.name] != nuevo[d.name]) d,
      };
      if (cambiados.isEmpty) return;
      // Copia: una pantalla puede dejar de escuchar mientras se avisa
      for (final o in List.of(_oyentes)) {
        if (o.datos.any(cambiados.contains)) o.alCambiar();
      }
    } catch (_) {
      // Sin conexión: se intenta en la siguiente vuelta
    } finally {
      _revisando = false;
    }
  }
}

class _Oyente {
  final Set<DatoAdmin> datos;
  final VoidCallback alCambiar;

  _Oyente(this.datos, this.alCambiar);
}
