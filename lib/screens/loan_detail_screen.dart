import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/amortization.dart';
import '../core/dates.dart';
import '../core/rates.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';
import 'amortization_screen.dart';
import 'extra_payment_sheet.dart';

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        // Se relee del estado para reflejar los abonos recién guardados.
        final actual = app.loans.firstWhere(
          (l) => l.id == loan.id,
          orElse: () => loan,
        );
        return _Detalle(loan: actual);
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final result = loan.result;
    final savings = loan.savings;
    final ea = monthlyToEffectiveAnnual(loan.monthlyRate) * 100;

    return ClayScaffold(
      header: ClayHeader(
        title: loan.name,
        subtitle: DateFormat.yMMMMd('es_CO').format(loan.createdAt),
        showBack: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                backgroundColor: ClayColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                title: const Text('¿Eliminar préstamo?'),
                content: Text('Se borrará "${loan.name}".'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(color: ClayColors.red),
                    ),
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
      builder: (context, topPadding) => ListView(
        padding: EdgeInsets.fromLTRB(20, topPadding + 18, 20, 40),
        children: [
          ClayCard(
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
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (result.paymentVaries)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Última cuota: ${money.format(result.lastPayment)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.9),
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
                  _row('Valor del inmueble', money.format(loan.propertyValue!)),
                if (loan.downPayment != null)
                  _row('Cuota inicial', money.format(loan.downPayment!)),
                _row('Sistema', loan.system.label),
                if (loan.uvr != null)
                  _row(
                    'Denominación',
                    'UVR (inflación ${(loan.uvr!.annualInflation * 100).toStringAsFixed(1)}%)',
                  ),
                _row(
                  'Tasa',
                  '${loan.ratePercent.toStringAsFixed(2)}% ${loan.rateType.label}',
                ),
                _row(
                  'Equivale a',
                  '${ea.toStringAsFixed(2)}% E.A.${loan.uvr != null ? ' real' : ''}',
                ),
                _FechaRow(loan: loan),
                _row(
                  'Plazo',
                  '${loan.months} meses${result.months != loan.months ? ' → ${result.months} con abonos' : ''}',
                ),
                _row(
                  'Total intereses',
                  money.format(result.totalInterest),
                  color: ClayColors.red,
                ),
                if (result.totalExtra > 0)
                  _row(
                    'Total abonado extra',
                    money.format(result.totalExtra),
                    color: ClayColors.green,
                  ),
                _row(
                  'Total a pagar',
                  money.format(result.totalPaid),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProgresoCard(loan: loan),
          const SizedBox(height: 16),
          _AbonosCard(loan: loan, savings: savings),
          const SizedBox(height: 20),
          ClayButton(
            label: 'Ver tabla de amortización',
            icon: Icons.table_rows_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AmortizationScreen(
                  result: result,
                  title: loan.name,
                  loan: loan,
                  firstPayment: loan.firstPayment,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: ClayColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                fontSize: bold ? 15 : 13.5,
                color: color ?? ClayColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fecha de la primera cuota, editable: de ahí salen las fechas de la tabla.
class _FechaRow extends StatelessWidget {
  const _FechaRow({required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final elegida = await showDatePicker(
          context: context,
          initialDate: loan.firstPayment,
          firstDate: DateTime(DateTime.now().year - 10),
          lastDate: DateTime(DateTime.now().year + 10),
          helpText: '¿Cuándo pagaste la primera cuota?',
        );
        if (elegida != null) {
          await AppState.instance.updateLoan(
            loan.copyWith(firstPaymentDate: elegida),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Primera cuota',
              style: TextStyle(color: ClayColors.textMuted, fontSize: 13),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      fullDate(loan.firstPayment),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.edit_calendar_rounded,
                    size: 15,
                    color: ClayColors.purple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avance del crédito: cuántas cuotas van, cuánto falta y el botón para
/// registrar la cuota del mes.
class _ProgresoCard extends StatelessWidget {
  const _ProgresoCard({required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final result = loan.result;
    final pagadas = loan.paidMonths;
    final siguiente = loan.nextRow;

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mi avance',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$pagadas / ${result.months} cuotas',
                    style: const TextStyle(
                      color: ClayColors.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClayProgress(value: loan.progress),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _mini(
                  'Pagado',
                  money.compact(loan.paidSoFar),
                  ClayColors.green,
                ),
              ),
              Container(width: 1, height: 32, color: ClayColors.background),
              Expanded(
                child: _mini(
                  'Saldo pendiente',
                  money.compact(loan.remainingBalance),
                  ClayColors.purple,
                ),
              ),
            ],
          ),
          if (pagadas > 0) ...[
            const SizedBox(height: 10),
            Text(
              'De eso, ${money.compact(loan.paidPrincipal)} bajaron la deuda y '
              '${money.compact(loan.paidInterest)} se fueron en intereses.',
              style: const TextStyle(
                fontSize: 11.5,
                color: ClayColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (siguiente == null)
            const Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: ClayColors.green,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Crédito saldado! No queda nada por pagar.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ClayColors.green,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Próxima: cuota ${siguiente.number} de '
              '${longMonth(loan.dateOf(siguiente.number))}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ClayColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ClayButton(
              label:
                  'Pagué la cuota ${siguiente.number} · '
                  '${money.compact(siguiente.totalOut)}',
              icon: Icons.check_circle_outline_rounded,
              color: ClayColors.green,
              onPressed: () =>
                  AppState.instance.setPaidCount(loan, siguiente.number),
            ),
          ],
          if (pagadas > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () =>
                    AppState.instance.setPaidCount(loan, pagadas - 1),
                child: const Text(
                  'Deshacer la última',
                  style: TextStyle(color: ClayColors.textMuted, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: ClayColors.textMuted),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Lista de abonos a capital: se van agregando cuando el usuario quiera,
/// varios en el mismo mes o ninguno.
class _AbonosCard extends StatelessWidget {
  const _AbonosCard({required this.loan, required this.savings});

  final SavedLoan loan;
  final ExtraSavings? savings;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;

    if (loan.extras.isEmpty) {
      return ClayCard(
        onTap: () => showAddExtraSheet(context, loan),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: ClayColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.bolt_rounded, color: ClayColors.green),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abonos a capital',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Agrega uno cada vez que abones y mira cuánto te ahorras.',
                    style: TextStyle(fontSize: 12, color: ClayColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_rounded, color: ClayColors.green),
          ],
        ),
      );
    }

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: ClayColors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mis abonos',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${loan.extras.length}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: ClayColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < loan.extras.length; i++)
            _AbonoTile(loan: loan, index: i),
          if (savings != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClayColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Te ahorras ${money.format(savings!.interesAhorrado)} '
                    'en intereses',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: ClayColors.green,
                    ),
                  ),
                  if (savings!.mesesAhorrados > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Terminas ${savings!.mesesAhorrados} meses antes: '
                      '${savings!.conAbonos.months} en vez de '
                      '${savings!.sinAbonos.months}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ClayColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClayButton(
            label: 'Agregar otro abono',
            icon: Icons.add_rounded,
            color: ClayColors.green,
            onPressed: () => showAddExtraSheet(context, loan),
          ),
        ],
      ),
    );
  }
}

/// Un abono de la lista, con su mes y el botón de quitar.
class _AbonoTile extends StatelessWidget {
  const _AbonoTile({required this.loan, required this.index});

  final SavedLoan loan;
  final int index;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final abono = loan.extras[index];
    final pagado = abono.startMonth <= loan.paidMonths;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            pagado ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 17,
            color: pagado ? ClayColors.green : ClayColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money.format(abono.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  abono.recurring
                      ? 'Cada mes desde la cuota ${abono.startMonth} '
                            '(${shortMonth(loan.dateOf(abono.startMonth))})'
                      : 'Cuota ${abono.startMonth} · '
                            '${longMonth(loan.dateOf(abono.startMonth))}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ClayColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: ClayColors.textMuted,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => AppState.instance.removeExtra(loan, index),
          ),
        ],
      ),
    );
  }
}
