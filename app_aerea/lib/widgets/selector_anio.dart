import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Botón «Año 2028 ▾» de los calendarios. Abre una cuadrícula con los años
/// (de 12 en 12, con flechas para ver más) para elegir cualquiera.
class SelectorAnio extends StatelessWidget {
  final int desde;
  final int hasta;

  /// Año que se está viendo.
  final int actual;
  final ValueChanged<int> onElegir;

  const SelectorAnio({
    super.key,
    required this.desde,
    required this.hasta,
    required this.actual,
    required this.onElegir,
  });

  /// Mes que se muestra al saltar a [anio]: el mismo mes que se veía,
  /// sin salirse de [primerMes] y [ultimoMes] (ambos día 1).
  static DateTime mesEn(
      int anio, DateTime mesActual, DateTime primerMes, DateTime ultimoMes) {
    var m = DateTime(anio, mesActual.month);
    if (m.isBefore(primerMes)) m = primerMes;
    if (m.isAfter(ultimoMes)) m = ultimoMes;
    return m;
  }

  Future<void> _abrir(BuildContext context) async {
    final anio = await showDialog<int>(
      context: context,
      builder: (_) =>
          _DialogoAnios(desde: desde, hasta: hasta, actual: actual),
    );
    if (anio != null) onElegir(anio);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _abrir(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        icon: const Icon(Icons.calendar_month_rounded, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Año $actual',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DialogoAnios extends StatefulWidget {
  final int desde;
  final int hasta;
  final int actual;

  const _DialogoAnios(
      {required this.desde, required this.hasta, required this.actual});

  @override
  State<_DialogoAnios> createState() => _DialogoAniosState();
}

class _DialogoAniosState extends State<_DialogoAnios> {
  static const _porPagina = 12;

  /// Primer año de la página visible.
  late int _inicio = widget.desde +
      (widget.actual - widget.desde) ~/ _porPagina * _porPagina;

  int get _fin => _inicio + _porPagina - 1;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Elige el año',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Años anteriores',
                    onPressed: _inicio > widget.desde
                        ? () => setState(() => _inicio -= _porPagina)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text('$_inicio – $_fin',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  IconButton(
                    tooltip: 'Años siguientes',
                    onPressed: _fin < widget.hasta
                        ? () => setState(() => _inicio += _porPagina)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (var a = _inicio; a <= _fin; a++) _anio(a),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _anio(int a) {
    if (a > widget.hasta) return const SizedBox.shrink();
    final elegido = a == widget.actual;
    return Material(
      color: elegido ? AppColors.primary : Colors.transparent,
      shape: StadiumBorder(
          side: BorderSide(
              color: elegido ? AppColors.primary : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.pop(context, a),
        child: Center(
          child: Text('$a',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: elegido ? Colors.white : AppColors.primary)),
        ),
      ),
    );
  }
}
