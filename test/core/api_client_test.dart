import 'dart:convert';

import 'package:demo_nfc/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('connection failures have an actionable API error', () async {
    final api = ApiClient(
      'http://10.0.2.2:5080',
      transport: MockClient((_) async {
        throw http.ClientException('Connection refused');
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.signIn('test@example.local', 'test-password'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'connection_failed')
            .having((e) => e.status, 'status', 0),
      ),
    );
  });

  test(
    'REST client encodes search parameters and propagates server errors',
    () async {
      final api = ApiClient(
        'http://localhost:5080/',
        transport: MockClient((request) async {
          expect(request.url.path, '/api/employees');
          expect(request.url.queryParameters['query'], 'Nguyen & Tran');
          return http.Response(jsonEncode({'error': 'Forbidden'}), 403);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.list('/employees', query: {'query': 'Nguyen & Tran'}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    },
  );

  test(
    'login persists token scoped to API and sends bearer on subsequent calls',
    () async {
      var requests = 0;
      final api = ApiClient(
        'http://localhost:5080',
        transport: MockClient((request) async {
          requests++;
          if (request.url.path.endsWith('/login')) {
            expect(jsonDecode(request.body)['password'], 'correct-password');
            return http.Response(
              jsonEncode({
                'token': 'test-token',
                'user': {
                  'id': 'u1',
                  'email': 'a@test.local',
                  'role': 'admin',
                  'employee_id': null,
                },
              }),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('[]', 200);
        }),
      );
      addTearDown(api.close);
      await api.signIn('a@test.local', 'correct-password');
      await api.list('/employees');
      expect(api.currentUser!.role, 'admin');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'attendance_api_session_v1:http://localhost:5080',
        ),
        'test-token',
      );
      expect(requests, 2);
    },
  );

  test(
    'expired persisted token is cleared instead of granting stale access',
    () async {
      SharedPreferences.setMockInitialValues({
        'attendance_api_session_v1:http://localhost:5080': 'expired',
      });
      final api = ApiClient(
        'http://localhost:5080',
        transport: MockClient(
          (_) async => http.Response('{"error":"Expired"}', 401),
        ),
      );
      addTearDown(api.close);
      await api.initialize();
      expect(api.currentUser, isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'attendance_api_session_v1:http://localhost:5080',
        ),
        isFalse,
      );
    },
  );
}
