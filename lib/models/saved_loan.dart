import '../core/amortization.dart';
import '../core/rates.dart';

enum LoanKind { prestamo, hipoteca }

/// Préstamo guardado. Se serializa a JSON en SharedPreferences.
///
/// Los campos nuevos (sistema, UVR, abonos) son opcionales para que los
/// préstamos guardados con versiones anteriores sigan abriendo.
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
    this.system = PaymentSystem.cuotaFija,
    this.uvr,
    this.extra,
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

  final PaymentSystem system;

  /// Si está presente, el crédito está denominado en UVR.
  final UvrProjection? uvr;

  /// Abono a capital configurado por el usuario después de guardar.
  final ExtraPayment? extra;

  double get monthlyRate => rateType.toMonthlyRate(ratePercent);

  /// Resultado tal como se pactó, sin abonos.
  LoanResult get baseResult => calculateLoan(
    amount: amount,
    monthlyRate: monthlyRate,
    months: months,
    system: system,
    uvr: uvr,
  );

  /// Resultado con los abonos configurados (igual al base si no hay).
  LoanResult get result => extra == null
      ? baseResult
      : calculateLoan(
          amount: amount,
          monthlyRate: monthlyRate,
          months: months,
          system: system,
          uvr: uvr,
          extra: extra,
        );

  ExtraSavings? get savings => extra == null
      ? null
      : ExtraSavings(sinAbonos: baseResult, conAbonos: result);

  SavedLoan copyWith({ExtraPayment? extra, bool clearExtra = false}) =>
      SavedLoan(
        id: id,
        name: name,
        kind: kind,
        amount: amount,
        ratePercent: ratePercent,
        rateType: rateType,
        months: months,
        currencyCode: currencyCode,
        createdAt: createdAt,
        propertyValue: propertyValue,
        downPayment: downPayment,
        system: system,
        uvr: uvr,
        extra: clearExtra ? null : (extra ?? this.extra),
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
    'system': system.name,
    'uvr': uvr?.toJson(),
    'extra': extra?.toJson(),
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
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    propertyValue: (j['propertyValue'] as num?)?.toDouble(),
    downPayment: (j['downPayment'] as num?)?.toDouble(),
    system: PaymentSystem.values.firstWhere(
      (s) => s.name == j['system'],
      orElse: () => PaymentSystem.cuotaFija,
    ),
    uvr: j['uvr'] == null
        ? null
        : UvrProjection.fromJson(j['uvr'] as Map<String, dynamic>),
    extra: j['extra'] == null
        ? null
        : ExtraPayment.fromJson(j['extra'] as Map<String, dynamic>),
  );
}
