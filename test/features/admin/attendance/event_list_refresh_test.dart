import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/admin/attendance/attendance_repository.dart';
import 'package:demo_nfc/features/admin/attendance/event_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  testWidgets('event list automatically refreshes with the original filters', (
    tester,
  ) async {
    final repo = MockAttendanceRepository();
    var scanned = false;
    when(
      () => repo.getEvents(employeeId: 'emp-1', date: DateTime(2026, 10, 30)),
    ).thenAnswer(
      (_) async => scanned
          ? [
              AttendanceEventItem(
                id: 'event-new',
                employeeId: 'emp-1',
                employeeCode: 'NV01',
                employeeName: 'Nhan vien',
                type: 'check_in',
                occurredAt: DateTime(2026, 10, 30, 8),
                source: 'nfc',
              ),
            ]
          : [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: EventListPage(employeeId: 'emp-1', date: '2026-10-30'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scanned = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('NV01'), findsOneWidget);
    verify(
      () => repo.getEvents(employeeId: 'emp-1', date: DateTime(2026, 10, 30)),
    ).called(2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
