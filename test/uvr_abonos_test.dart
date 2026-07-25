import 'package:flutter_test/flutter_test.dart';
import 'package:prestamo/core/amortization.dart';
import 'package:prestamo/core/rates.dart';

void main() {
  const tasaEa18 = 18.0;
  final mensual18 = RateType.efectivaAnual.toMonthlyRate(tasaEa18);

  group('cuota decreciente (sistema alemán)', () {
    final alemana = calculateLoan(
      amount: 50000000,
      monthlyRate: mensual18,
      months: 60,
      system: PaymentSystem.cuotaDecreciente,
    );
    final francesa = calculateLoan(
      amount: 50000000,
      monthlyRate: mensual18,
      months: 60,
    );

    test('abona el mismo capital todos los meses', () {
      final capitales =
          alemana.schedule.map((r) => r.principal.round()).toSet();
      expect(capitales.length, 1);
      expect(capitales.first, (50000000 / 60).round());
    });

    test('la cuota baja mes a mes', () {
      expect(alemana.payment, greaterThan(alemana.lastPayment));
      for (var i = 1; i < alemana.schedule.length; i++) {
        expect(
          alemana.schedule[i].payment,
          lessThan(alemana.schedule[i - 1].payment),
        );
      }
    });

    test('paga menos interés total que la cuota fija', () {
      expect(alemana.totalInterest, lessThan(francesa.totalInterest));
      expect(alemana.schedule.last.balance, 0);
    });
  });

  group('abonos a capital', () {
    final base = calculateLoan(
      amount: 50000000,
      monthlyRate: mensual18,
      months: 60,
    );

    test('reducir plazo: termina antes y ahorra interés', () {
      final conAbono = calculateLoan(
        amount: 50000000,
        monthlyRate: mensual18,
        months: 60,
        extra: const ExtraPayment(
          amount: 500000,
          effect: ExtraEffect.reducirPlazo,
        ),
      );

      expect(conAbono.months, lessThan(base.months));
      expect(conAbono.totalInterest, lessThan(base.totalInterest));
      expect(conAbono.schedule.last.balance, 0);
      // La cuota pactada no cambia.
      expect(conAbono.payment, closeTo(base.payment, 1));
    });

    test('reducir cuota: mismo plazo, cuota más baja', () {
      final conAbono = calculateLoan(
        amount: 50000000,
        monthlyRate: mensual18,
        months: 60,
        extra: const ExtraPayment(
          amount: 500000,
          effect: ExtraEffect.reducirCuota,
        ),
      );

      expect(conAbono.schedule.last.payment, lessThan(base.payment));
      expect(conAbono.totalInterest, lessThan(base.totalInterest));
      expect(conAbono.schedule.last.balance, 0);
    });

    test('reducir plazo ahorra más interés que reducir cuota', () {
      LoanResult con(ExtraEffect efecto) => calculateLoan(
            amount: 50000000,
            monthlyRate: mensual18,
            months: 60,
            extra: ExtraPayment(amount: 500000, effect: efecto),
          );

      expect(
        con(ExtraEffect.reducirPlazo).totalInterest,
        lessThan(con(ExtraEffect.reducirCuota).totalInterest),
      );
    });

    test('abono de una sola vez solo golpea el mes indicado', () {
      final unico = calculateLoan(
        amount: 50000000,
        monthlyRate: mensual18,
        months: 60,
        extra: const ExtraPayment(
          amount: 5000000,
          effect: ExtraEffect.reducirPlazo,
          startMonth: 12,
          recurring: false,
        ),
      );

      final conAbono =
          unico.schedule.where((r) => r.extra > 0).map((r) => r.number);
      expect(conAbono, [12]);
      expect(unico.totalExtra, closeTo(5000000, 1));
    });

    test('el abono nunca deja el saldo en negativo', () {
      final enorme = calculateLoan(
        amount: 10000000,
        monthlyRate: mensual18,
        months: 60,
        extra: const ExtraPayment(
          amount: 9000000,
          effect: ExtraEffect.reducirPlazo,
        ),
      );

      expect(enorme.schedule.last.balance, 0);
      expect(enorme.schedule.every((r) => r.balance >= 0), isTrue);
      expect(enorme.months, lessThan(4));
    });
  });

  group('crédito en UVR', () {
    const uvr = UvrProjection(uvrToday: 400, annualInflation: 0.05);
    final enUvr = calculateLoan(
      amount: 200000000,
      monthlyRate: RateType.efectivaAnual.toMonthlyRate(6),
      months: 240,
      uvr: uvr,
    );

    test('la UVR crece con la inflación proyectada', () {
      expect(uvr.valueAt(12), closeTo(400 * 1.05, 0.01));
      expect(uvr.valueAt(0), 400);
    });

    test('la cuota en pesos sube aunque en UVR sea fija', () {
      expect(enUvr.lastPayment, greaterThan(enUvr.payment));
      expect(enUvr.paymentVaries, isTrue);
      expect(enUvr.isUvr, isTrue);
    });

    test('cierra el saldo y el total supera al monto prestado', () {
      expect(enUvr.schedule.last.balance, 0);
      expect(enUvr.totalPaid, greaterThan(enUvr.amount));
    });

    test('con inflación cero se comporta como un crédito en pesos', () {
      final sinInflacion = calculateLoan(
        amount: 200000000,
        monthlyRate: RateType.efectivaAnual.toMonthlyRate(6),
        months: 240,
        uvr: const UvrProjection(uvrToday: 400, annualInflation: 0),
      );
      final enPesos = calculateLoan(
        amount: 200000000,
        monthlyRate: RateType.efectivaAnual.toMonthlyRate(6),
        months: 240,
      );

      expect(sinInflacion.payment, closeTo(enPesos.payment, 1));
      expect(sinInflacion.totalInterest, closeTo(enPesos.totalInterest, 100));
    });
  });
}
