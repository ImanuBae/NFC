import 'dart:async';

import 'package:demo_nfc/core/router.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:demo_nfc/features/kiosk/device_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeviceConfig extends Mock implements DeviceConfig {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockDeviceConfig mockDeviceConfig;
  late StreamController<AuthState> authStateController;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockDeviceConfig = MockDeviceConfig();
    authStateController = StreamController<AuthState>.broadcast();

    when(() => mockAuthRepo.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() {
    authStateController.close();
  });

  testWidgets('unauthenticated user is redirected to /login', (tester) async {
    when(() => mockAuthRepo.currentUser).thenReturn(null);
    when(() => mockAuthRepo.getCurrentUserRole()).thenAnswer((_) async => null);
    when(() => mockDeviceConfig.getDeviceId()).thenAnswer((_) async => null);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        deviceConfigProvider.overrideWithValue(mockDeviceConfig),
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
