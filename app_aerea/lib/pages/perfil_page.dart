import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/perfil.dart';
import '../models/reserva.dart';
import '../services/perfil_service.dart';
import '../services/reservas_service.dart';
import '../utils/formato.dart';
import '../widgets/barra_superior.dart';
import '../widgets/custom_toast.dart';
import '../widgets/acceso.dart';
import 'reservas_page.dart';

const _bordeSuave = Color(0xFFE6DED6);
const _lineaSuave = Color(0xFFF0EAE3);

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  Perfil? _perfil;
  List<Reserva> _reservas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final perfil = await PerfilService().obtenerPerfil();
      // Si fallan las reservas, el perfil se muestra igual (con ceros)
      List<Reserva> reservas = [];
      try {
        reservas = await ReservasService().listarMisReservas();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _reservas = reservas;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CustomToast.parseError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Navegación ────────────────────────────────────────────────

  void _irAVuelos() => Navigator.of(context).popUntil((r) => r.isFirst);

  void _irAReservas() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ReservasPage()),
    );
  }

  Future<void> _cerrarSesion() => Acceso.cerrarSesion(context);

  // ── Interfaz ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BarraSuperior(
            actual: null,
            onVuelos: _irAVuelos,
            onReservas: _irAReservas,
            onCerrarSesion: _cerrarSesion,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Mi perfil',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tu información personal y los datos de tu cuenta.',
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        _contenido(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    if (_error != null || _perfil == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.secondary),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar tu perfil',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final p = _perfil!;
    final tarjeta = _TarjetaIdentidad(
      perfil: p,
      proximos: _reservas.where((r) => r.esProxima).length,
      realizados: _reservas.where((r) => r.esPasada).length,
      ciudades: _reservas
          .where((r) => !r.esCancelada)
          .map((r) => r.destino)
          .toSet()
          .length,
      onReservas: _irAReservas,
    );
    final datos = _Datos(perfil: p);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tarjeta, const SizedBox(height: 20), datos],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 340, child: tarjeta),
            const SizedBox(width: 24),
            Expanded(child: datos),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Tarjeta de identidad (izquierda)
// ════════════════════════════════════════════════════════════════

class _TarjetaIdentidad extends StatelessWidget {
  final Perfil perfil;
  final int proximos;
  final int realizados;
  final int ciudades;
  final VoidCallback onReservas;

  const _TarjetaIdentidad({
    required this.perfil,
    required this.proximos,
    required this.realizados,
    required this.ciudades,
    required this.onReservas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bordeSuave),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Franja oscura + avatar encima
          SizedBox(
            height: 132,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(height: 84, color: AppColors.primary),
                Positioned(
                  top: 36,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD9B8A0),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      perfil.iniciales,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
            child: Column(
              children: [
                Text(
                  perfil.nombreCompleto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${perfil.usuario}',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (perfil.correoVerificado)
                      const _Etiqueta(
                        texto: 'Cuenta verificada',
                        icono: Icons.check,
                        color: AppColors.success,
                        fondo: AppColors.successLight,
                      ),
                    _Etiqueta(
                      texto: perfil.tipoCuenta,
                      color: AppColors.primary,
                      fondo: AppColors.background,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resumen de viajes
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _bordeSuave)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _Cifra(valor: proximos, texto: 'Próximos')),
                  const VerticalDivider(width: 1, color: _bordeSuave),
                  Expanded(
                      child: _Cifra(valor: realizados, texto: 'Realizados')),
                  const VerticalDivider(width: 1, color: _bordeSuave),
                  Expanded(child: _Cifra(valor: ciudades, texto: 'Ciudades')),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: OutlinedButton.icon(
              onPressed: onReservas,
              icon: const Icon(Icons.confirmation_number_outlined,
                  size: 18, color: AppColors.secondary),
              label: const Text('Ver mis reservas'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(44),
                side: const BorderSide(color: AppColors.border),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  final int valor;
  final String texto;

  const _Cifra({required this.valor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        children: [
          Text(
            '$valor',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            texto,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Secciones de datos (derecha)
// ════════════════════════════════════════════════════════════════

class _Datos extends StatelessWidget {
  final Perfil perfil;

  const _Datos({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final fecha = perfil.fechaCreacion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Seccion(
          titulo: 'Datos personales',
          subtitulo: 'La información con la que te registraste.',
          filas: [
            _FilaDato(
              icono: Icons.person_outline,
              etiqueta: 'Nombre completo',
              valor: perfil.nombreCompleto,
            ),
            _FilaDato(
              icono: Icons.alternate_email,
              etiqueta: 'Usuario',
              valor: perfil.usuario,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Seccion(
          titulo: 'Contacto y cuenta',
          subtitulo: 'A este correo te enviamos los códigos de verificación.',
          filas: [
            _FilaDato(
              icono: Icons.mail_outline,
              etiqueta: 'Correo electrónico',
              valor: perfil.correo,
              extra: perfil.correoVerificado
                  ? const _Etiqueta(
                      texto: 'Verificado',
                      icono: Icons.check,
                      color: AppColors.success,
                      fondo: AppColors.successLight,
                    )
                  : null,
            ),
            _FilaDato(
              icono: Icons.shield_outlined,
              etiqueta: 'Tipo de cuenta',
              valor: perfil.tipoCuenta,
            ),
            _FilaDato(
              icono: Icons.calendar_today_outlined,
              etiqueta: 'Miembro desde',
              valor: fecha == null ? '—' : Formato.fechaConAnio(fecha),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline,
                  size: 20, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tus datos están protegidos y solo tú puedes verlos.',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<Widget> filas;

  const _Seccion({
    required this.titulo,
    required this.subtitulo,
    required this.filas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bordeSuave),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _lineaSuave),
            filas[i],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Widget? extra;

  const _FilaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, size: 20, color: AppColors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  valor.isEmpty ? '—' : valor,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (extra != null) ...[
            const SizedBox(width: 12),
            extra!,
          ],
        ],
      ),
    );
  }
}

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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: color),
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
