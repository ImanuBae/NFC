import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_repository.dart';

class PayrollExportFiles {
  Future<bool> save(Map<String, dynamic> file) async =>
      await FilePicker.saveFile(
        fileName: file['file_name'] as String,
        bytes: base64Decode(file['content_base64'] as String),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ) !=
      null;
}

final payrollExportFilesProvider = Provider((ref) => PayrollExportFiles());

class PayrollExportButton extends ConsumerStatefulWidget {
  const PayrollExportButton({
    super.key,
    required this.runId,
    this.iconOnly = false,
    this.disabled = false,
  });
  final String runId;
  final bool iconOnly;
  final bool disabled;
  @override
  ConsumerState<PayrollExportButton> createState() =>
      _PayrollExportButtonState();
}

class _PayrollExportButtonState extends ConsumerState<PayrollExportButton> {
  bool _busy = false;
  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(businessRepositoryProvider)
          .exportPayroll(widget.runId);
      final saved = await ref.read(payrollExportFilesProvider).save(file);
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xuất ${file['file_name']}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xuất được bảng lương: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.download_outlined);
    return widget.iconOnly
        ? IconButton(
            tooltip: 'Xuất Excel kỳ lương đã chốt',
            onPressed: _busy || widget.disabled ? null : _export,
            icon: icon,
          )
        : FilledButton.icon(
            onPressed: _busy || widget.disabled ? null : _export,
            icon: icon,
            label: Text(_busy ? 'Đang xuất…' : 'Xuất Excel'),
          );
  }
}
