import '../core/amortization.dart';
import '../core/rates.dart';

enum LoanKind { prestamo, hipoteca }

/// Préstamo guardado. Se serializa a JSON en SharedPreferences.
class SavedLoan {
  SavedLoan({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.ratePercent,
    required this.rateType,
    required this.months,
    required this.currencyCode,
    required this.createdAt,
    this.propertyValue,
    this.downPayment,
  });

  final String id;
  final String name;
  final LoanKind kind;

  /// Monto prestado por el banco.
  final double amount;
  final double ratePercent;
  final RateType rateType;
  final int months;
  final String currencyCode;
  final DateTime createdAt;

  /// Solo hipoteca: valor total del inmueble y cuota inicial.
  final double? propertyValue;
  final double? downPayment;

  double get monthlyRate => rateType.toMonthlyRate(ratePercent);

  LoanResult get result => calculateLoan(
        amount: amount,
        monthlyRate: monthlyRate,
        months: months,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'amount': amount,
        'ratePercent': ratePercent,
        'rateType': rateType.name,
        'months': months,
        'currencyCode': currencyCode,
        'createdAt': createdAt.toIso8601String(),
        'propertyValue': propertyValue,
        'downPayment': downPayment,
      };

  static SavedLoan fromJson(Map<String, dynamic> j) => SavedLoan(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: LoanKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => LoanKind.prestamo,
        ),
        amount: (j['amount'] as num).toDouble(),
        ratePercent: (j['ratePercent'] as num).toDouble(),
        rateType: RateType.values.firstWhere(
          (r) => r.name == j['rateType'],
          orElse: () => RateType.efectivaAnual,
        ),
        months: (j['months'] as num).toInt(),
        currencyCode: j['currencyCode'] as String? ?? 'COP',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        propertyValue: (j['propertyValue'] as num?)?.toDouble(),
        downPayment: (j['downPayment'] as num?)?.toDouble(),
      );
}
