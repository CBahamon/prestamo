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

  testWidgets('agregar abonos uno por uno actualiza el préstamo guardado',
      (tester) async {
    await arrancar(tester);

    // Pestaña Préstamos → detalle del préstamo guardado.
    await tester.tap(find.text('Préstamos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carro'));
    await tester.pumpAndSettle();

    // La primera vez se entra por la tarjeta vacía; después, por el botón.
    Future<void> agregarAbono(String monto, String entrada) async {
      await tester.dragUntilVisible(
        find.text(entrada),
        find.byType(ListView).first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(entrada));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo abono a capital'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, monto);
      await tester.pumpAndSettle();
      expect(find.textContaining('Con este abono te ahorras'), findsOneWidget);

      await tester.ensureVisible(find.text('Agregar abono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar abono'));
      await tester.pumpAndSettle();
    }

    await agregarAbono('500000', 'Abonos a capital');

    var guardado = AppState.instance.loans.single;
    expect(guardado.extras, hasLength(1));
    expect(guardado.extras.single.amount, 500000);
    expect(guardado.extras.single.effect, ExtraEffect.reducirPlazo);
    expect(guardado.extras.single.recurring, isFalse);
    expect(guardado.extras.single.startMonth, 1);

    // Un segundo abono en el mismo mes se suma al primero.
    await agregarAbono('300000', 'Agregar otro abono');

    guardado = AppState.instance.loans.single;
    expect(guardado.extras, hasLength(2));
    expect(guardado.result.schedule.first.extra, 800000);

    // El plazo efectivo baja respecto a los 60 meses pactados.
    expect(guardado.result.months, lessThan(60));
    expect(
      guardado.result.totalInterest,
      lessThan(guardado.baseResult.totalInterest),
    );

    // Y el detalle ya lista los abonos con su ahorro.
    expect(find.text('Mis abonos'), findsOneWidget);
    expect(find.textContaining('Te ahorras'), findsOneWidget);

    // Quitar uno vuelve a dejar la lista en un solo abono.
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(AppState.instance.loans.single.extras, hasLength(1));
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
