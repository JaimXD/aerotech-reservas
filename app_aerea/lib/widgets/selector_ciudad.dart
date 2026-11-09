import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

/// Una ciudad que se puede elegir en el selector.
class OpcionCiudad {
  final String nombre;
  final String? detalle; // texto pequeño debajo, p. ej. "3 destinos"

  const OpcionCiudad(this.nombre, {this.detalle});
}

/// Campo del buscador que abre una lista desplegable con buscador
/// (estilo Google Flights / Skyscanner). Solo deja elegir ciudades de la lista.
class SelectorCiudad extends StatefulWidget {
  final String etiqueta;
  final IconData icono;
  final String? valor;
  final List<OpcionCiudad> opciones;
  final ValueChanged<String> onElegir;
  final String textoVacio;
  final String mensajeSinOpciones;
  final bool cargando;

  const SelectorCiudad({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.valor,
    required this.opciones,
    required this.onElegir,
    this.textoVacio = 'Elige una ciudad',
    this.mensajeSinOpciones = 'No hay ciudades disponibles',
    this.cargando = false,
  });

  @override
  State<SelectorCiudad> createState() => _SelectorCiudadState();
}

class _SelectorCiudadState extends State<SelectorCiudad> {
  final _panel = OverlayPortalController();
  final _enlace = LayerLink();
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  double _anchoCampo = 300;

  @override
  void dispose() {
    _busqueda.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _abrir() {
    _busqueda.clear();
    setState(() => _panel.show());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focoBusqueda.requestFocus());
  }

  void _cerrar() {
    if (_panel.isShowing) setState(() => _panel.hide());
  }

  void _elegir(String ciudad) {
    widget.onElegir(ciudad);
    _cerrar();
  }

  /// Minúsculas y sin tildes: "Galápagos" → "galapagos".
  static String _normalizar(String s) {
    const con = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sin = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = con.indexOf(ch);
      b.write(i >= 0 ? sin[i] : ch);
    }
    return b.toString().trim();
  }

  List<OpcionCiudad> get _filtradas {
    final q = _normalizar(_busqueda.text);
    if (q.isEmpty) return widget.opciones;
    return widget.opciones
        .where((o) => _normalizar(o.nombre).contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final abierto = _panel.isShowing;
    final sinValor = widget.valor == null;

    return OverlayPortal(
      controller: _panel,
      overlayChildBuilder: _construirPanel,
      child: CompositedTransformTarget(
        link: _enlace,
        child: LayoutBuilder(
          builder: (context, c) {
            _anchoCampo = c.maxWidth;
            return Material(
              color: abierto ? const Color(0xFFF7F2EC) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: widget.cargando ? null : _abrir,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(widget.icono, color: AppColors.secondary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.etiqueta,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.cargando
                                  ? 'Cargando…'
                                  : (widget.valor ?? widget.textoVacio),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: sinValor
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        abierto ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _construirPanel(BuildContext context) {
    final filtradas = _filtradas;

    return Stack(
      children: [
        // Clic fuera del panel = cerrar
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cerrar,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _enlace,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 8),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _cerrar
              },
              child: SizedBox(
                width: math.max(_anchoCampo, 320),
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _busqueda,
                          focusNode: _focoBusqueda,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (filtradas.isNotEmpty)
                              _elegir(filtradas.first.nombre);
                          },
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.primary),
                          decoration: InputDecoration(
                            hintText: 'Buscar ciudad',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.secondary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: filtradas.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  widget.opciones.isEmpty
                                      ? widget.mensajeSinOpciones
                                      : 'No encontramos "${_busqueda.text.trim()}"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                itemCount: filtradas.length,
                                itemBuilder: (context, i) {
                                  final o = filtradas[i];
                                  final elegida = o.nombre == widget.valor;
                                  return ListTile(
                                    dense: true,
                                    selected: elegida,
                                    selectedTileColor: const Color(0xFFF7EFE8),
                                    leading: Icon(
                                      Icons.location_city_outlined,
                                      color: elegida
                                          ? AppColors.secondary
                                          : AppColors.textSecondary,
                                    ),
                                    title: Text(
                                      o.nombre,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: elegida
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    subtitle: o.detalle == null
                                        ? null
                                        : Text(
                                            o.detalle!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                    trailing: elegida
                                        ? const Icon(Icons.check,
                                            color: AppColors.success)
                                        : null,
                                    onTap: () => _elegir(o.nombre),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
