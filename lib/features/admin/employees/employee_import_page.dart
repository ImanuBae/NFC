import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../attendance/day_report_page.dart';
import 'employee_import_repository.dart';
import 'employee_list_page.dart';
import 'import_email_status.dart';

class EmployeeImportPage extends ConsumerStatefulWidget {
  const EmployeeImportPage({super.key});

  @override
  ConsumerState<EmployeeImportPage> createState() => _EmployeeImportPageState();
}

class _EmployeeImportPageState extends ConsumerState<EmployeeImportPage> {
  final _department = TextEditingController();
  EmployeeImportFile? _file;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  late Future<List<Map<String, dynamic>>> _recent;
  String _importId = const Uuid().v4();
  String? _error;
  bool _busy = false;
  bool _commitAttempted = false;

  @override
  void initState() {
    super.initState();
    _recent = ref.read(employeeImportRepositoryProvider).recent();
  }

  @override
  void dispose() {
    _department.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _run(() async {
    final file = await ref.read(employeeImportFilesProvider).pick();
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _preview = null;
      _result = null;
      _importId = const Uuid().v4();
      _commitAttempted = false;
    });
    await _loadPreview();
  });

  Future<void> _loadPreview() async {
    if (_file == null) return;
    final preview = await ref
        .read(employeeImportRepositoryProvider)
        .preview(_file!, _department.text);
    if (mounted) setState(() => _preview = preview);
  }

  Future<void> _commit() => _run(() async {
    setState(() => _commitAttempted = true);
    final result = await ref
        .read(employeeImportRepositoryProvider)
        .commit(_file!, _department.text, _importId);
    if (!mounted) return;
    setState(() {
      _result = result;
      _recent = ref.read(employeeImportRepositoryProvider).recent();
    });
    ref.invalidate(employeeListProvider);
    ref.invalidate(dayReportProvider);
  });

  Future<void> _download(String id) => _run(() async {
    final file = await ref
        .read(employeeImportRepositoryProvider)
        .credentials(id);
    await ref.read(employeeImportFilesProvider).save(file);
  });

  @override
  Widget build(BuildContext context) {
    final rows = (_preview?['rows'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập nhân viên từ Excel')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final step in [
                (0, 'Chọn file'),
                (1, 'Kiểm tra'),
                (2, 'Kết quả'),
              ])
                Chip(
                  avatar: CircleAvatar(child: Text('${step.$1 + 1}')),
                  backgroundColor:
                      (_result != null
                              ? 2
                              : _preview != null
                              ? 1
                              : 0) ==
                          step.$1
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  label: Text(step.$2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Tạo hồ sơ và tài khoản trong một lần nhập',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Đồng bộ hồ sơ và gán thẻ NFC từ danh sách nhân viên. Nhập lại đúng mã NV và email sẽ giữ nguyên mật khẩu.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Bắt buộc: Mã NV, Họ và tên, Email. UID thẻ để dạng Text. Hỗ trợ .xls/.xlsx, tối đa 5 MB và 1.000 nhân viên/lần.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _department,
            enabled: !_busy && !_commitAttempted,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Phòng ban chung (không bắt buộc)',
              helperText: 'Chỉ áp dụng cho dòng chưa có phòng ban trong file.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _preview = null),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: const Text('Chọn file Excel'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final template = await ref
                            .read(employeeImportRepositoryProvider)
                            .template();
                        await ref
                            .read(employeeImportFilesProvider)
                            .save(template);
                      }),
                icon: const Icon(Icons.download),
                label: const Text('Tải file mẫu'),
              ),
              if (_file != null && _result == null)
                TextButton(
                  onPressed: _busy ? null : () => _run(_loadPreview),
                  child: const Text('Kiểm tra lại danh sách'),
                ),
            ],
          ),
          if (_file != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('File: ${_file!.name}'),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_commitAttempted && _result == null && !_busy)
            const Text(
              'Nếu mất kết nối khi nhập, bấm lại nút tạo bên dưới để lấy kết quả của cùng lần nhập. Có thể tải tài khoản đã tạo trong mục các lần nhập gần đây.',
            ),
          if (_result != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đã tạo ${_result!['created_count']} nhân viên và tài khoản. Đã cập nhật ${_result!['updated_count'] ?? 0} hồ sơ. Đã gán ${_result!['cards_assigned_count'] ?? 0} thẻ NFC. Bỏ qua ${_result!['skipped_count']} dòng đã có.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chỉ tài khoản mới được xếp hàng gửi email cấp tài khoản và hướng dẫn đổi mật khẩu, đăng ký khuôn mặt. Có thể tải bảng tài khoản trong 24 giờ để hỗ trợ nhân viên khi cần.',
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy || _result!['created_count'] == 0
                          ? null
                          : () => _download(_result!['import_id'] as String),
                      icon: const Icon(Icons.download),
                      label: const Text('Tải tài khoản nhân viên (.xlsx)'),
                    ),
                  ],
                ),
              ),
            ),
          if (_preview != null && _result == null) ...[
            const SizedBox(height: 16),
            if ((_preview!['ignored_sheets'] as List? ?? []).isNotEmpty)
              Text(
                'Không nhập các sheet chưa có đủ cột Mã NV, Họ và tên, Email: '
                '${(_preview!['ignored_sheets'] as List).join(', ')}',
              ),
            Text(
              'Tạo mới: ${_preview!['create_count']} · Cập nhật: ${_preview!['update_count'] ?? 0} · Gán thẻ: ${_preview!['card_count'] ?? 0} · Đã có: ${_preview!['skip_count']} · Dòng lỗi: ${_preview!['error_count']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if ((_preview!['error_count'] as num) > 0)
              const Text(
                'Chưa nhập dữ liệu. Sửa các dòng lỗi trong Excel rồi chọn lại file. Toàn bộ danh sách chỉ được nhập khi hết lỗi.',
              ),
            if (_preview!['can_import'] != true &&
                _preview!['error_count'] == 0)
              const Text(
                'Danh sách đã có trong hệ thống. Thông tin không đổi; giữ nguyên mật khẩu, không tạo trùng.',
              ),
            const SizedBox(height: 12),
            PaginatedDataTable(
              key: ValueKey(_preview),
              header: const Text('Xem trước danh sách'),
              columns: const [
                DataColumn(label: Text('Trạng thái')),
                DataColumn(label: Text('Sheet / dòng')),
                DataColumn(label: Text('Mã NV')),
                DataColumn(label: Text('Họ và tên')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Phòng ban')),
                DataColumn(label: Text('Chức vụ')),
                DataColumn(label: Text('Số điện thoại')),
                DataColumn(label: Text('Ngày vào làm')),
                DataColumn(label: Text('Đơn giá giờ')),
                DataColumn(label: Text('UID thẻ NFC')),
                DataColumn(label: Text('Kiểm tra')),
              ],
              source: _ImportRows(rows),
              rowsPerPage: 10,
              showEmptyRows: false,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: !_busy && _preview!['can_import'] == true
                    ? _commit
                    : null,
                icon: const Icon(Icons.group_add),
                label: Text(
                  (_preview!['update_count'] as num? ?? 0) > 0
                      ? 'Cập nhật ${_preview!['update_count']} hồ sơ, tạo ${_preview!['create_count']} và gán ${_preview!['card_count'] ?? 0} thẻ'
                      : (_preview!['card_count'] as num? ?? 0) > 0
                      ? 'Nhập ${_preview!['create_count']} nhân viên và gán ${_preview!['card_count']} thẻ'
                      : 'Tạo ${_preview!['create_count']} nhân viên và tài khoản',
                ),
              ),
            ),
          ],
          if (_result == null) const ImportEmailStatus(),
          if (_result != null)
            ImportEmailStatus(importId: _result!['import_id'] as String),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _recent,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Chưa tải được lịch sử nhập gần đây.');
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              return ExpansionTile(
                title: const Text('Các lần nhập của tôi trong 24 giờ'),
                children: snapshot.data!
                    .map(
                      (batch) => ListTile(
                        leading: IconButton(
                          tooltip: 'Trạng thái gửi email',
                          icon: const Icon(Icons.mail_outline),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Email cấp tài khoản'),
                              content: SizedBox(
                                width: 600,
                                child: SingleChildScrollView(
                                  child: ImportEmailStatus(
                                    importId: batch['id'] as String,
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Đóng'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          'Đã tạo ${batch['created_count']} tài khoản · Cập nhật ${batch['updated_count'] ?? 0} hồ sơ · Gán ${batch['cards_assigned_count'] ?? 0} thẻ',
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(
                            DateTime.parse(batch['created_at'] as String)
                                .toLocal(),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Tải tài khoản lần nhập này',
                          onPressed: _busy || batch['created_count'] == 0
                              ? null
                              : () => _download(batch['id'] as String),
                          icon: const Icon(Icons.download),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ImportRows extends DataTableSource {
  _ImportRows(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final r = rows[index];
    final errors = (r['errors'] as List? ?? []).join('\n');
    final warnings = (r['warnings'] as List? ?? []).join('\n');
    final date = DateTime.tryParse('${r['hire_date']}');
    DataCell cell(String text, [double width = 160]) =>
        DataCell(SizedBox(width: width, child: SelectableText(text)));
    return DataRow.byIndex(
      index: index,
      cells: [
        cell(switch (r['status']) {
          'create' => 'Tạo mới',
          'link_card' => 'Gán thẻ',
          'update' => 'Cập nhật',
          'skip' => 'Đã có',
          _ => 'Có lỗi',
        }, 90),
        cell('${r['sheet']} / ${r['row_number']}', 100),
        cell('${r['code']}', 100),
        cell('${r['full_name']}', 190),
        cell('${r['email']}', 230),
        cell('${r['department'] ?? ''}'),
        cell('${r['job_title'] ?? ''}'),
        cell('${r['phone'] ?? ''}'),
        cell(date == null ? '' : DateFormat('dd/MM/yyyy').format(date), 110),
        cell('${r['hourly_rate']}', 110),
        cell('${r['uid_the'] ?? ''}', 190),
        DataCell(
          SizedBox(
            width: 360,
            child: Tooltip(
              message: [errors, warnings].where((s) => s.isNotEmpty).join('\n'),
              child: Text(
                [errors, warnings].where((s) => s.isNotEmpty).join('\n'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: errors.isEmpty
                      ? Colors.orange.shade900
                      : Colors.red.shade800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => rows.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}
