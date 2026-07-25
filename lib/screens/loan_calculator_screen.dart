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

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController();

  RateType _rateType = RateType.efectivaAnual;
  TermUnit _termUnit = TermUnit.meses;
  LoanResult? _result;

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _term.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = parseAmount(_amount.text);
    final rate = parseAmount(_rate.text);
    final term = parseAmount(_term.text);

    if (amount == null || amount <= 0 || rate == null || term == null) {
      setState(() => _result = null);
      _toast('Completa monto, tasa y plazo');
      return;
    }

    final months = _termUnit.toMonths(term);
    if (months <= 0) {
      _toast('El plazo debe ser mayor a cero');
      return;
    }

    setState(() {
      _result = calculateLoan(
        amount: amount,
        monthlyRate: _rateType.toMonthlyRate(rate),
        months: months,
      );
    });
    FocusScope.of(context).unfocus();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ClayColors.purpleDark,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final name = await askLoanName(context, 'Préstamo');
    if (name == null) return;

    await AppState.instance.addLoan(SavedLoan(
      id: const Uuid().v4(),
      name: name,
      kind: LoanKind.prestamo,
      amount: result.amount,
      ratePercent: parseAmount(_rate.text) ?? 0,
      rateType: _rateType,
      months: result.months,
      currencyCode: AppState.instance.currencyCode,
      createdAt: DateTime.now(),
    ));
    if (mounted) _toast('Préstamo guardado');
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final symbol = AppState.instance.currency.symbol;

    return Scaffold(
      body: Column(
        children: [
          const ClayHeader(
            title: 'Calcular préstamo',
            subtitle: 'Cuota fija · sistema francés',
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
                          controller: _amount,
                          label: 'Valor del préstamo',
                          hint: 'Monto',
                          prefix: '$symbol ',
                          money: true,
                        ),
                        const SizedBox(height: 18),
                        ClayField(
                          controller: _rate,
                          label: 'Tasa de interés',
                          hint: 'Ej: 18,5',
                          suffix: '%',
                        ),
                        const SizedBox(height: 12),
                        ClayChips<RateType>(
                          options: RateType.values,
                          selected: _rateType,
                          labelOf: (r) => r.label,
                          onSelect: (r) => setState(() => _rateType = r),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _rateType.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ClayColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ClayField(
                          controller: _term,
                          label: 'Plazo',
                          hint: 'Ej: 60',
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
                    label: 'Calcular',
                    icon: Icons.calculate_rounded,
                    onPressed: _calculate,
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 22),
                    ResultSection(
                      result: result,
                      onSave: _save,
                      onSeeTable: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AmortizationScreen(
                            result: result,
                            title: 'Amortización',
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
