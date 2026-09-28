import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/result.dart';
import '../../core/supabase_client.dart';
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

class SupabaseKioskRpcService implements KioskRpcService {
  final SupabaseClient _client;

  SupabaseKioskRpcService(this._client);

  @override
  Future<dynamic> recordScan({
    required String uid,
    required String? deviceId,
    required DateTime deviceTime,
    required String clientScanId,
    required bool isReplay,
  }) {
    return _client.rpc(
      'record_scan',
      params: {
        'p_uid': uid,
        'p_device_id': deviceId,
        'p_device_time': deviceTime.toIso8601String(),
        'p_client_scan_id': clientScanId,
        'p_is_replay': isReplay,
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
          return null;
      }
    } catch (_) {
      final queue = offlineQueue;
      if (queue != null) {
        await queue.enqueue(
          clientScanId: clientScanId,
          uid: uid,
          deviceTime: deviceTime,
        );
      }
      return const ScanQueuedOffline();
    }
  }
}

final kioskRpcServiceProvider = Provider<KioskRpcService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseKioskRpcService(client);
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
