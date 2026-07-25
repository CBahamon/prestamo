import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/rates.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';
import 'amortization_screen.dart';

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final result = loan.result;
    final ea = monthlyToEffectiveAnnual(loan.monthlyRate) * 100;

    return Scaffold(
      body: Column(
        children: [
          ClayHeader(
            title: loan.name,
            subtitle: DateFormat.yMMMMd('es_CO').format(loan.createdAt),
            showBack: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: ClayColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    title: const Text('¿Eliminar préstamo?'),
                    content: Text('Se borrará "${loan.name}".'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Eliminar',
                            style: TextStyle(color: ClayColors.red)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await AppState.instance.deleteLoan(loan.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                ClayCard(
                  color: ClayColors.purple,
                  child: Column(
                    children: [
                      Text(
                        'CUOTA MENSUAL',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        child: Text(
                          money.format(result.payment),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClayCard(
                  child: Column(
                    children: [
                      _row('Monto prestado', money.format(loan.amount)),
                      if (loan.propertyValue != null)
                        _row('Valor del inmueble',
                            money.format(loan.propertyValue!)),
                      if (loan.downPayment != null)
                        _row('Cuota inicial', money.format(loan.downPayment!)),
                      _row('Tasa',
                          '${loan.ratePercent.toStringAsFixed(2)}% ${loan.rateType.label}'),
                      _row('Equivale a', '${ea.toStringAsFixed(2)}% E.A.'),
                      _row('Plazo', '${loan.months} meses'),
                      _row('Total intereses',
                          money.format(result.totalInterest),
                          color: ClayColors.red),
                      _row('Total a pagar', money.format(result.totalPaid),
                          bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ClayButton(
                  label: 'Ver tabla de amortización',
                  icon: Icons.table_rows_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AmortizationScreen(
                        result: result,
                        title: loan.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: ClayColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontSize: bold ? 15 : 13.5,
              color: color ?? ClayColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
