import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/attendance/attendance_models.dart';
import 'attendance_ticket_repository.dart';
import 'ticket_evidence.dart';

class AttendanceTicketForm extends ConsumerStatefulWidget {
  const AttendanceTicketForm({super.key, this.event});
  final AttendanceEventItem? event;

  static Future<bool?> show(
    BuildContext context, {
    AttendanceEventItem? event,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AttendanceTicketForm(event: event),
  );

  @override
  ConsumerState<AttendanceTicketForm> createState() =>
      _AttendanceTicketFormState();
}

class _AttendanceTicketFormState extends ConsumerState<AttendanceTicketForm> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _kind;
  late DateTime _proposedAt;
  bool _busy = false;
  String? _error;
  final List<TicketEvidence> _attachments = [];
  bool _pickingEvidence = false;

  Future<void> _attachEvidence() async {
    setState(() {
      _pickingEvidence = true;
      _error = null;
    });
    try {
      final file = await ref.read(ticketEvidenceFilesProvider).pick();
      if (file == null || !mounted) return;
      validateTicketEvidence([..._attachments, file]);
      setState(() => _attachments.add(file));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _pickingEvidence = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _kind = widget.event == null ? 'missing_in' : 'incorrect_time';
    _proposedAt = widget.event?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _proposedAt,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_proposedAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _proposedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_proposedAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Không đề nghị công trong tương lai.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(attendanceTicketRepositoryProvider)
          .create(
            kind: _kind,
            proposedAt: _proposedAt,
            reason: _reason.text,
            originalEventId: _kind == 'incorrect_time'
                ? widget.event?.id
                : null,
            attachments: List.unmodifiable(_attachments),
          );
      ref.invalidate(attendanceTicketsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tạo ticket sửa công'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Gửi yêu cầu để Admin/Quản lý kiểm tra. Bảng công chỉ thay đổi sau khi được duyệt.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
                isExpanded: true,
                items: ticketKinds.entries
                    .where(
                      (e) => widget.event != null || e.key != 'incorrect_time',
                    )
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _kind = value!),
              ),
              if (widget.event != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Lượt gốc: ${widget.event!.type == 'check_in' ? 'Vào' : 'Ra'} · ${DateFormat('dd/MM/yyyy HH:mm').format(widget.event!.occurredAt)}',
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.event),
                label: Text(
                  'Giờ đề nghị: ${DateFormat('dd/MM/yyyy HH:mm').format(_proposedAt)}',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                enabled: !_busy,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Lý do',
                  hintText: 'Mô tả sai sót và thời gian cần điều chỉnh',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập lý do.'
                    : null,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              const Text(
                'Bằng chứng (không bắt buộc)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text(
                'Ảnh JPG/PNG hoặc PDF · Tối đa 3 tệp, 2 MB/tệp, tổng 5 MB.',
              ),
              for (var index = 0; index < _attachments.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(
                    _attachments[index].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${(_attachments[index].bytes.length / 1024).ceil()} KB',
                  ),
                  trailing: IconButton(
                    tooltip: 'Bỏ tệp ${_attachments[index].name}',
                    onPressed: _busy || _pickingEvidence
                        ? null
                        : () => setState(() => _attachments.removeAt(index)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _busy || _pickingEvidence || _attachments.length >= 3
                    ? null
                    : _attachEvidence,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _pickingEvidence ? 'Đang chọn tệp…' : 'Đính kèm bằng chứng',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _busy || _pickingEvidence ? null : _submit,
        child: Text(_busy ? 'Đang gửi…' : 'Gửi ticket'),
      ),
    ],
  );
}
