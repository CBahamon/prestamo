import 'package:flutter/material.dart';

import '../core/amortization.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../core/rates.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import 'clay_motion.dart';
import 'clay_widgets.dart';

/// Bloque de resultado compartido por la calculadora y la hipoteca.
class ResultSection extends StatelessWidget {
  const ResultSection({
    super.key,
    required this.result,
    required this.onSave,
    required this.onSeeTable,
    this.extraRows = const [],
  });

  final LoanResult result;
  final VoidCallback onSave;
  final VoidCallback onSeeTable;
  final List<({String label, String value, Color? color})> extraRows;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final ea = monthlyToEffectiveAnnual(result.monthlyRate) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          key: ValueKey(result.payment),
          child: ClayCard(
            color: ClayColors.purple,
            child: Column(
              children: [
                Text(
                  result.paymentVaries ? 'PRIMERA CUOTA' : 'CUOTA MENSUAL',
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
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (result.paymentVaries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      result.isUvr
                          ? 'Última cuota (en pesos): ${money.format(result.lastPayment)}'
                          : 'Última cuota: ${money.format(result.lastPayment)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                Text(
                  '${result.months} cuotas · ${(result.monthlyRate * 100).toStringAsFixed(3)}% mensual · ${ea.toStringAsFixed(2)}% ${result.isUvr ? "E.A. real" : "E.A."}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          key: ValueKey('detalle-${result.totalPaid}'),
          delay: const Duration(milliseconds: 110),
          child: ClayCard(
            child: Column(
              children: [
                for (final r in extraRows) ...[
                  _Row(label: r.label, value: r.value, color: r.color),
                  const Divider(height: 20, color: ClayColors.background),
                ],
                _Row(
                  label: 'Monto del préstamo',
                  value: money.format(result.amount),
                ),
                const Divider(height: 20, color: ClayColors.background),
                _Row(
                  label: 'Total intereses',
                  value: money.format(result.totalInterest),
                  color: ClayColors.red,
                ),
                const Divider(height: 20, color: ClayColors.background),
                _Row(
                  label: 'Total a pagar',
                  value: money.format(result.totalPaid),
                  color: ClayColors.textDark,
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ClayButton(
          label: 'Ver tabla de amortización',
          icon: Icons.table_rows_rounded,
          onPressed: onSeeTable,
        ),
        const SizedBox(height: 12),
        ClayButton(
          label: 'Guardar préstamo',
          icon: Icons.bookmark_add_rounded,
          color: ClayColors.green,
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: ClayColors.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            fontSize: bold ? 16 : 14,
            color: color ?? ClayColors.textDark,
          ),
        ),
      ],
    );
  }
}

/// Lo que se pregunta al guardar: cómo se llama y cuándo se paga la primera
/// cuota (de ahí salen las fechas de toda la tabla).
class LoanDraft {
  const LoanDraft(this.name, this.firstPayment);

  final String name;
  final DateTime firstPayment;
}

/// Pide nombre y fecha de la primera cuota. Devuelve null si se cancela.
Future<LoanDraft?> askLoanDetails(BuildContext context, String suggestion) {
  final controller = TextEditingController(text: suggestion);
  var primera = nextMonthStart();

  return showDialog<LoanDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: ClayColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text(
          'Guardar préstamo',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClayField(
              controller: controller,
              hint: 'Ej: Carro Bancolombia',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            const Text(
              'PRIMERA CUOTA',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: ClayColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: primera,
                  firstDate: DateTime(DateTime.now().year - 10),
                  lastDate: DateTime(DateTime.now().year + 10),
                  helpText: '¿Cuándo pagas la primera cuota?',
                );
                if (elegida != null) setState(() => primera = elegida);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: ClayColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: ClayColors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fullDate(primera),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_rounded,
                      size: 18,
                      color: ClayColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: ClayColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              LoanDraft(
                controller.text.trim().isEmpty
                    ? suggestion
                    : controller.text.trim(),
                primera,
              ),
            ),
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: ClayColors.purple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Formatea porcentaje corto para etiquetas.
String pct(double v) => '${formatPlain(v, decimals: 2)}%';
