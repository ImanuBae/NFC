import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_repository.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});
  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  late Future<List<Map<String, dynamic>>> _accounts;
  late Future<List<Map<String, dynamic>>> _faces;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(businessRepositoryProvider);
    _accounts = repo.accounts();
    _faces = repo.faces();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit([Map<String, dynamic>? account]) async {
    try {
      final employees = await ref.read(businessRepositoryProvider).employees();
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _AccountDialog(account: account, employees: employees),
      );
      if (result == true && mounted) setState(_reload);
    } catch (e) {
      _message('$e');
    }
  }

  Future<void> _deviceAction(String action, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'approve_face'
              ? 'Duyệt khuôn mặt?'
              : action == 'revoke_face'
              ? 'Thu hồi khuôn mặt?'
              : 'Thu hồi khuôn mặt?',
        ),
        content: const Text(
          'Xác minh nhân viên và thiết bị trực tiếp trước khi thay đổi quyền chấm công.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(businessRepositoryProvider).action(action, {'id': id});
      if (mounted) setState(_reload);
    } catch (e) {
      _message('$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tài khoản & thiết bị'),
      actions: [
        IconButton(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.person_add),
      label: const Text('Tạo tài khoản'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _accounts,
      builder: (context, accounts) {
        if (accounts.hasError) return Center(child: Text('${accounts.error}'));
        if (!accounts.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final byId = {for (final a in accounts.data!) a['id']: a};
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const Text(
              'Khuôn mặt camera',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _faces,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Chưa tải được mẫu khuôn mặt. Kiểm tra migration 0008.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Text('Chưa có đăng ký khuôn mặt.');
                }
                return Column(
                  children: snapshot.data!
                      .map(
                        (f) => Card(
                          child: ListTile(
                            title: Text(
                              '${byId[f['user_id']]?['email'] ?? f['user_id']}',
                            ),
                            subtitle: SelectableText(
                              '${f['revoked'] == true
                                  ? 'Đã thu hồi'
                                  : f['approved'] == true
                                  ? 'Đang sử dụng'
                                  : 'Chưa kích hoạt'}\nMã đăng ký: ${f['id']}',
                            ),
                            trailing: f['revoked'] == true
                                ? null
                                : Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'Thu hồi khuôn mặt',
                                        icon: const Icon(Icons.block),
                                        onPressed: () => _deviceAction(
                                          'revoke_face',
                                          f['id'] as String,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Tài khoản đăng nhập',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ...accounts.data!.map(
              (a) => Card(
                child: ListTile(
                  leading: Icon(
                    a['active'] == true ? Icons.person : Icons.person_off,
                  ),
                  title: Text(a['email'] as String? ?? a['id'] as String),
                  subtitle: Text(
                    '${a['role']} · ${a['active'] == true ? 'Hoạt động' : 'Đã đóng'}',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _edit(a),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog({this.account, required this.employees});
  final Map<String, dynamic>? account;
  final List<Map<String, dynamic>> employees;
  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  late String _role;
  String? _employee;
  late bool _active;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: widget.account?['email'] as String? ?? '',
    );
    _role = widget.account?['role'] as String? ?? 'employee';
    _employee = widget.account?['employee_id'] as String?;
    _active = widget.account?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(businessRepositoryProvider).action('save_account', {
        'id': widget.account?['id'],
        'email': _email.text.trim(),
        'role': _role,
        'active': _active,
        'employee_id': _role == 'kiosk' ? null : _employee,
        if (_password.text.isNotEmpty) 'password': _password.text,
      });
      if (mounted) Navigator.pop(context, true);
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.account == null ? 'Tạo tài khoản' : 'Cập nhật tài khoản',
    ),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email đăng nhập / nhận báo cáo',
                ),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Email không hợp lệ',
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.account == null
                      ? 'Mật khẩu (ít nhất 12 ký tự)'
                      : 'Mật khẩu mới (để trống nếu giữ nguyên)',
                ),
                validator: (v) =>
                    (widget.account == null || (v?.isNotEmpty ?? false)) &&
                        (v?.length ?? 0) < 12
                    ? 'Cần ít nhất 12 ký tự'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Nhân viên')),
                  DropdownMenuItem(value: 'manager', child: Text('Quản lý')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                    value: 'kiosk',
                    child: Text('Máy NFC dùng chung'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _role = v!;
                  if (_role == 'kiosk') _employee = null;
                }),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_role == 'kiosk'),
                initialValue: _employee ?? '',
                decoration: const InputDecoration(
                  labelText: 'Liên kết hồ sơ nhân viên',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Không liên kết'),
                  ),
                  ...widget.employees.map(
                    (e) => DropdownMenuItem(
                      value: e['id'] as String,
                      child: Text('${e['code']} · ${e['full_name']}'),
                    ),
                  ),
                ],
                onChanged: _role == 'kiosk'
                    ? null
                    : (v) => setState(() => _employee = v == '' ? null : v),
                validator: (v) =>
                    _role == 'employee' && (v == null || v.isEmpty)
                    ? 'Chọn nhân viên'
                    : null,
              ),
              SwitchListTile(
                title: const Text('Cho phép đăng nhập'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Đang lưu...' : 'Lưu'),
      ),
    ],
  );
}
