import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_config.dart';
import 'pending_scan_store.dart';
import 'scan_coordinator.dart';

class SyncService {
  final PendingScanStore store;
  final KioskRpcService rpcService;
  final DeviceConfig deviceConfig;
  final Connectivity connectivity;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isFlushing = false;

  SyncService({
    required this.store,
    required this.rpcService,
    required this.deviceConfig,
    Connectivity? connectivity,
  }) : connectivity = connectivity ?? Connectivity();

  bool get isFlushing => _isFlushing;

  void start() {
    _connSub?.cancel();
    _timer?.cancel();

    // Run once at startup
    flush();

    // Listen to network changes
    _connSub = connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        flush();
      }
    });

    // Run every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      flush();
    });
  }

  void stop() {
    _timer?.cancel();
    _connSub?.cancel();
  }

  Future<int> flush() async {
    if (_isFlushing) return 0;
    _isFlushing = true;
    int syncedCount = 0;

    try {
      final deviceId = await deviceConfig.getDeviceId();
      final items = await store.listOrdered();

      for (final item in items) {
        try {
          final result = await rpcService
              .recordScan(
                uid: item.uid,
                deviceId: deviceId,
                deviceTime: item.deviceTime,
                clientScanId: item.clientScanId,
                isReplay: true,
              )
              .timeout(const Duration(seconds: 10));
          if (result is! Map ||
              !const [
                'ok',
                'duplicate',
                'ignored',
                'rejected',
              ].contains(result['status'])) {
            throw StateError('Invalid scan synchronization response');
          }

          // Any valid response from server means success -> remove item
          await store.remove(item.clientScanId);
          syncedCount++;
        } catch (e) {
          // Record failure and stop current flush round on network error
          await store.markFailed(item.clientScanId, e.toString());
          break;
        }
      }
    } catch (error) {
      // Storage/plugin initialization can fail before an RPC is attempted.
      // Keep the queue intact and allow the next scheduled retry.
      debugPrint('Unable to sync pending scans: $error');
    } finally {
      _isFlushing = false;
    }

    return syncedCount;
  }
}

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

final syncServiceProvider = Provider.autoDispose<SyncService>((ref) {
  final store = ref.watch(pendingScanStoreProvider);
  final rpcService = ref.watch(kioskRpcServiceProvider);
  final deviceConfig = ref.watch(deviceConfigProvider);
  final connectivity = ref.watch(connectivityProvider);

  final service = SyncService(
    store: store,
    rpcService: rpcService,
    deviceConfig: deviceConfig,
    connectivity: connectivity,
  );

  service.start();
  ref.onDispose(service.stop);
  return service;
});
