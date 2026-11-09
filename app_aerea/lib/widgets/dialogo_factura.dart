import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/reserva.dart';
import '../services/factura_service.dart';
import '../utils/descarga.dart';
import '../utils/formato.dart';
import 'custom_toast.dart';

const _bordeSuave = Color(0xFFE6DED6);
const _fondoSuave = Color(0xFFF7F2EC);

/// Muestra la factura de una reserva como un recibo y permite descargar el XML.
Future<void> mostrarFactura(BuildContext context, Reserva r) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.primary.withValues(alpha: 0.45),
    builder: (_) => _DialogoFactura(reserva: r),
  );
}

// ════════════════════════════════════════════════════════════════
//  Datos de la factura (leídos del XML que envía el backend)
// ════════════════════════════════════════════════════════════════

class _Factura {
  final String xml;

  _Factura(this.xml);

  /// Texto de la primera etiqueta <nombre>…</nombre> dentro de [texto].
  static String _valor(String texto, String etiqueta) {
    final m =
        RegExp('<$etiqueta(?: [^>]*)?>([^<]*)</$etiqueta>').firstMatch(texto);
    return _desescapar(m?.group(1)?.trim() ?? '');
  }

  /// Contenido de un bloque <cliente>…</cliente>.
  static String _bloque(String texto, String etiqueta) {
    final m =
        RegExp('<$etiqueta>(.*?)</$etiqueta>', dotAll: true).firstMatch(texto);
    return m?.group(1) ?? '';
  }

  static String _desescapar(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  String get _cliente => _bloque(xml, 'cliente');
  String get _emisor => _bloque(xml, 'emisor');
  String get _reserva => _bloque(xml, 'reserva');
  String get _vuelo => _bloque(xml, 'vuelo');
  String get _item => _bloque(xml, 'item');

  String get numero => _valor(xml, 'numero');
  DateTime? get fecha => DateTime.tryParse(_valor(xml, 'fecha'));

  String get emisor => _valor(_emisor, 'nombre');
  String get clienteNombre => _valor(_cliente, 'nombre');
  String get clienteCorreo => _valor(_cliente, 'correo');

  String get codigoReserva => _valor(_reserva, 'codigo');

  String get aerolinea => _valor(_vuelo, 'aerolinea');
  String get origen => _valor(_vuelo, 'origen');
  String get destino => _valor(_vuelo, 'destino');
  DateTime? get fechaVuelo => DateTime.tryParse(_valor(_vuelo, 'fecha'));
  String get horaSalida => _valor(_vuelo, 'hora_salida');
  String get horaLlegada => _valor(_vuelo, 'hora_llegada');

  String get descripcion => _valor(_item, 'descripcion');
  String get asientos => _valor(_item, 'asientos');
  int get cantidad => int.tryParse(_valor(_item, 'cantidad')) ?? 1;
  double get precioUnitario => _numero(_valor(_item, 'precio_unitario'));

  // Los totales están directamente en <factura> (después de <detalle>)
  String get _totales => xml.split('</detalle>').last;
  double get subtotal => _numero(_valor(_totales, 'subtotal'));
  double get iva => _numero(_valor(_totales, 'iva'));
  double get total => _numero(_valor(_totales, 'total'));
  String get porcentajeIva =>
      RegExp(r'porcentaje="(\d+)"').firstMatch(xml)?.group(1) ?? '15';

  static double _numero(String s) => double.tryParse(s) ?? 0;
}

// ════════════════════════════════════════════════════════════════
//  Diálogo
// ════════════════════════════════════════════════════════════════

class _DialogoFactura extends StatefulWidget {
  final Reserva reserva;

  const _DialogoFactura({required this.reserva});

  @override
  State<_DialogoFactura> createState() => _DialogoFacturaState();
}

class _DialogoFacturaState extends State<_DialogoFactura> {
  late Future<String> _xml;

  @override
  void initState() {
    super.initState();
    _xml = FacturaService().obtenerFacturaXml(widget.reserva.id);
  }

  void _descargar(_Factura f) {
    final nombre =
        'factura_${f.numero.isEmpty ? widget.reserva.codigoReserva : f.numero}.xml';
    try {
      descargarArchivo(nombre, f.xml);
      CustomToast.showSuccess(context, 'Factura descargada: $nombre');
    } catch (e) {
      CustomToast.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: FutureBuilder<String>(
          future: _xml,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 260,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                ),
              );
            }
            if (snap.hasError) {
              return _Error(
                texto: CustomToast.parseError(snap.error),
                onCerrar: () => Navigator.pop(context),
              );
            }
            return _recibo(_Factura(snap.data!));
          },
        ),
      ),
    );
  }

  Widget _recibo(_Factura f) {
    final fecha = f.fecha;
    final fechaVuelo = f.fechaVuelo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Encabezado con el total ──────────────────────────
                Container(
                  color: _fondoSuave,
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flight_takeoff,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f.emisor.isEmpty ? 'AeroTech Reservas' : f.emisor,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Total pagado',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formato.dinero(f.total),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const _Etiqueta(
                            icono: Icons.check_circle,
                            texto: 'Pagada',
                            color: AppColors.success,
                            fondo: AppColors.successLight,
                          ),
                          _Etiqueta(
                            texto: 'IVA ${f.porcentajeIva} % incluido',
                            color: AppColors.textSecondary,
                            fondo: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Datos de la factura ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Dato(
                              titulo: 'Factura N.º',
                              valor: f.numero,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _Dato(
                              titulo: 'Fecha de emisión',
                              valor: fecha == null
                                  ? '—'
                                  : Formato.fechaConAnio(fecha),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Dato(
                        titulo: 'Facturado a',
                        valor: f.clienteNombre,
                        detalle: f.clienteCorreo,
                      ),

                      const _Separador(),

                      // ── Vuelo ────────────────────────────────────
                      const _TituloSeccion('Tu vuelo'),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${f.origen} → ${f.destino}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            '${f.horaSalida} – ${f.horaLlegada}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (fechaVuelo != null)
                            Formato.fechaLarga(fechaVuelo),
                          f.aerolinea,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _bordeSuave),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Dato(
                                titulo: 'Asientos',
                                valor: f.asientos.isEmpty ? '—' : f.asientos,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _Dato(
                                titulo: 'Código de reserva',
                                valor: f.codigoReserva,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const _Separador(),

                      // ── Detalle del pago ─────────────────────────
                      const _TituloSeccion('Detalle del pago'),
                      _Fila(
                        texto: f.descripcion.isEmpty
                            ? 'Pasaje aéreo'
                            : f.descripcion,
                        detalle:
                            '${f.cantidad} × ${Formato.dinero(f.precioUnitario)}',
                        valor: Formato.dinero(f.subtotal),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: _bordeSuave),
                      const SizedBox(height: 14),
                      _Fila(
                        texto: 'Subtotal',
                        valor: Formato.dinero(f.subtotal),
                        suave: true,
                      ),
                      const SizedBox(height: 8),
                      _Fila(
                        texto: 'IVA (${f.porcentajeIva} %)',
                        valor: Formato.dinero(f.iva),
                        suave: true,
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: _bordeSuave),
                      const SizedBox(height: 14),
                      _Fila(
                        texto: 'Total',
                        valor: Formato.dinero(f.total),
                        fuerte: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Botones ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _bordeSuave)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.border),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _descargar(f),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Descargar factura XML'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Piezas pequeñas
// ════════════════════════════════════════════════════════════════

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  const _Etiqueta({
    required this.texto,
    required this.color,
    required this.fondo,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _bordeSuave),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            texto,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? detalle;

  const _Dato({required this.titulo, required this.valor, this.detalle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        if (detalle != null && detalle!.isNotEmpty)
          Text(
            detalle!,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  final String texto;
  final String? detalle;
  final String valor;
  final bool fuerte;
  final bool suave;

  const _Fila({
    required this.texto,
    required this.valor,
    this.detalle,
    this.fuerte = false,
    this.suave = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = suave ? AppColors.textSecondary : AppColors.primary;
    final tam = fuerte ? 18.0 : 15.0;
    final peso = fuerte ? FontWeight.w800 : FontWeight.w500;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto,
                  style:
                      TextStyle(fontSize: tam, fontWeight: peso, color: color)),
              if (detalle != null)
                Text(
                  detalle!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(valor,
            style: TextStyle(
                fontSize: tam,
                fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
                color: color)),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, color: _bordeSuave),
    );
  }
}

class _Error extends StatelessWidget {
  final String texto;
  final VoidCallback onCerrar;

  const _Error({required this.texto, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            'No se pudo generar la factura',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          TextButton(onPressed: onCerrar, child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
