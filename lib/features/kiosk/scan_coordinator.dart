import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/result.dart';
import '../../core/api_client.dart';
import '../../core/uid.dart';
import 'device_config.dart';
import 'pending_scan_store.dart';

abstract class OfflineScanQueue {
  Future<void> enqueue({
    required String clientScanId,
    required String uid,
    required DateTime deviceTime,
  });
}

abstract class KioskRpcService {
  Future<dynamic> recordScan({
    required String uid,
    required String? deviceId,
    required DateTime deviceTime,
    required String clientScanId,
    required bool isReplay,
  });
}

class ApiKioskRpcService implements KioskRpcService {
  final ApiClient _client;

  ApiKioskRpcService(this._client);

  @override
  Future<dynamic> recordScan({
    required String uid,
    required String? deviceId,
    required DateTime deviceTime,
    required String clientScanId,
    required bool isReplay,
  }) {
    return _client.request(
      'POST',
      '/scans',
      body: {
        'uid': uid,
        'device_id': deviceId,
        'device_time': deviceTime.toIso8601String(),
        'client_scan_id': clientScanId,
        'is_replay': isReplay,
      },
    );
  }
}

class ScanCoordinator {
  final KioskRpcService rpcService;
  final DeviceConfig deviceConfig;
  final OfflineScanQueue? offlineQueue;
  final Map<String, DateTime> _lastScanned = {};
  static const _cooldownDuration = Duration(seconds: 3);
  static const _rpcTimeout = Duration(seconds: 5);

  ScanCoordinator({
    required this.rpcService,
    required this.deviceConfig,
    this.offlineQueue,
  });

  Future<ScanResult?> handleUid(String rawUid) async {
    final uid = normalizeUid(rawUid);
    if (uid.isEmpty) return null;

    final now = DateTime.now();
    final lastScan = _lastScanned[uid];
    if (lastScan != null && now.difference(lastScan) < _cooldownDuration) {
      return null;
    }
    _lastScanned[uid] = now;

    final clientScanId = const Uuid().v4();
    final deviceTime = DateTime.now().toUtc();
    final deviceId = await deviceConfig.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return const ScanFailure(
        'Máy Kiosk chưa được đăng ký cho tài khoản này. Vui lòng nhờ quản lý thiết lập máy.',
        requiresDeviceSetup: true,
      );
    }

    try {
      final response = await rpcService
          .recordScan(
            uid: uid,
            deviceId: deviceId,
            deviceTime: deviceTime,
            clientScanId: clientScanId,
            isReplay: false,
          )
          .timeout(_rpcTimeout);

      final Map<String, dynamic> data = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      final status = data['status'] as String?;
      switch (status) {
        case 'ok':
          return ScanOk(
            isCheckIn: data['type'] == 'check_in',
            name: data['employee_name'] as String? ?? '',
            code: data['employee_code'] as String? ?? '',
            at: data['occurred_at'] != null
                ? DateTime.parse(data['occurred_at'] as String).toLocal()
                : now,
          );
        case 'rejected':
          return ScanRejected(reason: data['reason'] as String? ?? '');
        case 'ignored':
          return ScanIgnored(name: data['employee_name'] as String?);
        case 'duplicate':
          return null;
        default:
          return const ScanFailure(
            'Máy chủ trả kết quả không hợp lệ. Vui lòng thử lại.',
          );
      }
    } on ApiException catch (error) {
      if (error.message.contains('Unregistered or inactive device')) {
        try {
          await deviceConfig.clearDeviceId(expectedDeviceId: deviceId);
        } catch (_) {
          // Still offer the PIN-protected setup action if local cleanup fails.
        }
        return const ScanFailure(
          'Máy Kiosk chưa được liên kết với tài khoản hiện tại hoặc đã bị vô hiệu hóa. '
          'Quản lý cần kiểm tra trạng thái máy và đăng ký lại nếu được phép.',
          requiresDeviceSetup: true,
        );
      }
      return ScanFailure(
        'Máy chủ chưa ghi nhận lượt chấm công: ${error.message}',
      );
    } catch (_) {
      final queue = offlineQueue;
      if (queue != null) {
        try {
          await queue.enqueue(
            clientScanId: clientScanId,
            uid: uid,
            deviceTime: deviceTime,
          );
          return const ScanQueuedOffline();
        } catch (_) {
          return const ScanFailure(
            'Không lưu được lượt chấm công. Vui lòng thử lại hoặc liên hệ quản lý.',
          );
        }
      }
      return const ScanFailure(
        'Chưa ghi nhận lượt chấm công. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
  }
}

final kioskRpcServiceProvider = Provider<KioskRpcService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiKioskRpcService(client);
});

final scanCoordinatorProvider = Provider<ScanCoordinator>((ref) {
  final rpcService = ref.watch(kioskRpcServiceProvider);
  final deviceConfig = ref.watch(deviceConfigProvider);
  final store = ref.watch(pendingScanStoreProvider);
  return ScanCoordinator(
    rpcService: rpcService,
    deviceConfig: deviceConfig,
    offlineQueue: store,
  );
});
