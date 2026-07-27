import '../core/amortization.dart';
import '../core/dates.dart';
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
    this.extras = const [],
    this.paidCount = 0,
    this.firstPaymentDate,
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

  /// Abonos a capital que el usuario va agregando después de guardar. Puede
  /// haber varios en el mismo mes, o ninguno.
  final List<ExtraPayment> extras;

  bool get hasExtras => extras.isNotEmpty;

  /// Cuotas ya pagadas. Se cuentan desde la primera: un crédito se paga en
  /// orden, así que basta el número y no hace falta guardar cuál es cuál.
  final int paidCount;

  /// Mes en que se paga la primera cuota. Los préstamos guardados antes de
  /// que existiera el campo arrancan el mes siguiente a su creación.
  final DateTime? firstPaymentDate;

  DateTime get firstPayment => firstPaymentDate ?? nextMonthStart(createdAt);

  /// Fecha en que se paga la cuota [number] (1 = la primera).
  DateTime dateOf(int number) => addMonths(firstPayment, number - 1);

  double get monthlyRate => rateType.toMonthlyRate(ratePercent);

  /// Resultado tal como se pactó, sin abonos. Se calcula una sola vez porque
  /// las pantallas lo consultan varias veces por frame.
  late final LoanResult baseResult = calculateLoan(
    amount: amount,
    monthlyRate: monthlyRate,
    months: months,
    system: system,
    uvr: uvr,
  );

  /// Resultado con los abonos agregados (igual al base si no hay).
  late final LoanResult result = extras.isEmpty
      ? baseResult
      : calculateLoan(
          amount: amount,
          monthlyRate: monthlyRate,
          months: months,
          system: system,
          uvr: uvr,
          extras: extras,
        );

  ExtraSavings? get savings => extras.isEmpty
      ? null
      : ExtraSavings(sinAbonos: baseResult, conAbonos: result);

  /// Cuotas pagadas acotadas al plazo real: un abono puede acortar el crédito
  /// por debajo de lo que el usuario ya había chuleado.
  int get paidMonths => paidCount.clamp(0, result.months);

  bool get isPaidOff => result.months > 0 && paidMonths >= result.months;

  double get progress => result.months == 0 ? 0 : paidMonths / result.months;

  /// Saldo que queda después de la última cuota pagada.
  double get remainingBalance {
    if (paidMonths == 0) return amount;
    if (paidMonths >= result.months) return 0;
    return result.schedule[paidMonths - 1].balance;
  }

  /// Plata que ya salió del bolsillo (cuotas + abonos de esos meses).
  double get paidSoFar => result.schedule
      .take(paidMonths)
      .fold<double>(0, (sum, r) => sum + r.totalOut);

  /// De lo pagado, cuánto bajó la deuda (incluye los abonos a capital).
  double get paidPrincipal => result.schedule
      .take(paidMonths)
      .fold<double>(0, (sum, r) => sum + r.principal + r.extra);

  /// De lo pagado, cuánto se quedó el banco en intereses.
  double get paidInterest => result.schedule
      .take(paidMonths)
      .fold<double>(0, (sum, r) => sum + r.interest);

  double get remainingToPay => result.schedule
      .skip(paidMonths)
      .fold<double>(0, (sum, r) => sum + r.totalOut);

  /// Próxima cuota por pagar, o null si ya se pagó todo.
  AmortizationRow? get nextRow =>
      isPaidOff || result.schedule.isEmpty ? null : result.schedule[paidMonths];

  SavedLoan copyWith({
    List<ExtraPayment>? extras,
    int? paidCount,
    DateTime? firstPaymentDate,
  }) => SavedLoan(
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
    extras: extras ?? this.extras,
    paidCount: paidCount ?? this.paidCount,
    firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
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
    'extras': extras.map((e) => e.toJson()).toList(),
    'paidCount': paidCount,
    'firstPaymentDate': firstPaymentDate?.toIso8601String(),
  };

  /// Acepta el formato viejo ('extra', uno solo) y el nuevo ('extras').
  static List<ExtraPayment> _extrasFromJson(Map<String, dynamic> j) {
    final lista = j['extras'];
    if (lista is List) {
      return lista
          .map((e) => ExtraPayment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final viejo = j['extra'];
    if (viejo is Map<String, dynamic>) return [ExtraPayment.fromJson(viejo)];
    return const [];
  }

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
    extras: _extrasFromJson(j),
    paidCount: (j['paidCount'] as num?)?.toInt() ?? 0,
    firstPaymentDate: DateTime.tryParse(j['firstPaymentDate'] as String? ?? ''),
  );
}
