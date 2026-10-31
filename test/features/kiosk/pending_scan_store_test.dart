import 'package:demo_nfc/features/kiosk/pending_scan_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  late InMemoryPendingScanStore store;

  setUp(() {
    store = InMemoryPendingScanStore();
  });

  group('PendingScanStore', () {
    test('pending count includes scans saved before subscribing', () async {
      await store.enqueue(
        clientScanId: 'existing-scan',
        uid: 'UID1',
        deviceTime: DateTime.utc(2026, 9, 28),
      );
      final container = ProviderContainer(
        overrides: [pendingScanStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(pendingCountProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(pendingCountProvider.future), 1);
    });

    test('enqueues items and reports count correctly', () async {
      expect(await store.count(), equals(0));

      await store.enqueue(
        clientScanId: 'scan-1',
        uid: '04A1B2C3D4E501',
        deviceTime: DateTime.utc(2026, 9, 28, 8, 0, 0),
      );

      expect(await store.count(), equals(1));

      await store.enqueue(
        clientScanId: 'scan-2',
        uid: '04A1B2C3D4E502',
        deviceTime: DateTime.utc(2026, 9, 28, 8, 5, 0),
      );

      expect(await store.count(), equals(2));
    });

    test('listOrdered returns items sorted by device_time ascending', () async {
      final t1 = DateTime.utc(2026, 9, 28, 8, 0, 0);
      final t2 = DateTime.utc(2026, 9, 28, 8, 10, 0);
      final t3 = DateTime.utc(2026, 9, 28, 8, 20, 0);

      // Insert out of order
      await store.enqueue(clientScanId: 'scan-2', uid: 'UID2', deviceTime: t2);
      await store.enqueue(clientScanId: 'scan-3', uid: 'UID3', deviceTime: t3);
      await store.enqueue(clientScanId: 'scan-1', uid: 'UID1', deviceTime: t1);

      final list = await store.listOrdered();
      expect(list.length, equals(3));
      expect(list[0].clientScanId, equals('scan-1'));
      expect(list[1].clientScanId, equals('scan-2'));
      expect(list[2].clientScanId, equals('scan-3'));
    });

    test('remove removes the item from store', () async {
      await store.enqueue(
        clientScanId: 'scan-1',
        uid: 'UID1',
        deviceTime: DateTime.now().toUtc(),
      );
      expect(await store.count(), equals(1));

      await store.remove('scan-1');
      expect(await store.count(), equals(0));
    });

    test('markFailed increments attempts and saves lastError', () async {
      await store.enqueue(
        clientScanId: 'scan-1',
        uid: 'UID1',
        deviceTime: DateTime.now().toUtc(),
      );

      await store.markFailed('scan-1', 'Connection timeout');
      var list = await store.listOrdered();
      expect(list.first.attempts, equals(1));
      expect(list.first.lastError, equals('Connection timeout'));

      await store.markFailed('scan-1', 'Server 500 error');
      list = await store.listOrdered();
      expect(list.first.attempts, equals(2));
      expect(list.first.lastError, equals('Server 500 error'));
    });
  });
}
