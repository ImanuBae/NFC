import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:demo_nfc/features/kiosk/device_config.dart';
import 'package:demo_nfc/features/kiosk/pending_scan_store.dart';
import 'package:demo_nfc/features/kiosk/scan_coordinator.dart';
import 'package:demo_nfc/features/kiosk/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockKioskRpcService extends Mock implements KioskRpcService {}

class MockDeviceConfig extends Mock implements DeviceConfig {}

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late InMemoryPendingScanStore store;
  late MockKioskRpcService mockRpcService;
  late MockDeviceConfig mockDeviceConfig;
  late MockConnectivity mockConnectivity;
  late SyncService syncService;

  setUp(() {
    store = InMemoryPendingScanStore();
    mockRpcService = MockKioskRpcService();
    mockDeviceConfig = MockDeviceConfig();
    mockConnectivity = MockConnectivity();

    when(() => mockDeviceConfig.getDeviceId())
        .thenAnswer((_) async => 'dev-uuid-123');

    syncService = SyncService(
      store: store,
      rpcService: mockRpcService,
      deviceConfig: mockDeviceConfig,
      connectivity: mockConnectivity,
    );
  });

  group('SyncService', () {
    test(
      'flushes items in device_time ascending order and removes on success',
      () async {
        final t1 = DateTime.utc(2026, 9, 28, 8, 0, 0);
        final t2 = DateTime.utc(2026, 9, 28, 8, 10, 0);

        await store.enqueue(
          clientScanId: 'scan-2',
          uid: 'UID2',
          deviceTime: t2,
        );
        await store.enqueue(
          clientScanId: 'scan-1',
          uid: 'UID1',
          deviceTime: t1,
        );

        final syncedUids = <String>[];
        when(
          () => mockRpcService.recordScan(
            uid: any(named: 'uid'),
            deviceId: any(named: 'deviceId'),
            deviceTime: any(named: 'deviceTime'),
            clientScanId: any(named: 'clientScanId'),
            isReplay: any(named: 'isReplay'),
          ),
        ).thenAnswer((inv) async {
          syncedUids.add(inv.namedArguments[#uid] as String);
          return {'status': 'ok'};
        });

        final count = await syncService.flush();

        expect(count, equals(2));
        expect(syncedUids, equals(['UID1', 'UID2'])); // t1 before t2
        expect(await store.count(), equals(0)); // All removed from store
      },
    );

    test('retains item and stops flush on network exception', () async {
      final t1 = DateTime.utc(2026, 9, 28, 8, 0, 0);
      final t2 = DateTime.utc(2026, 9, 28, 8, 10, 0);

      await store.enqueue(clientScanId: 'scan-1', uid: 'UID1', deviceTime: t1);
      await store.enqueue(clientScanId: 'scan-2', uid: 'UID2', deviceTime: t2);

      // First call throws network error
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenThrow(Exception('No internet'));

      final count = await syncService.flush();

      expect(count, equals(0));
      expect(await store.count(), equals(2)); // Both items retained
      final list = await store.listOrdered();
      expect(list.first.attempts, equals(1)); // First item marked failed
      expect(list.first.lastError, contains('No internet'));
    });

    test('prevents concurrent flush executions (mutex flag)', () async {
      final t1 = DateTime.utc(2026, 9, 28, 8, 0, 0);
      await store.enqueue(clientScanId: 'scan-1', uid: 'UID1', deviceTime: t1);

      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return {'status': 'ok'};
      });

      // Launch two flushes simultaneously
      final future1 = syncService.flush();
      final future2 = syncService.flush();

      final results = await Future.wait([future1, future2]);
      // One flush executed and synced 1 item, the other was skipped returning 0
      expect(results, containsAllInOrder([1, 0]));
    });
  });
}
