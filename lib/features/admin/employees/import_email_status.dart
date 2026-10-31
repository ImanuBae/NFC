import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'employee_import_repository.dart';

final importEmailStatusProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      Timer? timer;
      ref.onDispose(() => timer?.cancel());
      try {
        final repo = ref.watch(employeeImportRepositoryProvider);
        return id.isEmpty
            ? await repo.emailSettings()
            : await repo.emailStatus(id);
      } finally {
        if (ref.mounted) {
          timer = Timer(const Duration(seconds: 5), ref.invalidateSelf);
        }
      }
    }, retry: (_, _) => null);

class ImportEmailStatus extends ConsumerStatefulWidget {
  const ImportEmailStatus({super.key, this.importId = ''});
  final String importId;
  @override
  ConsumerState<ImportEmailStatus> createState() => _ImportEmailStatusState();
}

class _ImportEmailStatusState extends ConsumerState<ImportEmailStatus> {
  bool _retrying = false;
  Future<void> _verify() async {
    setState(() => _retrying = true);
    try {
      final result = await ref
          .read(employeeImportRepositoryProvider)
          .verifyEmail();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${result['message']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await ref
          .read(employeeImportRepositoryProvider)
          .retryEmails(widget.importId);
      ref.invalidate(importEmailStatusProvider(widget.importId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(importEmailStatusProvider(widget.importId))
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Chưa tải được trạng thái email: $e'),
        data: (data) {
          final configured = data['configured'] == true;
          if (widget.importId.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    configured
                        ? 'Đã cấu hình dịch vụ email. Tài khoản mới sẽ được đưa vào hàng đợi gửi tự động.'
                        : 'Chưa cấu hình dịch vụ email. Tài khoản vẫn được tạo nhưng thư sẽ chờ trong hàng đợi; Admin cần cấu hình Gmail gửi và mật khẩu ứng dụng trên backend.',
                  ),
                ),
                if (configured && data['provider'] == 'Smtp')
                  TextButton.icon(
                    onPressed: _retrying ? null : _verify,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Kiểm tra kết nối Gmail'),
                  ),
              ],
            );
          }
          final rows = (data['rows'] as List? ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          final sent = rows.where((r) => r['status'] == 'sent').length;
          final failed = rows.where((r) => r['status'] == 'failed').length;
          String label(String status) => switch (status) {
            'sent' => 'Dịch vụ đã nhận thư',
            'failed' => 'Gửi lỗi',
            'sending' => 'Đang gửi',
            'cancelled' => 'Đã ngừng gửi',
            'expired' => 'Cần Admin xử lý',
            'needs_review' => 'Cần kiểm tra thư mục Đã gửi',
            _ => configured ? 'Đang chờ gửi' : 'Chờ cấu hình email',
          };
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email cấp tài khoản: $sent/${rows.length} thư được dịch vụ tiếp nhận · Lỗi: $failed',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (!configured)
                    const Text(
                      'Chưa gửi email vì thiếu cấu hình Gmail trên máy chủ. Hệ thống sẽ tự gửi sau khi được cấu hình.',
                    ),
                  const Text(
                    'Trạng thái tiếp nhận chưa xác nhận thư đã vào hộp thư đến. Nhân viên có thể cần kiểm tra Spam.',
                  ),
                  if (configured && failed > 0)
                    TextButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử gửi lại email lỗi'),
                    ),
                  ExpansionTile(
                    title: const Text('Chi tiết từng email'),
                    children: rows
                        .map(
                          (r) => ListTile(
                            title: Text('${r['recipient']}'),
                            subtitle: Text(
                              '${label('${r['status']}')}${r['last_error'] == null ? '' : '\n${r['last_error']}'}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
