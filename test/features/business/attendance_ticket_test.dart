import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/admin/employees/employee_detail_page.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:demo_nfc/features/business/attendance_ticket_form.dart';
import 'package:demo_nfc/features/business/attendance_ticket_repository.dart';
import 'package:demo_nfc/features/business/attendance_tickets_page.dart';
import 'package:demo_nfc/features/kiosk/my_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTicketRepository extends Mock implements AttendanceTicketRepository {}

void main() {
  late MockTicketRepository repository;
  final event = AttendanceEventItem(
    id: 'scan-1',
    employeeId: 'e1',
    type: 'check_in',
    occurredAt: DateTime(2025, 6, 2, 9),
    source: 'nfc',
  );
  setUpAll(() => registerFallbackValue(DateTime(2025)));
  setUp(() {
    repository = MockTicketRepository();
    when(() => repository.list()).thenAnswer((_) async => []);
    when(
      () => repository.create(
        kind: any(named: 'kind'),
        proposedAt: any(named: 'proposedAt'),
        reason: any(named: 'reason'),
        originalEventId: any(named: 'originalEventId'),
        attachments: any(named: 'attachments'),
      ),
    ).thenAnswer((_) async {});
  });
  Widget app(Widget child, {List<AttendanceEventItem> events = const []}) =>
      ProviderScope(
        overrides: [
          attendanceTicketRepositoryProvider.overrideWithValue(repository),
          currentUserEmployeeIdProvider.overrideWith((ref) async => 'e1'),
          myAttendanceEventsProvider('e1').overrideWith((ref) async => events),
          employeeDetailProvider('e1').overrideWith((ref) async => null),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('history exposes creation even without attendance events', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const MyHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('Tạo ticket sửa công'), findsOneWidget);
    expect(find.text('Ticket của tôi'), findsOneWidget);
    await tester.tap(find.text('Tạo ticket sửa công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correction submits the selected original event and reason', (
    tester,
  ) async {
    bool? submitted;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => submitted = await AttendanceTicketForm.show(
              context,
              event: event,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lượt gốc: Vào'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Máy ghi sai giờ');
    await tester.tap(find.text('Gửi ticket'));
    await tester.pumpAndSettle();
    verify(
      () => repository.create(
        kind: 'incorrect_time',
        proposedAt: event.occurredAt,
        reason: 'Máy ghi sai giờ',
        originalEventId: 'scan-1',
        attachments: any(named: 'attachments'),
      ),
    ).called(1);
    expect(submitted, true);
  });

  testWidgets('failed send keeps entered reason for retry', (tester) async {
    when(
      () => repository.create(
        kind: any(named: 'kind'),
        proposedAt: any(named: 'proposedAt'),
        reason: any(named: 'reason'),
        originalEventId: any(named: 'originalEventId'),
        attachments: any(named: 'attachments'),
      ),
    ).thenThrow(Exception('Mất kết nối'));
    await tester.pumpWidget(app(AttendanceTicketForm(event: event)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Quên quét thẻ');
    await tester.tap(find.text('Gửi ticket'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mất kết nối'), findsOneWidget);
    expect(find.text('Quên quét thẻ'), findsOneWidget);
    expect(find.text('Gửi ticket'), findsOneWidget);
  });

  testWidgets(
    'personal tickets show review feedback and filter other employees',
    (tester) async {
      when(() => repository.list()).thenAnswer(
        (_) async => [
          {
            'id': 't1',
            'employee_id': 'e1',
            'kind': 'missing_in',
            'status': 'rejected',
            'proposed_at': '2025-06-02T02:00:00Z',
            'reason': 'Quên quét',
            'response': 'Cần xác nhận ca làm',
          },
          {
            'id': 't2',
            'employee_id': 'e2',
            'kind': 'missing_out',
            'status': 'pending',
            'proposed_at': '2025-06-02T11:00:00Z',
            'reason': 'Thông tin người khác',
          },
        ],
      );
      await tester.pumpWidget(app(const AttendanceTicketsPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Từ chối'), findsOneWidget);
      expect(find.text('Phản hồi: Cần xác nhận ca làm'), findsOneWidget);
      expect(find.textContaining('Thông tin người khác'), findsNothing);
    },
  );
}
