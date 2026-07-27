import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/amortization.dart';
import '../core/money.dart';
import '../core/rates.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';
import '../widgets/result_section.dart';
import 'amortization_screen.dart';

enum FinancingMode { porcentaje, monto }

/// Denominación del crédito: pesos corrientes o UVR.
enum Denomination { pesos, uvr }

/// Formulario de crédito hipotecario dentro de [CalculatorScreen].
class MortgageForm extends StatefulWidget {
  const MortgageForm({
    super.key,
    required this.topPadding,
    required this.modeSelector,
  });

  /// Alto del encabezado: el contenido arranca debajo de la ola.
  final double topPadding;
  final Widget modeSelector;

  @override
  State<MortgageForm> createState() => _MortgageFormState();
}

class _MortgageFormState extends State<MortgageForm> {
  final _propertyValue = TextEditingController();
  final _financed = TextEditingController(text: '70');
  final _rate = TextEditingController();
  final _term = TextEditingController(text: '20');
  final _uvrToday = TextEditingController(text: '400');
  final _inflation = TextEditingController(text: '5');

  FinancingMode _mode = FinancingMode.porcentaje;
  RateType _rateType = RateType.efectivaAnual;
  TermUnit _termUnit = TermUnit.anios;
  PaymentSystem _system = PaymentSystem.cuotaFija;
  Denomination _denom = Denomination.pesos;

  LoanResult? _result;
  double _downPayment = 0;
  double _loanAmount = 0;

  @override
  void dispose() {
    _propertyValue.dispose();
    _financed.dispose();
    _rate.dispose();
    _term.dispose();
    _uvrToday.dispose();
    _inflation.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ClayColors.purpleDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  UvrProjection? _uvrProjection() {
    if (_denom == Denomination.pesos) return null;
    final valor = parseAmount(_uvrToday.text);
    final inflacion = parseAmount(_inflation.text);
    if (valor == null || valor <= 0 || inflacion == null) return null;
    return UvrProjection(uvrToday: valor, annualInflation: inflacion / 100);
  }

  void _calculate() {
    final value = parseAmount(_propertyValue.text);
    final financed = parseAmount(_financed.text);
    final rate = parseAmount(_rate.text);
    final term = parseAmount(_term.text);

    if (value == null ||
        value <= 0 ||
        financed == null ||
        rate == null ||
        term == null) {
      setState(() => _result = null);
      _toast('Completa todos los campos');
      return;
    }

    final loanAmount = _mode == FinancingMode.porcentaje
        ? value * (financed / 100)
        : financed;

    if (loanAmount <= 0 || loanAmount > value) {
      _toast('El banco no puede prestar más que el valor del inmueble');
      return;
    }

    final uvr = _uvrProjection();
    if (_denom == Denomination.uvr && uvr == null) {
      _toast('Revisa el valor de la UVR y la inflación');
      return;
    }

    final months = _termUnit.toMonths(term);
    setState(() {
      _loanAmount = loanAmount;
      _downPayment = value - loanAmount;
      _result = calculateLoan(
        amount: loanAmount,
        monthlyRate: _rateType.toMonthlyRate(rate),
        months: months,
        system: _system,
        uvr: uvr,
      );
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final draft = await askLoanDetails(context, 'Casa');
    if (draft == null) return;

    await AppState.instance.addLoan(
      SavedLoan(
        id: const Uuid().v4(),
        name: draft.name,
        kind: LoanKind.hipoteca,
        amount: result.amount,
        ratePercent: parseAmount(_rate.text) ?? 0,
        rateType: _rateType,
        months: result.months,
        currencyCode: AppState.instance.currencyCode,
        createdAt: DateTime.now(),
        firstPaymentDate: draft.firstPayment,
        propertyValue: parseAmount(_propertyValue.text),
        downPayment: _downPayment,
        system: _system,
        uvr: _uvrProjection(),
      ),
    );
    if (mounted) _toast('Crédito hipotecario guardado');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final money = app.money;
    final symbol = app.currency.symbol;
    final result = _result;
    final enUvr = _denom == Denomination.uvr;

    final falta = _downPayment - app.totalSavings;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, widget.topPadding + 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.modeSelector,
          const SizedBox(height: 16),
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClayField(
                  controller: _propertyValue,
                  label: 'Valor de la casa',
                  hint: 'Valor total del inmueble',
                  prefix: '$symbol ',
                  money: true,
                ),
                const SizedBox(height: 18),
                ClayChips<FinancingMode>(
                  label: 'El banco presta',
                  options: FinancingMode.values,
                  selected: _mode,
                  labelOf: (m) =>
                      m == FinancingMode.porcentaje ? 'En %' : 'En \$',
                  onSelect: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 12),
                ClayField(
                  controller: _financed,
                  hint: _mode == FinancingMode.porcentaje
                      ? 'Ej: 70'
                      : 'Monto prestado',
                  prefix: _mode == FinancingMode.monto ? '$symbol ' : null,
                  suffix: _mode == FinancingMode.porcentaje ? '%' : null,
                  money: _mode == FinancingMode.monto,
                ),
                const SizedBox(height: 18),
                ClayChips<Denomination>(
                  label: 'Denominación',
                  options: Denomination.values,
                  selected: _denom,
                  labelOf: (d) => d == Denomination.pesos ? 'Pesos' : 'UVR',
                  onSelect: (d) => setState(() => _denom = d),
                ),
                if (enUvr) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClayField(
                          controller: _uvrToday,
                          label: 'UVR hoy',
                          hint: 'Ej: 400',
                          prefix: '$symbol ',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClayField(
                          controller: _inflation,
                          label: 'Inflación',
                          hint: 'Ej: 5',
                          suffix: '%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La deuda queda en UVR: la cuota en pesos sube con la '
                    'inflación. La tasa que pides al banco es la real '
                    '(el "UVR + X%").',
                    style: TextStyle(
                      fontSize: 11,
                      color: ClayColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ClayField(
                  controller: _rate,
                  label: enUvr ? 'Tasa real (sobre UVR)' : 'Tasa de interés',
                  hint: enUvr ? 'Ej: 6' : 'Ej: 12,8',
                  suffix: '%',
                ),
                const SizedBox(height: 12),
                ClayChips<RateType>(
                  options: RateType.values,
                  selected: _rateType,
                  labelOf: (r) => r.label,
                  onSelect: (r) => setState(() => _rateType = r),
                ),
                const SizedBox(height: 18),
                ClayField(controller: _term, label: 'Plazo', hint: 'Ej: 20'),
                const SizedBox(height: 12),
                ClayChips<TermUnit>(
                  options: TermUnit.values,
                  selected: _termUnit,
                  labelOf: (t) => t.label,
                  onSelect: (t) => setState(() => _termUnit = t),
                ),
                const SizedBox(height: 18),
                ClayChips<PaymentSystem>(
                  label: 'Tipo de cuota',
                  options: PaymentSystem.values,
                  selected: _system,
                  labelOf: (s) => s.label,
                  onSelect: (s) => setState(() => _system = s),
                ),
                const SizedBox(height: 6),
                Text(
                  _system.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ClayColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ClayButton(
            label: 'Calcular hipoteca',
            icon: Icons.home_work_rounded,
            color: ClayColors.green,
            onPressed: _calculate,
          ),
          if (result != null) ...[
            const SizedBox(height: 22),
            ClayCard(
              color: _downPayment <= app.totalSavings
                  ? ClayColors.green
                  : ClayColors.pink,
              child: Row(
                children: [
                  Icon(
                    _downPayment <= app.totalSavings
                        ? Icons.check_circle_rounded
                        : Icons.savings_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuota inicial: ${money.format(_downPayment)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _downPayment <= app.totalSavings
                              ? 'Ya tienes ahorrado lo suficiente '
                                    '(${money.compact(app.totalSavings)})'
                              : 'Te faltan ${money.format(falta)} '
                                    '· ahorrado ${money.compact(app.totalSavings)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ResultSection(
              result: result,
              onSave: _save,
              extraRows: [
                (
                  label: 'Valor de la casa',
                  value: money.format(parseAmount(_propertyValue.text) ?? 0),
                  color: null,
                ),
                (
                  label: 'Financia el banco',
                  value:
                      '${(_loanAmount / (parseAmount(_propertyValue.text) ?? 1) * 100).toStringAsFixed(1)}%',
                  color: ClayColors.green,
                ),
              ],
              onSeeTable: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AmortizationScreen(
                    result: result,
                    title: 'Amortización hipoteca',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
