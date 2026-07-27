import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../models/saved_loan.dart';
import '../models/savings_entry.dart';

const _kLoans = 'loans_v1';
const _kSavings = 'savings_v1';
const _kCurrency = 'currency_v1';

/// Estado global: préstamos guardados, ahorros y moneda. Persistido local.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  late SharedPreferences _prefs;
  bool ready = false;

  List<SavedLoan> loans = [];
  List<SavingsEntry> savings = [];
  String currencyCode = 'COP';

  /// true hasta que el usuario confirma la moneda la primera vez.
  /// La región del celular no es confiable (ver [detectCurrencyCode]).
  bool needsCurrencySetup = false;

  CurrencyOption get currency => currencyByCode(currencyCode);
  Money get money => Money(currency);

  double get totalSavings =>
      savings.fold<double>(0, (sum, s) => sum + s.amount);

  /// Lo que toca pagar este mes: los créditos ya saldados no suman.
  double get totalMonthlyPayments => loans.fold<double>(
    0,
    (sum, l) => sum + (l.nextRow?.totalOut ?? 0),
  );

  /// Deuda viva: saldo pendiente, no el monto original.
  double get totalDebt =>
      loans.fold<double>(0, (sum, l) => sum + l.remainingBalance);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final storedCurrency = _prefs.getString(_kCurrency);
    currencyCode = storedCurrency ?? detectCurrencyCode();
    needsCurrencySetup = storedCurrency == null;

    loans = _decode(_kLoans).map(SavedLoan.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    savings = _decode(_kSavings).map(SavingsEntry.fromJson).toList();

    ready = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setCurrency(String code) async {
    currencyCode = code;
    needsCurrencySetup = false;
    await _prefs.setString(_kCurrency, code);
    notifyListeners();
  }

  Future<void> addLoan(SavedLoan loan) async {
    loans = [loan, ...loans];
    await _persistLoans();
  }

  Future<void> updateLoan(SavedLoan loan) async {
    final i = loans.indexWhere((l) => l.id == loan.id);
    if (i < 0) return;
    loans = [...loans]..[i] = loan;
    await _persistLoans();
  }

  /// Marca las primeras [paid] cuotas como pagadas.
  Future<void> setPaidCount(SavedLoan loan, int paid) async {
    final tope = loan.result.months;
    await updateLoan(loan.copyWith(paidCount: paid.clamp(0, tope)));
  }

  Future<void> deleteLoan(String id) async {
    loans = loans.where((l) => l.id != id).toList();
    await _persistLoans();
  }

  Future<void> upsertSavings(SavingsEntry entry) async {
    final i = savings.indexWhere((s) => s.id == entry.id);
    if (i >= 0) {
      savings = [...savings]..[i] = entry;
    } else {
      savings = [...savings, entry];
    }
    await _persistSavings();
  }

  Future<void> deleteSavings(String id) async {
    savings = savings.where((s) => s.id != id).toList();
    await _persistSavings();
  }

  Future<void> _persistLoans() async {
    await _prefs.setString(
      _kLoans,
      jsonEncode(loans.map((l) => l.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _persistSavings() async {
    await _prefs.setString(
      _kSavings,
      jsonEncode(savings.map((s) => s.toJson()).toList()),
    );
    notifyListeners();
  }
}
