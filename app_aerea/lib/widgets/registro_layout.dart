import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Tarjeta común de los pasos 1 y 2 del registro.
class RegistroLayout extends StatelessWidget {
  final int paso;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Widget child;

  const RegistroLayout({
    super.key,
    required this.paso,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3EDE7), Color(0xFFFAF8F5), Color(0xFFECE1D6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 490),
                child: Card(
                  color: Colors.white,
                  elevation: 6,
                  shadowColor: const Color(0x33855A43),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PasosRegistro(actual: paso),
                        const SizedBox(height: 24),
                        Center(
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF1E4DA),
                            ),
                            child:
                                Icon(icono, color: AppColors.primary, size: 34),
                          ),
                        ),
                        const SizedBox(height: 17),
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          subtitulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 25),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de progreso: 1. Correo · 2. Código · 3. Datos
class PasosRegistro extends StatelessWidget {
  final int actual;

  const PasosRegistro({super.key, required this.actual});

  static const _nombres = ['Correo', 'Código', 'Datos'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _nombres.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == _nombres.length - 1 ? 0 : 4,
              ),
              child: _paso(i + 1, _nombres[i]),
            ),
          ),
      ],
    );
  }

  Widget _paso(int numero, String nombre) {
    final hecho = numero < actual;
    final activo = numero == actual;
    final color = hecho || activo ? AppColors.primary : const Color(0xFFD9CCC1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 6),
        Text(
          '$numero. $nombre${hecho ? ' ✓' : ''}',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Recuadro de error con el estilo del resto de la app.
class AvisoError extends StatelessWidget {
  final String mensaje;

  const AvisoError(this.mensaje, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        border: Border.all(color: AppColors.error.withOpacity(0.23)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
