import 'dart:async';

import 'package:demo_nfc/features/business/face_camera_card.dart';
import 'package:demo_nfc/features/business/face_camera_service.dart';
import 'package:demo_nfc/features/auth/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFace extends Mock implements FaceCameraService {}

void main() {
  Widget faceCard(MockFace face) => ProviderScope(
    overrides: [faceCameraServiceProvider.overrideWithValue(face)],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: FaceCameraCard())),
    ),
  );

  testWidgets('employee can cancel replacement then replace after consent', (
    tester,
  ) async {
    final face = MockFace();
    var reads = 0;
    when(() => face.credential()).thenAnswer(
      (_) async => {'id': reads++ == 0 ? 'old' : 'new', 'approved': true},
    );
    when(() => face.submit('reenroll'))
        .thenAnswer((_) async => {'status': 'enrolled'});
    await tester.pumpWidget(faceCard(face));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký lại khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mẫu cũ chỉ được thay'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    verifyNever(() => face.submit(any()));
    expect(find.text('Mã đăng ký: old'), findsOneWidget);
    await tester.tap(find.text('Đăng ký lại khuôn mặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    verify(() => face.submit('reenroll')).called(1);
    expect(find.text('Mã đăng ký: new'), findsOneWidget);
    expect(find.textContaining('Đã cập nhật mẫu khuôn mặt.'), findsOneWidget);
  });

  testWidgets('failed replacement keeps previous status and permits retry', (
    tester,
  ) async {
    final face = MockFace();
    when(() => face.credential())
        .thenAnswer((_) async => {'id': 'old', 'approved': true});
    when(() => face.submit('reenroll')).thenThrow(
      PlatformException(code: 'FACE_CANCELLED', message: 'Camera đã hủy'),
    );
    await tester.pumpWidget(faceCard(face));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký lại khuôn mặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    expect(find.text('Mã đăng ký: old'), findsOneWidget);
    expect(
      find.textContaining('Mẫu khuôn mặt cũ vẫn được giữ nguyên.'),
      findsOneWidget,
    );
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    verify(() => face.credential()).called(1);
  });

  testWidgets('status refresh has loading, failure and success feedback', (
    tester,
  ) async {
    final face = MockFace();
    final pending = Completer<Map<String, dynamic>?>();
    var reads = 0;
    when(() => face.credential()).thenAnswer((_) {
      reads++;
      return reads == 2
          ? pending.future
          : Future.value({'id': 'old', 'approved': true});
    });
    await tester.pumpWidget(faceCard(face));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tải lại trạng thái khuôn mặt'));
    await tester.tap(find.text('Tải lại trạng thái khuôn mặt'));
    await tester.pump();
    expect(find.text('Đang tải trạng thái…'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    pending.completeError(Exception('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Mã đăng ký: old'), findsOneWidget);
    expect(find.textContaining('Kiểm tra kết nối mạng'), findsOneWidget);
    await tester.ensureVisible(find.text('Tải lại trạng thái khuôn mặt'));
    await tester.tap(find.text('Tải lại trạng thái khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('Đã cập nhật trạng thái khuôn mặt.'), findsOneWidget);
    verify(() => face.credential()).called(3);
  });

  testWidgets('enrollment requires consent and does not claim attendance', (
    tester,
  ) async {
    final face = MockFace();
    when(() => face.credential()).thenAnswer((_) async => null);
    when(() => face.submit('enroll'))
        .thenAnswer((_) async => {'status': 'enrolled'});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          faceCameraServiceProvider.overrideWithValue(face),
          currentUserEmployeeIdProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: FaceCameraCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Vào làm bằng camera'),
      findsNothing,
    );
    await tester.tap(find.text('Đăng ký khuôn mặt'));
    await tester.pumpAndSettle();
    verifyNever(() => face.submit(any()));
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    verifyNever(() => face.submit(any()));
    await tester.tap(find.text('Đăng ký khuôn mặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    verify(() => face.submit('enroll')).called(1);
    expect(find.textContaining('Đã đăng ký khuôn mặt.'), findsOneWidget);
    expect(find.textContaining('Đã ghi nhận'), findsNothing);
  });

  testWidgets('enrolled employee can see status but cannot clock personally', (
    tester,
  ) async {
    final face = MockFace();
    when(() => face.credential())
        .thenAnswer((_) async => {'id': 'f1', 'approved': true});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [faceCameraServiceProvider.overrideWithValue(face)],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: FaceCameraCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Khuôn mặt đã sẵn sàng chấm công.'), findsOneWidget);
    expect(find.text('Vào làm bằng camera'), findsNothing);
    expect(find.text('Ra về bằng camera'), findsNothing);
    verifyNever(() => face.submit(any()));
    expect(find.textContaining('Đã ghi nhận'), findsNothing);
  });
}
