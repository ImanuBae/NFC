import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:demo_nfc/features/kiosk/device_config.dart';
import 'package:demo_nfc/features/kiosk/pending_scan_store.dart';
import 'package:demo_nfc/features/kiosk/scan_coordinator.dart';
import 'package:demo_nfc/features/kiosk/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

class MockKioskRpcService extends Mock implements KioskRpcService {}

class MockDeviceConfig extends Mock implements DeviceConfig {}

class MockConnectivity extends Mock implements Connectivity {}

class MockPendingScanStore extends Mock implements PendingScanStore {}

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
      'keeps queued attendance when the server returns an unknown status',
      () async {
        await store.enqueue(
          clientScanId: 'pending',
          uid: '04AABB',
          deviceTime: DateTime.utc(2026, 1, 1),
        );
        when(
          () => mockRpcService.recordScan(
            uid: any(named: 'uid'),
            deviceId: any(named: 'deviceId'),
            deviceTime: any(named: 'deviceTime'),
            clientScanId: any(named: 'clientScanId'),
            isReplay: any(named: 'isReplay'),
          ),
        ).thenAnswer((_) async => {'status': 'unknown'});
        expect(await syncService.flush(), 0);
        expect(await store.count(), 1);
        expect((await store.listOrdered()).single.attempts, 1);
      },
    );

    test('provider starts syncing and stops listening when disposed', () async {
      final changes = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(changes.close);
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => changes.stream);
      await store.enqueue(
        clientScanId: 'pending-at-startup',
        uid: 'UID1',
        deviceTime: DateTime.utc(2026, 9, 28),
      );
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer((_) async => {'status': 'ok'});

      final container = ProviderContainer(
        overrides: [
          pendingScanStoreProvider.overrideWithValue(store),
          kioskRpcServiceProvider.overrideWithValue(mockRpcService),
          deviceConfigProvider.overrideWithValue(mockDeviceConfig),
          connectivityProvider.overrideWithValue(mockConnectivity),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(syncServiceProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(await store.count(), 0);
      expect(changes.hasListener, isTrue);
      subscription.close();
      await container.pump();
      expect(changes.hasListener, isFalse);
    });

    test('storage failure does not leave syncing locked', () async {
      final brokenStore = MockPendingScanStore();
      when(() => brokenStore.listOrdered()).thenThrow(StateError('DB failed'));
      final service = SyncService(
        store: brokenStore,
        rpcService: mockRpcService,
        deviceConfig: mockDeviceConfig,
        connectivity: mockConnectivity,
      );
      expect(await service.flush(), 0);
      expect(service.isFlushing, isFalse);
      when(() => brokenStore.listOrdered()).thenAnswer((_) async => []);
      expect(await service.flush(), 0);
      expect(service.isFlushing, isFalse);
    });

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
