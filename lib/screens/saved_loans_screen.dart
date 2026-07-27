import 'package:flutter/material.dart';

import '../models/saved_loan.dart';
import '../core/rates.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_motion.dart';
import '../widgets/clay_widgets.dart';
import 'loan_detail_screen.dart';

class SavedLoansScreen extends StatelessWidget {
  const SavedLoansScreen({super.key, this.standalone = false});

  /// true cuando se abre desde el acceso rápido (muestra flecha atrás).
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final money = app.money;
        final loans = app.loans;

        return ClayScaffold(
          header: ClayHeader(
            title: 'Mis préstamos',
            subtitle: loans.isEmpty
                ? 'Nada guardado todavía'
                : '${loans.length} guardados · ${money.compact(app.totalMonthlyPayments)} al mes',
            showBack: standalone,
          ),
          builder: (context, topPadding) => loans.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: const _Empty(),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    topPadding + 18,
                    20,
                    standalone ? 30 : 120,
                  ),
                  itemCount: loans.length,
                  itemBuilder: (context, i) => FadeSlideIn(
                    delay: Duration(milliseconds: 70 * (i < 6 ? i : 6)),
                    child: _LoanTile(loan: loans[i]),
                  ),
                ),
        );
      },
    );
  }
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final isMortgage = loan.kind == LoanKind.hipoteca;
    final color = isMortgage ? ClayColors.green : ClayColors.purple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayCard(
        padding: const EdgeInsets.all(18),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => LoanDetailScreen(loan: loan))),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    isMortgage
                        ? Icons.home_work_rounded
                        : Icons.request_quote_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${money.compact(loan.amount)} · ${loan.months} meses · ${loan.ratePercent.toStringAsFixed(2)}% ${loan.rateType.label}',
                        style: const TextStyle(
                          color: ClayColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: ClayColors.background),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loan.isPaidOff
                      ? 'Saldado'
                      : loan.paidMonths > 0
                      ? 'Próxima cuota'
                      : loan.result.paymentVaries
                      ? 'Primera cuota'
                      : 'Cuota mensual',
                  style: const TextStyle(
                    color: ClayColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      money.format(loan.nextRow?.totalOut ?? loan.paidSoFar),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: loan.isPaidOff ? ClayColors.green : color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (loan.paidMonths > 0) ...[
              const SizedBox(height: 12),
              ClayProgress(value: loan.progress, height: 8),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${loan.paidMonths} de ${loan.result.months} cuotas pagadas',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ClayColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.folder_open_rounded,
              size: 60,
              color: ClayColors.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'Calcula un préstamo o una hipoteca\ny tócale "Guardar".',
              textAlign: TextAlign.center,
              style: TextStyle(color: ClayColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
