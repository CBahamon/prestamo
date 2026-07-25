import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestamo/main.dart';
import 'package:prestamo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('la app arranca y navega a las pantallas principales',
      (tester) async {
    _usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues({'currency_v1': 'COP'});
    await initializeDateFormatting('es_CO');
    await AppState.instance.init();

    await tester.pumpWidget(const PrestamoApp());
    await tester.pumpAndSettle();

    expect(find.text('Mis finanzas'), findsOneWidget);

    // Calculadora de préstamo desde el acceso rápido.
    await tester.tap(find.text('Préstamo'));
    await tester.pumpAndSettle();
    expect(find.text('Calcular préstamo'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '50000000');
    await tester.enterText(fields.at(1), '18');
    await tester.enterText(fields.at(2), '60');
    await tester.ensureVisible(find.text('Calcular'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calcular'));
    await tester.pumpAndSettle();

    expect(find.text('CUOTA MENSUAL'), findsOneWidget);

    // La tabla de amortización trae las 60 cuotas.
    await tester.ensureVisible(find.text('Ver tabla de amortización'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver tabla de amortización'));
    await tester.pumpAndSettle();
    expect(find.text('Amortización'), findsOneWidget);
    expect(find.text('Saldo'), findsOneWidget);
  });

  testWidgets('la hipoteca calcula cuota inicial', (tester) async {
    _usePhoneScreen(tester);
    SharedPreferences.setMockInitialValues({'currency_v1': 'COP'});
    await AppState.instance.init();

    await tester.pumpWidget(const PrestamoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hipoteca'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '300000000'); // valor casa
    await tester.enterText(fields.at(1), '70'); // financia 70%
    await tester.enterText(fields.at(2), '12.8'); // tasa E.A.
    await tester.enterText(fields.at(3), '20'); // años
    await tester.ensureVisible(find.text('Calcular hipoteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calcular hipoteca'));
    await tester.pumpAndSettle();

    // 30% de 300M = 90M de cuota inicial.
    expect(find.textContaining('Cuota inicial:'), findsOneWidget);
    expect(find.textContaining('90.000.000'), findsWidgets);
  });
}

/// El viewport por defecto (800x600) corta las pantallas largas.
void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
