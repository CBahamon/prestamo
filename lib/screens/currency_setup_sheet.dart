import 'package:flutter/material.dart';

import '../core/money.dart';
import '../state/app_state.dart';
import '../theme/clay.dart';
import '../widgets/clay_widgets.dart';

/// Se muestra una sola vez, al primer arranque: la región del celular no
/// alcanza para saber en qué moneda piensa el usuario.
Future<void> showCurrencySetup(BuildContext context) async {
  var selected = AppState.instance.currencyCode;

  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 34),
        decoration: const BoxDecoration(
          color: ClayColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿En qué moneda trabajas?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Se puede cambiar después en Ajustes.',
              style: TextStyle(fontSize: 13, color: ClayColors.textMuted),
            ),
            const SizedBox(height: 20),
            ClayCard(
              child: ClayChips<String>(
                options: kCurrencies.map((c) => c.code).toList(),
                selected: selected,
                labelOf: (c) => c,
                onSelect: (c) => setSheetState(() => selected = c),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              currencyByCode(selected).name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ClayColors.textDark,
              ),
            ),
            const SizedBox(height: 18),
            ClayButton(
              label: 'Continuar',
              icon: Icons.check_rounded,
              onPressed: () {
                AppState.instance.setCurrency(selected);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
