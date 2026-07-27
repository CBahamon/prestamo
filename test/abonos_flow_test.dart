import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestamo/core/amortization.dart';
import 'package:prestamo/core/rates.dart';
import 'package:prestamo/main.dart';
import 'package:prestamo/models/saved_loan.dart';
import 'package:prestamo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final prestamo = SavedLoan(
    id: 'test-1',
    name: 'Carro',
    kind: LoanKind.prestamo,
    amount: 50000000,
    ratePercent: 18,
    rateType: RateType.efectivaAnual,
    months: 60,
    currencyCode: 'COP',
    createdAt: DateTime(2026, 1, 15),
  );

  Future<void> arrancar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'currency_v1': 'COP',
      'loans_v1': jsonEncode([prestamo.toJson()]),
    });
    await initializeDateFormatting('es_CO');
    await AppState.instance.init();

    await tester.pumpWidget(const PrestamoApp());
    await tester.pumpAndSettle();
  }

  testWidgets('configurar un abono actualiza el préstamo guardado',
      (tester) async {
    await arrancar(tester);

    // Pestaña Préstamos → detalle del préstamo guardado.
    await tester.tap(find.text('Préstamos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carro'));
    await tester.pumpAndSettle();

    // La invitación a abonar está más abajo, después del avance del crédito.
    await tester.dragUntilVisible(
      find.text('¿Vas a hacer abonos a capital?'),
      find.byType(ListView).first,
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Vas a hacer abonos a capital?'), findsOneWidget);

    await tester.tap(find.text('¿Vas a hacer abonos a capital?'));
    await tester.pumpAndSettle();

    expect(find.text('Abonos a capital'), findsOneWidget);

    // 500.000 mensuales reduciendo plazo (opción por defecto).
    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Te ahorras'), findsOneWidget);
    expect(find.textContaining('meses antes'), findsOneWidget);

    await tester.ensureVisible(find.text('Guardar abonos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar abonos'));
    await tester.pumpAndSettle();

    // Queda persistido en el estado, con el efecto elegido.
    final guardado = AppState.instance.loans.single;
    expect(guardado.extra, isNotNull);
    expect(guardado.extra!.amount, 500000);
    expect(guardado.extra!.effect, ExtraEffect.reducirPlazo);
    expect(guardado.extra!.recurring, isTrue);

    // El plazo efectivo baja respecto a los 60 meses pactados.
    expect(guardado.result.months, lessThan(60));
    expect(
      guardado.result.totalInterest,
      lessThan(guardado.baseResult.totalInterest),
    );

    // Y el detalle ya muestra el ahorro en vez de la invitación.
    expect(find.textContaining('Ahorras'), findsOneWidget);
    expect(find.text('¿Vas a hacer abonos a capital?'), findsNothing);
  });

  testWidgets('el selector préstamo/hipotecario cambia el formulario',
      (tester) async {
    await arrancar(tester);

    // El botón central abre la calculadora en modo préstamo.
    await tester.tap(find.byIcon(Icons.calculate_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Calcular préstamo'), findsOneWidget);
    expect(find.text('Valor del préstamo'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Hipotecario'));
    await tester.pumpAndSettle();

    expect(find.text('Crédito hipotecario'), findsOneWidget);
    expect(find.text('Valor de la casa'.toUpperCase()), findsOneWidget);

    // La opción UVR muestra los campos de proyección.
    expect(find.text('UVR HOY'), findsNothing);
    await tester.tap(find.text('UVR'));
    await tester.pumpAndSettle();
    expect(find.text('UVR HOY'), findsOneWidget);
    expect(find.text('INFLACIÓN'), findsOneWidget);
  });
}
