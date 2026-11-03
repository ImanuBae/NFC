import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'employee_model.dart';
import 'employee_repository.dart';

class EmployeeDeleteButton extends ConsumerStatefulWidget {
  const EmployeeDeleteButton({
    super.key,
    required this.employee,
    required this.onDeleted,
  });
  final Employee employee;
  final VoidCallback onDeleted;

  @override
  ConsumerState<EmployeeDeleteButton> createState() =>
      _EmployeeDeleteButtonState();
}

class _EmployeeDeleteButtonState extends ConsumerState<EmployeeDeleteButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final employee = widget.employee;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhân viên?'),
        content: Text(
          'Xóa vĩnh viễn ${employee.fullName} (${employee.code}), tài khoản đăng nhập, '
          'thẻ NFC, mẫu khuôn mặt, lịch sử chấm công, email cấp tài khoản và chi tiết lương liên quan. '
          'Không thể hoàn tác thao tác này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(employeeRepositoryProvider).deleteEmployee(employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã xóa ${employee.fullName}.')));
      widget.onDeleted();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xóa được nhân viên: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Xóa nhân viên',
    onPressed: _busy ? null : _delete,
    color: Theme.of(context).colorScheme.error,
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.delete_outline),
  );
}
