import 'package:flutter/material.dart';

import '../core/amortization.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

/// Agrega un abono a capital al préstamo. Se pueden agregar los que sean,
/// incluso varios en el mismo mes.
Future<void> showAddExtraSheet(BuildContext context, SavedLoan loan) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddExtraSheet(loan: loan),
  );
}

class _AddExtraSheet extends StatefulWidget {
  const _AddExtraSheet({required this.loan});

  final SavedLoan loan;

  @override
  State<_AddExtraSheet> createState() => _AddExtraSheetState();
}

class _AddExtraSheetState extends State<_AddExtraSheet> {
  final _amount = TextEditingController();
  late final TextEditingController _month = TextEditingController(
    text: '$_mesSugerido',
  );

  ExtraEffect _effect = ExtraEffect.reducirPlazo;
  bool _recurring = false;

  /// Por defecto, la próxima cuota sin pagar.
  int get _mesSugerido =>
      (widget.loan.paidMonths + 1).clamp(1, widget.loan.months);

  @override
  void dispose() {
    _amount.dispose();
    _month.dispose();
    super.dispose();
  }

  ExtraPayment? get _nuevo {
    final monto = parseAmount(_amount.text);
    if (monto == null || monto <= 0) return null;
    final mes = parseAmount(_month.text)?.round() ?? _mesSugerido;
    return ExtraPayment(
      amount: monto,
      effect: _effect,
      startMonth: mes.clamp(1, widget.loan.months),
      recurring: _recurring,
    );
  }

  /// Cómo queda el crédito si se agrega este abono a los que ya hay.
  ExtraSavings? get _savings {
    final nuevo = _nuevo;
    if (nuevo == null) return null;
    return ExtraSavings(
      sinAbonos: widget.loan.result,
      conAbonos: calculateLoan(
        amount: widget.loan.amount,
        monthlyRate: widget.loan.monthlyRate,
        months: widget.loan.months,
        system: widget.loan.system,
        uvr: widget.loan.uvr,
        extras: [...widget.loan.extras, nuevo],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final symbol = AppState.instance.currency.symbol;
    final savings = _savings;
    final nuevo = _nuevo;
    final mes = nuevo?.startMonth ?? _mesSugerido;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        decoration: const BoxDecoration(
          color: ClayColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ClayColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nuevo abono a capital',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Plata extra que le metes al préstamo además de la cuota.',
                style: TextStyle(fontSize: 12.5, color: ClayColors.textMuted),
              ),
              const SizedBox(height: 18),
              ClayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClayField(
                      controller: _amount,
                      label: 'Cuánto abonas',
                      hint: '0',
                      prefix: '$symbol ',
                      money: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ClayField(
                      controller: _month,
                      label: 'En la cuota',
                      hint: '$_mesSugerido',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      longMonth(widget.loan.dateOf(mes)),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ClayColors.purple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClayChips<bool>(
                      label: 'Cada cuánto',
                      options: const [false, true],
                      selected: _recurring,
                      labelOf: (r) => r ? 'Y todos los meses' : 'Solo ese mes',
                      onSelect: (r) => setState(() => _recurring = r),
                    ),
                    const SizedBox(height: 16),
                    ClayChips<ExtraEffect>(
                      label: 'Qué quieres bajar',
                      options: ExtraEffect.values,
                      selected: _effect,
                      labelOf: (e) => e.label,
                      onSelect: (e) => setState(() => _effect = e),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _effect.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ClayColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (savings != null) ...[
                const SizedBox(height: 16),
                ClayCard(
                  color: ClayColors.green,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Con este abono te ahorras '
                        '${money.format(savings.interesAhorrado)} más',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        savings.mesesAhorrados > 0
                            ? 'Terminas ${savings.mesesAhorrados} meses antes: '
                                  '${savings.conAbonos.months} en vez de '
                                  '${savings.sinAbonos.months}'
                            : 'La cuota queda en '
                                  '${money.format(savings.cuotaNueva)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ComoFunciona(savings: savings, extra: nuevo!),
              ],
              const SizedBox(height: 18),
              ClayButton(
                label: 'Agregar abono',
                icon: Icons.add_rounded,
                color: ClayColors.green,
                onPressed: nuevo == null
                    ? null
                    : () {
                        AppState.instance.addExtra(widget.loan, nuevo);
                        Navigator.pop(context);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Por qué un abono mueve el reparto interés/capital, con los números del
/// propio préstamo. Corto a propósito: la idea cabe en tres renglones.
class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona({required this.savings, required this.extra});

  final ExtraSavings savings;
  final ExtraPayment extra;

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final sin = savings.sinAbonos.schedule;
    final con = savings.conAbonos.schedule;

    // El mes siguiente al abono es donde se ve el cambio.
    final i = extra.startMonth.clamp(0, con.length - 1);
    final muestra = i < sin.length && i < con.length;

    return ClayCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 17, color: ClayColors.purple),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'El abono va 100% a capital',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            extra.effect == ExtraEffect.reducirPlazo
                ? 'Baja el saldo de una, así el mes siguiente el banco te cobra '
                      'menos interés. Como la cuota no cambia, esa plata pasa a '
                      'capital y el crédito se acorta solo.'
                : 'Baja el saldo de una y con ese saldo nuevo se recalcula la '
                      'cuota para el plazo que queda.',
            style: const TextStyle(
              fontSize: 12,
              color: ClayColors.textMuted,
              height: 1.4,
            ),
          ),
          if (muestra) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ClayColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Cuota ${i + 1}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ClayColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Cambio(
                    label: 'Interés',
                    antes: money.compact(sin[i].interest),
                    despues: money.compact(con[i].interest),
                    color: ClayColors.red,
                  ),
                  const SizedBox(height: 4),
                  _Cambio(
                    label: 'Capital',
                    antes: money.compact(sin[i].principal),
                    despues: money.compact(con[i].principal),
                    color: ClayColors.green,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Al banco pídeselo así: «abono a capital, '
            '${extra.effect == ExtraEffect.reducirPlazo ? "reducir plazo" : "reducir cuota"}». '
            'Si no, muchos lo aplican como cuotas adelantadas.',
            style: const TextStyle(
              fontSize: 10.5,
              color: ClayColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cambio extends StatelessWidget {
  const _Cambio({
    required this.label,
    required this.antes,
    required this.despues,
    required this.color,
  });

  final String label;
  final String antes;
  final String despues;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: ClayColors.textMuted),
          ),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                Text(
                  antes,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ClayColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: ClayColors.textMuted,
                  ),
                ),
                Text(
                  despues,
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
      ],
    );
  }
}
