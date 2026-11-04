import 'dart:async';

import 'package:demo_nfc/core/router.dart';
import 'package:demo_nfc/core/server_connection.dart';
import 'package:demo_nfc/features/admin/attendance/day_report_page.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:demo_nfc/features/kiosk/device_config.dart';
import 'package:demo_nfc/features/kiosk/sync_service.dart';
import 'package:demo_nfc/features/business/face_camera_service.dart';
import 'package:demo_nfc/features/business/attendance_ticket_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeviceConfig extends Mock implements DeviceConfig {}

class MockUser extends Mock implements AppUser {}

class MockSyncService extends Mock implements SyncService {}

class MockFaceCameraService extends Mock implements FaceCameraService {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockDeviceConfig mockDeviceConfig;
  late StreamController<AppUser?> authStateController;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockDeviceConfig = MockDeviceConfig();
    authStateController = StreamController<AppUser?>.broadcast();

    when(() => mockAuthRepo.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() {
    authStateController.close();
  });

  test('login notifications still update routing after changing API server', () async {
    SharedPreferences.setMockInitialValues({});
    final nextAuth = MockAuthRepository();
    final nextEvents = StreamController<AppUser?>.broadcast();
    addTearDown(nextEvents.close);
    AppUser? signedInUser;
    when(() => mockAuthRepo.currentUser).thenReturn(null);
    when(() => mockAuthRepo.getCurrentUserRole()).thenAnswer((_) async => null);
    when(() => nextAuth.authStateChanges).thenAnswer((_) => nextEvents.stream);
    when(() => nextAuth.currentUser).thenAnswer((_) => signedInUser);
    when(() => nextAuth.getCurrentUserRole())
        .thenAnswer((_) async => signedInUser?.role);
    when(() => mockDeviceConfig.getDeviceId()).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [
        initialServerUrlProvider.overrideWithValue('http://127.0.0.1:5080'),
        authRepositoryProvider.overrideWith(
          (ref) => ref.watch(serverUrlProvider).startsWith('https:')
              ? nextAuth
              : mockAuthRepo,
        ),
        deviceConfigProvider.overrideWithValue(mockDeviceConfig),
      ],
    );
    addTearDown(container.dispose);
    await container.read(routerNotifierProvider).refreshState();
    await container
        .read(serverUrlProvider.notifier)
        .save('https://demo.devtunnels.ms');
    final notifier = container.read(routerNotifierProvider);
    await notifier.refreshState();
    expect(notifier.userRole, isNull);
    signedInUser = const AppUser(
      id: 'kiosk',
      email: 'kiosk@test.local',
      role: 'kiosk',
    );
    nextEvents.add(signedInUser);
    // Drain the async role/device lookup triggered by the new server's stream.
    await Future<void>.delayed(Duration.zero);
    expect(notifier.userRole, 'kiosk');
  });

  for (final role in ['employee', 'manager']) {
    testWidgets('$role cannot enter account or employee administration', (
      tester,
    ) async {
      when(() => mockAuthRepo.currentUser).thenReturn(MockUser());
      when(() => mockAuthRepo.getCurrentUserRole())
          .thenAnswer((_) async => role);
      when(() => mockDeviceConfig.getDeviceId()).thenAnswer((_) async => null);
      final biometric = MockFaceCameraService();
      when(() => biometric.credential()).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          deviceConfigProvider.overrideWithValue(mockDeviceConfig),
          faceCameraServiceProvider.overrideWithValue(biometric),
          dayReportProvider.overrideWith((ref) async => []),
          attendanceTicketsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      await container.read(routerNotifierProvider).refreshState();
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      for (final path in ['/admin/accounts', '/admin/employees']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.state.matchedLocation,
          role == 'employee' ? '/me' : '/admin/days',
        );
      }
    });
  }

  testWidgets('unauthenticated user is redirected to /login', (tester) async {
    when(() => mockAuthRepo.currentUser).thenReturn(null);
    when(() => mockAuthRepo.getCurrentUserRole()).thenAnswer((_) async => null);
    when(() => mockDeviceConfig.getDeviceId()).thenAnswer((_) async => null);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        deviceConfigProvider.overrideWithValue(mockDeviceConfig),
        syncServiceProvider.overrideWithValue(MockSyncService()),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, equals('/login'));
  });

  testWidgets('admin cannot access /kiosk and is redirected to /admin/days', (
    tester,
  ) async {
    final mockUser = MockUser();
    when(() => mockAuthRepo.currentUser).thenReturn(mockUser);
    when(() => mockAuthRepo.getCurrentUserRole())
        .thenAnswer((_) async => 'admin');
    when(() => mockDeviceConfig.getDeviceId()).thenAnswer((_) async => null);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        deviceConfigProvider.overrideWithValue(mockDeviceConfig),
        syncServiceProvider.overrideWithValue(MockSyncService()),
        dayReportProvider.overrideWith((ref) async => []),
        attendanceTicketsProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);

    // Initialize router notifier
    final notifier = container.read(routerNotifierProvider);
    await notifier.refreshState();

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Try navigating to kiosk
    router.go('/kiosk');
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, equals('/admin/days'));
  });

  testWidgets(
    'kiosk without device_id is redirected to /kiosk/setup, cannot access /admin/days',
    (tester) async {
      final mockUser = MockUser();
      when(() => mockAuthRepo.currentUser).thenReturn(mockUser);
      when(() => mockAuthRepo.getCurrentUserRole())
          .thenAnswer((_) async => 'kiosk');
      when(() => mockDeviceConfig.getDeviceId()).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          deviceConfigProvider.overrideWithValue(mockDeviceConfig),
          syncServiceProvider.overrideWithValue(MockSyncService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routerNotifierProvider);
      await notifier.refreshState();

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/kiosk/setup'));

      // Try navigating to admin
      router.go('/admin/days');
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/kiosk/setup'));
    },
  );

  testWidgets(
    'kiosk with device_id goes to /kiosk, cannot access /admin/days',
    (tester) async {
      final mockUser = MockUser();
      when(() => mockAuthRepo.currentUser).thenReturn(mockUser);
      when(() => mockAuthRepo.getCurrentUserRole())
          .thenAnswer((_) async => 'kiosk');
      when(() => mockDeviceConfig.getDeviceId())
          .thenAnswer((_) async => 'device-123');

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          deviceConfigProvider.overrideWithValue(mockDeviceConfig),
          syncServiceProvider.overrideWithValue(MockSyncService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routerNotifierProvider);
      await notifier.refreshState();

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/kiosk'));

      // Try navigating to admin
      router.go('/admin/days');
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/kiosk'));
    },
  );
}
