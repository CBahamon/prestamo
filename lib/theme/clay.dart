import 'package:flutter/material.dart';

/// Paleta claymorphism: base lavanda, morado principal y acentos suaves.
class ClayColors {
  static const purple = Color(0xFF6C5CE7);
  static const purpleDark = Color(0xFF5344C4);
  static const purpleLight = Color(0xFF8B7BF0);
  static const background = Color(0xFFEDEAFB);
  static const surface = Color(0xFFFFFFFF);
  static const green = Color(0xFF4CD08A);
  static const pink = Color(0xFFF77E9C);
  static const cyan = Color(0xFF7ED8E4);
  static const red = Color(0xFFEF5E5E);
  static const textDark = Color(0xFF2C2A4A);
  static const textMuted = Color(0xFF8B88A8);
}

/// Sombra doble: oscura abajo-derecha + luz arriba-izquierda.
List<BoxShadow> claySoft({Color? base, double depth = 1}) {
  final b = base ?? ClayColors.purple;
  return [
    BoxShadow(
      color: b.withValues(alpha: 0.18),
      offset: Offset(6 * depth, 8 * depth),
      blurRadius: 18 * depth,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.85),
      offset: Offset(-4 * depth, -4 * depth),
      blurRadius: 12 * depth,
    ),
  ];
}

ThemeData buildClayTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ClayColors.purple,
      primary: ClayColors.purple,
      surface: ClayColors.surface,
    ),
    scaffoldBackgroundColor: ClayColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ClayColors.textDark,
      displayColor: ClayColors.textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: ClayColors.textDark,
      titleTextStyle: TextStyle(
        color: ClayColors.textDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
