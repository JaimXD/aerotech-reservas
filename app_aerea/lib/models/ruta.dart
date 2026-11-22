/// Par origen → destino que tiene al menos un vuelo disponible.
class Ruta {
  final String origen;
  final String destino;

  const Ruta({required this.origen, required this.destino});

  factory Ruta.fromJson(Map<String, dynamic> json) => Ruta(
        origen: json['origen'],
        destino: json['destino'],
      );
}
