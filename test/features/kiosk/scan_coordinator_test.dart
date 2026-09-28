import 'package:demo_nfc/core/result.dart';
import 'package:demo_nfc/features/kiosk/device_config.dart';
import 'package:demo_nfc/features/kiosk/scan_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockKioskRpcService extends Mock implements KioskRpcService {}

class MockDeviceConfig extends Mock implements DeviceConfig {}

class MockOfflineScanQueue extends Mock implements OfflineScanQueue {}

void main() {
  late MockKioskRpcService mockRpcService;
  late MockDeviceConfig mockDeviceConfig;
  late MockOfflineScanQueue mockOfflineQueue;
  late ScanCoordinator coordinator;

  setUp(() {
    mockRpcService = MockKioskRpcService();
    mockDeviceConfig = MockDeviceConfig();
    mockOfflineQueue = MockOfflineScanQueue();

    when(() => mockDeviceConfig.getDeviceId())
        .thenAnswer((_) async => 'dev-uuid-123');

    coordinator = ScanCoordinator(
      rpcService: mockRpcService,
      deviceConfig: mockDeviceConfig,
      offlineQueue: mockOfflineQueue,
    );
  });

  group('ScanCoordinator', () {
    test('maps ok check_in response correctly', () async {
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer(
        (_) async => {
          'status': 'ok',
          'type': 'check_in',
          'employee_name': 'Nguyen Van A',
          'employee_code': 'NV01',
          'occurred_at': '2026-09-28T08:30:00Z',
        },
      );

      final result = await coordinator.handleUid('04:A1:B2:C3:D4:E5:01');

      expect(result, isA<ScanOk>());
      final ok = result as ScanOk;
      expect(ok.isCheckIn, isTrue);
      expect(ok.name, equals('Nguyen Van A'));
      expect(ok.code, equals('NV01'));
    });

    test('maps ok check_out response correctly', () async {
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer(
        (_) async => {
          'status': 'ok',
          'type': 'check_out',
          'employee_name': 'Tran Thi B',
          'employee_code': 'NV02',
          'occurred_at': '2026-09-28T17:30:00Z',
        },
      );

      final result = await coordinator.handleUid('04A1B2C3D4E502');

      expect(result, isA<ScanOk>());
      final ok = result as ScanOk;
      expect(ok.isCheckIn, isFalse);
      expect(ok.name, equals('Tran Thi B'));
    });

    test('maps rejected response correctly', () async {
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer(
        (_) async => {
          'status': 'rejected',
          'reason': 'unknown_or_inactive_card',
        },
      );

      final result = await coordinator.handleUid('UNKNOWN999999');

      expect(result, isA<ScanRejected>());
      final rej = result as ScanRejected;
      expect(rej.reason, equals('unknown_or_inactive_card'));
    });

    test('maps ignored response correctly', () async {
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer(
        (_) async => {'status': 'ignored', 'employee_name': 'Nguyen Van A'},
      );

      final result = await coordinator.handleUid('04A1B2C3D4E503');

      expect(result, isA<ScanIgnored>());
      final ign = result as ScanIgnored;
      expect(ign.name, equals('Nguyen Van A'));
    });

    test('maps duplicate response to null', () async {
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer((_) async => {'status': 'duplicate'});

      final result = await coordinator.handleUid('04A1B2C3D4E504');

      expect(result, isNull);
    });

    test('enforces 3-second cooldown on same UID and returns null', () async {
      when(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).thenAnswer(
        (_) async => {
          'status': 'ok',
          'type': 'check_in',
          'employee_name': 'Nguyen Van A',
          'employee_code': 'NV01',
          'occurred_at': '2026-09-28T08:30:00Z',
        },
      );

      final firstResult = await coordinator.handleUid('04A1B2C3D4E505');
      expect(firstResult, isNotNull);

      // Immediate second scan of same card should be debounced locally
      final secondResult = await coordinator.handleUid('04A1B2C3D4E505');
      expect(secondResult, isNull);
      verify(
        () => mockRpcService.recordScan(
          uid: any(named: 'uid'),
          deviceId: any(named: 'deviceId'),
          deviceTime: any(named: 'deviceTime'),
          clientScanId: any(named: 'clientScanId'),
          isReplay: any(named: 'isReplay'),
        ),
      ).called(1);
    });

    test(
      'on network exception, calls enqueue and returns ScanQueuedOffline',
      () async {
        when(
          () => mockRpcService.recordScan(
            uid: any(named: 'uid'),
            deviceId: any(named: 'deviceId'),
            deviceTime: any(named: 'deviceTime'),
            clientScanId: any(named: 'clientScanId'),
            isReplay: any(named: 'isReplay'),
          ),
        ).thenThrow(Exception('Network timeout'));

        when(
          () => mockOfflineQueue.enqueue(
            clientScanId: any(named: 'clientScanId'),
            uid: any(named: 'uid'),
            deviceTime: any(named: 'deviceTime'),
          ),
        ).thenAnswer((_) async {});

        final result = await coordinator.handleUid('04A1B2C3D4E506');

        expect(result, isA<ScanQueuedOffline>());
        verify(
          () => mockOfflineQueue.enqueue(
            clientScanId: any(named: 'clientScanId'),
            uid: '04A1B2C3D4E506',
            deviceTime: any(named: 'deviceTime'),
          ),
        ).called(1);
      },
    );
  });
}
