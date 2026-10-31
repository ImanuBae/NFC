import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/server_connection.dart';

class ServerConnectionPage extends ConsumerStatefulWidget {
  const ServerConnectionPage({super.key});

  @override
  ConsumerState<ServerConnectionPage> createState() =>
      _ServerConnectionPageState();
}

class _ServerConnectionPageState extends ConsumerState<ServerConnectionPage> {
  late final _url = TextEditingController(text: ref.read(serverUrlProvider));
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final transport = http.Client();
    try {
      final url = normalizeServerUrl(_url.text);
      final response = await transport
          .get(
            Uri.parse('$url/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          data is! Map ||
          data['status'] != 'ok' ||
          data['database'] != 'SQL Server') {
        throw StateError('Máy chủ hoặc SQL Server chưa sẵn sàng.');
      }
      if (!mounted) return;
      // Close the settings route before rebuilding clients and the auth router.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(url);
      } else {
        await ref.read(serverUrlProvider.notifier).save(url);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(
          () => _message = e.message.toString().startsWith('Nhập URL')
              ? e.message.toString()
              : 'Máy chủ không trả JSON hợp lệ. Kiểm tra URL và đặt Dev Tunnel thành Public.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Chưa kết nối được backend và SQL Server. Kiểm tra Internet, URL tunnel, '
              'quyền Public và backend đang chạy trên laptop.',
        );
      }
    } finally {
      transport.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kết nối máy chủ')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nhập địa chỉ HTTPS của API do người điều khiển laptop cung cấp. '
                'Dùng cùng địa chỉ trên các điện thoại để demo không cần USB.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _url,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ máy chủ',
                  hintText: 'https://…devtunnels.ms',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chỉ nhập URL gốc, không thêm /api hay /health. '
                'Đổi máy chủ sẽ yêu cầu đăng nhập vào máy chủ đã chọn.',
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child: Text(_busy ? 'Đang kiểm tra…' : 'Kiểm tra và sử dụng'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
