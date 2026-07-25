import 'dart:math' as math;

/// Una fila de la tabla de amortización.
class AmortizationRow {
  const AmortizationRow({
    required this.number,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.balance,
  });

  final int number;
  final double payment;
  final double interest;
  final double principal;
  final double balance;
}

/// Resultado completo de un préstamo con cuota fija (sistema francés).
class LoanResult {
  const LoanResult({
    required this.amount,
    required this.monthlyRate,
    required this.months,
    required this.payment,
    required this.totalPaid,
    required this.totalInterest,
    required this.schedule,
  });

  final double amount;
  final double monthlyRate;
  final int months;
  final double payment;
  final double totalPaid;
  final double totalInterest;
  final List<AmortizationRow> schedule;
}

/// Cuota fija:  C = P · i / (1 - (1+i)^-n)
double monthlyPayment({
  required double amount,
  required double monthlyRate,
  required int months,
}) {
  if (months <= 0 || amount <= 0) return 0;
  if (monthlyRate == 0) return amount / months;
  final factor = math.pow(1 + monthlyRate, -months).toDouble();
  return amount * monthlyRate / (1 - factor);
}

/// Calcula cuota + tabla de amortización completa.
LoanResult calculateLoan({
  required double amount,
  required double monthlyRate,
  required int months,
}) {
  final payment = monthlyPayment(
    amount: amount,
    monthlyRate: monthlyRate,
    months: months,
  );

  final rows = <AmortizationRow>[];
  var balance = amount;
  var totalInterest = 0.0;
  var totalPaid = 0.0;

  for (var n = 1; n <= months; n++) {
    final interest = balance * monthlyRate;
    var principal = payment - interest;
    var thisPayment = payment;

    // Última cuota: se ajusta para cerrar el saldo exacto en cero.
    if (n == months || principal > balance) {
      principal = balance;
      thisPayment = principal + interest;
    }

    balance = balance - principal;
    if (balance.abs() < 0.005) balance = 0;

    totalInterest += interest;
    totalPaid += thisPayment;

    rows.add(AmortizationRow(
      number: n,
      payment: thisPayment,
      interest: interest,
      principal: principal,
      balance: balance,
    ));
  }

  return LoanResult(
    amount: amount,
    monthlyRate: monthlyRate,
    months: months,
    payment: payment,
    totalPaid: totalPaid,
    totalInterest: totalInterest,
    schedule: rows,
  );
}
