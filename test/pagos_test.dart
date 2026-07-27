import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestamo/core/amortization.dart';
import 'package:prestamo/core/rates.dart';
import 'package:prestamo/main.dart';
import 'package:prestamo/models/saved_loan.dart';
import 'package:prestamo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedLoan _prestamo({int paidCount = 0, ExtraPayment? extra}) => SavedLoan(
  id: 'test-1',
  name: 'Carro',
  kind: LoanKind.prestamo,
  amount: 50000000,
  ratePercent: 18,
  rateType: RateType.efectivaAnual,
  months: 60,
  currencyCode: 'COP',
  createdAt: DateTime(2026, 1, 15),
  paidCount: paidCount,
  extra: extra,
);

void main() {
  group('cuotas pagadas', () {
    test('sin pagos el saldo pendiente es el monto completo', () {
      final l = _prestamo();
      expect(l.paidMonths, 0);
      expect(l.progress, 0);
      expect(l.remainingBalance, 50000000);
      expect(l.paidSoFar, 0);
      expect(l.isPaidOff, isFalse);
      expect(l.nextRow!.number, 1);
    });

    test('el saldo pendiente es el de la última cuota pagada', () {
      final l = _prestamo(paidCount: 12);
      expect(l.paidMonths, 12);
      expect(l.progress, closeTo(12 / 60, 1e-9));
      expect(l.remainingBalance, l.result.schedule[11].balance);
      expect(l.remainingBalance, lessThan(50000000));
      expect(l.nextRow!.number, 13);
    });

    test('lo pagado más lo pendiente da el total del crédito', () {
      final l = _prestamo(paidCount: 20);
      expect(l.paidSoFar + l.remainingToPay, closeTo(l.result.totalPaid, 1));
    });

    test('pagadas todas las cuotas queda saldado', () {
      final l = _prestamo(paidCount: 60);
      expect(l.isPaidOff, isTrue);
      expect(l.progress, 1);
      expect(l.remainingBalance, 0);
      expect(l.nextRow, isNull);
      expect(l.paidSoFar, closeTo(l.result.totalPaid, 1));
    });

    test('un abono que acorta el plazo recorta también las pagadas', () {
      // 40 chuleadas sobre un crédito que con abonos dura menos de 40 meses:
      // el avance no puede pasarse del plazo real.
      final l = _prestamo(
        paidCount: 40,
        extra: const ExtraPayment(
          amount: 2000000,
          effect: ExtraEffect.reducirPlazo,
        ),
      );
      expect(l.result.months, lessThan(40));
      expect(l.paidMonths, l.result.months);
      expect(l.isPaidOff, isTrue);
      expect(l.progress, 1);
    });

    test('paidCount sobrevive el viaje a JSON', () {
      final json = _prestamo(paidCount: 7).toJson();
      expect(SavedLoan.fromJson(json).paidCount, 7);
    });

    test('un préstamo guardado con la versión vieja abre en cero', () {
      final json = _prestamo(paidCount: 7).toJson()..remove('paidCount');
      expect(SavedLoan.fromJson(json).paidCount, 0);
    });
  });

  group('estado', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'currency_v1': 'COP',
        'loans_v1': jsonEncode([_prestamo().toJson()]),
      });
      await AppState.instance.init();
    });

    test('setPaidCount persiste y se acota al plazo', () async {
      final app = AppState.instance;
      await app.setPaidCount(app.loans.single, 5);
      expect(app.loans.single.paidCount, 5);

      await app.setPaidCount(app.loans.single, 999);
      expect(app.loans.single.paidCount, 60);

      await app.setPaidCount(app.loans.single, -3);
      expect(app.loans.single.paidCount, 0);
    });

    test('la deuda total del inicio es el saldo vivo, no el monto', () async {
      final app = AppState.instance;
      final original = app.totalDebt;
      await app.setPaidCount(app.loans.single, 24);
      expect(app.totalDebt, lessThan(original));
      expect(app.totalDebt, app.loans.single.remainingBalance);
    });

    test('un crédito saldado deja de sumar a las cuotas del mes', () async {
      final app = AppState.instance;
      expect(app.totalMonthlyPayments, greaterThan(0));
      await app.setPaidCount(app.loans.single, 60);
      expect(app.totalMonthlyPayments, 0);
    });
  });

  testWidgets('chulear una cuota en la tabla guarda el avance', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'currency_v1': 'COP',
      'loans_v1': jsonEncode([_prestamo().toJson()]),
    });
    await initializeDateFormatting('es_CO');
    await AppState.instance.init();

    await tester.pumpWidget(const PrestamoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Préstamos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carro'));
    await tester.pumpAndSettle();

    // La tarjeta de avance arranca en cero.
    expect(find.text('0 / 60 cuotas'), findsOneWidget);

    // Registrar la cuota del mes desde el detalle.
    await tester.ensureVisible(find.textContaining('Pagué la cuota 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pagué la cuota 1'));
    await tester.pumpAndSettle();

    expect(AppState.instance.loans.single.paidCount, 1);
    expect(find.text('1 / 60 cuotas'), findsOneWidget);
    expect(find.textContaining('Pagué la cuota 2'), findsOneWidget);

    // En la tabla, tocar la cuota 3 marca también la 2.
    await tester.ensureVisible(find.text('Ver tabla de amortización'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver tabla de amortización'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 de 60 cuotas pagadas'), findsOneWidget);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(AppState.instance.loans.single.paidCount, 3);
    expect(find.textContaining('3 de 60 cuotas pagadas'), findsOneWidget);
    expect(find.text('5% pagado'), findsOneWidget);

    // Volver a tocar una cuota pagada la devuelve a pendiente.
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(AppState.instance.loans.single.paidCount, 4);

    // El número sigue a la vista aunque la cuota ya esté chuleada.
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(AppState.instance.loans.single.paidCount, 3);
  });
}
