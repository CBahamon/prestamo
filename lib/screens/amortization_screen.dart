import 'package:flutter/material.dart';

import '../core/amortization.dart';
import '../core/dates.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';
import 'export_loan.dart';

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
    this.firstPayment,
  });

  final LoanResult result;
  final String title;
  final SavedLoan? loan;

  /// Fecha de la primera cuota cuando el préstamo todavía no se guarda.
  final DateTime? firstPayment;

  @override
  Widget build(BuildContext context) {
    if (loan == null) {
      return _Tabla(
        result: result,
        title: title,
        firstPayment: firstPayment ?? nextMonthStart(),
      );
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
        return _Tabla(
          result: actual.result,
          title: title,
          loan: actual,
          firstPayment: actual.firstPayment,
        );
      },
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({
    required this.result,
    required this.title,
    required this.firstPayment,
    this.loan,
  });

  final LoanResult result;
  final String title;
  final DateTime firstPayment;
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
        trailing: loan == null
            ? null
            : IconButton(
                tooltip: 'Exportar a Excel',
                icon: const Icon(
                  Icons.file_download_outlined,
                  color: Colors.white,
                ),
                onPressed: () => exportLoanToExcel(context, loan!),
              ),
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
              loan == null ? topPadding + 12 : 8,
              20,
              6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.swipe_left_rounded,
                  size: 14,
                  color: ClayColors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Desliza la tabla para ver todas las columnas',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: ClayColors.textMuted.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // La tabla entera va en un scroll horizontal: los valores se ven
          // completos en vez de recortados en columnas de 45px.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: _anchoTabla(conAbono),
                child: Column(
                  children: [
                    ClayCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      radius: 20,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: _anchoNumero,
                            child: Text('# / MES', style: _headStyle),
                          ),
                          for (final c in _columnas(conAbono))
                            _Head(c.$1, ancho: c.$2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 30),
                        itemCount: result.schedule.length,
                        itemBuilder: (context, i) {
                          final row = result.schedule[i];
                          final pagada = row.number <= pagadas;
                          final siguiente = row.number == pagadas + 1;

                          final fila = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: pagada
                                  ? ClayColors.green.withValues(alpha: 0.13)
                                  : i.isEven
                                  ? ClayColors.surface
                                  : ClayColors.surface.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            // El borde de la próxima cuota va como decoración
                            // de frente: como borde normal robaría 3px de
                            // ancho y desbordaría la fila.
                            foregroundDecoration: siguiente && loan != null
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: ClayColors.purple.withValues(
                                        alpha: 0.55,
                                      ),
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                            child: Row(
                              children: [
                                _NumeroCuota(
                                  number: row.number,
                                  fecha: addMonths(
                                    firstPayment,
                                    row.number - 1,
                                  ),
                                  pagada: pagada,
                                  conCasilla: loan != null,
                                ),
                                _Cell(
                                  money.format(row.payment),
                                  ancho: _anchoValor,
                                  apagada: pagada,
                                ),
                                _Cell(
                                  money.format(row.interest),
                                  ancho: _anchoValor,
                                  color: ClayColors.red,
                                  apagada: pagada,
                                ),
                                _Cell(
                                  money.format(row.principal),
                                  ancho: _anchoValor,
                                  color: ClayColors.green,
                                  apagada: pagada,
                                ),
                                if (conAbono)
                                  _Cell(
                                    row.extra > 0
                                        ? money.format(row.extra)
                                        : '—',
                                    ancho: _anchoValor,
                                    color: ClayColors.purple,
                                    apagada: pagada,
                                  ),
                                _Cell(
                                  money.format(row.balance),
                                  ancho: _anchoSaldo,
                                  bold: true,
                                  apagada: pagada,
                                ),
                              ],
                            ),
                          );

                          if (loan == null) return fila;

                          // Tocar una cuota la marca como pagada junto con las
                          // anteriores; tocar una pagada la devuelve a
                          // pendiente.
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _anchoNumero = 58.0;
const _anchoValor = 118.0;
const _anchoSaldo = 126.0;

/// Ancho total: columnas + el padding horizontal de las tarjetas (14 a cada
/// lado), que si no se cuenta desborda la fila.
double _anchoTabla(bool conAbono) =>
    _anchoNumero + _anchos(conAbono).reduce((a, b) => a + b) + 28;

List<double> _anchos(bool conAbono) => [
  _anchoValor,
  _anchoValor,
  _anchoValor,
  if (conAbono) _anchoValor,
  _anchoSaldo,
];

List<(String, double)> _columnas(bool conAbono) => [
  ('Cuota', _anchoValor),
  ('Interés', _anchoValor),
  ('Capital', _anchoValor),
  if (conAbono) ('Abono', _anchoValor),
  ('Saldo', _anchoSaldo),
];

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
          const SizedBox(height: 10),
          // De lo que va pagado, cuánto bajó la deuda y cuánto se lo llevó
          // el banco.
          Row(
            children: [
              Expanded(
                child: _Acumulado(
                  label: 'A capital',
                  value: money.compact(loan.paidPrincipal),
                  color: ClayColors.green,
                ),
              ),
              Expanded(
                child: _Acumulado(
                  label: 'A intereses',
                  value: money.compact(loan.paidInterest),
                  color: ClayColors.red,
                ),
              ),
            ],
          ),
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

/// Número de cuota, mes en que se paga y —en préstamos guardados— la casilla
/// para chulearla. El número queda siempre a la vista: en 240 filas uno se
/// pierde.
class _NumeroCuota extends StatelessWidget {
  const _NumeroCuota({
    required this.number,
    required this.fecha,
    required this.pagada,
    required this.conCasilla,
  });

  final int number;
  final DateTime fecha;
  final bool pagada;
  final bool conCasilla;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _anchoNumero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _fila(),
          const SizedBox(height: 2),
          Text(
            shortMonth(fecha),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: ClayColors.textMuted.withValues(alpha: pagada ? 0.6 : 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila() {
    final numero = Text(
      '$number',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: pagada ? ClayColors.textMuted : ClayColors.purple,
        fontSize: 10.5,
      ),
    );
    if (!conCasilla) return numero;

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
        Flexible(child: numero),
      ],
    );
  }
}

/// "A capital $X" / "A intereses $Y" de lo ya pagado.
class _Acumulado extends StatelessWidget {
  const _Acumulado({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ClayColors.textMuted,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
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
  const _Head(this.text, {required this.ancho});

  final String text;
  final double ancho;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ancho,
    child: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: _headStyle,
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    required this.ancho,
    this.color,
    this.bold = false,
    this.apagada = false,
  });

  final String text;
  final double ancho;
  final Color? color;
  final bool bold;

  /// Las cuotas pagadas se ven atenuadas: ya no hay que mirarlas.
  final bool apagada;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Padding(
        // Aire entre columnas: pegadas se leen como un solo número.
        padding: const EdgeInsets.only(left: 8),
        child: Opacity(
          opacity: apagada ? 0.6 : 1,
          child: Text(
            text,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? ClayColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
