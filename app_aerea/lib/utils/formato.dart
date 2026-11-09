/// Utilidades de formato en español (sin depender del paquete intl).
class Formato {
  Formato._();

  static const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _diasLargos = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];
  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre'
  ];
  static const _mesesCortos = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic'
  ];

  /// "dom"
  static String diaCorto(DateTime d) => _diasCortos[d.weekday - 1];

  /// "8 nov"
  static String fechaCorta(DateTime d) =>
      '${d.day} ${_mesesCortos[d.month - 1]}';

  /// "dom 8 nov"
  static String fechaConDia(DateTime d) => '${diaCorto(d)} ${fechaCorta(d)}';

  /// "Jueves 12 de noviembre"
  static String fechaLarga(DateTime d) =>
      '${_diasLargos[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

  /// "Noviembre 2026"
  static String mesAnio(DateTime d) {
    final m = _meses[d.month - 1];
    return '${m[0].toUpperCase()}${m.substring(1)} ${d.year}';
  }

  /// "2026-11-08" (formato que espera el backend)
  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "$85.00"
  static String dinero(double v) => '\$${v.toStringAsFixed(2)}';

  /// "45 min", "1 h", "1 h 20 min"
  static String duracion(int minutos) {
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// La fecha sin la hora (medianoche local).
  static DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Suma días sin problemas de horario de verano.
  static DateTime sumarDias(DateTime d, int dias) =>
      DateTime(d.year, d.month, d.day + dias);
}
