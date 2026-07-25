import 'dart:math' as math;

/// Formas en que un banco puede publicar la tasa.
/// Todo se normaliza a **tasa efectiva mensual** antes de calcular.
enum RateType {
  efectivaAnual,
  efectivaMensual,
  nominalAnualMesVencido,
  nominalAnualTrimestreVencido,
  nominalAnualSemestreVencido,
}

extension RateTypeX on RateType {
  String get label => switch (this) {
    RateType.efectivaAnual => 'E.A.',
    RateType.efectivaMensual => 'E.M.',
    RateType.nominalAnualMesVencido => 'N.A. M.V.',
    RateType.nominalAnualTrimestreVencido => 'N.A. T.V.',
    RateType.nominalAnualSemestreVencido => 'N.A. S.V.',
  };

  String get description => switch (this) {
    RateType.efectivaAnual => 'Efectiva anual (la usual en Colombia)',
    RateType.efectivaMensual => 'Efectiva mensual',
    RateType.nominalAnualMesVencido => 'Nominal anual, mes vencido',
    RateType.nominalAnualTrimestreVencido => 'Nominal anual, trimestre vencido',
    RateType.nominalAnualSemestreVencido => 'Nominal anual, semestre vencido',
  };

  /// Convierte el porcentaje ingresado (ej. 18.5) a tasa efectiva mensual
  /// en decimal (ej. 0.014249).
  double toMonthlyRate(double percent) {
    final r = percent / 100.0;
    return switch (this) {
      // (1+EA)^(1/12) - 1  — NO se divide entre 12.
      RateType.efectivaAnual => math.pow(1 + r, 1 / 12).toDouble() - 1,
      RateType.efectivaMensual => r,
      // Nominal: se divide entre los periodos del año y se lleva a mensual.
      RateType.nominalAnualMesVencido => r / 12,
      RateType.nominalAnualTrimestreVencido =>
        math.pow(1 + r / 4, 1 / 3).toDouble() - 1,
      RateType.nominalAnualSemestreVencido =>
        math.pow(1 + r / 2, 1 / 6).toDouble() - 1,
    };
  }
}

/// Tasa efectiva anual equivalente a una efectiva mensual.
double monthlyToEffectiveAnnual(double monthly) =>
    math.pow(1 + monthly, 12).toDouble() - 1;

enum TermUnit { meses, anios }

extension TermUnitX on TermUnit {
  String get label => this == TermUnit.meses ? 'Meses' : 'Años';
  int toMonths(num value) =>
      this == TermUnit.meses ? value.round() : (value * 12).round();
}
