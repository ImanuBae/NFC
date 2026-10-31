import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});
  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _replacement = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _replacement.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      await client.request(
        'POST',
        '/auth/change-password',
        body: {
          'current_password': _current.text,
          'new_password': _replacement.text,
        },
      );
      // Refresh the first-login reminder; the current session remains signed in.
      await client.me();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Nhập mật khẩu hiện tại.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _replacement,
                  obscureText: true,
                  enabled: !_busy,
                  maxLength: 128,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    helperText: 'Ít nhất 8 ký tự, khác mật khẩu mặc định.',
                  ),
                  validator: (v) {
                    if (v == null ||
                        v.trim().isEmpty ||
                        v.length < 8 ||
                        v.length > 128) {
                      return 'Mật khẩu cần từ 8 đến 128 ký tự.';
                    }
                    if (v == '12345678' || v == _current.text) {
                      return 'Chọn mật khẩu khác mật khẩu hiện tại và mặc định.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                  ),
                  validator: (v) => v != _replacement.text
                      ? 'Mật khẩu nhập lại chưa khớp.'
                      : null,
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Lưu mật khẩu mới'),
        ),
      ],
    ),
  );
}
