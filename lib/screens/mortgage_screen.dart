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

class MortgageScreen extends StatefulWidget {
  const MortgageScreen({super.key});

  @override
  State<MortgageScreen> createState() => _MortgageScreenState();
}

class _MortgageScreenState extends State<MortgageScreen> {
  final _propertyValue = TextEditingController();
  final _financed = TextEditingController(text: '70');
  final _rate = TextEditingController();
  final _term = TextEditingController(text: '20');

  FinancingMode _mode = FinancingMode.porcentaje;
  RateType _rateType = RateType.efectivaAnual;
  TermUnit _termUnit = TermUnit.anios;

  LoanResult? _result;
  double _downPayment = 0;
  double _loanAmount = 0;

  @override
  void dispose() {
    _propertyValue.dispose();
    _financed.dispose();
    _rate.dispose();
    _term.dispose();
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

  void _calculate() {
    final value = parseAmount(_propertyValue.text);
    final financed = parseAmount(_financed.text);
    final rate = parseAmount(_rate.text);
    final term = parseAmount(_term.text);

    if (value == null || value <= 0 || financed == null || rate == null ||
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

    final months = _termUnit.toMonths(term);
    setState(() {
      _loanAmount = loanAmount;
      _downPayment = value - loanAmount;
      _result = calculateLoan(
        amount: loanAmount,
        monthlyRate: _rateType.toMonthlyRate(rate),
        months: months,
      );
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final name = await askLoanName(context, 'Casa');
    if (name == null) return;

    await AppState.instance.addLoan(SavedLoan(
      id: const Uuid().v4(),
      name: name,
      kind: LoanKind.hipoteca,
      amount: result.amount,
      ratePercent: parseAmount(_rate.text) ?? 0,
      rateType: _rateType,
      months: result.months,
      currencyCode: AppState.instance.currencyCode,
      createdAt: DateTime.now(),
      propertyValue: parseAmount(_propertyValue.text),
      downPayment: _downPayment,
    ));
    if (mounted) _toast('Crédito hipotecario guardado');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final money = app.money;
    final symbol = app.currency.symbol;
    final result = _result;

    final falta = _downPayment - app.totalSavings;

    return Scaffold(
      body: Column(
        children: [
          const ClayHeader(
            title: 'Crédito hipotecario',
            subtitle: 'Cuánto presta el banco y cuánto pones tú',
            showBack: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          prefix: _mode == FinancingMode.monto
                              ? '$symbol '
                              : null,
                          suffix: _mode == FinancingMode.porcentaje
                              ? '%'
                              : null,
                          money: _mode == FinancingMode.monto,
                        ),
                        const SizedBox(height: 18),
                        ClayField(
                          controller: _rate,
                          label: 'Tasa de interés',
                          hint: 'Ej: 12,8',
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
                        ClayField(
                          controller: _term,
                          label: 'Plazo',
                          hint: 'Ej: 20',
                        ),
                        const SizedBox(height: 12),
                        ClayChips<TermUnit>(
                          options: TermUnit.values,
                          selected: _termUnit,
                          labelOf: (t) => t.label,
                          onSelect: (t) => setState(() => _termUnit = t),
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
                          value: money
                              .format(parseAmount(_propertyValue.text) ?? 0),
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
            ),
          ),
        ],
      ),
    );
  }
}
