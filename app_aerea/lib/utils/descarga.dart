// Descarga de archivos. En web usa el navegador; en otras plataformas
// todavía no está disponible (la app por ahora es solo web).
export 'descarga_stub.dart' if (dart.library.js_interop) 'descarga_web.dart';
