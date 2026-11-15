import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/usuario_admin.dart';
import '../../services/admin_usuario_service.dart';
import '../../utils/formato.dart';
import '../../widgets/admin/admin_ui.dart';
import '../../widgets/custom_toast.dart';

/// Sección "Usuarios" del administrador: cuentas, roles y suspensiones.
class UsuariosAdminPage extends StatefulWidget {
  const UsuariosAdminPage({super.key});

  @override
  State<UsuariosAdminPage> createState() => _UsuariosAdminPageState();
}

/// Lo que se puede hacer con una cuenta desde la lista.
enum _Accion { hacerAdmin, quitarAdmin, suspender, reactivar }

class _UsuariosAdminPageState extends State<UsuariosAdminPage> {
  final _service = AdminUsuarioService();
  final _busqueda = TextEditingController();
  Timer? _espera;

  RolFiltro _rol = RolFiltro.todos;
  EstadoCuentaFiltro _estado = EstadoCuentaFiltro.todos;
  int _pagina = 1;

  ListaUsuariosAdmin? _datos;
  bool _cargando = true;
  String? _error;
  int _consulta = 0; // descarta respuestas viejas si llegan tarde

  /// Cuentas con una acción en curso (sus botones quedan desactivados).
  final Set<int> _ocupados = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _service.listar(
        busqueda: _busqueda.text,
        rol: _rol,
        estado: _estado,
        pagina: _pagina,
      );
      if (!mounted || consulta != _consulta) return;
      if (datos.usuarios.isEmpty && _pagina > 1) {
        _pagina = datos.paginas;
        await _cargar();
        return;
      }
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _cargando = false;
        _error = mensajeError(e);
      });
    }
  }

  void _filtrar(VoidCallback cambio) {
    setState(() {
      cambio();
      _pagina = 1;
    });
    _cargar();
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () => _filtrar(() {}));
  }

  bool get _hayFiltros =>
      _rol != RolFiltro.todos ||
      _estado != EstadoCuentaFiltro.todos ||
      _busqueda.text.trim().isNotEmpty;

  // ── Acciones ─────────────────────────────────────────────────────

  Future<void> _ejecutar(UsuarioAdmin u, _Accion accion) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _DialogoConfirmar(usuario: u, accion: accion),
    );
    if (ok != true || !mounted) return;

    setState(() => _ocupados.add(u.id));
    try {
      final String mensaje;
      switch (accion) {
        case _Accion.hacerAdmin:
          await _service.cambiarRol(u.id, admin: true);
          mensaje = '${u.nombre} ahora es administrador';
        case _Accion.quitarAdmin:
          await _service.cambiarRol(u.id, admin: false);
          mensaje = '${u.nombre} ahora es cliente';
        case _Accion.suspender:
          await _service.cambiarEstado(u.id, activo: false);
          mensaje = 'Cuenta de ${u.nombre} suspendida';
        case _Accion.reactivar:
          await _service.cambiarEstado(u.id, activo: true);
          mensaje = 'Cuenta de ${u.nombre} reactivada';
      }
      if (!mounted) return;
      CustomToast.showSuccess(context, mensaje);
      await _cargar();
    } catch (e) {
      if (mounted) CustomToast.showError(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _ocupados.remove(u.id));
    }
  }

  // ── Interfaz ─────────────────────────────────────────────────────

  String _resumen(ListaUsuariosAdmin d) {
    String n(int c, String uno, String varios) => '$c ${c == 1 ? uno : varios}';
    return '${n(d.cuentas, 'cuenta', 'cuentas')} · '
        '${n(d.administradores, 'administrador', 'administradores')} · '
        '${n(d.suspendidas, 'suspendida', 'suspendidas')}';
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _cargar,
          child: PaginaAdmin(
            children: [
              EncabezadoAdmin(
                titulo: 'Usuarios',
                subtitulo: Text(d == null
                    ? 'Cuentas de clientes y administradores'
                    : _resumen(d)),
                acciones: [
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _cargando ? null : _cargar,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _filtros(),
              const SizedBox(height: 14),
              if (d == null && _error != null)
                ErrorAdmin(mensaje: _error!, onReintentar: _cargar)
              else if (d == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.secondary)),
                )
              else ...[
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 10),
                ],
                _tabla(d),
                const SizedBox(height: 14),
                const _Nota(),
              ],
            ],
          ),
        ),
        if (_cargando && d != null)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
                minHeight: 3, color: AppColors.secondary),
          ),
      ],
    );
  }

  Widget _filtros() {
    final buscador = TextField(
      controller: _busqueda,
      onChanged: _alEscribir,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _filtrar(() {}),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Nombre, usuario o correo',
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        suffixIcon: _busqueda.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _filtrar(_busqueda.clear),
              ),
      ),
    );

    final rol = SelectorAdmin<RolFiltro>(
      valor: _rol,
      opciones: {for (final r in RolFiltro.values) r: r.etiqueta},
      onChanged: (r) => _filtrar(() => _rol = r ?? RolFiltro.todos),
    );
    final estado = SelectorAdmin<EstadoCuentaFiltro>(
      valor: _estado,
      opciones: {for (final e in EstadoCuentaFiltro.values) e: e.etiqueta},
      onChanged: (e) =>
          _filtrar(() => _estado = e ?? EstadoCuentaFiltro.todos),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        return Column(children: [
          buscador,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: rol),
            const SizedBox(width: 10),
            Expanded(child: estado),
          ]),
        ]);
      }
      return Row(children: [
        Expanded(child: buscador),
        const SizedBox(width: 12),
        SizedBox(width: 200, child: rol),
        const SizedBox(width: 12),
        SizedBox(width: 200, child: estado),
      ]);
    });
  }

  Widget _tabla(ListaUsuariosAdmin d) {
    if (d.usuarios.isEmpty) {
      return TarjetaAdmin(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 40, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text(
                _hayFiltros
                    ? 'No hay cuentas con estos filtros.'
                    : 'Todavía no hay cuentas.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (_hayFiltros) ...[
                const SizedBox(height: 12),
                BotonSecundarioAdmin(
                  texto: 'Quitar filtros',
                  onPressed: () => _filtrar(() {
                    _rol = RolFiltro.todos;
                    _estado = EstadoCuentaFiltro.todos;
                    _busqueda.clear();
                  }),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final desde = (d.pagina - 1) * d.porPagina + 1;
    final hasta = desde + d.usuarios.length - 1;

    return TarjetaAdmin(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ancho) const _Cabecera(),
            for (final u in d.usuarios)
              _FilaUsuario(
                usuario: u,
                ancho: ancho,
                ocupado: _ocupados.contains(u.id),
                onAccion: (a) => _ejecutar(u, a),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBordeFilaAdmin)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Mostrando $desde–$hasta de ${d.total}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: d.pagina > 1 && !_cargando
                            ? () {
                                setState(() => _pagina = d.pagina - 1);
                                _cargar();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Anterior'),
                      ),
                      Text('${d.pagina} / ${d.paginas}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      TextButton.icon(
                        onPressed: d.pagina < d.paginas && !_cargando
                            ? () {
                                setState(() => _pagina = d.pagina + 1);
                                _cargar();
                              }
                            : null,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('Siguiente'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ───────────────────────── Piezas ─────────────────────────

/// "ago 2026"
String _mesAnio(DateTime d) => '${Formato.mesCorto(d).toLowerCase()} ${d.year}';

const _anchoRol = 130.0;
const _anchoReservas = 80.0;
const _anchoDesde = 120.0;
const _anchoEstado = 110.0;
const _anchoAcciones = 220.0;

class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textSecondary);
    return Container(
      color: kCabeceraAdmin,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('USUARIO', style: estilo)),
          SizedBox(width: _anchoRol, child: Text('ROL', style: estilo)),
          Expanded(flex: 4, child: Text('CORREO', style: estilo)),
          SizedBox(
              width: _anchoReservas,
              child: Text('RESERVAS',
                  style: estilo, textAlign: TextAlign.right)),
          SizedBox(width: 20),
          SizedBox(
              width: _anchoDesde,
              child: Text('MIEMBRO DESDE', style: estilo)),
          SizedBox(width: _anchoEstado, child: Text('ESTADO', style: estilo)),
          SizedBox(
              width: _anchoAcciones,
              child: Text('ACCIONES',
                  style: estilo, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  final UsuarioAdmin usuario;
  final bool ancho;
  final bool ocupado;
  final ValueChanged<_Accion> onAccion;

  const _FilaUsuario({
    required this.usuario,
    required this.ancho,
    required this.ocupado,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    const gris = TextStyle(fontSize: 12, color: AppColors.textSecondary);

    final identidad = Row(
      children: [
        _Avatar(usuario: u),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: u.nombre),
                  if (u.esYo)
                    const TextSpan(
                        text: ' (tú)',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              Text('@${u.usuario}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: gris),
            ],
          ),
        ),
      ],
    );
    final rol = _ChipRol(admin: u.esAdmin);
    final correo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(u.correo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.primary)),
        Text(u.verificado ? 'Verificado' : 'Sin verificar',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: u.verificado
                    ? AppColors.success
                    : const Color(0xFF8A4B00))),
      ],
    );
    final estado = _EstadoCuenta(activo: u.activo);
    final acciones = _Acciones(usuario: u, ocupado: ocupado, onAccion: onAccion);

    if (ancho) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBordeFilaAdmin)),
        ),
        child: Row(
          children: [
            Expanded(flex: 4, child: identidad),
            const SizedBox(width: 10),
            SizedBox(
                width: _anchoRol,
                child: Align(alignment: Alignment.centerLeft, child: rol)),
            Expanded(flex: 4, child: correo),
            SizedBox(
              width: _anchoReservas,
              child: Text('${u.reservas}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: _anchoDesde,
              child: Text(u.desde == null ? '—' : _mesAnio(u.desde!),
                  style: const TextStyle(color: AppColors.primary)),
            ),
            SizedBox(width: _anchoEstado, child: estado),
            SizedBox(
              width: _anchoAcciones,
              // Se achica si la fuente es más ancha, en vez de desbordarse.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: acciones,
              ),
            ),
          ],
        ),
      );
    }

    final reservas =
        '${u.reservas} ${u.reservas == 1 ? 'reserva activa' : 'reservas activas'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBordeFilaAdmin)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: identidad),
            const SizedBox(width: 8),
            rol,
          ]),
          const SizedBox(height: 10),
          correo,
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              estado,
              Text(reservas, style: gris),
              if (u.desde != null)
                Text('Desde ${_mesAnio(u.desde!)}', style: gris),
            ],
          ),
          Align(alignment: Alignment.centerRight, child: acciones),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UsuarioAdmin usuario;

  const _Avatar({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: usuario.esAdmin
            ? const Color(0xFFD9B8A0)
            : const Color(0xFFE8DCD2),
      ),
      child: Text(usuario.iniciales,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary)),
    );
  }
}

class _ChipRol extends StatelessWidget {
  final bool admin;

  const _ChipRol({required this.admin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: admin ? AppColors.primary : const Color(0xFFF5EDE6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(admin ? 'Administrador' : 'Cliente',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: admin ? Colors.white : AppColors.secondary)),
    );
  }
}

class _EstadoCuenta extends StatelessWidget {
  final bool activo;

  const _EstadoCuenta({required this.activo});

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.success : const Color(0xFFB71C1C);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(activo ? 'Activo' : 'Suspendido',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _Acciones extends StatelessWidget {
  final UsuarioAdmin usuario;
  final bool ocupado;
  final ValueChanged<_Accion> onAccion;

  const _Acciones({
    required this.usuario,
    required this.ocupado,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    // La propia cuenta no se puede suspender ni cambiar de rol.
    if (u.esYo) {
      return const Tooltip(
        message: 'No puedes cambiar tu propia cuenta',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text('—', style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    ButtonStyle estilo(Color color, FontWeight peso) => TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: TextStyle(fontSize: 13, fontWeight: peso),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: ocupado
              ? null
              : () => onAccion(
                  u.esAdmin ? _Accion.quitarAdmin : _Accion.hacerAdmin),
          style: estilo(AppColors.secondary, FontWeight.w700),
          child: Text(u.esAdmin ? 'Quitar admin' : 'Hacer admin'),
        ),
        TextButton(
          onPressed: ocupado
              ? null
              : () =>
                  onAccion(u.activo ? _Accion.suspender : _Accion.reactivar),
          style: estilo(u.activo ? AppColors.error : AppColors.success,
              FontWeight.w600),
          child: Text(u.activo ? 'Suspender' : 'Reactivar'),
        ),
      ],
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.textSecondary),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Suspender una cuenta cierra sus sesiones y le impide iniciar '
            'sesión; sus reservas no se borran. No puedes suspenderte ni '
            'quitarte el rol de administrador a ti mismo.',
            style: TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _DialogoConfirmar extends StatelessWidget {
  final UsuarioAdmin usuario;
  final _Accion accion;

  const _DialogoConfirmar({required this.usuario, required this.accion});

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    const negrita =
        TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary);
    final nombre = TextSpan(text: u.nombre, style: negrita);
    final reservas = u.reservas == 0
        ? 'No tiene reservas activas'
        : 'Sus ${u.reservas} ${u.reservas == 1 ? 'reserva activa se mantiene' : 'reservas activas se mantienen'}';

    final (titulo, cuerpo, boton, color) = switch (accion) {
      _Accion.hacerAdmin => (
          '¿Dar permisos de administrador?',
          <InlineSpan>[
            nombre,
            TextSpan(
                text: ' (@${u.usuario}) podrá entrar a este panel y '
                    'gestionar vuelos, reservas y usuarios. Se cerrarán sus '
                    'sesiones abiertas para que entre de nuevo con el rol nuevo.'),
          ],
          'Hacer admin',
          AppColors.primary,
        ),
      _Accion.quitarAdmin => (
          '¿Quitar el rol de administrador?',
          <InlineSpan>[
            nombre,
            TextSpan(
                text: ' (@${u.usuario}) volverá a ser cliente y ya no podrá '
                    'entrar a este panel. Se cerrarán sus sesiones abiertas.'),
          ],
          'Quitar admin',
          AppColors.error,
        ),
      _Accion.suspender => (
          '¿Suspender esta cuenta?',
          <InlineSpan>[
            nombre,
            TextSpan(
                text: ' (@${u.usuario}) no podrá iniciar sesión hasta que la '
                    'reactives y se cerrarán sus sesiones abiertas. '
                    '$reservas y los asientos de su carrito quedarán libres.'),
          ],
          'Suspender',
          AppColors.error,
        ),
      _Accion.reactivar => (
          '¿Reactivar esta cuenta?',
          <InlineSpan>[
            nombre,
            TextSpan(
                text: ' (@${u.usuario}) podrá volver a iniciar sesión con su '
                    'usuario y contraseña.'),
          ],
          'Reactivar',
          AppColors.success,
        ),
    };

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(children: cuerpo),
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  BotonSecundarioAdmin(
                      texto: 'Volver',
                      onPressed: () => Navigator.pop(context, false)),
                  BotonAdmin(
                    texto: boton,
                    color: color,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
