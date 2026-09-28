import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/strings.dart';

class KioskPinDialog extends StatefulWidget {
  final VoidCallback onAuthorized;

  const KioskPinDialog({super.key, required this.onAuthorized});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAuthorized,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => KioskPinDialog(onAuthorized: onAuthorized),
    );
  }

  @override
  State<KioskPinDialog> createState() => _KioskPinDialogState();
}

class _KioskPinDialogState extends State<KioskPinDialog> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final entered = _pinController.text.trim();
    if (entered == AppConfig.kioskExitPin) {
      Navigator.of(context).pop();
      widget.onAuthorized();
    } else {
      setState(() {
        _error = S.wrongPin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.enterPinToExit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: S.pin, errorText: _error),
            onSubmitted: (_) => _verifyPin(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(onPressed: _verifyPin, child: const Text(S.confirm)),
      ],
    );
  }
}
