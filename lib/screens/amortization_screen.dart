import 'package:flutter/material.dart';

import '../core/amortization.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

/// Tabla de amortización mes a mes.
///
/// Con [loan] la tabla es interactiva: se chulean las cuotas pagadas y se ve
/// el avance. Sin él (préstamo recién calculado, sin guardar) es solo lectura.
class AmortizationScreen extends StatelessWidget {
  const AmortizationScreen({
    super.key,
    required this.result,
    required this.title,
    this.loan,
  });

  final LoanResult result;
  final String title;
  final SavedLoan? loan;

  @override
  Widget build(BuildContext context) {
    if (loan == null) {
      return _Tabla(result: result, title: title);
    }
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        // Se relee del estado: los chulazos y los abonos cambian la tabla.
        final actual = app.loans.firstWhere(
          (l) => l.id == loan!.id,
          orElse: () => loan!,
        );
        return _Tabla(result: actual.result, title: title, loan: actual);
      },
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({required this.result, required this.title, this.loan});

  final LoanResult result;
  final String title;
  final SavedLoan? loan;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final pagadas = loan?.paidMonths ?? 0;
    final conAbono = result.totalExtra > 0;

    return ClayScaffold(
      header: ClayHeader(
        title: title,
        subtitle: [
          loan == null
              ? '${result.months} cuotas'
              : '$pagadas de ${result.months} cuotas pagadas',
          'intereses ${money.compact(result.totalInterest)}',
          if (conAbono) 'abonos ${money.compact(result.totalExtra)}',
          if (result.isUvr) 'en pesos proyectados',
        ].join(' · '),
        showBack: true,
      ),
      builder: (context, topPadding) => Column(
        children: [
          if (loan != null)
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 4),
              child: _ProgresoBar(loan: loan!),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              loan == null ? topPadding + 12 : 10,
              20,
              10,
            ),
            child: ClayCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 20,
              child: Row(
                children: [
                  const SizedBox(
                    width: 45,
                    child: Text('#', style: _headStyle),
                  ),
                  const _Head('Cuota'),
                  const _Head('Interés'),
                  const _Head('Capital'),
                  if (conAbono) const _Head('Abono'),
                  const _Head('Saldo'),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              itemCount: result.schedule.length,
              itemBuilder: (context, i) {
                final row = result.schedule[i];
                final pagada = row.number <= pagadas;
                final siguiente = row.number == pagadas + 1;

                final fila = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: pagada
                        ? ClayColors.green.withValues(alpha: 0.13)
                        : i.isEven
                        ? ClayColors.surface
                        : ClayColors.surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: siguiente && loan != null
                        ? Border.all(
                            color: ClayColors.purple.withValues(alpha: 0.55),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 45,
                        child: loan == null
                            ? Text(
                                '${row.number}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ClayColors.purple,
                                  fontSize: 12,
                                ),
                              )
                            : _Chulo(number: row.number, pagada: pagada),
                      ),
                      _Cell(money.compact(row.payment), apagada: pagada),
                      _Cell(
                        money.compact(row.interest),
                        color: ClayColors.red,
                        apagada: pagada,
                      ),
                      _Cell(
                        money.compact(row.principal),
                        color: ClayColors.green,
                        apagada: pagada,
                      ),
                      if (conAbono)
                        _Cell(
                          row.extra > 0 ? money.compact(row.extra) : '—',
                          color: ClayColors.purple,
                          apagada: pagada,
                        ),
                      _Cell(
                        money.compact(row.balance),
                        bold: true,
                        apagada: pagada,
                      ),
                    ],
                  ),
                );

                if (loan == null) return fila;

                // Tocar una cuota la marca como pagada junto con todas las
                // anteriores; tocar una ya pagada la devuelve a pendiente.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => AppState.instance.setPaidCount(
                    loan!,
                    pagada ? row.number - 1 : row.number,
                  ),
                  child: fila,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de avance del crédito.
class _ProgresoBar extends StatelessWidget {
  const _ProgresoBar({required this.loan});

  final SavedLoan loan;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final porcentaje = (loan.progress * 100).round();

    return ClayCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$porcentaje% pagado',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ClayColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    loan.isPaidOff
                        ? '¡Crédito saldado!'
                        : 'Falta ${money.compact(loan.remainingBalance)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ClayColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClayProgress(value: loan.progress),
          const SizedBox(height: 8),
          Text(
            loan.isPaidOff
                ? 'Pagaste las ${loan.result.months} cuotas.'
                : 'Toca una cuota para marcarla pagada. Vuelve a tocarla para '
                      'deshacer.',
            style: const TextStyle(fontSize: 11, color: ClayColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Casilla de la cuota: se llena de verde al chulearla. El número queda
/// siempre a la vista, que en 240 filas uno se pierde.
class _Chulo extends StatelessWidget {
  const _Chulo({required this.number, required this.pagada});

  final int number;
  final bool pagada;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pagada ? ClayColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: pagada
                  ? ClayColors.green
                  : ClayColors.purple.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: pagada
              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 22,
          child: Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: pagada ? ClayColors.textMuted : ClayColors.purple,
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    );
  }
}

const _headStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: ClayColors.textMuted,
  letterSpacing: 0.4,
);

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: 3,
    child: Text(text, textAlign: TextAlign.right, style: _headStyle),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    this.color,
    this.bold = false,
    this.apagada = false,
  });

  final String text;
  final Color? color;
  final bool bold;

  /// Las cuotas pagadas se ven atenuadas: ya no hay que mirarlas.
  final bool apagada;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Opacity(
        opacity: apagada ? 0.45 : 1,
        child: Text(
          text,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? ClayColors.textDark,
          ),
        ),
      ),
    );
  }
}
