import 'package:flutter/material.dart';

import '../models/saved_loan.dart';
import '../widgets/clay_widgets.dart';
import 'loan_calculator_screen.dart';
import 'mortgage_screen.dart';

/// Pantalla única de cálculo: el usuario elige si va a calcular un préstamo
/// normal o un crédito hipotecario. Antes la hipoteca solo se alcanzaba desde
/// el acceso rápido de inicio.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.initialKind = LoanKind.prestamo});

  final LoanKind initialKind;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late LoanKind _kind = widget.initialKind;

  @override
  Widget build(BuildContext context) {
    final esHipoteca = _kind == LoanKind.hipoteca;

    return ClayScaffold(
      header: ClayHeader(
        title: esHipoteca ? 'Crédito hipotecario' : 'Calcular préstamo',
        subtitle: esHipoteca
            ? 'Cuánto presta el banco y cuánto pones tú'
            : 'Cuota, intereses y tabla de amortización',
        showBack: true,
      ),
      // El selector va dentro del scroll: si se queda fijo vuelve a aparecer
      // el corte recto que la ola debía reemplazar.
      builder: (context, topPadding) => esHipoteca
          ? MortgageForm(
              key: const ValueKey('hipoteca'),
              topPadding: topPadding,
              modeSelector: _selector(),
            )
          : LoanCalculatorForm(
              key: const ValueKey('prestamo'),
              topPadding: topPadding,
              modeSelector: _selector(),
            ),
    );
  }

  Widget _selector() => ClayCard(
    padding: const EdgeInsets.all(14),
    radius: 22,
    child: ClayChips<LoanKind>(
      label: '¿Qué vas a calcular?',
      options: LoanKind.values,
      selected: _kind,
      labelOf: (k) => k == LoanKind.prestamo ? 'Préstamo' : 'Hipotecario',
      onSelect: (k) => setState(() => _kind = k),
    ),
  );
}
