import 'package:demo_nfc/features/business/accounts_page.dart';
import 'package:demo_nfc/features/business/business_repository.dart';
import 'package:demo_nfc/features/business/employee_home_page.dart';
import 'package:demo_nfc/features/business/employee_today_page.dart';
import 'package:demo_nfc/features/business/employee_profile_card.dart';
import 'package:demo_nfc/features/business/face_camera_service.dart';
import 'package:demo_nfc/features/business/reports_page.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBusiness extends Mock implements BusinessRepository {}

class MockAuth extends Mock implements AuthRepository {}

class MockFaceCamera extends Mock implements FaceCameraService {}

void main() {
  testWidgets(
    'period report renders payroll preview and exposes all four periods',
    (tester) async {
      final repo = MockBusiness();
      when(() => repo.report(any(), any())).thenAnswer(
        (_) async => [
          {
            'employee_id': 'e1',
            'code': 'E1',
            'full_name': 'An',
            'worked_minutes': 480,
            'hourly_rate': 60000,
            'gross_pay': 480000,
            'days_worked': 1,
            'missing_checkout': 0,
            'late_days': 0,
            'early_days': 0,
          },
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [businessRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: ReportsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('E1 · An'), findsOneWidget);
      expect(find.textContaining('8.00 giờ'), findsOneWidget);
      await tester.tap(find.text('Tháng').first);
      await tester.pumpAndSettle();
      expect(find.text('Tuần'), findsOneWidget);
      expect(find.text('Quý'), findsOneWidget);
      expect(find.text('Năm'), findsOneWidget);
      await tester.tap(find.text('Tuần'));
      await tester.pumpAndSettle();
      expect(find.text('Chốt lương'), findsOneWidget);
      verify(() => repo.report(any(), any())).called(2);
    },
  );

  testWidgets(
    'email failures are shown per employee instead of claiming success',
    (tester) async {
      final repo = MockBusiness();
      when(() => repo.report(any(), any())).thenAnswer(
        (_) async => [
          {
            'employee_id': 'e1',
            'code': 'E1',
            'full_name': 'An',
            'worked_minutes': 0,
            'hourly_rate': 60000,
            'gross_pay': 0,
            'days_worked': 0,
            'missing_checkout': 0,
            'late_days': 0,
            'early_days': 0,
          },
        ],
      );
      when(() => repo.action('email_report', any()))
          .thenThrow(Exception('Email chưa cấu hình'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [businessRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: ReportsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi báo cáo qua email'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Đã xử lý 0/1 báo cáo'), findsOneWidget);
      expect(find.textContaining('Email chưa cấu hình'), findsOneWidget);
    },
  );

  testWidgets(
    'face revocation requires confirmation and refreshes account list',
    (tester) async {
      final repo = MockBusiness();
      when(() => repo.accounts()).thenAnswer(
        (_) async => [
          {
            'id': 'u1',
            'email': 'an@example.com',
            'role': 'employee',
            'active': true,
          },
        ],
      );
      when(() => repo.faces()).thenAnswer(
        (_) async => [
          {
            'id': 'device1',
            'user_id': 'u1',
            'device_name': 'Phone',
            'approved': true,
            'revoked': false,
          },
        ],
      );
      when(() => repo.action('revoke_face', any()))
          .thenAnswer((_) async => {'status': 'ok'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [businessRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: AccountsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Duyệt khuôn mặt'), findsNothing);
      await tester.tap(find.byTooltip('Thu hồi khuôn mặt'));
      await tester.pumpAndSettle();
      verifyNever(() => repo.action('revoke_face', any()));
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      verify(() => repo.action('revoke_face', {'id': 'device1'})).called(1);
    },
  );

  testWidgets(
    'employee dashboard exposes camera without OS biometric controls',
    (tester) async {
      final face = MockFaceCamera();
      when(() => face.credential()).thenAnswer((_) async => null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            faceCameraServiceProvider.overrideWithValue(face),
            currentRoleProvider.overrideWith((ref) async => 'employee'),
            myTodayProvider.overrideWith((ref) async => null),
            currentEmployeeProfileProvider.overrideWith((ref) async => null),
            currentEmployeeCardsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: EmployeeHomePage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cá nhân').last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.fingerprint), findsNothing);
      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    },
  );
}
