import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Descarga [contenido] como un archivo llamado [nombre] desde el navegador.
void descargarArchivo(String nombre, String contenido,
    {String tipo = 'application/xml'}) {
  final blob = web.Blob(
    [contenido.toJS].toJS,
    web.BlobPropertyBag(type: '$tipo;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);

  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre;
  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();

  web.URL.revokeObjectURL(url);
}
