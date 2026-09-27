import 'package:flutter/material.dart';

extension AppUiUtils on BuildContext {
  /// Verifica se ainda dá pra usar o context antes de tocar no messenger.
  /// Evita "Looking up a deactivated widget's ancestor is unsafe".
  bool get _podeUsarUi => mounted;

  void showError(String message) {
    if (!_podeUsarUi) return;
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void showSuccess(String message) {
    if (!_podeUsarUi) return;
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showInfo(String message) {
    if (!_podeUsarUi) return;
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}