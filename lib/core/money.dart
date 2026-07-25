import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Monedas disponibles. La app arranca con la del celular; si el país no
/// está en la lista, cae en COP.
class CurrencyOption {
  const CurrencyOption(this.code, this.symbol, this.name, this.decimals);

  final String code;
  final String symbol;
  final String name;
  final int decimals;
}

const kCurrencies = <CurrencyOption>[
  CurrencyOption('COP', r'$', 'Peso colombiano', 0),
  CurrencyOption('USD', r'$', 'Dólar', 2),
  CurrencyOption('EUR', '€', 'Euro', 2),
  CurrencyOption('MXN', r'$', 'Peso mexicano', 2),
  CurrencyOption('ARS', r'$', 'Peso argentino', 2),
  CurrencyOption('CLP', r'$', 'Peso chileno', 0),
  CurrencyOption('PEN', 'S/', 'Sol peruano', 2),
  CurrencyOption('BRL', r'R$', 'Real', 2),
  CurrencyOption('UYU', r'$U', 'Peso uruguayo', 2),
  CurrencyOption('CRC', '₡', 'Colón', 0),
  CurrencyOption('GBP', '£', 'Libra', 2),
];

const _countryToCurrency = {
  'CO': 'COP',
  'US': 'USD',
  'MX': 'MXN',
  'AR': 'ARS',
  'CL': 'CLP',
  'PE': 'PEN',
  'BR': 'BRL',
  'UY': 'UYU',
  'CR': 'CRC',
  'GB': 'GBP',
  'ES': 'EUR',
  'FR': 'EUR',
  'DE': 'EUR',
  'IT': 'EUR',
};

CurrencyOption currencyByCode(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies[0]);

/// Moneda sugerida por el dispositivo (Colombia por defecto).
///
/// Ojo con `es-US`: es la configuración típica de un latino en un celular
/// vendido con inglés de EE.UU., no la de alguien que cobra en dólares. Si el
/// idioma es español y la región es US, no se asume USD.
String detectCurrencyCode() {
  final locales = [
    PlatformDispatcher.instance.locale,
    ...PlatformDispatcher.instance.locales,
  ];

  for (final locale in locales) {
    final country = locale.countryCode;
    if (country == null || !_countryToCurrency.containsKey(country)) continue;
    if (country == 'US' && locale.languageCode == 'es') continue;
    return _countryToCurrency[country]!;
  }
  return 'COP';
}

class Money {
  Money(this.currency);

  final CurrencyOption currency;

  NumberFormat get _number => NumberFormat.decimalPatternDigits(
    locale: 'es_CO',
    decimalDigits: currency.decimals,
  );

  NumberFormat get _compactNumber => NumberFormat.compact(locale: 'es_CO');

  /// Siempre con el símbolo adelante: "$ 1.250.000".
  String format(num value) => '${currency.symbol} ${_number.format(value)}';

  /// Para montos grandes en tarjetas pequeñas: "$ 12,5 M".
  String compact(num value) => value.abs() >= 1000000
      ? '${currency.symbol} ${_compactNumber.format(value)}'
      : format(value);
}

final _plainNumber = NumberFormat.decimalPattern('es_CO');

String formatPlain(num value, {int decimals = 0}) {
  _plainNumber.minimumFractionDigits = decimals;
  _plainNumber.maximumFractionDigits = decimals;
  return _plainNumber.format(value);
}

/// Va poniendo los puntos de miles mientras se escribe: 12000000 → 12.000.000.
/// Acepta una coma decimal (formato colombiano) y la deja pasar tal cual.
class MilesInputFormatter extends TextInputFormatter {
  const MilesInputFormatter({this.maxDecimals = 2, this.maxDigits = 12});

  final int maxDecimals;

  /// Tope de dígitos enteros: 12 llega a 999.999.999.999, de sobra en pesos.
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    // Solo dígitos y una coma decimal.
    var clean = raw.replaceAll(RegExp(r'[^\d,]'), '');
    final firstComma = clean.indexOf(',');
    if (firstComma >= 0) {
      clean =
          clean.substring(0, firstComma + 1) +
          clean.substring(firstComma + 1).replaceAll(',', '');
    }

    var entera = firstComma >= 0 ? clean.substring(0, firstComma) : clean;
    var decimales = firstComma >= 0 ? clean.substring(firstComma + 1) : null;
    if (decimales != null && decimales.length > maxDecimals) {
      decimales = decimales.substring(0, maxDecimals);
    }

    // Los ceros a la izquierda estorban ("007" → "7"), pero "0," es válido.
    entera = entera.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (entera.length > maxDigits) {
      // Pasado el tope se ignora la tecla: se conserva lo que ya estaba.
      return oldValue;
    }

    final agrupada = entera.isEmpty
        ? ''
        : formatPlain(int.parse(entera), decimals: 0);
    final texto = decimales == null ? agrupada : '$agrupada,$decimales';

    // El cursor se ancla contando dígitos desde el final, así los puntos que
    // aparecen o desaparecen no lo mueven de lugar.
    final digitosDespuesDelCursor = raw
        .substring(newValue.selection.end.clamp(0, raw.length))
        .replaceAll(RegExp(r'[^\d,]'), '')
        .length;
    var offset = texto.length;
    var contados = 0;
    while (offset > 0 && contados < digitosDespuesDelCursor) {
      offset--;
      if (RegExp(r'[\d,]').hasMatch(texto[offset])) contados++;
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Convierte lo que el usuario escribe ("12.000.000" o "12000000,5") a double.
double? parseAmount(String raw) {
  if (raw.trim().isEmpty) return null;
  var s = raw.replaceAll(RegExp(r'[^\d,.\-]'), '');
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma > lastDot) {
    // coma decimal (formato es-CO)
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    // punto decimal o solo separadores de miles
    s = s.replaceAll(',', '');
    final parts = s.split('.');
    if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
      s = parts.join();
    }
  }
  return double.tryParse(s);
}
