import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/excel_export.dart';
import '../models/saved_loan.dart';
import '../theme/clay.dart';

/// Genera el Excel del crédito y abre el menú de compartir del sistema
/// (WhatsApp, Drive, correo, guardar en archivos...).
Future<void> exportLoanToExcel(BuildContext context, SavedLoan loan) async {
  final messenger = ScaffoldMessenger.of(context);

  void avisar(String texto, {bool error = false}) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? ClayColors.red : ClayColors.purpleDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  try {
    final bytes = buildLoanWorkbook(loan);
    await SharePlus.instance.share(
      ShareParams(
        subject: '${loan.name} · tabla de amortización',
        text: 'Tabla de amortización y abonos de "${loan.name}".',
        files: [
          XFile.fromData(
            bytes,
            name: workbookFileName(loan),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: [workbookFileName(loan)],
      ),
    );
  } catch (e) {
    avisar('No se pudo exportar: $e', error: true);
  }
}
