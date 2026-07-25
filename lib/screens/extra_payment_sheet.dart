import 'package:flutter/material.dart';

import '../core/amortization.dart';
import '../core/money.dart';
import '../models/saved_loan.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

/// Configura abonos extraordinarios a capital sobre un préstamo guardado.
/// Muestra en vivo cuánto interés ahorra y cuántos meses recorta.
Future<void> showExtraPaymentSheet(BuildContext context, SavedLoan loan) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ExtraPaymentSheet(loan: loan),
  );
}

class _ExtraPaymentSheet extends StatefulWidget {
  const _ExtraPaymentSheet({required this.loan});

  final SavedLoan loan;

  @override
  State<_ExtraPaymentSheet> createState() => _ExtraPaymentSheetState();
}

class _ExtraPaymentSheetState extends State<_ExtraPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.loan.extra == null
        ? ''
        : formatPlain(widget.loan.extra!.amount),
  );
  late final TextEditingController _startMonth = TextEditingController(
    text: '${widget.loan.extra?.startMonth ?? 1}',
  );

  late ExtraEffect _effect =
      widget.loan.extra?.effect ?? ExtraEffect.reducirPlazo;
  late bool _recurring = widget.loan.extra?.recurring ?? true;

  @override
  void dispose() {
    _amount.dispose();
    _startMonth.dispose();
    super.dispose();
  }

  ExtraPayment? get _extra {
    final monto = parseAmount(_amount.text);
    if (monto == null || monto <= 0) return null;
    final desde = parseAmount(_startMonth.text)?.round() ?? 1;
    return ExtraPayment(
      amount: monto,
      effect: _effect,
      startMonth: desde.clamp(1, widget.loan.months),
      recurring: _recurring,
    );
  }

  ExtraSavings? get _savings {
    final extra = _extra;
    if (extra == null) return null;
    return ExtraSavings(
      sinAbonos: widget.loan.baseResult,
      conAbonos: calculateLoan(
        amount: widget.loan.amount,
        monthlyRate: widget.loan.monthlyRate,
        months: widget.loan.months,
        system: widget.loan.system,
        uvr: widget.loan.uvr,
        extra: extra,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = AppState.instance.money;
    final symbol = AppState.instance.currency.symbol;
    final savings = _savings;

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
                'Abonos a capital',
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
                      label: 'Valor del abono',
                      hint: '0',
                      prefix: '$symbol ',
                      money: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ClayChips<bool>(
                      label: 'Cada cuánto',
                      options: const [true, false],
                      selected: _recurring,
                      labelOf: (r) => r ? 'Todos los meses' : 'Una sola vez',
                      onSelect: (r) => setState(() => _recurring = r),
                    ),
                    const SizedBox(height: 16),
                    ClayField(
                      controller: _startMonth,
                      label: _recurring ? 'Desde la cuota' : 'En la cuota',
                      hint: '1',
                      onChanged: (_) => setState(() {}),
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
                        'Te ahorras ${money.format(savings.interesAhorrado)} '
                        'en intereses',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _effect == ExtraEffect.reducirPlazo
                            ? 'Terminas ${savings.mesesAhorrados} meses antes: '
                                  '${savings.conAbonos.months} en vez de '
                                  '${savings.sinAbonos.months}'
                            : 'La cuota baja a '
                                  '${money.format(savings.cuotaNueva)} '
                                  'manteniendo los ${savings.sinAbonos.months} meses',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ClayButton(
                label: 'Guardar abonos',
                icon: Icons.check_rounded,
                color: ClayColors.green,
                onPressed: _extra == null
                    ? null
                    : () {
                        AppState.instance.updateLoan(
                          widget.loan.copyWith(extra: _extra),
                        );
                        Navigator.pop(context);
                      },
              ),
              if (widget.loan.extra != null) ...[
                const SizedBox(height: 10),
                ClayButton(
                  label: 'Quitar abonos',
                  icon: Icons.close_rounded,
                  color: ClayColors.red,
                  onPressed: () {
                    AppState.instance.updateLoan(
                      widget.loan.copyWith(clearExtra: true),
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
