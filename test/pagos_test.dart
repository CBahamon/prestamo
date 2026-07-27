import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestamo/core/amortization.dart';
import 'package:prestamo/core/dates.dart';
import 'package:prestamo/core/rates.dart';
import 'package:prestamo/main.dart';
import 'package:prestamo/models/saved_loan.dart';
import 'package:prestamo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedLoan _prestamo({
  int paidCount = 0,
  List<ExtraPayment> extras = const [],
  DateTime? first,
}) => SavedLoan(
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
  extras: extras,
  firstPaymentDate: first,
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
        extras: [const ExtraPayment(
          amount: 2000000,
          effect: ExtraEffect.reducirPlazo,
        )],
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

  group('fechas de las cuotas', () {
    test('sin fecha guardada arranca el mes siguiente a la creación', () {
      final l = _prestamo();
      expect(l.firstPayment, DateTime(2026, 2, 1));
      expect(l.dateOf(1), DateTime(2026, 2, 1));
      expect(l.dateOf(12), DateTime(2027, 1, 1));
      expect(l.dateOf(60), DateTime(2031, 1, 1));
    });

    test('respeta la fecha que puso el usuario', () {
      final l = _prestamo(first: DateTime(2026, 8, 5));
      expect(l.dateOf(1), DateTime(2026, 8, 5));
      expect(l.dateOf(6), DateTime(2027, 1, 5));
    });

    test('el día 31 cae al último día de los meses cortos', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
    });

    test('la fecha sobrevive el viaje a JSON', () {
      final json = _prestamo(first: DateTime(2026, 8, 5)).toJson();
      expect(SavedLoan.fromJson(json).firstPaymentDate, DateTime(2026, 8, 5));
    });
  });

  group('capital e interés pagados', () {
    test('suman lo que va pagado', () {
      final l = _prestamo(paidCount: 10);
      expect(l.paidPrincipal + l.paidInterest, closeTo(l.paidSoFar, 1));
    });

    test('al principio pesa más el interés que el capital', () {
      final l = _prestamo(paidCount: 6);
      expect(l.paidInterest, greaterThan(l.paidPrincipal));
      // Y al final se invierte: la última mitad del crédito casi todo capital.
      final completo = _prestamo(paidCount: 60);
      expect(completo.paidPrincipal, greaterThan(completo.paidInterest));
    });

    test('el capital pagado es lo que bajó la deuda', () {
      final l = _prestamo(paidCount: 15);
      expect(l.paidPrincipal, closeTo(l.amount - l.remainingBalance, 1));
    });

    test('los abonos cuentan como capital', () {
      final l = _prestamo(
        paidCount: 6,
        extras: [const ExtraPayment(
          amount: 1000000,
          effect: ExtraEffect.reducirPlazo,
        )],
      );
      final sinAbonos = _prestamo(paidCount: 6);
      expect(l.paidPrincipal, greaterThan(sinAbonos.paidPrincipal));
      expect(l.paidPrincipal, closeTo(l.amount - l.remainingBalance, 1));
    });
  });

  group('abonos y cuotas pagadas', () {
    test('un abono ya configurado en una cuota pagada no se mueve', () {
      // El usuario abonó en la cuota 2 y ya pagó 4: eso es historia, la hoja
      // de abonos no debe empujarlo a la cuota 5.
      final l = _prestamo(
        paidCount: 4,
        extras: [const ExtraPayment(
          amount: 5000000,
          effect: ExtraEffect.reducirPlazo,
          startMonth: 2,
          recurring: false,
        )],
      );
      expect(l.result.schedule[1].extra, 5000000);
      expect(l.paidPrincipal, closeTo(l.amount - l.remainingBalance, 1));
    });
  });

  group('varios abonos', () {
    test('dos abonos en el mismo mes se suman', () {
      final l = _prestamo(
        extras: const [
          ExtraPayment(
            amount: 1000000,
            effect: ExtraEffect.reducirPlazo,
            startMonth: 3,
            recurring: false,
          ),
          ExtraPayment(
            amount: 500000,
            effect: ExtraEffect.reducirPlazo,
            startMonth: 3,
            recurring: false,
          ),
        ],
      );
      expect(l.result.schedule[2].extra, 1500000);
      expect(l.result.totalExtra, 1500000);
    });

    test('abonos en meses distintos caen cada uno en el suyo', () {
      final l = _prestamo(
        extras: const [
          ExtraPayment(
            amount: 2000000,
            effect: ExtraEffect.reducirPlazo,
            startMonth: 1,
            recurring: false,
          ),
          ExtraPayment(
            amount: 3000000,
            effect: ExtraEffect.reducirPlazo,
            startMonth: 10,
            recurring: false,
          ),
        ],
      );
      expect(l.result.schedule[0].extra, 2000000);
      expect(l.result.schedule[9].extra, 3000000);
      expect(l.result.schedule[4].extra, 0);
      expect(l.result.months, lessThan(60));
    });

    test('un abono no puede pasarse del saldo que queda', () {
      final l = _prestamo(
        extras: const [
          ExtraPayment(
            amount: 999999999,
            effect: ExtraEffect.reducirPlazo,
            startMonth: 1,
            recurring: false,
          ),
        ],
      );
      expect(l.result.months, 1);
      expect(l.result.schedule.last.balance, 0);
      expect(l.result.totalExtra, lessThan(50000000));
    });

    test('el formato viejo de un solo abono sigue abriendo', () {
      final viejo = {
        ..._prestamo().toJson(),
        'extra': const ExtraPayment(
          amount: 700000,
          effect: ExtraEffect.reducirPlazo,
        ).toJson(),
      }..remove('extras');
      final l = SavedLoan.fromJson(viejo);
      expect(l.extras, hasLength(1));
      expect(l.extras.single.amount, 700000);
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
    await tester.dragUntilVisible(
      find.text('Ver tabla de amortización'),
      find.byType(ListView).first,
      const Offset(0, -160),
    );
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
