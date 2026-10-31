import 'package:demo_nfc/features/business/business_repository.dart';
import 'package:demo_nfc/features/business/face_camera_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements BusinessRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockRepository repo;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    repo = MockRepository();
    when(() => repo.action('begin_face_camera', any()))
        .thenAnswer((_) async => {'id': 'challenge-1', 'turn_first': true});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FaceCameraService.channel, null);
  });
  test('server preflight error is shown without opening camera or submitting a scan', () async {
    var opened = false;
    when(() => repo.action('begin_face_camera', any()))
        .thenThrow(Exception('Chưa có mẫu khuôn mặt để chấm công.'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FaceCameraService.channel, (_) async {
          opened = true;
          return null;
        });
    await expectLater(
      FaceCameraService(repo).submit('check_in', deviceId: 'kiosk-1'),
      throwsA(predicate((e) => '$e'.contains('Chưa có mẫu khuôn mặt'))),
    );
    expect(opened, isFalse);
    verifyNever(() => repo.action('finish_face_camera', any()));
  });
  test(
    'camera cancellation never submits a verification or attendance',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(FaceCameraService.channel, (_) async {
            throw PlatformException(code: 'FACE_CANCELLED');
          });
      await expectLater(
        FaceCameraService(repo).submit('check_in'),
        throwsA(isA<PlatformException>()),
      );
      verifyNever(() => repo.action('finish_face_camera', any()));
    },
  );
  test(
    'capture submits its model and vectors with the server challenge',
    () async {
      final vector = List<double>.generate(128, (i) => i == 0 ? 1 : 0);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(FaceCameraService.channel, (call) async {
            expect(call.arguments['turnFirst'], true);
            expect(call.arguments['purpose'], 'check_in');
            return {
              'first': vector,
              'last': vector,
              'model': 'sface-2021dec-v1',
            };
          });
      when(() => repo.action('finish_face_camera', any()))
          .thenAnswer((_) async => {'status': 'ok'});
      expect(
        await FaceCameraService(repo).submit('check_in', deviceId: 'kiosk-1'),
        {'status': 'ok'},
      );
      final payload =
          verify(() => repo.action('finish_face_camera', captureAny()))
                  .captured
                  .single
              as Map;
      expect(payload['challenge_id'], 'challenge-1');
      expect(payload['first'], vector);
      expect(payload['model'], 'sface-2021dec-v1');
      verify(
        () => repo.action('begin_face_camera', {
          'purpose': 'check_in',
          'device_id': 'kiosk-1',
        }),
      ).called(1);
    },
  );
  for (final purpose in ['enroll', 'reenroll', 'check_out']) {
    test(
      'capture receives $purpose so enrollment and attendance stay distinct',
      () async {
        final vector = List<double>.generate(128, (i) => i == 0 ? 1 : 0);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(FaceCameraService.channel, (call) async {
              expect(call.arguments['purpose'], purpose);
              return {
                'first': vector,
                'last': vector,
                'model': 'sface-2021dec-v1',
              };
            });
        when(() => repo.action('finish_face_camera', any()))
            .thenAnswer((_) async => {'status': 'ok'});
        await FaceCameraService(
          repo,
        ).submit(purpose, deviceId: purpose == 'check_out' ? 'kiosk-1' : null);
        verify(() => repo.action('finish_face_camera', any())).called(1);
      },
    );
  }
}
