import 'package:flutter/material.dart';

import '../core/money.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return AnimatedBuilder(
      animation: app,
      builder: (context, _) => Scaffold(
        backgroundColor: ClayColors.background,
        body: Column(
          children: [
            const ClayHeader(
              title: 'Ajustes',
              subtitle: 'Moneda y datos locales',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                children: [
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MONEDA',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: ClayColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Detectada del celular: ${detectCurrencyCode()}',
                          style: const TextStyle(
                              fontSize: 12, color: ClayColors.textMuted),
                        ),
                        const SizedBox(height: 14),
                        ClayChips<String>(
                          options: kCurrencies.map((c) => c.code).toList(),
                          selected: app.currencyCode,
                          labelOf: (c) => c,
                          onSelect: app.setCurrency,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${app.currency.name} (${app.currency.symbol})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ClayColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATOS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: ClayColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${app.loans.length} préstamos · ${app.savings.length} bolsillos de ahorro',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Todo se guarda solo en este dispositivo. Sin cuenta, sin internet, sin publicidad.',
                          style: TextStyle(
                              fontSize: 12, color: ClayColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CÓMO SE CALCULA',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: ClayColors.textMuted,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Cuota fija (sistema francés):\n'
                          'cuota = P · i / (1 - (1+i)^-n)\n\n'
                          'La tasa se convierte a efectiva mensual antes de calcular. '
                          'Una E.A. NO se divide entre 12: se usa (1+EA)^(1/12) - 1.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: ClayColors.textDark),
                        ),
                      ],
                    ),
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
