import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import 'employee_model.dart';
import 'employee_repository.dart';

class EmployeeFormDialog extends StatefulWidget {
  final Employee? employee;
  final EmployeeRepository repository;

  const EmployeeFormDialog({
    super.key,
    this.employee,
    required this.repository,
  });

  static Future<bool?> show(
    BuildContext context, {
    Employee? employee,
    required EmployeeRepository repository,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) =>
          EmployeeFormDialog(employee: employee, repository: repository),
    );
  }

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late bool _active;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.employee?.code ?? '');
    _nameController = TextEditingController(
      text: widget.employee?.fullName ?? '',
    );
    _active = widget.employee?.active ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.employee == null) {
        await widget.repository.createEmployee(
          code: _codeController.text,
          fullName: _nameController.text,
          active: _active,
        );
      } else {
        await widget.repository.updateEmployee(
          id: widget.employee!.id,
          code: _codeController.text,
          fullName: _nameController.text,
          active: _active,
        );
      }
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
    final isEditing = widget.employee != null;

    return AlertDialog(
      title: Text(isEditing ? S.editEmployee : S.addEmployee),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: S.employeeCode),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return S.codeEmpty;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: S.employeeName),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return S.nameEmpty;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(S.employeeStatus),
                subtitle: Text(_active ? S.active : S.inactive),
                value: _active,
                onChanged: (val) => setState(() => _active = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: Text(_isLoading ? S.loading : S.save),
        ),
      ],
    );
  }
}
