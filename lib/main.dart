import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/currency_setup_sheet.dart';
import 'screens/home_screen.dart';
import 'screens/loan_calculator_screen.dart';
import 'screens/saved_loans_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';
import 'theme/clay.dart';
import 'widgets/clay_motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  await AppState.instance.init();
  runApp(const PrestamoApp());
}

class PrestamoApp extends StatelessWidget {
  const PrestamoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) => MaterialApp(
        title: 'Préstamos',
        debugShowCheckedModeBanner: false,
        theme: buildClayTheme(),
        home: const RootShell(),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (AppState.instance.needsCurrencySetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showCurrencySetup(context);
      });
    }
  }

  static const _tabs = [
    HomeScreen(),
    SavedLoansScreen(),
    SavingsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _tabs[_index],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CenterFab(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoanCalculatorScreen()),
        ),
      ),
      bottomNavigationBar: _ClayNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayPressable(
      onTap: onTap,
      borderRadius: 32,
      pressedScale: 0.86,
      waveColor: Colors.white,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ClayColors.purpleLight, ClayColors.purpleDark],
          ),
          border: Border.all(color: ClayColors.background, width: 5),
          boxShadow: [
            BoxShadow(
              color: ClayColors.purple.withValues(alpha: 0.5),
              offset: const Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child:
            const Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _ClayNavBar extends StatelessWidget {
  const _ClayNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Inicio'),
      (Icons.receipt_long_rounded, 'Préstamos'),
      (Icons.savings_rounded, 'Ahorros'),
      (Icons.settings_rounded, 'Ajustes'),
    ];

    return Container(
      height: 78,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).padding.bottom * 0.4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ClayColors.purpleLight, ClayColors.purple],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: ClayColors.purple.withValues(alpha: 0.4),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      // Rejilla de 5 espacios iguales: 2 ítems, el hueco del botón central y
      // otros 2 ítems. La burbuja usa esta misma rejilla, así nunca se
      // desfasa de los íconos.
      child: LayoutBuilder(
        builder: (context, constraints) {
          const slots = 5;
          final anchoSlot = constraints.maxWidth / slots;
          // El ítem 2 y 3 viven a la derecha del hueco central.
          final slotActivo = index < 2 ? index : index + 1;

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                left: slotActivo * anchoSlot + anchoSlot * 0.14,
                top: 12,
                bottom: 12,
                width: anchoSlot * 0.72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var slot = 0; slot < slots; slot++)
                    SizedBox(
                      width: anchoSlot,
                      child: slot == 2
                          ? const SizedBox.shrink()
                          : _NavItem(
                              icon: items[slot < 2 ? slot : slot - 1].$1,
                              label: items[slot < 2 ? slot : slot - 1].$2,
                              active: slotActivo == slot,
                              onTap: () =>
                                  onChanged(slot < 2 ? slot : slot - 1),
                            ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // El ícono activo salta y sube un poco.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: active ? 1 : 0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Transform.translate(
                offset: Offset(0, -4 * t),
                child: Transform.scale(scale: 1 + 0.18 * t, child: child),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
