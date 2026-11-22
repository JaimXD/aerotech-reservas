import 'package:flutter/services.dart';

/// Reglas de lo que se puede escribir (o pegar) en los campos de texto.
///
/// Los caracteres que no cumplen la regla simplemente no aparecen.
class Entradas {
  Entradas._();

  /// Largo máximo de los buscadores.
  static const largoBusqueda = 50;

  /// Largo máximo de aerolíneas y ciudades.
  static const largoNombre = 40;

  /// Precio máximo de un asiento (igual que en el backend).
  static const precioMaximo = 10000;

  static const _letras = 'A-Za-zÁÉÍÓÚÜÑáéíóúüñ';

  /// Letras (con tildes, ñ y ü), números, espacio y los signos que aparecen
  /// en ciudades, aerolíneas y números de vuelo: "#41", "Sto. Domingo",
  /// "Ñandú-Air". Deja fuera emojis y símbolos como < > % _ @.
  static final _caracterBusquedaVuelos = RegExp('[${_letras}0-9 #.\\-]');

  /// Reservas: código ("RES-2026…-2"), nombre del cliente, usuario
  /// ("ana.torres_1") o correo ("ana+viajes@correo.com").
  static final _caracterBusquedaReservas = RegExp('[${_letras}0-9 @._+\\-]');

  /// Ciudades: letras, espacio y . - ' ("Sto. Domingo", "Lago-Agrio").
  static final _caracterCiudad = RegExp("[$_letras .'\\-]");

  /// Aerolíneas: como las ciudades, más números y & ("Air 2000", "Sky & Sea").
  static final _caracterAerolinea = RegExp("[${_letras}0-9 .&'\\-]");

  /// Espacios al inicio y espacios repetidos ("Quito  " → "Quito ").
  static final _espaciosDeMas = RegExp(r'^ +|(?<= ) ');

  /// Un nombre no empieza con espacio ni con signo.
  static final _inicioNombre = RegExp(r"^[ .&'\-]+|(?<= ) ");

  static final _unaLetra = RegExp('[$_letras]');

  /// Cuántas letras tiene [texto] (para pedir al menos 2 en un nombre).
  static int letras(String texto) => _unaLetra.allMatches(texto).length;

  /// Buscador de la sección Vuelos del administrador.
  static List<TextInputFormatter> get busquedaVuelos => [
        FilteringTextInputFormatter.allow(_caracterBusquedaVuelos),
        FilteringTextInputFormatter.deny(_espaciosDeMas),
        LengthLimitingTextInputFormatter(largoBusqueda),
      ];

  /// Buscador de la sección Reservas del administrador.
  static List<TextInputFormatter> get busquedaReservas => [
        FilteringTextInputFormatter.allow(_caracterBusquedaReservas),
        FilteringTextInputFormatter.deny(_espaciosDeMas),
        LengthLimitingTextInputFormatter(largoBusqueda),
      ];

  /// Buscador de la sección Usuarios del administrador: nombre, usuario o
  /// correo, con los mismos caracteres que el de Reservas.
  static List<TextInputFormatter> get busquedaUsuarios => busquedaReservas;

  /// Origen y destino de un vuelo.
  static List<TextInputFormatter> get ciudad => [
        FilteringTextInputFormatter.allow(_caracterCiudad),
        FilteringTextInputFormatter.deny(_inicioNombre),
        LengthLimitingTextInputFormatter(largoNombre),
      ];

  /// Nombre de la aerolínea.
  static List<TextInputFormatter> get aerolinea => [
        FilteringTextInputFormatter.allow(_caracterAerolinea),
        FilteringTextInputFormatter.deny(_inicioNombre),
        LengthLimitingTextInputFormatter(largoNombre),
      ];

  /// Precio en dólares: hasta 2 decimales y como máximo [precioMaximo].
  static List<TextInputFormatter> get precio => [_FormatoPrecio()];

  /// Filas de la cabina: solo números, sin 0 inicial y como máximo [maximo].
  static List<TextInputFormatter> filas(int maximo) => [
        FilteringTextInputFormatter.digitsOnly,
        _FormatoFilas(maximo),
      ];

  /// No deja escribir un nombre igual a [otro] (sin contar tildes ni
  /// mayúsculas). Así el destino no puede ser el mismo que el origen.
  static TextInputFormatter distintoDe(String Function() otro) =>
      _DistintoDe(otro);

  static const _sinTilde = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'
  };

  /// Texto para comparar nombres: "  Quíto " → "quito".
  static String clave(String texto) => texto
      .toLowerCase()
      .split('')
      .map((c) => _sinTilde[c] ?? c)
      .join()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .join(' ');
}

class _FormatoFilas extends TextInputFormatter {
  final int maximo;

  _FormatoFilas(this.maximo);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    final texto = nuevo.text;
    if (texto.isEmpty) return nuevo;
    if (texto.startsWith('0') || int.parse(texto) > maximo) return anterior;
    return nuevo;
  }
}

class _DistintoDe extends TextInputFormatter {
  final String Function() otro;

  _DistintoDe(this.otro);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    final clave = Entradas.clave(nuevo.text);
    return clave.isNotEmpty && clave == Entradas.clave(otro())
        ? anterior
        : nuevo;
  }
}

/// Solo deja escribir un precio válido: "85", "85.5", "85.50", "0.99".
/// La coma se cambia por punto. Si el cambio no es válido, no se aplica.
class _FormatoPrecio extends TextInputFormatter {
  static final _forma = RegExp(r'^(0|[1-9]\d{0,4})(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue nuevo) {
    final texto = nuevo.text.replaceAll(',', '.');
    if (texto.isEmpty) return nuevo;
    if (!_forma.hasMatch(texto)) return anterior;
    final valor = double.parse(texto.endsWith('.') ? '${texto}0' : texto);
    if (valor > Entradas.precioMaximo) return anterior;
    return nuevo.copyWith(text: texto);
  }
}
