import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamo/core/amortization.dart';
import 'package:prestamo/core/money.dart';
import 'package:prestamo/core/rates.dart';

void main() {
  test(
    'E.A. se convierte a mensual con raíz doceava, no dividiendo entre 12',
    () {
      final m = RateType.efectivaAnual.toMonthlyRate(18);
      expect(m, closeTo(0.013888, 0.0001)); // 1,3888% mensual, no 1,5%
      expect(monthlyToEffectiveAnnual(m) * 100, closeTo(18, 0.0001));
    },
  );

  test('nominal anual mes vencido se divide entre 12', () {
    expect(
      RateType.nominalAnualMesVencido.toMonthlyRate(18),
      closeTo(0.015, 1e-9),
    );
  });

  test('cuota fija y cierre exacto del saldo', () {
    final r = calculateLoan(
      amount: 50000000,
      monthlyRate: RateType.efectivaAnual.toMonthlyRate(18),
      months: 60,
    );

    expect(r.schedule.length, 60);
    expect(r.schedule.last.balance, 0);
    expect(r.totalPaid, closeTo(r.amount + r.totalInterest, 1));
  });

  test('tasa cero reparte el capital en partes iguales', () {
    final r = calculateLoan(amount: 1200, monthlyRate: 0, months: 12);
    expect(r.payment, 100);
    expect(r.totalInterest, 0);
    expect(r.schedule.last.balance, 0);
  });

  test('el monto se formatea con el símbolo adelante', () {
    final cop = Money(currencyByCode('COP'));
    expect(cop.format(1250000), r'$ 1.250.000'); // COP sin decimales
    // intl separa la abreviatura con espacio duro (U+00A0).
    expect(cop.compact(12500000), '\$ 12,5 M');

    final usd = Money(currencyByCode('USD'));
    expect(usd.format(1250.5), r'$ 1.250,50');
  });

  group('MilesInputFormatter', () {
    const f = MilesInputFormatter();

    TextEditingValue escribir(String antes, String despues, {int? cursor}) =>
        f.formatEditUpdate(
          TextEditingValue(text: antes),
          TextEditingValue(
            text: despues,
            selection: TextSelection.collapsed(
              offset: cursor ?? despues.length,
            ),
          ),
        );

    test('agrupa los miles mientras se escribe', () {
      expect(escribir('1.200.00', '1.200.000').text, '1.200.000');
      expect(escribir('', '12000000').text, '12.000.000');
      expect(escribir('', '999').text, '999');
    });

    test('deja una sola coma decimal y máximo dos decimales', () {
      expect(escribir('', '1500,75').text, '1.500,75');
      expect(escribir('', '1500,7,5').text, '1.500,75');
      expect(escribir('', '1500,7599').text, '1.500,75');
    });

    test('quita ceros a la izquierda y basura', () {
      expect(escribir('', '007').text, '7');
      expect(escribir('', r'$ 1.200abc').text, '1.200');
      expect(escribir('', '').text, '');
    });

    test('no deja pasar de 12 dígitos enteros', () {
      expect(escribir('', '999999999999').text, '999.999.999.999');
      // El dígito 13 se ignora y queda lo que ya había.
      expect(
        escribir('999.999.999.999', '999.999.999.9999').text,
        '999.999.999.999',
      );
    });

    test('el cursor no se va al final cuando aparece un punto', () {
      // Escribiendo al final: "1234" + "5" → "12.345", cursor al final.
      final alFinal = escribir('1234', '12345');
      expect(alFinal.text, '12.345');
      expect(alFinal.selection.end, alFinal.text.length);

      // Editando en medio: "1.234" con el cursor tras el "2" (offset 3) y se
      // teclea un "9" → "12.934"; el cursor queda tras el "9", con 2 dígitos
      // todavía a su derecha.
      final enMedio = escribir('1.234', '1.2934', cursor: 4);
      expect(enMedio.text, '12.934');
      expect(enMedio.text.substring(enMedio.selection.end), '34');
    });
  });

  test('parseAmount entiende formato colombiano', () {
    expect(parseAmount('250.000.000'), 250000000);
    expect(parseAmount('12,5'), 12.5);
    expect(parseAmount(r'$ 1.200.000'), 1200000);
    expect(parseAmount(''), isNull);
  });
}
