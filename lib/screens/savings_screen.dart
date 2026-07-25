import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../models/savings_entry.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final money = app.money;

        return Scaffold(
          backgroundColor: ClayColors.background,
          body: Column(
            children: [
              ClayHeader(
                title: 'Mis ahorros',
                subtitle: 'Total: ${money.format(app.totalSavings)}',
                showBack: standalone,
              ),
              Expanded(
                child: ListView(
                  padding:
                      EdgeInsets.fromLTRB(20, 18, 20, standalone ? 30 : 120),
                  children: [
                    ClayCard(
                      color: ClayColors.pink,
                      child: Column(
                        children: [
                          Text(
                            'TOTAL AHORRADO',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            child: Text(
                              money.format(app.totalSavings),
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
                    const SizedBox(height: 18),
                    ...app.savings.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClayCard(
                          padding: const EdgeInsets.all(16),
                          onTap: () => _editSheet(context, entry: s),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: ClayColors.cyan.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded,
                                    color: ClayColors.cyan),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                              Text(
                                money.format(s.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: ClayColors.textDark,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: ClayColors.textMuted),
                                onPressed: () =>
                                    AppState.instance.deleteSavings(s.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClayButton(
                      label: 'Agregar ahorro',
                      icon: Icons.add_rounded,
                      color: ClayColors.pink,
                      onPressed: () => _editSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editSheet(BuildContext context, {SavingsEntry? entry}) {
    final nameCtrl = TextEditingController(text: entry?.name ?? '');
    final amountCtrl = TextEditingController(
      text: entry == null ? '' : formatPlain(entry.amount),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
          decoration: const BoxDecoration(
            color: ClayColors.background,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: ClayColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              ClayCard(
                child: Column(
                  children: [
                    ClayField(
                      controller: nameCtrl,
                      label: 'Nombre',
                      hint: 'Ej: Cuenta de ahorros',
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    ClayField(
                      controller: amountCtrl,
                      label: 'Monto',
                      hint: '0',
                      prefix: '${AppState.instance.currency.symbol} ',
                      money: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ClayButton(
                label: entry == null ? 'Agregar' : 'Guardar cambios',
                icon: Icons.check_rounded,
                color: ClayColors.pink,
                onPressed: () {
                  final amount = parseAmount(amountCtrl.text) ?? 0;
                  final name = nameCtrl.text.trim().isEmpty
                      ? 'Ahorro'
                      : nameCtrl.text.trim();
                  AppState.instance.upsertSavings(
                    entry == null
                        ? SavingsEntry(
                            id: const Uuid().v4(),
                            name: name,
                            amount: amount,
                            updatedAt: DateTime.now(),
                          )
                        : entry.copyWith(name: name, amount: amount),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
