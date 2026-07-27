import 'package:intl/intl.dart';

/// Suma meses cuidando los meses cortos: si la fecha cae 31 y el mes destino
/// no lo tiene, se va al último día de ese mes (31 ene + 1 mes = 28 feb).
DateTime addMonths(DateTime from, int months) {
  final total = from.month - 1 + months;
  final year = from.year + (total ~/ 12);
  final month = total % 12 + 1;
  final ultimoDia = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, from.day > ultimoDia ? ultimoDia : from.day);
}

/// Primer día del mes siguiente: el arranque por defecto de un crédito nuevo.
DateTime nextMonthStart([DateTime? now]) {
  final hoy = now ?? DateTime.now();
  return DateTime(hoy.year, hoy.month + 1, 1);
}

final _corta = DateFormat('MMM yy', 'es_CO');
final _larga = DateFormat('MMMM yyyy', 'es_CO');

/// "ago 26", para la columna de la tabla.
String shortMonth(DateTime d) => _corta.format(d).replaceAll('.', '');

/// "5 ago 2026", para el resumen del crédito.
String fullDate(DateTime d) => DateFormat.yMMMd('es_CO').format(d);

/// "agosto 2026", para las tarjetas.
String longMonth(DateTime d) {
  final s = _larga.format(d);
  return s[0].toUpperCase() + s.substring(1);
}
