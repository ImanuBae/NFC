import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_repository.dart';

final faceCameraServiceProvider = Provider(
  (ref) => FaceCameraService(ref.watch(businessRepositoryProvider)),
);

class FaceCameraService {
  FaceCameraService(this.repository);
  final BusinessRepository repository;
  static const channel = MethodChannel('attendance/face_camera');

  Future<Map<String, dynamic>?> credential() async {
    final rows = await repository.faces();
    final userId = repository.client.currentUser?.id;
    for (final row in rows) {
      if (row['user_id'] == userId && row['revoked'] == false) {
        return Map<String, dynamic>.from(row);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> submit(
    String purpose, {
    String? deviceId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw Exception('Hãy dùng ứng dụng Android để mở camera trước.');
    }
    final challenge = await repository.action('begin_face_camera', {
      'purpose': purpose,
      'device_id': ?deviceId,
    });
    final capture = await channel.invokeMapMethod<String, dynamic>('capture', {
      'purpose': purpose,
      'turnFirst': challenge['turn_first'],
    });
    if (capture == null) throw Exception('Đã hủy xác thực khuôn mặt.');
    return repository.action('finish_face_camera', {
      ...capture,
      'challenge_id': challenge['id'],
    });
  }
}
