import 'package:flutter/material.dart';

import '../core/amortization.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

/// Tabla de amortización mes a mes.
class AmortizationScreen extends StatelessWidget {
  const AmortizationScreen({
    super.key,
    required this.result,
    required this.title,
  });

  final LoanResult result;
  final String title;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;

    return ClayScaffold(
      header: ClayHeader(
        title: title,
        subtitle: [
          '${result.months} cuotas',
          'intereses ${money.compact(result.totalInterest)}',
          if (result.totalExtra > 0)
            'abonos ${money.compact(result.totalExtra)}',
          if (result.isUvr) 'en pesos proyectados',
        ].join(' · '),
        showBack: true,
      ),
      builder: (context, topPadding) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 10),
            child: ClayCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 20,
              child: Row(
                children: [
                  const SizedBox(
                    width: 30,
                    child: Text('#', style: _headStyle),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Cuota',
                      textAlign: TextAlign.right,
                      style: _headStyle,
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Interés',
                      textAlign: TextAlign.right,
                      style: _headStyle,
                    ),
                  ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Capital',
                      textAlign: TextAlign.right,
                      style: _headStyle,
                    ),
                  ),
                  if (result.totalExtra > 0)
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Abono',
                        textAlign: TextAlign.right,
                        style: _headStyle,
                      ),
                    ),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Saldo',
                      textAlign: TextAlign.right,
                      style: _headStyle,
                    ),
                  ),
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
                final even = i.isEven;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: even
                        ? ClayColors.surface
                        : ClayColors.surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${row.number}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ClayColors.purple,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _Cell(money.compact(row.payment)),
                      _Cell(money.compact(row.interest), color: ClayColors.red),
                      _Cell(
                        money.compact(row.principal),
                        color: ClayColors.green,
                      ),
                      if (result.totalExtra > 0)
                        _Cell(
                          row.extra > 0 ? money.compact(row.extra) : '—',
                          color: ClayColors.purple,
                        ),
                      _Cell(money.compact(row.balance), bold: true),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _headStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: ClayColors.textMuted,
  letterSpacing: 0.4,
);

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.color, this.bold = false});

  final String text;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
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
    );
  }
}
