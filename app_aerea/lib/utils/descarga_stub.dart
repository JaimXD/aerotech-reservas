/// Versión para plataformas que no son web.
void descargarArchivo(String nombre, String contenido,
    {String tipo = 'application/xml'}) {
  throw UnsupportedError(
      'La descarga de archivos solo está disponible en web.');
}
