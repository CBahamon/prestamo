import 'package:flutter/material.dart';

import '../core/rates.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_motion.dart';
import '../widgets/clay_widgets.dart';
import 'loan_calculator_screen.dart';
import 'loan_detail_screen.dart';
import 'mortgage_screen.dart';
import 'saved_loans_screen.dart';
import 'savings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final money = app.money;
        final recent = app.loans.take(3).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(child: _SummaryCard()),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 90),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClayIconButton(
                          icon: Icons.calculate_rounded,
                          label: 'Préstamo',
                          color: ClayColors.purple,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoanCalculatorScreen(),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClayIconButton(
                          icon: Icons.home_work_rounded,
                          label: 'Hipoteca',
                          color: ClayColors.green,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MortgageScreen(),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClayIconButton(
                          icon: Icons.savings_rounded,
                          label: 'Ahorros',
                          color: ClayColors.pink,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SavingsScreen(standalone: true),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClayIconButton(
                          icon: Icons.folder_rounded,
                          label: 'Guardados',
                          color: ClayColors.cyan,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SavedLoansScreen(standalone: true),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ClayCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: ClayColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aún no guardas préstamos. Calcula uno y toca "Guardar".',
                            style: TextStyle(
                              color: ClayColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recent.map(
                  (l) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: ClayCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LoanDetailScreen(loan: l),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  (l.propertyValue != null
                                          ? ClayColors.green
                                          : ClayColors.purple)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              l.propertyValue != null
                                  ? Icons.home_work_rounded
                                  : Icons.request_quote_rounded,
                              color: l.propertyValue != null
                                  ? ClayColors.green
                                  : ClayColors.purple,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${l.months} meses · ${l.ratePercent.toStringAsFixed(2)}% ${l.rateType.label}',
                                  style: const TextStyle(
                                    color: ClayColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            money.compact(l.result.payment),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ClayColors.purple,
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
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final money = app.money;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 210,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ClayColors.purpleLight, ClayColors.purple],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 22,
            right: 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mis finanzas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      app.currencyCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClayCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AHORRADO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: ClayColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      money.format(app.totalSavings),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ClayColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Cuotas / mes',
                            value: money.compact(app.totalMonthlyPayments),
                            color: ClayColors.pink,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: ClayColors.background,
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Deuda total',
                            value: money.compact(app.totalDebt),
                            color: ClayColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: ClayColors.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
