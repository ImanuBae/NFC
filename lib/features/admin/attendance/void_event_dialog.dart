import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import 'attendance_repository.dart';

class VoidEventDialog extends StatefulWidget {
  final String eventId;
  final AttendanceRepository repository;

  const VoidEventDialog({
    super.key,
    required this.eventId,
    required this.repository,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String eventId,
    required AttendanceRepository repository,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) =>
          VoidEventDialog(eventId: eventId, repository: repository),
    );
  }

  @override
  State<VoidEventDialog> createState() => _VoidEventDialogState();
}

class _VoidEventDialogState extends State<VoidEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitVoid() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.repository.voidEvent(
        eventId: widget.eventId,
        reason: _reasonController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.voidEvent),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: S.voidReason,
                hintText: 'VD: Quẹt nhầm thẻ, sai giờ',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return S.voidReasonEmpty;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submitVoid,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text(_isLoading ? S.loading : S.voidEvent),
        ),
      ],
    );
  }
}
