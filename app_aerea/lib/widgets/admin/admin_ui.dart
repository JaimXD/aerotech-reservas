import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/vuelo_admin.dart';

/// Piezas visuales compartidas por las secciones del administrador.

const kBordeAdmin = Color(0xFFE6DED6);
const kBordeFilaAdmin = Color(0xFFF0EAE3);
const kCabeceraAdmin = Color(0xFFF7F2EC);
const kBarraFondoAdmin = Color(0xFFEFE8E1);
const kCarritoFondo = Color(0xFFFFF8E1);
const kCarritoBorde = Color(0xFFF3DFA2);
const kCarritoTexto = Color(0xFF5C4500);

/// "$1,284.80"
String dineroAdmin(double v) {
  final partes = v.toStringAsFixed(2).split('.');
  final entero =
      partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '\$$entero.${partes[1]}';
}

/// Contenido desplazable con ancho máximo y márgenes según el tamaño.
class PaginaAdmin extends StatelessWidget {
  final List<Widget> children;
  final double anchoMaximo;

  const PaginaAdmin({
    super.key,
    required this.children,
    this.anchoMaximo = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, c) {
          final padding = c.maxWidth < 700 ? 16.0 : 32.0;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: anchoMaximo),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Encabezado de página: migas, título, subtítulo y botones.
class EncabezadoAdmin extends StatelessWidget {
  final String titulo;
  final Widget? subtitulo;
  final Widget? chip;
  final List<MigaAdmin> migas;
  final List<Widget> acciones;

  const EncabezadoAdmin({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.chip,
    this.migas = const [],
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 700;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 14,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (migas.isNotEmpty) ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < migas.length; i++) ...[
                    if (i > 0)
                      const Text(' / ',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    migas[i],
                  ],
                ],
              ),
              const SizedBox(height: 6),
            ],
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: compacto ? 22 : 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                if (chip != null) chip!,
              ],
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                child: subtitulo!,
              ),
            ],
          ],
        ),
        if (acciones.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: acciones,
          ),
      ],
    );
  }
}

/// Un paso de las migas de pan ("Vuelos / #41").
class MigaAdmin extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;

  const MigaAdmin(this.texto, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 14,
      color: onTap == null ? AppColors.textSecondary : AppColors.secondary,
      fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w600,
    );
    if (onTap == null) return Text(texto, style: estilo);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(texto, style: estilo),
      ),
    );
  }
}

/// Botón principal oscuro (Nuevo vuelo, Guardar...).
class BotonAdmin extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool cargando;
  final Color color;

  const BotonAdmin({
    super.key,
    required this.texto,
    this.icono,
    this.onPressed,
    this.cargando = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = FilledButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
    if (!cargando && icono == null) {
      return FilledButton(
          onPressed: onPressed, style: estilo, child: Text(texto));
    }
    return FilledButton.icon(
      onPressed: cargando ? null : onPressed,
      style: estilo,
      icon: cargando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icono, size: 20),
      label: Text(texto),
    );
  }
}

/// Botón blanco con borde (Editar, Cancelar...). [peligro] lo pinta en rojo.
class BotonSecundarioAdmin extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool peligro;

  const BotonSecundarioAdmin({
    super.key,
    required this.texto,
    this.icono,
    this.onPressed,
    this.peligro = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = peligro ? AppColors.error : AppColors.primary;
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      side: BorderSide(
          color: peligro ? const Color(0xFFF2B8B5) : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    if (icono == null) {
      return OutlinedButton(
          onPressed: onPressed, style: estilo, child: Text(texto));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: estilo,
      icon: Icon(icono, size: 18),
      label: Text(texto),
    );
  }
}

/// Tarjeta blanca con borde suave.
class TarjetaAdmin extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const TarjetaAdmin({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBordeAdmin),
      ),
      child: child,
    );
  }
}

/// Indicador numérico (Vendidos, Libres, Ingresos...).
class IndicadorAdmin extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? detalle;
  final String? pie;
  final bool destacado;

  const IndicadorAdmin({
    super.key,
    required this.titulo,
    required this.valor,
    this.detalle,
    this.pie,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destacado ? kCarritoFondo : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: destacado ? kCarritoBorde : kBordeAdmin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: valor),
              if (detalle != null)
                TextSpan(
                  text: ' $detalle',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary),
                ),
            ]),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
          if (pie != null) ...[
            const SizedBox(height: 2),
            Text(pie!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Cuadrícula de indicadores: 4, 2 o 1 por fila según el ancho.
class FilaIndicadores extends StatelessWidget {
  final List<Widget> children;

  const FilaIndicadores({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth >= 860 ? 4 : (c.maxWidth >= 420 ? 2 : 1);
      const espacio = 14.0;
      final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
      return Wrap(
        spacing: espacio,
        runSpacing: espacio,
        children: [
          for (final h in children) SizedBox(width: ancho, child: h),
        ],
      );
    });
  }
}

/// Barra de ocupación con el texto "11/18".
class BarraOcupacion extends StatelessWidget {
  final int vendidos;
  final int total;

  const BarraOcupacion(
      {super.key, required this.vendidos, required this.total});

  @override
  Widget build(BuildContext context) {
    final valor = total == 0 ? 0.0 : vendidos / total;
    final lleno = total > 0 && vendidos >= total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: valor.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: kBarraFondoAdmin,
              color: lleno ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(total == 0 ? '—' : '$vendidos/$total',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      ],
    );
  }
}

/// Píldora con el estado del vuelo.
class ChipEstadoVuelo extends StatelessWidget {
  final EstadoVuelo estado;

  const ChipEstadoVuelo({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (estado) {
      EstadoVuelo.programado => (
          AppColors.successLight,
          const Color(0xFF1B5E20)
        ),
      EstadoVuelo.completo => (kBarraFondoAdmin, AppColors.primary),
      EstadoVuelo.salio => (const Color(0xFFECEFF1), const Color(0xFF455A64)),
      EstadoVuelo.cancelado => (AppColors.errorLight, AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(99)),
      child: Text(estado.etiqueta,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Mensaje de error con botón para reintentar.
class ErrorAdmin extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const ErrorAdmin(
      {super.key, required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 40, color: AppColors.secondary),
          const SizedBox(height: 12),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          BotonAdmin(
              texto: 'Reintentar',
              icono: Icons.refresh_rounded,
              onPressed: onReintentar),
        ],
      ),
    );
  }
}

/// Mensaje de error legible a partir de una excepción.
String mensajeError(Object e) =>
    e.toString().replaceFirst('Exception: ', '');
