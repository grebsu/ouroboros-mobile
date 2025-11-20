import 'package:flutter/material.dart';

class ConfirmationModal extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onClose;
  final String confirmText;
  final String cancelText;

  const ConfirmationModal({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onClose,
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(message, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16)),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      actions: <Widget>[
        TextButton(
          onPressed: onClose,
          child: Text(cancelText, style: const TextStyle(color: Colors.teal, fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
