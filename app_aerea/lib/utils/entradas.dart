import 'package:flutter/services.dart';

/// Reglas de lo que se puede escribir (o pegar) en los campos de texto.
///
/// Los caracteres que no cumplen la regla simplemente no aparecen.
class Entradas {
  Entradas._();

  /// Largo máximo de los buscadores.
  static const largoBusqueda = 50;

  /// Letras (con tildes, ñ y ü), números, espacio y los signos que aparecen
  /// en ciudades, aerolíneas y números de vuelo: "#41", "Sto. Domingo",
  /// "Ñandú-Air". Deja fuera emojis y símbolos como < > % _ @.
  static final _caracterBusquedaVuelos =
      RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 #.\-]');

  /// Espacios al inicio y espacios repetidos ("Quito  " → "Quito ").
  static final _espaciosDeMas = RegExp(r'^ +|(?<= ) ');

  /// Buscador de la sección Vuelos del administrador.
  static List<TextInputFormatter> get busquedaVuelos => [
        FilteringTextInputFormatter.allow(_caracterBusquedaVuelos),
        FilteringTextInputFormatter.deny(_espaciosDeMas),
        LengthLimitingTextInputFormatter(largoBusqueda),
      ];
}
