import 'dart:convert';
import 'dart:typed_data';

import 'package:demo_nfc/core/api_client.dart';
import 'package:demo_nfc/features/admin/attendance/attendance_models.dart';
import 'package:demo_nfc/features/business/attendance_ticket_form.dart';
import 'package:demo_nfc/features/business/attendance_ticket_repository.dart';
import 'package:demo_nfc/features/business/ticket_evidence.dart';
import 'package:demo_nfc/features/business/ticket_evidence_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements AttendanceTicketRepository {}

class MockFiles extends Mock implements TicketEvidenceFiles {}

void main() {
  late MockRepository repository;
  late MockFiles files;
  final evidence = TicketEvidence(
    'bang_chung.png',
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    ),
  );
  final event = AttendanceEventItem(
    id: 's1',
    employeeId: 'e1',
    type: 'check_in',
    occurredAt: DateTime(2025, 7, 1, 9),
    source: 'nfc',
  );
  setUpAll(() {
    registerFallbackValue(DateTime(2025));
    registerFallbackValue(evidence);
  });
  setUp(() {
    repository = MockRepository();
    files = MockFiles();
    when(() => files.pick()).thenAnswer((_) async => evidence);
    when(() => files.save(any(), any())).thenAnswer((_) async => true);
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
  Widget app(Widget child) => ProviderScope(
    overrides: [
      attendanceTicketRepositoryProvider.overrideWithValue(repository),
      ticketEvidenceFilesProvider.overrideWithValue(files),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  test('evidence size count and type validation', () {
    expect(() => validateTicketEvidence([evidence]), returnsNormally);
    expect(
      () => validateTicketEvidence(List.filled(4, evidence)),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => validateTicketEvidence([TicketEvidence('bad.exe', evidence.bytes)]),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => validateTicketEvidence([
        TicketEvidence('big.pdf', Uint8List(2 * 1024 * 1024 + 1)),
      ]),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => validateTicketEvidence(
        List.generate(
          3,
          (i) => TicketEvidence('$i.png', Uint8List(2 * 1024 * 1024)),
        ),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  testWidgets('pick remove and submit selected evidence on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => AttendanceTicketForm.show(context, event: event),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Sai gio, co bang chung',
    );
    await tester.ensureVisible(find.text('Đính kèm bằng chứng'));
    await tester.tap(find.text('Đính kèm bằng chứng'));
    await tester.pumpAndSettle();
    expect(find.text('bang_chung.png'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Bỏ tệp bang_chung.png'));
    await tester.tap(find.byTooltip('Bỏ tệp bang_chung.png'));
    await tester.pumpAndSettle();
    expect(find.text('bang_chung.png'), findsNothing);
    await tester.ensureVisible(find.text('Đính kèm bằng chứng'));
    await tester.tap(find.text('Đính kèm bằng chứng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi ticket'));
    await tester.pumpAndSettle();
    final captured =
        verify(
              () => repository.create(
                kind: 'incorrect_time',
                proposedAt: event.occurredAt,
                reason: 'Sai gio, co bang chung',
                originalEventId: 's1',
                attachments: captureAny(named: 'attachments'),
              ),
            ).captured.single
            as List<TicketEvidence>;
    expect(captured.single.name, evidence.name);
    expect(captured.single.bytes, evidence.bytes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reviewer can preview and download evidence', (tester) async {
    when(() => repository.evidence('t1', 'f1')).thenAnswer(
      (_) async => {
        'file_name': evidence.name,
        'content_type': 'image/png',
        'content_base64': base64Encode(evidence.bytes),
      },
    );
    await tester.pumpWidget(
      app(
        TicketEvidenceList(
          ticket: {
            'id': 't1',
            'attachments': [
              {
                'id': 'f1',
                'file_name': evidence.name,
                'content_type': 'image/png',
                'size_bytes': evidence.bytes.length,
              },
            ],
          },
        ),
      ),
    );
    await tester.tap(find.textContaining('bang_chung.png'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Tải tệp'));
    await tester.pumpAndSettle();
    verify(() => files.save(any(), 'image/png')).called(1);
    expect(find.text('Đã lưu bằng chứng.'), findsOneWidget);
  });

  testWidgets('download denial shows error without preview', (tester) async {
    when(
      () => repository.evidence('t1', 'f1'),
    ).thenThrow(const ApiException('Không tìm thấy bằng chứng', status: 404));
    await tester.pumpWidget(
      app(
        const TicketEvidenceList(
          ticket: {
            'id': 't1',
            'attachments': [
              {
                'id': 'f1',
                'file_name': 'private.pdf',
                'content_type': 'application/pdf',
                'size_bytes': 100,
              },
            ],
          },
        ),
      ),
    );
    await tester.tap(find.textContaining('private.pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tải được bằng chứng'), findsOneWidget);
    expect(find.text('Tải tệp'), findsNothing);
    verifyNever(() => files.save(any(), any()));
  });
}
