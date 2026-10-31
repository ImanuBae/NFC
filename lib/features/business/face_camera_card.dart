import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'face_camera_service.dart';

class FaceCameraCard extends ConsumerStatefulWidget {
  const FaceCameraCard({super.key});
  @override
  ConsumerState<FaceCameraCard> createState() => _FaceCameraCardState();
}

class _FaceCameraCardState extends ConsumerState<FaceCameraCard> {
  Map<String, dynamic>? _credential;
  String? _message;
  bool _busy = false;
  bool _confirming = false;
  bool _refreshing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<bool> _refresh({bool feedback = false}) async {
    if (_refreshing) return false;
    setState(() => _refreshing = true);
    try {
      final credential = await ref.read(faceCameraServiceProvider).credential();
      if (mounted) {
        setState(() {
          _credential = credential;
          _loaded = true;
          _message = feedback ? 'Đã cập nhật trạng thái khuôn mặt.' : null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Chưa tải được trạng thái khuôn mặt. Kiểm tra kết nối mạng rồi thử lại.';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _submit(String purpose) async {
    if (_busy || _refreshing) return;
    final replacing = purpose == 'reenroll';
    setState(() {
      _busy = true;
      _confirming = true;
      _message = null;
    });
    try {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            replacing
                ? 'Đăng ký lại khuôn mặt'
                : 'Đăng ký khuôn mặt bằng camera',
          ),
          content: Text(
            'Ứng dụng mở camera trước, lấy đặc trưng khuôn mặt và lưu mẫu trên máy chủ để đối chiếu chấm công. '
            'Không lưu hoặc tải ảnh/video lên máy chủ. Mẫu được kích hoạt ngay khi đăng ký thành công. '
            '${replacing ? 'Mẫu cũ chỉ được thay khi đăng ký mới thành công. Hủy hoặc gặp lỗi sẽ giữ nguyên mẫu cũ. ' : ''}'
            'Bạn đồng ý đăng ký mẫu khuôn mặt cho tài khoản này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );
      if (consent != true || !mounted) return;
      setState(() => _confirming = false);
      await ref.read(faceCameraServiceProvider).submit(purpose);
      if (!mounted) return;
      final refreshed = await _refresh();
      if (mounted) {
        setState(
          () => _message = !refreshed
              ? 'Mẫu khuôn mặt đã được lưu. Chưa tải lại được trạng thái; hãy bấm Tải lại trạng thái khuôn mặt.'
              : replacing
              ? 'Đã cập nhật mẫu khuôn mặt. Bạn có thể chấm công tại kiosk ngay.'
              : 'Đã đăng ký khuôn mặt. Bạn có thể chấm công tại kiosk ngay.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = switch (e) {
            PlatformException(code: 'FACE_CANCELLED') =>
              replacing
                  ? 'Đã hủy đăng ký lại. Mẫu khuôn mặt cũ vẫn được giữ nguyên.'
                  : 'Đã hủy đăng ký khuôn mặt.',
            PlatformException(:final message) =>
              message ?? 'Không mở được camera. Hãy thử lại.',
            ApiException(:final message) => message,
            _ => '$e',
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.face_retouching_natural, size: 48),
          const Text(
            'Khuôn mặt bằng camera',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Khi đăng ký mẫu, dùng camera trước và làm theo hướng dẫn chớp mắt/quay đầu. '
            'Đăng ký thành công là có thể chấm công tại kiosk: nhìn thẳng và giữ yên.',
          ),
          const SizedBox(height: 8),
          Text(
            !_loaded
                ? 'Chưa tải được trạng thái.'
                : _credential == null
                ? 'Chưa đăng ký khuôn mặt.'
                : _credential!['approved'] == true
                ? 'Khuôn mặt đã sẵn sàng chấm công.'
                : 'Mẫu chưa được kích hoạt. Hãy cập nhật trạng thái sau khi backend khởi động lại.',
          ),
          if (_credential != null)
            SelectableText('Mã đăng ký: ${_credential!['id']}'),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          if ((_busy && !_confirming) || _refreshing)
            const LinearProgressIndicator(),
          FilledButton.icon(
            onPressed: _busy || _refreshing || !_loaded
                ? null
                : () => _submit(_credential == null ? 'enroll' : 'reenroll'),
            icon: Icon(
              _credential == null
                  ? Icons.add_a_photo
                  : Icons.cameraswitch_outlined,
            ),
            label: Text(
              _credential == null
                  ? 'Đăng ký khuôn mặt'
                  : 'Đăng ký lại khuôn mặt',
            ),
          ),
          const Text(
            'Chấm công tại kiosk của công ty bằng thẻ NFC hoặc khuôn mặt.',
          ),
          OutlinedButton.icon(
            onPressed: _busy || _refreshing
                ? null
                : () => _refresh(feedback: true),
            icon: const Icon(Icons.refresh),
            label: Text(
              _refreshing
                  ? 'Đang tải trạng thái…'
                  : 'Tải lại trạng thái khuôn mặt',
            ),
          ),
          const Text(
            'Bạn có thể đăng ký lại để thay mẫu khuôn mặt. Camera chỉ kiểm tra chuyển động cơ bản, '
            'chưa bảo đảm chống giả mạo bằng video.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
