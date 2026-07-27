import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/saved_loan.dart';
import 'amortization.dart';
import 'dates.dart';
import 'rates.dart';

/// Arma el .xlsx del crédito: resumen, tabla de amortización y abonos, todo
/// en el mismo archivo. Los montos van como número (no como texto) para poder
/// sumarlos y graficarlos en Excel.
Uint8List buildLoanWorkbook(SavedLoan loan) {
  final excel = Excel.createExcel();
  final resumen = excel['Resumen'];
  final tabla = excel['Amortización'];
  final abonos = excel['Abonos'];
  excel.delete('Sheet1');

  _resumen(resumen, loan);
  _amortizacion(tabla, loan);
  _abonos(abonos, loan);

  excel.setDefaultSheet('Resumen');
  return Uint8List.fromList(excel.encode() ?? const []);
}

/// Nombre de archivo sin caracteres raros: "Casa" → "Casa-amortizacion.xlsx".
String workbookFileName(SavedLoan loan) {
  final limpio = loan.name
      .trim()
      .replaceAll(RegExp(r'[^\w\sáéíóúñÁÉÍÓÚÑ-]'), '')
      .replaceAll(RegExp(r'\s+'), '-');
  return '${limpio.isEmpty ? 'prestamo' : limpio}-amortizacion.xlsx';
}

void _titulo(Sheet hoja, String texto) {
  hoja.appendRow([TextCellValue(texto)]);
  final fila = hoja.maxRows - 1;
  hoja
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: fila))
      .cellStyle = CellStyle(
    bold: true,
    fontSize: 13,
  );
}

void _fila(Sheet hoja, String etiqueta, CellValue valor) {
  hoja.appendRow([TextCellValue(etiqueta), valor]);
}

void _encabezados(Sheet hoja, List<String> columnas) {
  hoja.appendRow(columnas.map(TextCellValue.new).toList());
  final fila = hoja.maxRows - 1;
  for (var c = 0; c < columnas.length; c++) {
    hoja
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: fila))
        .cellStyle = CellStyle(
      bold: true,
    );
  }
}

void _resumen(Sheet hoja, SavedLoan loan) {
  final r = loan.result;
  final ea = monthlyToEffectiveAnnual(loan.monthlyRate) * 100;

  _titulo(hoja, loan.name);
  _fila(hoja, 'Moneda', TextCellValue(loan.currencyCode));
  _fila(
    hoja,
    'Tipo',
    TextCellValue(loan.kind == LoanKind.hipoteca ? 'Hipotecario' : 'Préstamo'),
  );
  if (loan.propertyValue != null) {
    _fila(hoja, 'Valor del inmueble', DoubleCellValue(loan.propertyValue!));
  }
  if (loan.downPayment != null) {
    _fila(hoja, 'Cuota inicial', DoubleCellValue(loan.downPayment!));
  }
  _fila(hoja, 'Monto prestado', DoubleCellValue(loan.amount));
  _fila(
    hoja,
    'Tasa',
    TextCellValue(
      '${loan.ratePercent.toStringAsFixed(2)}% ${loan.rateType.label}',
    ),
  );
  _fila(hoja, 'Equivale a (E.A.)', DoubleCellValue(ea / 100));
  _fila(hoja, 'Tasa mensual', DoubleCellValue(loan.monthlyRate));
  _fila(hoja, 'Sistema', TextCellValue(loan.system.label));
  if (loan.uvr != null) {
    _fila(hoja, 'Denominación', TextCellValue('UVR'));
    _fila(hoja, 'UVR hoy', DoubleCellValue(loan.uvr!.uvrToday));
    _fila(
      hoja,
      'Inflación proyectada',
      DoubleCellValue(loan.uvr!.annualInflation),
    );
  }
  _fila(hoja, 'Plazo pactado (meses)', IntCellValue(loan.months));
  _fila(hoja, 'Plazo con abonos (meses)', IntCellValue(r.months));
  _fila(hoja, 'Primera cuota', TextCellValue(fullDate(loan.firstPayment)));
  _fila(hoja, 'Última cuota', TextCellValue(fullDate(loan.dateOf(r.months))));

  hoja.appendRow([]);
  _titulo(hoja, 'Avance');
  _fila(hoja, 'Cuotas pagadas', IntCellValue(loan.paidMonths));
  _fila(hoja, 'Cuotas por pagar', IntCellValue(r.months - loan.paidMonths));
  _fila(hoja, '% pagado', DoubleCellValue(loan.progress));
  _fila(hoja, 'Pagado hasta hoy', DoubleCellValue(loan.paidSoFar));
  _fila(hoja, '  De eso, a capital', DoubleCellValue(loan.paidPrincipal));
  _fila(hoja, '  De eso, a intereses', DoubleCellValue(loan.paidInterest));
  _fila(hoja, 'Saldo pendiente', DoubleCellValue(loan.remainingBalance));
  _fila(hoja, 'Falta por pagar', DoubleCellValue(loan.remainingToPay));

  hoja.appendRow([]);
  _titulo(hoja, 'Totales del crédito');
  _fila(hoja, 'Total intereses', DoubleCellValue(r.totalInterest));
  _fila(hoja, 'Total abonos a capital', DoubleCellValue(r.totalExtra));
  _fila(hoja, 'Total a pagar', DoubleCellValue(r.totalPaid));

  final savings = loan.savings;
  if (savings != null) {
    hoja.appendRow([]);
    _titulo(hoja, 'Gracias a los abonos');
    _fila(hoja, 'Interés ahorrado', DoubleCellValue(savings.interesAhorrado));
    _fila(hoja, 'Meses ahorrados', IntCellValue(savings.mesesAhorrados));
    _fila(
      hoja,
      'Intereses sin abonar',
      DoubleCellValue(savings.sinAbonos.totalInterest),
    );
  }

  hoja.setColumnWidth(0, 26);
  hoja.setColumnWidth(1, 20);
}

void _amortizacion(Sheet hoja, SavedLoan loan) {
  _encabezados(hoja, [
    '#',
    'Fecha',
    'Estado',
    'Cuota',
    'Interés',
    'Capital',
    'Abono',
    'Saldo',
  ]);

  for (final row in loan.result.schedule) {
    hoja.appendRow([
      IntCellValue(row.number),
      TextCellValue(fullDate(loan.dateOf(row.number))),
      TextCellValue(row.number <= loan.paidMonths ? 'Pagada' : 'Pendiente'),
      DoubleCellValue(row.payment),
      DoubleCellValue(row.interest),
      DoubleCellValue(row.principal),
      DoubleCellValue(row.extra),
      DoubleCellValue(row.balance),
    ]);
  }

  hoja.setColumnWidth(0, 6);
  hoja.setColumnWidth(1, 16);
  hoja.setColumnWidth(2, 12);
  for (var c = 3; c <= 7; c++) {
    hoja.setColumnWidth(c, 16);
  }
}

void _abonos(Sheet hoja, SavedLoan loan) {
  _encabezados(hoja, [
    '#',
    'Monto',
    'Cuota',
    'Fecha',
    'Frecuencia',
    'Efecto',
    'Estado',
  ]);

  if (loan.extras.isEmpty) {
    hoja.appendRow([TextCellValue('Sin abonos registrados')]);
  }

  for (var i = 0; i < loan.extras.length; i++) {
    final abono = loan.extras[i];
    hoja.appendRow([
      IntCellValue(i + 1),
      DoubleCellValue(abono.amount),
      IntCellValue(abono.startMonth),
      TextCellValue(fullDate(loan.dateOf(abono.startMonth))),
      TextCellValue(
        abono.recurring ? 'Todos los meses desde esa cuota' : 'Una sola vez',
      ),
      TextCellValue(abono.effect.label),
      TextCellValue(
        abono.startMonth <= loan.paidMonths ? 'Aplicado' : 'Programado',
      ),
    ]);
  }

  hoja.appendRow([]);
  _fila(
    hoja,
    'Total abonado (proyectado)',
    DoubleCellValue(loan.result.totalExtra),
  );

  hoja.setColumnWidth(0, 6);
  hoja.setColumnWidth(1, 16);
  hoja.setColumnWidth(2, 8);
  hoja.setColumnWidth(3, 16);
  hoja.setColumnWidth(4, 30);
  hoja.setColumnWidth(5, 16);
  hoja.setColumnWidth(6, 12);
}
