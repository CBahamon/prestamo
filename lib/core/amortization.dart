import 'dart:math' as math;

/// Cómo se reparte la deuda mes a mes.
enum PaymentSystem {
  /// Sistema francés: la cuota no cambia, al principio casi todo es interés.
  cuotaFija,

  /// Sistema alemán: se abona el mismo capital cada mes, así que la cuota
  /// arranca alta y va bajando. Se paga menos interés en total.
  cuotaDecreciente,
}

extension PaymentSystemX on PaymentSystem {
  String get label =>
      this == PaymentSystem.cuotaFija ? 'Cuota fija' : 'Cuota decreciente';

  String get description => this == PaymentSystem.cuotaFija
      ? 'La misma cuota todos los meses (sistema francés)'
      : 'Abono a capital constante: la cuota baja mes a mes (sistema alemán)';
}

/// Qué se acorta cuando abonas de más: el plazo o el valor de la cuota.
enum ExtraEffect {
  /// Sigues pagando lo mismo y terminas antes. Ahorra bastante más interés.
  reducirPlazo,

  /// Mantienes el plazo y te baja la cuota. Alivia el flujo del mes.
  reducirCuota,
}

extension ExtraEffectX on ExtraEffect {
  String get label =>
      this == ExtraEffect.reducirPlazo ? 'Reducir plazo' : 'Reducir cuota';

  String get description => this == ExtraEffect.reducirPlazo
      ? 'Pagas la misma cuota y terminas antes (ahorra más interés)'
      : 'Mantienes el plazo y te baja la cuota mensual';
}

/// Abono extraordinario a capital.
class ExtraPayment {
  const ExtraPayment({
    required this.amount,
    required this.effect,
    this.startMonth = 1,
    this.recurring = true,
  });

  /// Valor del abono, en la moneda del préstamo.
  final double amount;
  final ExtraEffect effect;

  /// Primer mes en que se abona (1 = con la primera cuota).
  final int startMonth;

  /// true = todos los meses desde [startMonth]; false = una sola vez.
  final bool recurring;

  bool appliesTo(int month) =>
      recurring ? month >= startMonth : month == startMonth;

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'effect': effect.name,
    'startMonth': startMonth,
    'recurring': recurring,
  };

  static ExtraPayment fromJson(Map<String, dynamic> j) => ExtraPayment(
    amount: (j['amount'] as num).toDouble(),
    effect: ExtraEffect.values.firstWhere(
      (e) => e.name == j['effect'],
      orElse: () => ExtraEffect.reducirPlazo,
    ),
    startMonth: (j['startMonth'] as num?)?.toInt() ?? 1,
    recurring: j['recurring'] as bool? ?? true,
  );
}

/// Crédito en UVR: la deuda se lleva en unidades y la UVR sube con la
/// inflación, así que la cuota en pesos crece aunque en UVR sea fija.
class UvrProjection {
  const UvrProjection({required this.uvrToday, required this.annualInflation});

  /// Pesos que vale una UVR hoy.
  final double uvrToday;

  /// Inflación anual proyectada, en decimal (0.05 = 5%).
  final double annualInflation;

  /// Valor de la UVR en el mes [month].
  double valueAt(int month) =>
      uvrToday * math.pow(1 + annualInflation, month / 12).toDouble();

  Map<String, dynamic> toJson() => {
    'uvrToday': uvrToday,
    'annualInflation': annualInflation,
  };

  static UvrProjection fromJson(Map<String, dynamic> j) => UvrProjection(
    uvrToday: (j['uvrToday'] as num).toDouble(),
    annualInflation: (j['annualInflation'] as num).toDouble(),
  );
}

/// Una fila de la tabla de amortización, siempre en pesos.
class AmortizationRow {
  const AmortizationRow({
    required this.number,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.balance,
    this.extra = 0,
  });

  final int number;
  final double payment;
  final double interest;
  final double principal;
  final double balance;

  /// Abono extraordinario aplicado en este mes.
  final double extra;

  /// Lo que sale del bolsillo ese mes.
  double get totalOut => payment + extra;
}

class LoanResult {
  const LoanResult({
    required this.amount,
    required this.monthlyRate,
    required this.months,
    required this.payment,
    required this.lastPayment,
    required this.totalPaid,
    required this.totalInterest,
    required this.totalExtra,
    required this.schedule,
    required this.system,
    this.uvr,
  });

  final double amount;
  final double monthlyRate;

  /// Meses que de verdad se pagaron (con abonos puede ser menos que el plazo).
  final int months;

  /// Primera cuota. En cuota decreciente y en UVR las siguientes cambian.
  final double payment;
  final double lastPayment;

  final double totalPaid;
  final double totalInterest;
  final double totalExtra;
  final List<AmortizationRow> schedule;
  final PaymentSystem system;
  final UvrProjection? uvr;

  bool get isUvr => uvr != null;
  bool get paymentVaries => system == PaymentSystem.cuotaDecreciente || isUvr;
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

/// Calcula cuota + tabla de amortización.
///
/// Con [uvr] la deuda se lleva en unidades UVR y cada fila se convierte a
/// pesos con la UVR proyectada de ese mes; [monthlyRate] es entonces la tasa
/// **real** (la que el banco cota "UVR + X%").
LoanResult calculateLoan({
  required double amount,
  required double monthlyRate,
  required int months,
  PaymentSystem system = PaymentSystem.cuotaFija,
  List<ExtraPayment> extras = const [],
  UvrProjection? uvr,
}) {
  final enUvr = uvr != null;

  // En UVR se trabaja en unidades; al final cada fila se pasa a pesos.
  final saldoInicial = enUvr ? amount / uvr.uvrToday : amount;
  final abonos = enUvr
      ? [
          for (final e in extras)
            ExtraPayment(
              amount: e.amount / uvr.uvrToday,
              effect: e.effect,
              startMonth: e.startMonth,
              recurring: e.recurring,
            ),
        ]
      : extras;

  var balance = saldoInicial;
  var cuota = monthlyPayment(
    amount: saldoInicial,
    monthlyRate: monthlyRate,
    months: months,
  );
  var capitalFijo = months > 0 ? saldoInicial / months : 0.0;

  final rows = <AmortizationRow>[];
  var totalInterest = 0.0;
  var totalPaid = 0.0;
  var totalExtra = 0.0;

  for (var n = 1; n <= months && balance > 0; n++) {
    final interes = balance * monthlyRate;

    var capital = system == PaymentSystem.cuotaFija
        ? cuota - interes
        : capitalFijo;
    if (capital > balance) capital = balance;

    var cuotaMes = capital + interes;

    // Varios abonos pueden caer en el mismo mes: se suman.
    final delMes = abonos.where((a) => a.appliesTo(n));
    var abonoMes = delMes.fold<double>(0, (sum, a) => sum + a.amount);
    if (abonoMes > balance - capital) abonoMes = balance - capital;
    if (abonoMes < 0) abonoMes = 0;

    // Basta que uno pida bajar la cuota para recalcularla.
    final bajaCuota = delMes.any((a) => a.effect == ExtraEffect.reducirCuota);

    balance = balance - capital - abonoMes;
    if (balance.abs() < 1e-6) balance = 0;

    // Con "reducir cuota" se recalcula con el saldo nuevo y el plazo que queda.
    if (abonoMes > 0 && bajaCuota && balance > 0) {
      final restantes = months - n;
      if (restantes > 0) {
        cuota = monthlyPayment(
          amount: balance,
          monthlyRate: monthlyRate,
          months: restantes,
        );
        capitalFijo = balance / restantes;
      }
    }

    // Última cuota: cierra el saldo exacto.
    if (n == months && balance > 0) {
      cuotaMes += balance;
      capital += balance;
      balance = 0;
    }

    final factor = enUvr ? uvr.valueAt(n) : 1.0;

    totalInterest += interes * factor;
    totalPaid += (cuotaMes + abonoMes) * factor;
    totalExtra += abonoMes * factor;

    rows.add(
      AmortizationRow(
        number: n,
        payment: cuotaMes * factor,
        interest: interes * factor,
        principal: capital * factor,
        extra: abonoMes * factor,
        balance: balance * factor,
      ),
    );
  }

  return LoanResult(
    amount: amount,
    monthlyRate: monthlyRate,
    months: rows.length,
    payment: rows.isEmpty ? 0 : rows.first.payment,
    lastPayment: rows.isEmpty ? 0 : rows.last.payment,
    totalPaid: totalPaid,
    totalInterest: totalInterest,
    totalExtra: totalExtra,
    schedule: rows,
    system: system,
    uvr: uvr,
  );
}

/// Comparación entre pagar normal y pagar con abonos.
class ExtraSavings {
  const ExtraSavings({required this.sinAbonos, required this.conAbonos});

  final LoanResult sinAbonos;
  final LoanResult conAbonos;

  double get interesAhorrado =>
      sinAbonos.totalInterest - conAbonos.totalInterest;

  int get mesesAhorrados => sinAbonos.months - conAbonos.months;

  double get cuotaNueva =>
      conAbonos.schedule.isEmpty ? 0 : conAbonos.schedule.last.payment;
}
