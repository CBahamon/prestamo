import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestamo/core/amortization.dart';
import 'package:prestamo/core/excel_export.dart';
import 'package:prestamo/core/rates.dart';
import 'package:prestamo/models/saved_loan.dart';

SavedLoan _prestamo({
  int paidCount = 0,
  List<ExtraPayment> extras = const [],
  String name = 'Casa',
}) => SavedLoan(
  id: 'x',
  name: name,
  kind: LoanKind.hipoteca,
  amount: 184000000,
  ratePercent: 12,
  rateType: RateType.efectivaAnual,
  months: 240,
  currencyCode: 'COP',
  createdAt: DateTime(2026, 7, 25),
  propertyValue: 230000000,
  downPayment: 46000000,
  firstPaymentDate: DateTime(2026, 8, 1),
  paidCount: paidCount,
  extras: extras,
);

/// Excel guarda 5.000.000,0 como entero al releerlo: da igual el tipo, lo que
/// importa es el número.
num _num(CellValue? v) => switch (v) {
  IntCellValue(:final value) => value,
  DoubleCellValue(:final value) => value,
  _ => throw StateError('no es un número: $v'),
};

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  test('el archivo trae las tres hojas', () {
    final excel = Excel.decodeBytes(buildLoanWorkbook(_prestamo()));
    expect(
      excel.tables.keys,
      containsAll(['Resumen', 'Amortización', 'Abonos']),
    );
    expect(excel.tables.keys, isNot(contains('Sheet1')));
  });

  test('la amortización trae una fila por cuota, con estado y fecha', () {
    final loan = _prestamo(paidCount: 3);
    final excel = Excel.decodeBytes(buildLoanWorkbook(loan));
    final hoja = excel.tables['Amortización']!;

    // Encabezado + 240 cuotas.
    expect(hoja.maxRows, 241);

    final primera = hoja.rows[1];
    expect((primera[0]!.value as IntCellValue).value, 1);
    expect((primera[2]!.value as TextCellValue).value.text, 'Pagada');
    expect(
      _num(primera[3]!.value),
      closeTo(loan.result.schedule.first.payment, 0.01),
    );
    expect((primera[1]!.value as TextCellValue).value.text, contains('2026'));

    // La cuarta ya está pendiente.
    expect((hoja.rows[4][2]!.value as TextCellValue).value.text, 'Pendiente');
  });

  test('los abonos salen listados con su estado', () {
    final loan = _prestamo(
      paidCount: 3,
      extras: const [
        ExtraPayment(
          amount: 5000000,
          effect: ExtraEffect.reducirPlazo,
          startMonth: 2,
          recurring: false,
        ),
        ExtraPayment(
          amount: 1000000,
          effect: ExtraEffect.reducirCuota,
          startMonth: 24,
          recurring: true,
        ),
      ],
    );
    final hoja = Excel.decodeBytes(buildLoanWorkbook(loan)).tables['Abonos']!;

    expect(_num(hoja.rows[1][1]!.value), 5000000);
    expect((hoja.rows[1][6]!.value as TextCellValue).value.text, 'Aplicado');
    expect(_num(hoja.rows[2][1]!.value), 1000000);
    expect((hoja.rows[2][6]!.value as TextCellValue).value.text, 'Programado');
  });

  test('sin abonos la hoja lo dice en vez de quedar vacía', () {
    final hoja = Excel.decodeBytes(
      buildLoanWorkbook(_prestamo()),
    ).tables['Abonos']!;
    expect(
      (hoja.rows[1][0]!.value as TextCellValue).value.text,
      'Sin abonos registrados',
    );
  });

  test('el resumen lleva el avance del crédito', () {
    final loan = _prestamo(paidCount: 12);
    final hoja = Excel.decodeBytes(buildLoanWorkbook(loan)).tables['Resumen']!;

    final textos = <String, CellValue?>{};
    for (final fila in hoja.rows) {
      final etiqueta = fila.isEmpty ? null : fila[0]?.value;
      if (etiqueta is TextCellValue && fila.length > 1) {
        textos[etiqueta.value.text ?? ''] = fila[1]?.value;
      }
    }

    expect(_num(textos['Cuotas pagadas']), 12);
    expect(
      _num(textos['Saldo pendiente']),
      closeTo(loan.remainingBalance, 0.01),
    );
    expect(
      _num(textos['  De eso, a intereses']),
      closeTo(loan.paidInterest, 0.01),
    );
  });

  test('el nombre del archivo sale limpio', () {
    expect(workbookFileName(_prestamo(name: 'Casa')), 'Casa-amortizacion.xlsx');
    expect(
      workbookFileName(_prestamo(name: 'Crédito / Casa #2')),
      'Crédito-Casa-2-amortizacion.xlsx',
    );
  });
}
