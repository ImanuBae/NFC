import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../employees/employee_model.dart';
import '../employees/employee_repository.dart';
import 'attendance_repository.dart';

class ManualEditSheet extends ConsumerStatefulWidget {
  final String? initialEmployeeId;
  final VoidCallback onSaved;

  const ManualEditSheet({
    super.key,
    this.initialEmployeeId,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialEmployeeId,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ManualEditSheet(
          initialEmployeeId: initialEmployeeId,
          onSaved: onSaved,
        ),
      ),
    );
  }

  @override
  ConsumerState<ManualEditSheet> createState() => _ManualEditSheetState();
}

class _ManualEditSheetState extends ConsumerState<ManualEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _selectedEmployeeId;
  String _eventType = 'check_in';
  DateTime _eventTime = DateTime.now();
  bool _isLoading = false;
  String? _error;
  List<Employee> _employees = [];
  bool _loadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final repo = ref.read(employeeRepositoryProvider);
    try {
      final list = await repo.getEmployees(activeOnly: true);
      if (mounted) {
        setState(() {
          _employees = list;
          if (!list.any((e) => e.id == _selectedEmployeeId)) {
            _selectedEmployeeId = list.isEmpty ? null : list.first.id;
          }
          _loadingEmployees = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được nhân viên: $error';
          _loadingEmployees = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _eventTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _eventTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.addManualEvent(
        employeeId: _selectedEmployeeId!,
        type: _eventType,
        occurredAt: _eventTime,
        reason: _reasonController.text,
      );

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.addManualEvent,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            if (_loadingEmployees)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedEmployeeId,
                decoration: const InputDecoration(labelText: 'Nhân viên'),
                items: _employees.map((emp) {
                  return DropdownMenuItem(
                    value: emp.id,
                    child: Text('${emp.code} - ${emp.fullName}'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedEmployeeId = val),
                validator: (val) =>
                    val == null ? 'Vui lòng chọn nhân viên' : null,
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _eventType,
              decoration: const InputDecoration(labelText: S.eventType),
              items: const [
                DropdownMenuItem(value: 'check_in', child: Text(S.checkIn)),
                DropdownMenuItem(value: 'check_out', child: Text(S.checkOut)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _eventType = val);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text(S.eventTime),
              subtitle: Text(
                DateFormat('HH:mm - dd/MM/yyyy').format(_eventTime),
              ),
              trailing: TextButton(
                onPressed: _pickDateTime,
                child: const Text('Thay đổi'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập lý do chấm công thủ công'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Ghi chú / Lý do thêm tay',
                hintText: 'VD: Quên mang thẻ',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading || _loadingEmployees || _employees.isEmpty
                  ? null
                  : _save,
              child: Text(_isLoading ? S.loading : S.save),
            ),
          ],
        ),
      ),
    );
  }
}
